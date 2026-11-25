import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/prefs/prefs_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/enums.dart';

class _Area {
  const _Area(this.name, this.icon, this.color);

  final String name;
  final String icon;
  final String color;
}

const List<_Area> _areas = [
  _Area('Health', 'fitness_center', '#22C55E'),
  _Area('Learning', 'menu_book', '#3B82F6'),
  _Area('Work', 'work', '#F59E0B'),
  _Area('Social', 'groups', '#EC4899'),
  _Area('Faith', 'self_improvement', '#8B5CF6'),
  _Area('Finance', 'savings', '#10B981'),
  _Area('Fun', 'sports_esports', '#F97316'),
];

class _Suggestion {
  const _Suggestion({
    required this.area,
    required this.name,
    required this.icon,
    this.frequency = 'daily',
    this.weekdays,
    this.times,
  });

  final int area;
  final String name;
  final String icon;
  final String frequency;
  final String? weekdays;
  final int? times;
}

const List<_Suggestion> _suggestions = [
  _Suggestion(
      area: 0,
      name: 'Exercise 20 min',
      icon: 'fitness_center',
      frequency: 'weekdays',
      weekdays: '1,2,3,4,5'),
  _Suggestion(area: 0, name: 'Drink 2L water', icon: 'water_drop'),
  _Suggestion(area: 0, name: 'Sleep by 11pm', icon: 'bedtime'),
  _Suggestion(area: 1, name: 'Read 20 pages', icon: 'menu_book'),
  _Suggestion(area: 1, name: 'Practice a language', icon: 'school'),
  _Suggestion(
      area: 2,
      name: 'Deep work 90 min',
      icon: 'timer',
      frequency: 'weekdays',
      weekdays: '1,2,3,4,5'),
  _Suggestion(area: 2, name: 'Plan tomorrow', icon: 'edit_calendar'),
  _Suggestion(
      area: 3,
      name: 'Call family',
      icon: 'call',
      frequency: 'times_per_week',
      times: 2),
  _Suggestion(area: 3, name: 'Message a friend', icon: 'chat_bubble'),
  _Suggestion(area: 4, name: 'Morning reflection', icon: 'self_improvement'),
  _Suggestion(area: 4, name: 'Evening reflection', icon: 'self_improvement'),
  _Suggestion(area: 5, name: 'Track expenses', icon: 'savings'),
  _Suggestion(area: 5, name: 'No-spend day', icon: 'savings'),
  _Suggestion(area: 6, name: 'Hobby time 30 min', icon: 'sports_esports'),
  _Suggestion(area: 6, name: 'Walk outside', icon: 'fitness_center'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _page = 0;
  final Set<int> _selectedAreas = {0, 1, 2, 3};
  final Set<int> _selectedSuggestions = {0, 3, 6};
  Set<String> _existingNames = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDeeds();
  }

  Future<void> _loadExistingDeeds() async {
    try {
      final deeds = await ref.read(deedsProvider.future);
      if (!mounted) return;
      setState(() {
        _existingNames = deeds
            .map((deed) => deed.name.trim().toLowerCase())
            .toSet();
      });
    } catch (_) {
      // First-run setup still works if the list cannot be read yet.
    }
  }

  int get _newStarterCount => _selectedSuggestions.where((index) {
        final name = _suggestions[index].name.toLowerCase();
        return !_existingNames.contains(name);
      }).length;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pageController.nextPage(
        duration: AppTheme.motion(context, 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _skip() async {
    try {
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await ref.read(userNameProvider.notifier).set(name);
      }
      await ref.read(onboardedProvider.notifier).complete();
      if (mounted) context.go('/today');
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Could not skip setup. Try again.',
            duration: const Duration(milliseconds: 3000));
      }
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await ref.read(userNameProvider.notifier).set(name);
      }

      final repository = ref.read(repositoryProvider);
      final existing = (await repository.allDeeds())
          .map((deed) => deed.name.trim().toLowerCase())
          .toSet();
      var categories = await repository.allCategories();

      db.Category? categoryFor(_Area area) {
        for (final candidate in categories) {
          if (candidate.name.toLowerCase() == area.name.toLowerCase()) {
            return candidate;
          }
        }
        return null;
      }

      // Persist every chosen focus area as a category, even if the user
      // unchecks all suggestions inside it.
      for (final areaIndex in _selectedAreas) {
        final area = _areas[areaIndex];
        if (categoryFor(area) != null) continue;
        final id = await repository.createCategory(
          name: area.name,
          icon: area.icon,
          color: area.color,
          sortOrder: 10 + areaIndex,
        );
        final created = await repository.categoryById(id);
        if (created != null) categories = [...categories, created];
      }

      for (final index in _selectedSuggestions) {
        final suggestion = _suggestions[index];
        if (existing.contains(suggestion.name.toLowerCase())) continue;

        final area = _areas[suggestion.area];
        final category = categoryFor(area);

        await repository.createDeed(
          db.DeedsCompanion(
            name: Value(suggestion.name),
            categoryId: Value(category?.id),
            frequencyType: Value(suggestion.frequency),
            weekdays: Value(suggestion.weekdays),
            timesPerPeriod: Value(suggestion.times),
            icon: Value(suggestion.icon),
          ),
        );
      }

      await ref.read(onboardedProvider.notifier).complete();
      if (mounted) context.go('/today');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, 'Could not finish setup. Please try again.',
            duration: const Duration(milliseconds: 3000));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleSuggestions = _suggestions
        .where((suggestion) => _selectedAreas.contains(suggestion.area))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton.icon(
                      onPressed: () => _pageController.previousPage(
                        duration: AppTheme.motion(context, 250),
                        curve: Curves.easeOutCubic,
                      ),
                      icon: const Icon(AppIcons.back, size: 18),
                      label: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 76),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  _welcomePage(theme),
                  _areasPage(theme),
                  _deedsPage(theme, visibleSuggestions),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final active = index == _page;
                      return Semantics(
                        button: true,
                        selected: active,
                        label: 'Step ${index + 1}',
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: AppTheme.motion(context, 250),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _pageController.animateToPage(
                              index,
                              duration: AppTheme.motion(context, 250),
                              curve: Curves.easeOutCubic,
                            ),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: AppTheme.motion(context, 200),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  width: active ? 22 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme
                                            .onSurfaceVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      disabledBackgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.65),
                      disabledForegroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                              semanticsLabel: 'Saving starter deeds',
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _page == 2
                                    ? AppIcons.rocket
                                    : AppIcons.forward,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(_page == 2 ? 'Let\'s go' : 'Continue'),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen, vertical: 24),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.check,
                color: theme.colorScheme.onPrimary,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to PlanIT',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Build habits, tick your days,\nand watch the streaks grow.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A deed is any habit or task you want to repeat.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 36),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'What should we call you?',
            ),
          ),
        ],
            ),
          ),
        );
      },
    );
  }

  Widget _areasPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What matters\nright now?',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick as many as you like — you can change these later.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_areas.length, (index) {
              final area = _areas[index];
              final selected = _selectedAreas.contains(index);
              return FilterChip(
                label: Text(area.name),
                avatar: Icon(
                  iconForName(area.icon, fallback: Icons.star_rounded),
                  size: 18,
                  color: context.appStyle.isDigital
                      ? theme.colorScheme.onSurfaceVariant
                      : AppTheme.ensureVisible(
                          colorFromHex(area.color),
                          theme.cardTheme.color ?? theme.colorScheme.surface,
                          theme.brightness,
                          ratio: 3.2,
                        ),
                ),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedAreas.add(index);
                    } else {
                      _selectedAreas.remove(index);
                      _selectedSuggestions
                          .removeWhere((s) => _suggestions[s].area == index);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _deedsPage(ThemeData theme, List<_Suggestion> visible) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen, vertical: 32),
      children: [
        Text(
          'Pick starter deeds',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'You can add, edit or remove these anytime.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text(
          _newStarterCount == 0
              ? 'No new starter deeds — your existing ones are kept.'
              : '$_newStarterCount new starter ${_newStarterCount == 1 ? 'deed' : 'deeds'} will be added.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No starter deeds for the selected areas. You can add your own later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ...visible.asMap().entries.map((entry) {
          final suggestionIndex = _suggestions.indexOf(entry.value);
          final suggestion = entry.value;
          final selected = _selectedSuggestions.contains(suggestionIndex);
          final area = _areas[suggestion.area];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.10)
                  : theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
                side: BorderSide(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (!_selectedSuggestions.remove(suggestionIndex)) {
                      _selectedSuggestions.add(suggestionIndex);
                    }
                  });
                },
                child: Semantics(
                  button: true,
                  toggled: selected,
                  label: suggestion.name,
                  child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: AppTheme.motion(context, 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? Icon(AppIcons.check,
                                size: 16, color: theme.colorScheme.onPrimary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        iconForName(suggestion.icon,
                            fallback: AppIcons.check),
                        color: context.appStyle.isDigital
                      ? theme.colorScheme.onSurfaceVariant
                      : AppTheme.ensureVisible(
                          colorFromHex(area.color),
                          theme.cardTheme.color ?? theme.colorScheme.surface,
                          theme.brightness,
                          ratio: 3.2,
                        ),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suggestion.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        FrequencyType.fromDb(suggestion.frequency).label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          );
        }),
      ],
    );
  }
}