import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
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
    final color = diff.abs() < 1
        ? theme.colorScheme.onSurfaceVariant
        : (up ? const Color(0xFF22C55E) : const Color(0xFFEF4444));
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
            '${diff.abs().round()}% vs prev',
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
    final categoriesAsync = ref.watch(categoriesProvider);

    final deeds = deedsAsync.value;
    final logs = logsAsync.value;
    final categories = categoriesAsync.value ?? const <db.Category>[];

    if (deeds == null || logs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = dateOnly(DateTime.now());
    final from = _period == StatsPeriodType.all
        ? _earliest(deeds, logs, today)
        : today.subtract(Duration(days: _period.days - 1));
    final loggedDays = logs.map((log) => dateOnly(log.day)).toSet();
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
        digital ? theme.colorScheme.primary : const Color(0xFF22C55E);
    final lateColor =
        digital ? theme.colorScheme.onSurfaceVariant : const Color(0xFFF59E0B);
    final skippedColor = digital
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65)
        : const Color(0xFFEF4444);
    final missedColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: deeds.isEmpty
          ? Center(
              child: Text(
                'Create a deed to see your stats.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _SlidingPeriodBar(
                  selected: _period,
                  onSelect: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 20),
                _Label('HEATMAP — LAST ${math.min(30, _period.days)} DAYS'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _Heatmap(
                      deeds: result.deeds,
                      logs: logs,
                      categories: categories,
                      days: math.min(30, _period.days),
                      today: today,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _Label('STREAKS'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StreakCard(
                        icon: AppIcons.fire,
                        color: digital
                            ? theme.colorScheme.primary
                            : const Color(0xFFF97316),
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
                            : const Color(0xFFF59E0B),
                        label: 'Best streak',
                        value: '$bestRun ${bestRun == 1 ? 'day' : 'days'}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _Label('STATUS SUMMARY'),
                    const Spacer(),
                    if (_period != StatsPeriodType.all)
                      _deltaChip(result, deeds, logs, from, _period),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    _RingStat(
                      percent: result.donePct,
                      color: doneColor,
                      icon: AppIcons.done,
                      count: result.done,
                    ),
                    _RingStat(
                      percent: result.latePct,
                      color: lateColor,
                      icon: AppIcons.late,
                      count: result.late,
                    ),
                    _RingStat(
                      percent: result.skippedPct,
                      color: skippedColor,
                      icon: AppIcons.skipped,
                      count: result.skipped,
                    ),
                    _RingStat(
                      percent: result.missedPct,
                      color: missedColor,
                      icon: AppIcons.missed,
                      count: result.missed,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Label('STATS BY DEEDS'),
                const SizedBox(height: 6),
                ...result.deeds.map(
                  (stats) => _DeedStatsRow(
                    stats: stats,
                    onTap: () =>
                        context.push('/deed?id=${stats.deed.id}'),
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

class _Heatmap extends StatelessWidget {
  const _Heatmap({
    required this.deeds,
    required this.logs,
    required this.categories,
    required this.days,
    required this.today,
  });

  final List<DeedStats> deeds;
  final List<db.DeedLog> logs;
  final List<db.Category> categories;
  final int days;
  final DateTime today;

  String? _categoryIcon(int? categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category.icon;
    }
    return null;
  }

  Color? _colorFor(
    Map<String, LogStatus> index,
    DeedStats stats,
    DateTime day,
    ThemeData theme,
    bool digital,
  ) {
    final status =
        index['${stats.deed.id}/${day.year}-${day.month}-${day.day}'];
    if (status != null) {
      if (digital) {
        return switch (status) {
          LogStatus.done => theme.colorScheme.onSurface,
          LogStatus.late => theme.colorScheme.onSurfaceVariant
              .withValues(alpha: 0.75),
          LogStatus.skipped => theme.colorScheme.onSurfaceVariant
              .withValues(alpha: 0.45),
        };
      }
      return switch (status) {
        LogStatus.done => const Color(0xFF22C55E),
        LogStatus.late => const Color(0xFFF59E0B),
        LogStatus.skipped => const Color(0xFFEF4444),
      };
    }
    if (!isScheduledOn(stats.deed, day)) return null;
    if (frequencyOf(stats.deed).isCountBased) return null;
    if (day.isBefore(today)) {
      return theme.colorScheme.onSurfaceVariant.withValues(
        alpha: digital ? 0.22 : 0.35,
      );
    }
    if (day.year == today.year &&
        day.month == today.month &&
        day.day == today.day) {
      return theme.colorScheme.primary.withValues(alpha: digital ? 0.30 : 0.25);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digital = context.appStyle.isDigital;
    final start = today.subtract(Duration(days: days - 1));
    final dateList = List.generate(days, (index) => start.add(Duration(days: index)));
    final index = <String, LogStatus>{
      for (final log in logs)
        '${log.deedId}/${log.day.year}-${log.day.month}-${log.day.day}':
            LogStatus.fromDb(log.status),
    };

    if (deeds.isEmpty) {
      return Text(
        'No scheduled deeds.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        for (final stats in deeds) ...[
          Row(
            children: [
              SizedBox(
                width: 34,
                child: Tooltip(
                  message: stats.deed.name,
                  child: Icon(
                    iconForDeed(
                      deedIcon: stats.deed.icon,
                      categoryIcon: _categoryIcon(stats.deed.categoryId),
                      name: stats.deed.name,
                    ),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: dateList.map((day) {
                    final color = _colorFor(index, stats, day, theme, digital);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color ??
                                theme.colorScheme.outline
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 34),
            Text(
              DateFormat('d MMM').format(dateList.first),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              'Today',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
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
        borderRadius: BorderRadius.circular(16),
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
    required this.percent,
    required this.color,
    required this.icon,
    required this.count,
  });

  final double percent;
  final Color color;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
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
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(76, 76),
                      painter: _RingPainter(
                        progress: value,
                        color: color,
                        track: color.withValues(alpha: 0.12),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
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
        ],
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

    return Container(
      height: 46,
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
    final percent = (stats.completionRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
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
