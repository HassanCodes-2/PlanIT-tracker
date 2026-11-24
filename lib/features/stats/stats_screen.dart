import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/load_error.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';
import '../../domain/streak.dart';
import '../../domain/stats.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriodType _period = StatsPeriodType.months;

  DateTime _earliest(
    List<db.Deed> deeds,
    List<db.DeedLog> logs,
    DateTime fallback,
  ) {
    final dates = <DateTime>[
      ...deeds.map((deed) => dateOnly(deed.createdAt)),
      ...logs.map((log) => dateOnly(log.day)),
    ];
    if (dates.isEmpty) return fallback;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Widget _deltaChip(
    StatsResult result,
    List<db.Deed> deeds,
    List<db.DeedLog> logs,
    DateTime from,
    StatsPeriodType period,
  ) {
    final theme = Theme.of(context);
    final prevFrom = from.subtract(Duration(days: period.days));
    final prevTo = from.subtract(const Duration(days: 1));
    final prev = computeStats(
      deeds: deeds,
      logs: logs,
      from: prevFrom,
      to: prevTo,
    );
    if (prev.expected == 0 && result.expected == 0) {
      return const SizedBox.shrink();
    }
    final diff = result.donePct - prev.donePct;
    final up = diff >= 0;
    final digital = context.appStyle.isDigital;
    final Color color;
    if (diff.abs() < 1) {
      color = theme.colorScheme.onSurfaceVariant;
    } else if (digital) {
      color = up
          ? theme.colorScheme.secondary
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    } else {
      final isLight = theme.brightness == Brightness.light;
      color = up
          ? (isLight ? AppColors.doneLight : const Color(0xFF4ADE80))
          : (isLight ? AppColors.skippedLight : const Color(0xFFFF9B9B));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? AppIcons.trendUp : AppIcons.trendDown,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${diff.abs().round()} pts vs last ${period.label.toLowerCase()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deedsAsync = ref.watch(deedsProvider);
    final logsAsync = ref.watch(allLogsProvider);

    final deeds = deedsAsync.value;
    final logs = logsAsync.value;

    if (deedsAsync.hasError || logsAsync.hasError) {
      return Scaffold(
        body: LoadError(
          onRetry: () {
            ref.invalidate(deedsProvider);
            ref.invalidate(allLogsProvider);
          },
        ),
      );
    }

    if (deeds == null || logs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = dateOnly(DateTime.now());
    final from = _period == StatsPeriodType.all
        ? _earliest(deeds, logs, today)
        : today.subtract(Duration(days: _period.days - 1));
    final loggedDays = logs
        .where((log) {
          final status = LogStatus.fromDb(log.status);
          return status == LogStatus.done || status == LogStatus.late;
        })
        .map((log) => dateOnly(log.day))
        .toSet();
    final streakNow = currentStreak(loggedDays, today: today);
    final bestRun = bestStreak(loggedDays);
    final result = computeStats(
      deeds: deeds,
      logs: logs,
      from: from,
      to: today,
    );

    final digital = context.appStyle.isDigital;
    final doneColor =
        AppColors.outcome(LogStatus.done, theme, digital: digital);
    final lateColor =
        AppColors.outcome(LogStatus.late, theme, digital: digital);
    final skippedColor =
        AppColors.outcome(LogStatus.skipped, theme, digital: digital);
    final missedColor = AppColors.missed(theme, digital: digital);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: deeds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.trendUp,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No stats yet',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a deed and start logging to see your trends.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/create-deed'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create a deed'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.xxl),
              children: [
                _Label('CONSISTENCY · LAST 7 DAYS'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _Heatmap(
                      deeds: deeds,
                      logs: logs,
                      today: today,
                      days: 7,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _Legend(
                  doneColor: doneColor,
                  lateColor: lateColor,
                  skippedColor: skippedColor,
                  missedColor: missedColor,
                ),
                const SizedBox(height: 24),
                _Label('PROGRESS OVERVIEW'),
                const SizedBox(height: 10),
                _SlidingPeriodBar(
                  selected: _period,
                  onSelect: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Label('STATUS SUMMARY'),
                    if (_period != StatsPeriodType.all)
                      _deltaChip(result, deeds, logs, from, _period),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: width,
                          child: _RingStat(
                            label: 'On time',
                            percent: result.donePct,
                            color: doneColor,
                            icon: AppIcons.done,
                            count: result.done,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _RingStat(
                            label: 'Done late',
                            percent: result.latePct,
                            color: lateColor,
                            icon: AppIcons.late,
                            count: result.late,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _RingStat(
                            label: 'Skipped',
                            percent: result.skippedPct,
                            color: skippedColor,
                            icon: AppIcons.skipped,
                            count: result.skipped,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _RingStat(
                            label: 'Missed',
                            percent: result.missedPct,
                            color: missedColor,
                            icon: AppIcons.missed,
                            count: result.missed,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _Label('STREAKS · ALL TIME'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StreakCard(
                        icon: AppIcons.fire,
                        color: digital
                            ? theme.colorScheme.primary
                            : AppTheme.ensureVisible(
                                const Color(0xFFF97316),
                                theme.colorScheme.surface,
                                theme.brightness,
                                ratio: 3.0,
                              ),
                        label: 'Current streak',
                        value: '$streakNow ${streakNow == 1 ? 'day' : 'days'}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StreakCard(
                        icon: AppIcons.star,
                        color: digital
                            ? theme.colorScheme.onSurfaceVariant
                            : AppTheme.ensureVisible(
                                const Color(0xFFF59E0B),
                                theme.colorScheme.surface,
                                theme.brightness,
                                ratio: 3.0,
                              ),
                        label: 'Best streak',
                        value: '$bestRun ${bestRun == 1 ? 'day' : 'days'}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Label('STATS BY DEEDS · ${_period.label.toUpperCase()}'),
                const SizedBox(height: 6),
                ...result.deeds.map(
                  (stats) => _DeedStatsRow(
                    stats: stats,
                    onTap: () => context.push('/deed?id=${stats.deed.id}'),
                  ),
                ),
                if (result.deeds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Nothing scheduled in this period.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.doneColor,
    required this.lateColor,
    required this.skippedColor,
    required this.missedColor,
  });

  final Color doneColor;
  final Color lateColor;
  final Color skippedColor;
  final Color missedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _item(theme, AppIcons.done, 'Done', doneColor),
        _item(theme, AppIcons.late, 'Late', lateColor),
        _item(theme, AppIcons.skipped, 'Skipped', skippedColor),
        _item(theme, AppIcons.missed, 'Missed', missedColor),
        _item(
          theme,
          Icons.crop_square_rounded,
          'No entry',
          theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _item(ThemeData theme, IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({
    required this.deeds,
    required this.logs,
    required this.today,
    required this.days,
  });

  final List<db.Deed> deeds;
  final List<db.DeedLog> logs;
  final DateTime today;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digital = context.appStyle.isDigital;
    final start = today.subtract(Duration(days: days - 1));
    final dateList =
        List.generate(days, (index) => start.add(Duration(days: index)));
    final logIndex = <String, LogStatus>{
      for (final log in logs)
        '${log.deedId}/${log.day.year}-${log.day.month}-${log.day.day}':
            LogStatus.fromDb(log.status),
    };

    String rowLabel(db.Deed deed) {
      var done = 0;
      var late = 0;
      var skipped = 0;
      var missed = 0;
      for (final day in dateList) {
        final status =
            logIndex['${deed.id}/${day.year}-${day.month}-${day.day}'];
        if (status != null) {
          switch (status) {
            case LogStatus.done:
              done++;
            case LogStatus.late:
              late++;
            case LogStatus.skipped:
              skipped++;
          }
        } else if (isScheduledOn(deed, day) &&
            !frequencyOf(deed).isCountBased &&
            day.isBefore(today)) {
          missed++;
        }
      }
      return '${deed.name}: $done done, $late late, $skipped skipped, '
          '$missed missed in the last $days days';
    }

    if (deeds.isEmpty) {
      return Text(
        'No scheduled deeds.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelWidth = 60.0;
          const gap = 4.0;
          const headerHeight = 34.0;
          final available = (constraints.maxWidth - labelWidth).clamp(0, 400);
          final cellSize =
              ((available - gap * days) / days).clamp(18.0, 34.0);
          final chartWidth = (cellSize + gap) * days;

          Widget cell(db.Deed deed, DateTime day) {
            final status =
                logIndex['${deed.id}/${day.year}-${day.month}-${day.day}'];
            final scheduled = isScheduledOn(deed, day) &&
                !frequencyOf(deed).isCountBased;
            final missed = status == null && scheduled && day.isBefore(today);

            Color fill;
            Color? borderColor;
            IconData? glyph;
            Color? glyphColor;

            if (status != null) {
              fill = AppColors.outcome(status, theme, digital: digital);
              glyph = switch (status) {
                LogStatus.done => AppIcons.done,
                LogStatus.late => AppIcons.late,
                LogStatus.skipped => AppIcons.skipped,
              };
              glyphColor = AppTheme.onColor(fill);
            } else if (missed) {
              fill = theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: digital ? 0.16 : 0.10);
              borderColor = theme.colorScheme.outline;
              glyph = AppIcons.missed;
              glyphColor = AppColors.missed(theme, digital: digital);
            } else {
              fill = theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: digital ? 0.06 : 0.06);
            }

            return Container(
              width: cellSize,
              height: cellSize,
              margin: const EdgeInsets.only(right: gap),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
                border:
                    borderColor != null ? Border.all(color: borderColor) : null,
              ),
              child: glyph == null
                  ? null
                  : Icon(glyph, size: cellSize * 0.52, color: glyphColor),
            );
          }

          Widget header(DateTime day) => SizedBox(
                width: cellSize + gap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('EE').format(day),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        height: 1.1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Column(
                      children: [
                        const SizedBox(height: headerHeight),
                        for (final deed in deeds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: SizedBox(
                              height: cellSize,
                              child: Tooltip(
                                message: deed.name,
                                child: Text(
                                  deed.name.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: chartWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: headerHeight,
                          child: Row(children: dateList.map(header).toList()),
                        ),
                        for (final deed in deeds)
                          Semantics(
                            label: rowLabel(deed),
                            child: ExcludeSemantics(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  children: dateList
                                      .map((day) => cell(deed, day))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: labelWidth),
                child: Text(
                  '${DateFormat('d MMM').format(start)} – today · one column per day',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({
    required this.label,
    required this.percent,
    required this.color,
    required this.icon,
    required this.count,
  });

  final String label;
  final double percent;
  final Color color;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      value: '${percent.round()} percent, $count times',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (percent / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(56, 56),
                        painter: _RingPainter(
                          progress: value,
                          color: color,
                          track: color.withValues(alpha: 0.12),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(value * 100).round()}%',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2 + 1);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, 6.283185307179586, false, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      -1.5707963267948966,
      6.283185307179586 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _SlidingPeriodBar extends StatelessWidget {
  const _SlidingPeriodBar({
    required this.selected,
    required this.onSelect,
  });

  final StatsPeriodType selected;
  final ValueChanged<StatsPeriodType> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periods = StatsPeriodType.values;
    final index = periods.indexOf(selected);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);

    return Container(
      height: 48 * textScale,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment(index * 2 / (periods.length - 1) - 1, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / periods.length,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: periods
                .map(
                  (period) => Expanded(
                    child: Semantics(
                      button: true,
                      selected: period == selected,
                      label: '${period.label} period',
                      child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(period),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: (theme.textTheme.labelMedium ?? const TextStyle())
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            color: period == selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          child: Text(period.label),
                        ),
                      ),
                    ),
                  ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DeedStatsRow extends StatelessWidget {
  const _DeedStatsRow({required this.stats, required this.onTap});

  final DeedStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (stats.completionRate * 100).round().clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  iconForDeed(
                    deedIcon: stats.deed.icon,
                    name: stats.deed.name,
                  ),
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.deed.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${stats.done} done · ${stats.late} late · ${stats.skipped} skipped · ${stats.missed} missed',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.caretRight,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$percent%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
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
