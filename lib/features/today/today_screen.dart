import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/prefs/prefs_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/confetti.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';
import '../../domain/quotes.dart';
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

    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final timeLabel = DateFormat('HH:mm').format(now);
    final userName = ref.watch(userNameProvider);
    final dateLabel = userName.isEmpty
        ? DateFormat('EEEE, d MMMM').format(day)
        : '$userName · ${DateFormat('EEEE, d MMMM').format(day)}';

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
        child: Stack(
          children: [
            if (context.appStyle.isDigital)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GridPainter(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
            ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _DateHeader(
              timeLabel: timeLabel,
              dateLabel: dateLabel,
              streak: streak,
              done: doneCount,
              total: scheduled.length,
              isDark: isDark,
              onToggleTheme: () => _toggleTheme(context, ref),
            ),
            _DayScroller(
              today: today,
              selected: day,
              onSelect: (value) {
                HapticFeedback.selectionClick();
                ref.read(selectedDayProvider.notifier).select(value);
              },
            ),
            if (!isFuture)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Text(
                  '“${quoteForDay(today)}”',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (isFuture)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  'Planning view — logging opens on the day.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else if (scheduled.isNotEmpty && logs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  'Tap a deed to mark it done · long-press for more options',
                  textAlign: TextAlign.center,
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
                  allLogs: allLogs,
                  selectedDay: day,
                  canLog: !isFuture,
                  onTap: (deed) => _onTapDeed(
                    context,
                    ref,
                    deed,
                    day,
                    logs,
                    doneCount,
                    scheduled.length,
                  ),
                  onLongPress: (deed) =>
                      _showOutcomeSheet(context, ref, deed, day, logs),
                ),
              ),
              if (uncategorized.isNotEmpty)
                _CategorySection(
                  category: null,
                  deeds: uncategorized,
                  logs: logs,
                  allLogs: allLogs,
                  selectedDay: day,
                  canLog: !isFuture,
                  onTap: (deed) => _onTapDeed(
                    context,
                    ref,
                    deed,
                    day,
                    logs,
                    doneCount,
                    scheduled.length,
                  ),
                  onLongPress: (deed) =>
                      _showOutcomeSheet(context, ref, deed, day, logs),
                ),
              if (doneCount >= scheduled.length && !isFuture)
                const _CaughtUpCard(),
            ],
          ],
        ),
            ],
          ),
        ),
    );
  }

  void _toggleTheme(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
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

  Future<void> _onTapDeed(
    BuildContext context,
    WidgetRef ref,
    db.Deed deed,
    DateTime day,
    Map<int, db.DeedLog> logs,
    int doneCount,
    int total,
  ) async {
    if (logs[deed.id] == null) {
      await _markDone(context, ref, deed, day, logs, doneCount, total);
    } else {
      await _showOutcomeSheet(context, ref, deed, day, logs);
    }
  }

  Future<void> _markDone(
    BuildContext context,
    WidgetRef ref,
    db.Deed deed,
    DateTime day,
    Map<int, db.DeedLog> logs,
    int doneCount,
    int total,
  ) async {
    final repository = ref.read(repositoryProvider);
    final existing = logs[deed.id];
    if (existing == null) {
      await repository.setLog(deed.id, day, LogStatus.done);
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        final name = ref.read(userNameProvider);
        final allDone = doneCount + 1 >= total && total > 0;
        if (allDone) {
          HapticFeedback.heavyImpact();
          showConfetti(context);
        }
        _snack(
          context,
          allDone
              ? 'All deeds done${name.isEmpty ? '' : ', $name'}! 🎉'
              : 'Marked "${deed.name}" done',
          () => repository.clearLog(deed.id, day),
        );
      }
    } else {
      await _showOutcomeSheet(context, ref, deed, day, logs);
    }
  }

  Future<void> _showOutcomeSheet(
    BuildContext context,
    WidgetRef ref,
    db.Deed deed,
    DateTime day,
    Map<int, db.DeedLog> logs,
  ) async {
    if (day.isAfter(dateOnly(DateTime.now()))) return;

    final theme = Theme.of(context);
    final repository = ref.read(repositoryProvider);
    final existing = logs[deed.id];
    final digital = context.appStyle.isDigital;
    final doneColor =
        digital ? theme.colorScheme.primary : const Color(0xFF22C55E);
    final lateColor =
        digital ? theme.colorScheme.onSurfaceVariant : const Color(0xFFF59E0B);
    final skippedColor =
        digital ? theme.colorScheme.onSurfaceVariant : const Color(0xFFEF4444);

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
                icon: Icons.timer_rounded,
                color: theme.colorScheme.primary,
                label: 'Start focus session',
                selected: false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/focus?id=${deed.id}');
                },
              ),
              _OutcomeTile(
                icon: AppIcons.done,
                color: doneColor,
                label: 'Done on time',
                selected: existing?.status == LogStatus.done.dbValue,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await repository.setLog(deed.id, day, LogStatus.done);
                  HapticFeedback.mediumImpact();
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
                icon: AppIcons.late,
                color: lateColor,
                label: 'Done late',
                selected: existing?.status == LogStatus.late.dbValue,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await repository.setLog(deed.id, day, LogStatus.late);
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
                icon: AppIcons.skipped,
                color: skippedColor,
                label: 'Skipped',
                selected: existing?.status == LogStatus.skipped.dbValue,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
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
              _OutcomeTile(
                icon: Icons.bar_chart_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                label: 'View history & stats',
                selected: false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/deed?id=${deed.id}');
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
                    Navigator.of(sheetContext).pop();
                    await repository.clearLog(deed.id, day);
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
    required this.timeLabel,
    required this.dateLabel,
    required this.streak,
    required this.done,
    required this.total,
    required this.isDark,
    required this.onToggleTheme,
  });

  final String timeLabel;
  final String dateLabel;
  final int streak;
  final int done;
  final int total;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: context.appStyle.isDigital ? 2.4 : 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
          const SizedBox(height: 12),
          _SegmentBar(done: done, total: total),
          const SizedBox(height: 8),
          Row(
              children: [
                Icon(
                  AppIcons.fire,
                  size: 16,
                  color: context.appStyle.isDigital
                      ? theme.colorScheme.primary
                      : const Color(0xFFF97316),
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak-day streak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  AppIcons.done,
                  size: 16,
                  color: context.appStyle.isDigital
                      ? theme.colorScheme.onSurfaceVariant
                      : const Color(0xFF22C55E),
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
      height: 68,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == widget.selected.year &&
              day.month == widget.selected.month &&
              day.day == widget.selected.day;
          final theme = Theme.of(context);
          final digital = context.appStyle.isDigital;
          return InkWell(
            borderRadius: BorderRadius.circular(digital ? 8 : 12),
            onTap: () => widget.onSelect(day),
            child: Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(digital ? 8 : 12),
                boxShadow: digital && isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.30),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
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

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digital = context.appStyle.isDigital;
    final count = total <= 0 ? 12 : total.clamp(1, 24);
    final filled = total <= 0
        ? 0
        : ((done / total) * count).round().clamp(0, count);

    return Row(
      children: List.generate(count, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == count - 1 ? 0 : 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: digital ? 6 : 5,
              decoration: BoxDecoration(
                color: index < filled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
                boxShadow: digital && index < filled
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.deeds,
    required this.logs,
    required this.allLogs,
    required this.selectedDay,
    required this.canLog,
    required this.onTap,
    required this.onLongPress,
  });

  final db.Category? category;
  final List<db.Deed> deeds;
  final Map<int, db.DeedLog> logs;
  final List<db.DeedLog> allLogs;
  final DateTime selectedDay;
  final bool canLog;
  final ValueChanged<db.Deed> onTap;
  final ValueChanged<db.Deed> onLongPress;

  String? _progressFor(db.Deed deed) {
    final frequency = frequencyOf(deed);
    if (!frequency.isCountBased) return null;
    final target = deed.timesPerPeriod ?? 1;
    final DateTime start;
    final DateTime end;
    if (frequency == FrequencyType.timesPerWeek) {
      start = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
      end = start.add(const Duration(days: 6));
    } else {
      start = DateTime(selectedDay.year, selectedDay.month, 1);
      end = DateTime(selectedDay.year, selectedDay.month + 1, 1)
          .subtract(const Duration(days: 1));
    }
    final done = allLogs
        .where((log) =>
            log.deedId == deed.id &&
            !dateOnly(log.day).isBefore(start) &&
            !dateOnly(log.day).isAfter(end))
        .length;
    final period =
        frequency == FrequencyType.timesPerWeek ? 'this week' : 'this month';
    return '$done/$target $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm + 2),
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
              progressText: _progressFor(deed),
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
    required this.progressText,
    required this.canLog,
    required this.onTap,
    required this.onLongPress,
  });

  final db.Deed deed;
  final db.Category? category;
  final db.DeedLog? log;
  final String? progressText;
  final bool canLog;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digital = context.appStyle.isDigital;
    final accent = digital
        ? theme.colorScheme.primary
        : colorFromHex(category?.color ?? '#1B6CFF');
    final status = log == null ? null : LogStatus.fromDb(log!.status);
    final completed = status != null;

    final (tint, icon, iconColor) = switch (status) {
      null => (
          accent.withValues(alpha: digital ? 0.05 : 0.06),
          null,
          accent
        ),
      LogStatus.done => digital
          ? (
              theme.colorScheme.primary.withValues(alpha: 0.12),
              AppIcons.done,
              theme.colorScheme.primary,
            )
          : (
              const Color(0xFF22C55E).withValues(alpha: 0.24),
              AppIcons.done,
              const Color(0xFF22C55E),
            ),
      LogStatus.late => digital
          ? (
              theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.14),
              AppIcons.late,
              theme.colorScheme.onSurfaceVariant,
            )
          : (
              const Color(0xFFF59E0B).withValues(alpha: 0.24),
              AppIcons.late,
              const Color(0xFFF59E0B),
            ),
      LogStatus.skipped => digital
          ? (
              theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.07),
              AppIcons.skipped,
              theme.colorScheme.onSurfaceVariant,
            )
          : (
              const Color(0xFFEF4444).withValues(alpha: 0.20),
              AppIcons.skipped,
              const Color(0xFFEF4444),
            ),
    };

    final hasReason = log?.reason != null && log!.reason!.isNotEmpty;
    final reminder = deed.reminderTime;
    final reminderLabel = (reminder != null && reminder.isNotEmpty)
        ? 'Reminder at $reminder'
        : null;
    final subtitle = hasReason ? log!.reason! : (progressText ?? reminderLabel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm + 2),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: IntrinsicHeight(
                child: Row(
                children: [
                  Container(width: 4, height: double.infinity,
                      color: digital
                          ? theme.colorScheme.primary.withValues(alpha: 0.45)
                          : accent),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: digital ? 0.10 : 0.12),
                      shape: digital ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius:
                          digital ? BorderRadius.circular(10) : null,
                    ),
                    child: Icon(
                      iconForDeed(
                        deedIcon: deed.icon,
                        categoryIcon: category?.icon,
                        name: deed.name,
                      ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration:
                                completed ? TextDecoration.lineThrough : null,
                            color: completed
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: canLog ? onLongPress : null,
                    tooltip: 'More actions',
                    iconSize: 20,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
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
            Icon(
              Icons.celebration_rounded,
              color: context.appStyle.isDigital
                  ? theme.colorScheme.primary
                  : const Color(0xFF22C55E),
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.huge, AppSpacing.screen, 0),
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
          ? Icon(AppIcons.done, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// Subtle HUD grid behind the Today screen (Digital theme only).
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 26.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.color != color;
}