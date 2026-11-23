import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/icons.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deedsAsync = ref.watch(deedsProvider);
    final logsAsync = ref.watch(allLogsProvider);

    final deeds = deedsAsync.value;
    final logs = logsAsync.value;

    if (deeds == null || logs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = dateOnly(DateTime.now());
    final from = _period == StatsPeriodType.all
        ? _earliest(deeds, logs, today)
        : today.subtract(Duration(days: _period.days - 1));
    final result = computeStats(
      deeds: deeds,
      logs: logs,
      from: from,
      to: today,
    );

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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StatsPeriodType.values.map((period) {
                    return ChoiceChip(
                      label: Text(period.label),
                      selected: period == _period,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _period = period),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _Label('HEATMAP — LAST ${math.min(30, _period.days)} DAYS'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _Heatmap(
                      deeds: result.deeds.take(6).toList(),
                      logs: logs,
                      days: math.min(30, _period.days),
                      today: today,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _Label('STATUS SUMMARY'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: [
                    _SummaryCard(
                      label: 'Done',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF22C55E),
                      percent: result.donePct,
                      count: result.done,
                    ),
                    _SummaryCard(
                      label: 'Done late',
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFF59E0B),
                      percent: result.latePct,
                      count: result.late,
                    ),
                    _SummaryCard(
                      label: 'Skipped',
                      icon: Icons.remove_circle_rounded,
                      color: const Color(0xFFEF4444),
                      percent: result.skippedPct,
                      count: result.skipped,
                    ),
                    _SummaryCard(
                      label: 'Missed',
                      icon: Icons.highlight_off_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      percent: result.missedPct,
                      count: result.missed,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Label('STATS BY DEEDS'),
                const SizedBox(height: 6),
                ...result.deeds.map((stats) => _DeedStatsRow(stats: stats)),
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
    required this.days,
    required this.today,
  });

  final List<DeedStats> deeds;
  final List<db.DeedLog> logs;
  final int days;
  final DateTime today;

  Color? _colorFor(
    Map<String, LogStatus> index,
    DeedStats stats,
    DateTime day,
  ) {
    final status =
        index['${stats.deed.id}/${day.year}-${day.month}-${day.day}'];
    if (status != null) {
      return switch (status) {
        LogStatus.done => const Color(0xFF22C55E),
        LogStatus.late => const Color(0xFFF59E0B),
        LogStatus.skipped => const Color(0xFFEF4444),
      };
    }
    if (!isScheduledOn(stats.deed, day)) return null;
    if (frequencyOf(stats.deed).isCountBased) return null;
    if (day.isBefore(today)) {
      return const Color(0xFF6B7280).withValues(alpha: 0.35);
    }
    if (day.year == today.year &&
        day.month == today.month &&
        day.day == today.day) {
      return const Color(0xFF1B6CFF).withValues(alpha: 0.25);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                width: 92,
                child: Text(
                  stats.deed.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Row(
                  children: dateList.map((day) {
                    final color = _colorFor(index, stats, day);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: color ??
                                theme.colorScheme.outline.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
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
            const SizedBox(width: 92),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.percent,
    required this.count,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double percent;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          Text(
            '${percent.round()}%',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '$count times',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DeedStatsRow extends StatelessWidget {
  const _DeedStatsRow({required this.stats});

  final DeedStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (stats.completionRate * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            iconForName(stats.deed.icon, fallback: Icons.check_rounded),
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
          Text(
            '$percent%',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
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
