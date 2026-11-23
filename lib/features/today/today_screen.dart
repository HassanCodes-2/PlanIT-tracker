import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

/// M0: Today screen with mock data, matching the demo's layout.
/// M2 replaces the mock state with Supabase-backed repositories.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _MockDeed {
  const _MockDeed(this.name, this.icon);

  final String name;
  final IconData icon;
}

class _MockCategory {
  const _MockCategory(this.name, this.deeds, this.icon);

  final String name;
  final List<_MockDeed> deeds;
  final IconData icon;
}

class _TodayScreenState extends State<TodayScreen> {
  final DateTime _today = DateTime.now();
  late DateTime _selectedDay = _today;
  final Set<String> _done = <String>{};

  static const List<_MockCategory> _categories = [
    _MockCategory('Health', [
      _MockDeed('Exercise 20 min', Icons.fitness_center_rounded),
      _MockDeed('Drink 2L water', Icons.water_drop_rounded),
      _MockDeed('Sleep by 11pm', Icons.bedtime_rounded),
    ], Icons.favorite_rounded),
    _MockCategory('Learning', [
      _MockDeed('Read 20 pages', Icons.menu_book_rounded),
      _MockDeed('Practice a language', Icons.translate_rounded),
    ], Icons.school_rounded),
    _MockCategory('Work', [
      _MockDeed('Plan tomorrow', Icons.edit_calendar_rounded),
      _MockDeed('Deep work 90 min', Icons.timer_rounded),
    ], Icons.work_rounded),
    _MockCategory('Social', [
      _MockDeed('Call a family member', Icons.call_rounded),
    ], Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-deed'),
        tooltip: 'Create new deed',
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _DateHeader(selectedDay: _selectedDay),
            _DayScroller(
              today: _today,
              selected: _selectedDay,
              onSelect: (day) => setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 8),
            ..._categories.map(
              (category) => _CategorySection(
                category: category,
                isDone: (deed) => _done.contains('${category.name}/${deed.name}'),
                onTap: (deed) {
                  final key = '${category.name}/${deed.name}';
                  setState(() {
                    if (!_done.remove(key)) _done.add(key);
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Mock data — live deeds arrive in M2.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.selectedDay});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _isSameDay(selectedDay, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Text(
            '${isToday ? 'Today, ' : ''}${DateFormat('d MMMM, yyyy').format(selectedDay)}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE').format(selectedDay),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayScroller extends StatelessWidget {
  const _DayScroller({
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      15,
      (index) => DateTime(today.year, today.month, today.day - 6 + index),
    );
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, selected);
          final theme = Theme.of(context);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(day),
            child: Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : theme.colorScheme.outline,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.isDone,
    required this.onTap,
  });

  final _MockCategory category;
  final bool Function(_MockDeed) isDone;
  final ValueChanged<_MockDeed> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              category.name.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...category.deeds.map(
            (deed) => _DeedCard(
              deed: deed,
              done: isDone(deed),
              onTap: () => onTap(deed),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeedCard extends StatelessWidget {
  const _DeedCard({
    required this.deed,
    required this.done,
    required this.onTap,
  });

  final _MockDeed deed;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(deed.icon, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    deed.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? theme.colorScheme.outline : null,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: done ? 56 : 84,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        (done ? AppColors.done : AppColors.accent)
                            .withValues(alpha: done ? 0.28 : 0.06),
                      ],
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.done, size: 22)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;