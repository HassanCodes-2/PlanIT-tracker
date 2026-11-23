import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/prefs/prefs_providers.dart';
import '../../core/utils/icons.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';
import '../../domain/streak.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(selectedDayProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final deedsAsync = ref.watch(deedsProvider);
    final logsAsync = ref.watch(logsForDayProvider(day));
    final allLogsAsync = ref.watch(allLogsProvider);

    final categories = categoriesAsync.value;
    final deeds = deedsAsync.value;
    final logs = logsAsync.value ?? const <int, db.DeedLog>{};
    final allLogs = allLogsAsync.value ?? const <db.DeedLog>[];

    if (categories == null || deeds == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = dateOnly(DateTime.now());
    final isFuture = day.isAfter(today);
    final scheduled = deeds.where((deed) => isScheduledOn(deed, day)).toList();
    final doneCount =
        scheduled.where((deed) => logs[deed.id] != null).length;

    final loggedDays = allLogs.map((log) => dateOnly(log.day)).toSet();
    final streak = currentStreak(loggedDays, today: today);

    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final grouped = <db.Category, List<db.Deed>>{};
    for (final category in categories) {
      final items =
          scheduled.where((deed) => deed.categoryId == category.id).toList();
      if (items.isNotEmpty) grouped[category] = items;
    }
    final uncategorized =
        scheduled.where((deed) => deed.categoryId == null).toList();

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
            _DateHeader(
              day: day,
              done: doneCount,
              total: scheduled.length,
              streak: streak,
              isDark: isDark,
              onToggleTheme: () => _toggleTheme(context, ref),
            ),
            _DayScroller(
              today: today,
              selected: day,
              onSelect: (value) =>
                  ref.read(selectedDayProvider.notifier).select(value),
            ),
            if (isFuture)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Planning view — logging opens on the day.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else if (scheduled.isNotEmpty && logs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Tap a deed to mark it done · long-press for more options',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (scheduled.isEmpty)
              _EmptyState(onCreate: () => context.push('/create-deed'))
            else ...[
              ...grouped.entries.map(
                (entry) => _CategorySection(
                  category: entry.key,
                  deeds: entry.value,
                  logs: logs,
                  canLog: !isFuture,
                  onTap: (deed) => _markDone(context, ref, deed, day, logs),
                  onLongPress: (deed) =>
                      _showOutcomeSheet(context, ref, deed, day, logs[deed.id]),
                ),
              ),
              if (uncategorized.isNotEmpty)
                _CategorySection(
                  category: null,
                  deeds: uncategorized,
                  logs: logs,
                  canLog: !isFuture,
                  onTap: (deed) => _markDone(context, ref, deed, day, logs),
                  onLongPress: (deed) =>
                      _showOutcomeSheet(context, ref, deed, day, logs[deed.id]),
                ),
              if (doneCount >= scheduled.length && !isFuture)
                const _CaughtUpCard(),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleTheme(BuildContext context, WidgetRef ref) {
    final mode = ref.read(themeModeProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    ref
        .read(themeModeProvider.notifier)
        .setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  void _snack(BuildContext context, String message, VoidCallback? undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ));
  }

  Future<void> _markDone(
    BuildContext context,
    WidgetRef ref,
    db.Deed deed,
    DateTime day,
    Map<int, db.DeedLog> logs,
  ) async {
    final repository = ref.read(repositoryProvider);
    final existing = logs[deed.id];
    if (existing == null) {
      await repository.setLog(deed.id, day, LogStatus.done);
      if (context.mounted) {
        _snack(
          context,
          'Marked "${deed.name}" done',
          () => repository.clearLog(deed.id, day),
        );
      }
    } else {
      final previous = existing;
      await repository.clearLog(deed.id, day);
      if (context.mounted) {
        _snack(
          context,
          'Removed log for "${deed.name}"',
          () => repository.setLog(
            deed.id,
            day,
            LogStatus.fromDb(previous.status),
            reason: previous.reason,
          ),
        );
      }
    }
  }

  Future<void> _showOutcomeSheet(
    BuildContext context,
    WidgetRef ref,
    db.Deed deed,
    DateTime day,
    db.DeedLog? existing,
  ) async {
    if (day.isAfter(dateOnly(DateTime.now()))) return;

    final theme = Theme.of(context);
    final repository = ref.read(repositoryProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.cardTheme.color,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        deed.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push('/create-deed?id=${deed.id}');
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              _OutcomeTile(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF22C55E),
                label: 'Done on time',
                selected: existing?.status == LogStatus.done.dbValue,
                onTap: () async {
                  await repository.setLog(deed.id, day, LogStatus.done);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    _snack(
                      context,
                      'Marked "${deed.name}" done',
                      () => repository.clearLog(deed.id, day),
                    );
                  }
                },
              ),
              _OutcomeTile(
                icon: Icons.schedule_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Done late',
                selected: existing?.status == LogStatus.late.dbValue,
                onTap: () async {
                  await repository.setLog(deed.id, day, LogStatus.late);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    _snack(
                      context,
                      'Logged "${deed.name}" as late',
                      () => repository.clearLog(deed.id, day),
                    );
                  }
                },
              ),
              _OutcomeTile(
                icon: Icons.remove_circle_rounded,
                color: const Color(0xFFEF4444),
                label: 'Skipped',
                selected: existing?.status == LogStatus.skipped.dbValue,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  String? reason;
                  if (deed.reasonsEnabled) {
                    reason = await _askReason(context);
                    if (reason == null) return;
                  }
                  await repository.setLog(
                    deed.id,
                    day,
                    LogStatus.skipped,
                    reason: (reason == null || reason.isEmpty) ? null : reason,
                  );
                  if (context.mounted) {
                    _snack(
                      context,
                      'Skipped "${deed.name}"',
                      () => repository.clearLog(deed.id, day),
                    );
                  }
                },
              ),
              if (existing != null)
                _OutcomeTile(
                  icon: Icons.restart_alt_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  label: 'Clear today\'s log',
                  selected: false,
                  onTap: () async {
                    final previous = existing;
                    await repository.clearLog(deed.id, day);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (context.mounted) {
                      _snack(
                        context,
                        'Cleared log for "${deed.name}"',
                        () => repository.setLog(
                          deed.id,
                          day,
                          LogStatus.fromDb(previous.status),
                          reason: previous.reason,
                        ),
                      );
                    }
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Why was it skipped?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Optional note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.day,
    required this.done,
    required this.total,
    required this.streak,
    required this.isDark,
    required this.onToggleTheme,
  });

  final DateTime day;
  final int done;
  final int total;
  final int streak;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${isToday ? 'Today, ' : ''}${DateFormat('d MMMM, yyyy').format(day)}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: Color(0xFFF97316),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak-day streak',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          total == 0 ? 'No deeds' : '$done of $total done',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Switch theme',
                onPressed: onToggleTheme,
                icon: Icon(
                  isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayScroller extends StatefulWidget {
  const _DayScroller({
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayScroller> createState() => _DayScrollerState();
}

class _DayScrollerState extends State<_DayScroller> {
  final ScrollController _controller =
      ScrollController(initialScrollOffset: 172);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      15,
      (index) => DateTime(
        widget.today.year,
        widget.today.month,
        widget.today.day - 6 + index,
      ),
    );
    return SizedBox(
      height: 64,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == widget.selected.year &&
              day.month == widget.selected.month &&
              day.day == widget.selected.day;
          final theme = Theme.of(context);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.onSelect(day),
            child: Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
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
                          : theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
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
    required this.deeds,
    required this.logs,
    required this.canLog,
    required this.onTap,
    required this.onLongPress,
  });

  final db.Category? category;
  final List<db.Deed> deeds;
  final Map<int, db.DeedLog> logs;
  final bool canLog;
  final ValueChanged<db.Deed> onTap;
  final ValueChanged<db.Deed> onLongPress;

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
              (category?.name ?? 'Other').toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...deeds.map(
            (deed) => _DeedCard(
              deed: deed,
              category: category,
              log: logs[deed.id],
              canLog: canLog,
              onTap: () => onTap(deed),
              onLongPress: () => onLongPress(deed),
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
    required this.category,
    required this.log,
    required this.canLog,
    required this.onTap,
    required this.onLongPress,
  });

  final db.Deed deed;
  final db.Category? category;
  final db.DeedLog? log;
  final bool canLog;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = colorFromHex(category?.color ?? '#1B6CFF');
    final status = log == null ? null : LogStatus.fromDb(log!.status);
    final completed = status != null;

    final (tint, icon, iconColor) = switch (status) {
      null => (accent.withValues(alpha: 0.06), null, accent),
      LogStatus.done => (
          const Color(0xFF22C55E).withValues(alpha: 0.24),
          Icons.check_rounded,
          const Color(0xFF22C55E),
        ),
      LogStatus.late => (
          const Color(0xFFF59E0B).withValues(alpha: 0.24),
          Icons.schedule_rounded,
          const Color(0xFFF59E0B),
        ),
      LogStatus.skipped => (
          const Color(0xFFEF4444).withValues(alpha: 0.20),
          Icons.close_rounded,
          const Color(0xFFEF4444),
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Opacity(
        opacity: canLog ? 1 : 0.6,
        child: Material(
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canLog ? onTap : null,
            onLongPress: canLog ? onLongPress : null,
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  Container(width: 4, height: double.infinity, color: accent),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconForName(deed.icon ?? category?.icon,
                          fallback: Icons.check_rounded),
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deed.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration:
                                completed ? TextDecoration.lineThrough : null,
                            color: completed
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (log?.reason != null && log!.reason!.isNotEmpty)
                          Text(
                            log!.reason!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: completed ? 56 : 84,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, tint],
                      ),
                    ),
                    child: icon == null
                        ? null
                        : Icon(icon, color: iconColor, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaughtUpCard extends StatelessWidget {
  const _CaughtUpCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.celebration_rounded,
              color: Color(0xFF22C55E),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All caught up!',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You completed every deed for today. See you tomorrow!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded,
              size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'No deeds for this day',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a deed to start tracking your daily habits.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a deed'),
          ),
        ],
      ),
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}