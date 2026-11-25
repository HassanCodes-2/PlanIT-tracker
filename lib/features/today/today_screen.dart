import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/prefs/prefs_providers.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/load_error.dart';
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
    final logs = logsAsync.value;
    final allLogs = allLogsAsync.value;

    if (categoriesAsync.hasError ||
        deedsAsync.hasError ||
        logsAsync.hasError ||
        allLogsAsync.hasError) {
      return Scaffold(
        body: LoadError(
          onRetry: () {
            ref.invalidate(categoriesProvider);
            ref.invalidate(deedsProvider);
            ref.invalidate(logsForDayProvider(day));
            ref.invalidate(allLogsProvider);
          },
        ),
      );
    }

    if (categories == null ||
        deeds == null ||
        logs == null ||
        allLogs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = dateOnly(DateTime.now());
    final isFuture = day.isAfter(today);
    final scheduled = deeds.where((deed) => isScheduledOn(deed, day)).toList();
    final dailyScheduled = scheduled
        .where((deed) => !frequencyOf(deed).isCountBased)
        .toList();
    final doneCount = dailyScheduled.where((deed) {
      final log = logs[deed.id];
      if (log == null) return false;
      final status = LogStatus.fromDb(log.status);
      return status == LogStatus.done || status == LogStatus.late;
    }).length;
    final hasIncompleteGoals = scheduled.any(
      (deed) => frequencyOf(deed).isCountBased && !goalIsMet(deed, allLogs, day),
    );

    final loggedDays = allLogs
        .where((log) {
          final status = LogStatus.fromDb(log.status);
          return status == LogStatus.done || status == LogStatus.late;
        })
        .map((log) => dateOnly(log.day))
        .toSet();
    final streak = currentStreak(loggedDays, today: today);

    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final use24Hour = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? true;
    final timeLabel = use24Hour
        ? DateFormat('HH:mm').format(now)
        : DateFormat('h:mm a').format(now);
    final userName = ref.watch(userNameProvider);
    final date = DateFormat('EEEE, d MMMM yyyy').format(day);
    final dateLabel = userName.isEmpty ? date : '$date · $userName';

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
        child: const Icon(AppIcons.add),
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
          padding: const EdgeInsets.only(bottom: 150),
          children: [
            _DateHeader(
              timeLabel: timeLabel,
              dateLabel: dateLabel,
              onPickDate: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(today.year, today.month, today.day - 365),
                  lastDate: DateTime(today.year, today.month, today.day + 365),
                );
                if (picked != null) {
                  ref.read(selectedDayProvider.notifier).select(picked);
                }
              },
              streak: streak,
              done: doneCount,
              total: dailyScheduled.length,
              isFuture: isFuture,
              showToday: !(day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day),
              onToday: () => ref.read(selectedDayProvider.notifier).select(today),
            ),
            _DayScroller(
              today: today,
              selected: day,
              onSelect: (value) {
                HapticFeedback.selectionClick();
                ref.read(selectedDayProvider.notifier).select(value);
              },
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
            else if (!isFuture && scheduled.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  'Tap a card: done · tap the status: outcomes',
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
                    dailyScheduled.length,
                  ),
                  onLongPress: (deed) =>
                      _showOutcomeSheet(context, ref, deed, day, logs),
                  onFocus: (deed) => _openFocus(context, deed, day),

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
                    dailyScheduled.length,
                  ),
                  onLongPress: (deed) =>
                      _showOutcomeSheet(context, ref, deed, day, logs),
                  onFocus: (deed) => _openFocus(context, deed, day),

                ),
              if (dailyScheduled.isNotEmpty &&
                  doneCount >= dailyScheduled.length &&
                  !isFuture)
                _CaughtUpCard(
                  day: day,
                  hasGoals: hasIncompleteGoals,
                ),
            ],
          ],
        ),
            ],
          ),
        ),
    );
  }

  void _snack(BuildContext context, String message, VoidCallback? undo) {
    AppToast.show(
      context,
      message,
      actionLabel: undo == null ? null : 'Undo',
      onAction: undo,
      duration: undo == null
          ? const Duration(milliseconds: 2400)
          : const Duration(seconds: 5),
    );
  }

  void _openFocus(BuildContext context, db.Deed deed, DateTime day) {
    context.push(
      '/focus?id=${deed.id}&day=${DateFormat('yyyy-MM-dd').format(day)}',
    );
  }

  Future<void> _archiveDeed(
    BuildContext context,
    WidgetRef ref,
    db.Deed deed,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive this deed?'),
        content: const Text(
          'It disappears from Today and Stats. Past logs are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = ref.read(repositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    await repository.archiveDeed(deed.id);
    await notifications.syncAll(await repository.allDeeds());
    if (!context.mounted) return;
    AppToast.show(
      context,
      '"${deed.name}" archived',
      actionLabel: 'Undo',
      onAction: () async {
        await repository.unarchiveDeed(deed.id);
        await notifications.syncAll(await repository.allDeeds());
      },
      duration: const Duration(seconds: 5),
    );
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
        final allDone = !frequencyOf(deed).isCountBased &&
            doneCount + 1 >= total &&
            total > 0;
        if (allDone) {
          HapticFeedback.heavyImpact();
          showConfetti(context);
        }
        _snack(
          context,
          allDone
              ? 'All daily deeds done${name.isEmpty ? '' : ', $name'}! 🎉'
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
        AppColors.outcome(LogStatus.done, theme, digital: digital);
    final lateColor =
        AppColors.outcome(LogStatus.late, theme, digital: digital);
    final skippedColor =
        AppColors.outcome(LogStatus.skipped, theme, digital: digital);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardTheme.color,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
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
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              _OutcomeTile(
                icon: AppIcons.focus,
                color: theme.colorScheme.primary,
                label: 'Start focus session',
                selected: false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/focus?id=${deed.id}&day=${DateFormat('yyyy-MM-dd').format(day)}',
                  );
                },
              ),
              _OutcomeTile(
                icon: AppIcons.done,
                color: doneColor,
                label: 'Done on time',
                selected: existing?.status == LogStatus.done.dbValue,
                onTap: () async {
                  final previous = existing;
                  Navigator.of(sheetContext).pop();
                  await repository.setLog(deed.id, day, LogStatus.done);
                  HapticFeedback.mediumImpact();
                  if (context.mounted) {
                    _snack(
                      context,
                      'Marked "${deed.name}" done',
                      () => previous == null
                          ? repository.clearLog(deed.id, day)
                          : repository.setLog(
                              deed.id,
                              day,
                              LogStatus.fromDb(previous.status),
                              reason: previous.reason,
                            ),
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
                  final previous = existing;
                  Navigator.of(sheetContext).pop();
                  HapticFeedback.selectionClick();
                  await repository.setLog(deed.id, day, LogStatus.late);
                  if (context.mounted) {
                    _snack(
                      context,
                      'Logged "${deed.name}" as late',
                      () => previous == null
                          ? repository.clearLog(deed.id, day)
                          : repository.setLog(
                              deed.id,
                              day,
                              LogStatus.fromDb(previous.status),
                              reason: previous.reason,
                            ),
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
                  final previous = existing;
                  Navigator.of(sheetContext).pop();
                  HapticFeedback.selectionClick();
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
                      () => previous == null
                          ? repository.clearLog(deed.id, day)
                          : repository.setLog(
                              deed.id,
                              day,
                              LogStatus.fromDb(previous.status),
                              reason: previous.reason,
                            ),
                    );
                  }
                },
              ),
              _OutcomeTile(
                icon: AppIcons.history,
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
                  icon: AppIcons.reset,
                  color: theme.colorScheme.onSurfaceVariant,
                  label: 'Clear log for ${DateFormat('d MMM').format(day)}',
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
              const Divider(height: 12),
              _OutcomeTile(
                icon: AppIcons.archive,
                color: theme.colorScheme.error,
                label: 'Archive deed',
                selected: false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _archiveDeed(context, ref, deed);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
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
    required this.onPickDate,
    required this.streak,
    required this.done,
    required this.total,
    required this.isFuture,
    required this.showToday,
    required this.onToday,
  });

  final String timeLabel;
  final String dateLabel;
  final VoidCallback onPickDate;
  final int streak;
  final int done;
  final int total;
  final bool isFuture;
  final bool showToday;
  final VoidCallback onToday;

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
                        fontFamily: context.appStyle.isDigital
                            ? 'RobotoMono'
                            : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      dateLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (showToday)
                TextButton(
                  onPressed: onToday,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: theme.colorScheme.secondary,
                  ),
                  child: const Text('Today'),
                ),
              IconButton(
                tooltip: 'Pick a date',
                onPressed: onPickDate,
                icon: const Icon(AppIcons.calendar),
              ),
            ],
          ),
          if (!isFuture && total > 0) ...[
            const SizedBox(height: 12),
            _SegmentBar(done: done, total: total),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 8),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.fire,
                      size: 16,
                      color: context.appStyle.isDigital
                          ? theme.colorScheme.primary
                          : AppTheme.ensureVisible(
                              const Color(0xFFF97316),
                              theme.colorScheme.surface,
                              theme.brightness,
                              ratio: 3.0,
                            ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streak-day streak',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.done,
                      size: 16,
                      color: AppColors.outcome(
                        LogStatus.done,
                        theme,
                        digital: context.appStyle.isDigital,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFuture
                          ? (total == 0 ? 'No daily deeds' : '$total planned')
                          : (total == 0
                              ? 'No daily deeds'
                              : '$done of $total done'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
  static const int _window = 365;
  final ScrollController _controller = ScrollController(
    initialScrollOffset: _window * 54.0 - 151,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _centerSelected(animate: false);
      }
    });
  }

  void _centerSelected({required bool animate}) {
    final index =
        widget.selected.difference(dateOnly(widget.today)).inDays + _window;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final tileWidth = 48.0 * scale;
    final itemExtent = tileWidth + 6;
    final viewport = _controller.position.viewportDimension;
    final leadingItems =
        (((viewport - tileWidth) / 2) / itemExtent).floor().toInt();
    final target = ((index - leadingItems) * itemExtent + AppSpacing.screen)
        .clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(covariant _DayScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.selected.year != widget.selected.year ||
        oldWidget.selected.month != widget.selected.month ||
        oldWidget.selected.day != widget.selected.day;
    if (!changed || !_controller.hasClients) return;
    _centerSelected(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      _window * 2 + 1,
      (index) => DateTime(
        widget.today.year,
        widget.today.month,
        widget.today.day - _window + index,
      ),
    );
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final tileWidth = 48.0 * scale;
    return SizedBox(
      height: 68 + 80 * (scale - 1),
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
          return Semantics(
            button: true,
            selected: isSelected,
            label: DateFormat('EEEE d MMMM').format(day),
            onTap: () => widget.onSelect(day),
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(digital ? 8 : 12),
                onTap: () => widget.onSelect(day),
                child: Container(
                  width: tileWidth,
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
              duration: AppTheme.motion(context, 300),
              height: digital ? 6 : 5,
              decoration: BoxDecoration(
                color: index < filled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
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
    required this.onFocus,
  });

  final db.Category? category;
  final List<db.Deed> deeds;
  final Map<int, db.DeedLog> logs;
  final List<db.DeedLog> allLogs;
  final DateTime selectedDay;
  final bool canLog;
  final ValueChanged<db.Deed> onTap;
  final ValueChanged<db.Deed> onLongPress;
  final ValueChanged<db.Deed> onFocus;


  String? _progressFor(db.Deed deed) {
    final frequency = frequencyOf(deed);
    if (!frequency.isCountBased) return null;
    final target = deed.timesPerPeriod ?? 1;
    final done = _goalDoneFor(deed) ?? 0;
    final period =
        frequency == FrequencyType.timesPerWeek ? 'this week' : 'this month';
    final capped = done > target ? target : done;
    return '$capped/$target $period';
  }

  int? _goalDoneFor(db.Deed deed) {
    if (!frequencyOf(deed).isCountBased) return null;
    return goalDoneCount(deed, allLogs, selectedDay);
  }

  bool _goalMet(db.Deed deed) => goalIsMet(deed, allLogs, selectedDay);

  void _goalAlreadyMet(
    BuildContext context,
    db.Deed deed,
    String? progress,
  ) {
    HapticFeedback.selectionClick();
    AppToast.show(
      context,
      '${deed.name}: goal met${progress == null ? '' : ' · $progress'}.',
      actionLabel: 'History',
      onAction: () => context.push('/deed?id=${deed.id}'),
      duration: const Duration(seconds: 5),
    );
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
            child: Semantics(
              header: true,
              child: Text(
                (category?.name ?? 'Other').toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ...deeds.map((deed) {
            final goalMet = _goalMet(deed);
            final progress = _progressFor(deed);
            final hasTodayLog = logs[deed.id] != null;
            return _DeedCard(
              deed: deed,
              category: category,
              log: logs[deed.id],
              progressText: progress,
              goalMet: goalMet,
              canLog: canLog,
              onTap: goalMet && !hasTodayLog
                  ? () => _goalAlreadyMet(context, deed, progress)
                  : () => onTap(deed),
              onLongPress: () => onLongPress(deed),
              onFocus: () => onFocus(deed),
            );
          }),
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
    required this.goalMet,
    required this.canLog,
    required this.onTap,
    required this.onLongPress,
    required this.onFocus,
  });

  final db.Deed deed;
  final db.Category? category;
  final db.DeedLog? log;
  final String? progressText;
  final bool goalMet;
  final bool canLog;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFocus;


  String? _reminderLabel(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return 'Reminder at ${TimeOfDay(hour: hour, minute: minute).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digital = context.appStyle.isDigital;
    final accent = digital || category == null
        ? theme.colorScheme.primary
        : AppTheme.ensureVisible(
            colorFromHex(category!.color),
            theme.cardTheme.color ?? theme.colorScheme.surface,
            theme.brightness,
            ratio: 3.2,
          );
    final status = log == null ? null : LogStatus.fromDb(log!.status);
    final logged = status != null;
    final succeeded =
        status == LogStatus.done || status == LogStatus.late;
    final completedGoal = goalMet && status == null;
    final goalColor = AppColors.outcome(LogStatus.done, theme, digital: digital);

    final statusColor = status != null
        ? AppColors.outcome(status, theme, digital: digital)
        : (goalMet ? goalColor : accent);
    final tint = status == null && !goalMet
        ? accent.withValues(alpha: digital ? 0.05 : 0.06)
        : statusColor.withValues(alpha: digital ? 0.12 : 0.18);
    final (Color iconTint, IconData? icon) = switch (status) {
      null => (
          statusColor,
          goalMet ? statusIcon(LogStatus.done, digital: digital) : null
        ),
      LogStatus.done => (statusColor, statusIcon(status, digital: digital)),
      LogStatus.late => (statusColor, statusIcon(status, digital: digital)),
      LogStatus.skipped => (statusColor, statusIcon(status, digital: digital)),
    };

    final hasReason = log?.reason != null && log!.reason!.isNotEmpty;
    final reminder = deed.reminderTime;
    final reminderLabel = _reminderLabel(context, reminder);
    final subtitle = hasReason
        ? log!.reason!
        : (completedGoal
            ? 'Goal met${progressText == null ? '' : ' · $progressText'}'
            : (progressText ?? reminderLabel));
    final statusLabel = status?.label ?? (completedGoal ? 'goal met' : null);
    final semanticsLabel = '${deed.name}'
        '${statusLabel != null ? ', $statusLabel' : (!canLog ? ', planned' : ', not logged')}'
        '${subtitle != null && subtitle.isNotEmpty ? ', $subtitle' : ''}';

    return Semantics(
      container: true,
      button: canLog,
      label: semanticsLabel,
      onTap: canLog ? onTap : null,
      onLongPress: canLog ? onLongPress : null,
      customSemanticsActions: canLog
          ? {
              const CustomSemanticsAction(label: 'Start focus session'):
                  onFocus,
              const CustomSemanticsAction(label: 'Log outcome'): onLongPress,
            }
          : null,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm + 2),
        child: Material(
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration:
                                succeeded ? TextDecoration.lineThrough : null,
                            color: succeeded
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
                  if (canLog)
                    IconButton(
                      onPressed: onFocus,
                      tooltip: 'Start focus session',
                      iconSize: 20,
                      icon: Icon(
                        AppIcons.focus,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Tooltip(
                    message: canLog ? 'Change outcome' : 'Planned',
                    child: InkWell(
                      onTap: canLog ? onLongPress : null,
                      child: AnimatedContainer(
                        duration: AppTheme.motion(context, 200),
                        width: logged ? 56 : 64,
                        height: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.transparent, tint],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            icon == null
                                ? (!canLog
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            AppIcons.calendar,
                                            size: 18,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'PLAN',
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                fontSize: 11,
                                                letterSpacing: 0.8,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(
                                        context.appStyle.isDigital
                                            ? AppIcons.uncheckedSquare
                                            : AppIcons.circle,
                                        size: 20,
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ))
                                : Icon(icon, color: iconTint, size: 20),
                            if (canLog)
                              Positioned(
                                right: logged ? 5 : 9,
                                bottom: 6,
                                child: Icon(
                                  AppIcons.caretDown,
                                  size: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
  const _CaughtUpCard({required this.day, required this.hasGoals});

  final DateTime day;
  final bool hasGoals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = dateOnly(day) == dateOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.confetti,
              color: AppColors.outcome(
                LogStatus.done,
                theme,
                digital: context.appStyle.isDigital,
              ),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasGoals ? 'Daily deeds complete' : 'All caught up!',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasGoals
                        ? 'All daily deeds for ${isToday ? 'today' : DateFormat('d MMM').format(day)} are done. Weekly goals stay open below.'
                        : 'You completed every deed for '
                            '${isToday ? 'today. See you tomorrow!' : '${DateFormat('d MMM').format(day)}.'}',
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
          Icon(
              AppIcons.calendar,
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
            icon: const Icon(AppIcons.add),
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
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
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
