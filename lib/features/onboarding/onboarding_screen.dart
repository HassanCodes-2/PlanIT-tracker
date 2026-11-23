import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/prefs/prefs_providers.dart';
import '../../core/utils/icons.dart';
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
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await ref.read(userNameProvider.notifier).set(name);
    }

    final repository = ref.read(repositoryProvider);
    final existing = (await repository.allDeeds())
        .map((deed) => deed.name.trim().toLowerCase())
        .toSet();
    var categories = await repository.allCategories();

    for (final index in _selectedSuggestions) {
      final suggestion = _suggestions[index];
      if (existing.contains(suggestion.name.toLowerCase())) continue;

      final area = _areas[suggestion.area];
      db.Category? category;
      for (final candidate in categories) {
        if (candidate.name.toLowerCase() == area.name.toLowerCase()) {
          category = candidate;
          break;
        }
      }
      if (category == null) {
        final id = await repository.createCategory(
          name: area.name,
          icon: area.icon,
          color: area.color,
          sortOrder: 10 + suggestion.area,
        );
        category = await repository.categoryById(id);
        categories = [...categories, ?category];
      }

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
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _next,
                    icon: _page == 2
                        ? const Icon(Icons.rocket_launch_rounded)
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      _page == 2
                          ? 'Let\'s go'
                          : 'Continue',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
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
    );
  }

  Widget _areasPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
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
                  color: colorFromHex(area.color),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
        const SizedBox(height: 20),
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
                borderRadius: BorderRadius.circular(14),
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
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
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        iconForName(suggestion.icon,
                            fallback: Icons.check_rounded),
                        color: colorFromHex(area.color),
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
          );
        }),
      ],
    );
  }
}