import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications/notification_service.dart';
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

  db.Deed? _existing;
  bool _loading = false;
  bool _saving = false;

  FrequencyType _frequency = FrequencyType.daily;
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  int? _categoryId;
  int? _parentId;
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
    'favorite',
    'star',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.deedId != null) {
      _loadDeed();
    }
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
      _parentId = deed.parentId;
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
    super.dispose();
  }

  String _formatReminder(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

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
      parentId: Value(_parentId),
      frequencyType: Value(frequencyValue),
      weekdays: Value(weekdaysValue),
      timesPerPeriod: Value(timesValue),
      reasonsEnabled: Value(_reasonsEnabled),
      reminderTime: Value(reminderValue),
      icon: Value(_icon),
    );

    final repository = ref.read(repositoryProvider);
    if (_existing == null) {
      await repository.createDeed(companion);
    } else {
      await repository.updateDeed(_existing!, companion);
    }

    final deeds = await repository.allDeeds();
    await ref.read(notificationServiceProvider).syncAll(deeds);

    if (mounted) context.pop();
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
        .createCategory(name: name, icon: 'star');
    if (mounted) setState(() => _categoryId = id);
  }

  Future<void> _archive() async {
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
    final deeds = ref.watch(deedsProvider).value ?? [];

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }

    final parentOptions = deeds
        .where((deed) => _existing == null || deed.id != _existing!.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_existing == null ? 'Create new deed' : 'Edit deed'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Deed name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give your deed a name'
                  : null,
            ),
            const SizedBox(height: 20),
            _Label('ICON'),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _icons.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final name = _icons[index];
                  final selected = name == _icon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _icon = name),
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary.withValues(alpha: 0.16)
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      child: Icon(
                        iconForName(name, fallback: Icons.star_rounded),
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _Label('CATEGORY'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...categories.map((category) {
                  final selected = category.id == _categoryId;
                  return ChoiceChip(
                    label: Text(category.name),
                    avatar: Icon(
                      iconForName(category.icon, fallback: Icons.star_rounded),
                      size: 18,
                    ),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _categoryId = category.id),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
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
                if (value != null) setState(() => _frequency = value);
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
                      });
                    },
                  );
                }),
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
                  if (parsed == null || parsed < 1 || parsed > 31) {
                    return 'Enter a number between 1 and 31';
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
                  Icons.notifications_none_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  _reminder == null
                      ? 'No reminder'
                      : _reminder!.format(context),
                ),
                trailing: _reminder == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _reminder = null),
                      ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminder ?? const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (picked != null) setState(() => _reminder = picked);
                },
              ),
            ),
            const SizedBox(height: 20),
            _Label('PARENT DEED (OPTIONAL)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _parentId,
              decoration: const InputDecoration(hintText: 'None'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('None'),
                ),
                ...parentOptions.map(
                  (deed) => DropdownMenuItem<int?>(
                    value: deed.id,
                    child: Text(deed.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _parentId = value),
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
              onChanged: (value) => setState(() => _reasonsEnabled = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_existing == null ? 'Create deed' : 'Save changes'),
            ),
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
