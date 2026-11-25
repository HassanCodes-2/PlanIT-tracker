import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/prefs/prefs_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';

class CreateDeedScreen extends ConsumerStatefulWidget {
  const CreateDeedScreen({super.key, this.deedId});

  final int? deedId;

  @override
  ConsumerState<CreateDeedScreen> createState() => _CreateDeedScreenState();
}

class _CreateDeedScreenState extends ConsumerState<CreateDeedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _timesController = TextEditingController(text: '3');
  final _scrollController = ScrollController();

  db.Deed? _existing;
  bool _loading = false;
  bool _saving = false;

  FrequencyType _frequency = FrequencyType.daily;
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  int? _categoryId;
  bool _dirty = false;
  bool _weekdayError = false;
  bool _reasonsEnabled = false;
  TimeOfDay? _reminder;
  String _icon = 'fitness_center';

  static const _icons = <String>[
    'fitness_center',
    'menu_book',
    'work',
    'groups',
    'water_drop',
    'bedtime',
    'timer',
    'edit_calendar',
    'call',
    'school',
    'self_improvement',
    'savings',
    'chat_bubble',
    'sports_esports',
    'favorite',
    'star',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_touch);
    _timesController.addListener(_touch);
    if (widget.deedId != null) {
      _loadDeed();
    }
  }

  void _touch() {
    _dirty = true;
  }

  Future<void> _loadDeed() async {
    setState(() => _loading = true);
    final deed =
        await ref.read(repositoryProvider).deedById(widget.deedId!);
    if (!mounted) return;
    if (deed != null) {
      _existing = deed;
      _nameController.text = deed.name;
      _frequency = FrequencyType.fromDb(deed.frequencyType);
      _weekdays = parseWeekdays(deed.weekdays);
      if (_weekdays.isEmpty) _weekdays = {1, 2, 3, 4, 5};
      _timesController.text = '${deed.timesPerPeriod ?? 3}';
      _categoryId = deed.categoryId;
      _dirty = false;
      _reasonsEnabled = deed.reasonsEnabled;
      _icon = deed.icon ?? 'fitness_center';
      final reminder = deed.reminderTime;
      if (reminder != null) {
        final parts = reminder.split(':');
        if (parts.length == 2) {
          _reminder = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatReminder(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _leave() async {
    final dirty = _dirty ||
        (_existing == null && _nameController.text.trim().isNotEmpty);
    if (!dirty) {
      if (mounted) context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to this deed will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the highlighted fields before saving.'),
        ),
      );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (_frequency == FrequencyType.weekdays && _weekdays.isEmpty) {
      setState(() => _weekdayError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one weekday for this deed.'),
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _weekdayError = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    final frequencyValue = _frequency.dbValue;
    final weekdaysValue = _frequency == FrequencyType.weekdays
        ? encodeWeekdays(_weekdays)
        : null;
    final timesValue = _frequency.isCountBased
        ? int.tryParse(_timesController.text.trim())
        : null;
    final reminderValue =
        _reminder == null ? null : _formatReminder(_reminder!);

    final companion = db.DeedsCompanion(
      name: Value(_nameController.text.trim()),
      categoryId: Value(_categoryId),
      frequencyType: Value(frequencyValue),
      weekdays: Value(weekdaysValue),
      timesPerPeriod: Value(timesValue),
      reasonsEnabled: Value(_reasonsEnabled),
      reminderTime: Value(reminderValue),
      icon: Value(_icon),
    );

    final repository = ref.read(repositoryProvider);
    try {
      if (_existing == null) {
        await repository.createDeed(companion);
      } else {
        await repository.updateDeed(_existing!, companion);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the deed. Try again.'),
          ),
        );
      }
      return;
    }

    // Close first, then refresh reminders in the background.
    _dirty = false;
    final notifications = ref.read(notificationServiceProvider);
    if (reminderValue != null) {
      final allowed = await notifications.ensurePermission();
      if (allowed == false) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Reminder saved, but notifications are off in Android settings.',
            ),
          ),
        );
      }
    }
    if (mounted) context.pop();
    final deeds = await repository.allDeeds();
    unawaited(notifications.syncAll(deeds));
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final id = await ref
        .read(repositoryProvider)
        .createCategory(
          name: name,
          icon: 'star',
          color: _accentHex(ref.read(accentColorProvider)),
        );
    if (mounted) setState(() => _categoryId = id);
  }

  String _accentHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

  Future<void> _archive() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive this deed?'),
        content: const Text(
          'It will disappear from your lists. Past logs are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = ref.read(repositoryProvider);
    await repository.archiveDeed(_existing!.id);
    await ref
        .read(notificationServiceProvider)
        .syncAll(await repository.allDeeds());
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? [];

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    ref.listen(categoriesProvider, (previous, next) {
      final list = next.value;
      if (widget.deedId == null &&
          list != null &&
          list.isNotEmpty &&
          _categoryId == null) {
        setState(() => _categoryId = list.first.id);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(AppIcons.back),
          onPressed: _leave,
        ),
        title: Text(_existing == null ? 'Create new deed' : 'Edit deed'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Deed name *',
                hintText: 'e.g. Read 20 pages',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give your deed a name'
                  : null,
            ),
            const SizedBox(height: 20),
            _Label('ICON'),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final columns = constraints.maxWidth >= 560 ? 8 : 4;
                final tile =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _icons.map((name) {
                    final selected = name == _icon;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: name.replaceAll('_', ' '),
                      onTap: () {
                        setState(() => _icon = name);
                        _dirty = true;
                      },
                      child: ExcludeSemantics(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _icon = name);
                            _dirty = true;
                          },
                          child: Container(
                            width: tile,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.16)
                                  : theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  iconForName(name,
                                      fallback: Icons.star_rounded),
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                if (selected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      AppIcons.done,
                                      size: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            _Label('CATEGORY'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: _categoryId == null,
                  onSelected: (_) {
                    setState(() {
                      _categoryId = null;
                      _dirty = true;
                    });
                  },
                ),
                ...categories.map((category) {
                  final selected = category.id == _categoryId;
                  return ChoiceChip(
                    label: Text(category.name),
                    avatar: Icon(
                      iconForName(category.icon, fallback: Icons.star_rounded),
                      size: 18,
                      color: AppTheme.ensureVisible(
                        colorFromHex(category.color),
                        theme.colorScheme.surface,
                        theme.brightness,
                        ratio: 3.2,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() {
                        _categoryId = category.id;
                        _dirty = true;
                      }),
                  );
                }),
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 18),
                  label: const Text('New'),
                  onPressed: _addCategory,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Label('FREQUENCY'),
            const SizedBox(height: 8),
            DropdownButtonFormField<FrequencyType>(
              initialValue: _frequency,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: FrequencyType.values
                  .map(
                    (frequency) => DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                setState(() => _frequency = value);
                _weekdayError = false;
                _dirty = true;
              }
              },
            ),
            if (_frequency == FrequencyType.weekdays) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  final selected = _weekdays.contains(weekday);
                  return FilterChip(
                    label: Text(weekdayShort[index]),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _weekdays.add(weekday);
                        } else {
                          _weekdays.remove(weekday);
                        }
                        _weekdayError = _weekdays.isEmpty;
                        _dirty = true;
                      });
                    },
                  );
                }),
              ),
              if (_weekdayError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Pick at least one day, or the deed will never appear.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
            if (_frequency.isCountBased) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _timesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _frequency == FrequencyType.timesPerWeek
                      ? 'Times per week'
                      : 'Times per month',
                ),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  final max = _frequency == FrequencyType.timesPerWeek ? 7 : 31;
                  if (parsed == null || parsed < 1 || parsed > max) {
                    return 'Enter a number between 1 and $max';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 20),
            _Label('REMINDER'),
            const SizedBox(height: 8),
            Material(
              color: theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  AppIcons.bell,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  _reminder == null
                      ? 'No reminder'
                      : _reminder!.format(context),
                ),
                trailing: _reminder == null
                    ? const Icon(AppIcons.caretRight)
                    : IconButton(
                        tooltip: 'Clear reminder',
                        icon: const Icon(AppIcons.close),
                        onPressed: () {
                        setState(() => _reminder = null);
                        _dirty = true;
                      },
                      ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminder ?? const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (picked != null) {
                    setState(() => _reminder = picked);
                    _dirty = true;
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Track reasons'),
              subtitle: Text(
                'Ask why when this deed is skipped.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              value: _reasonsEnabled,
              onChanged: (value) {
                    setState(() => _reasonsEnabled = value);
                    _dirty = true;
                  },
            ),
            const SizedBox(height: 24),
            if (_existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _archive,
                child: Text(
                  'Archive deed',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              disabledBackgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.65),
              disabledForegroundColor: theme.colorScheme.onPrimary,
            ),
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                      semanticsLabel: 'Saving deed',
                    ),
                  )
                : Text(_existing == null ? 'Create deed' : 'Save changes'),
          ),
        ),
      ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
