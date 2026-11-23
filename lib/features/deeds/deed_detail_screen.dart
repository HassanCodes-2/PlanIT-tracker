import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/icons.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';
import '../../domain/stats.dart';

class DeedDetailScreen extends ConsumerWidget {
  const DeedDetailScreen({super.key, required this.deedId});

  final int deedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repository = ref.read(repositoryProvider);
    final deedFuture = repository.deedById(deedId);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deed'),
        actions: [
          IconButton(
            tooltip: 'Edit deed',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/create-deed?id=$deedId'),
          ),
        ],
      ),
      body: FutureBuilder<db.Deed?>(
        future: deedFuture,
        builder: (context, deedSnapshot) {
          final deed = deedSnapshot.data;
          if (deedSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (deed == null) {
            return Center(
              child: Text(
                'This deed no longer exists.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }

          final categories = categoriesAsync.value ?? const <db.Category>[];
          db.Category? category;
          for (final candidate in categories) {
            if (candidate.id == deed.categoryId) category = candidate;
          }

          return StreamBuilder<List<db.DeedLog>>(
            stream: repository.watchLogsForDeed(deedId),
            builder: (context, logsSnapshot) {
              final logs = logsSnapshot.data ?? const <db.DeedLog>[];
              final today = dateOnly(DateTime.now());
              final from = today.subtract(const Duration(days: 29));
              final stats = computeStats(
                deeds: [deed],
                logs: logs,
                from: from,
                to: today,
              ).deeds.firstOrNull;

              final reasons = logs
                  .where((log) => log.reason != null && log.reason!.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.day.compareTo(a.day));
              final recent = logs.toList()..sort((a, b) => b.day.compareTo(a.day));

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colorFromHex(category?.color ?? '#1B6CFF')
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconForName(deed.icon ?? category?.icon,
                                fallback: Icons.check_rounded),
                            color: colorFromHex(category?.color ?? '#1B6CFF'),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deed.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                FrequencyType.fromDb(deed.frequencyType).label,
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
                  const SizedBox(height: 24),
                  _Label('LAST 30 DAYS'),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _SingleDeedHeatmap(
                        deed: deed,
                        logs: logs,
                        today: today,
                      ),
                    ),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 20),
                    _Label('30-DAY SUMMARY'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                            label: 'Done',
                            value: '${stats.done}',
                            color: const Color(0xFF22C55E)),
                        _MiniStat(
                            label: 'Late',
                            value: '${stats.late}',
                            color: const Color(0xFFF59E0B)),
                        _MiniStat(
                            label: 'Skipped',
                            value: '${stats.skipped}',
                            color: const Color(0xFFEF4444)),
                        _MiniStat(
                            label: 'Missed',
                            value: '${stats.missed}',
                            color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _Label('WHY YOU SKIPPED'),
                    const SizedBox(height: 10),
                    ...reasons.take(8).map(
                          (log) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: theme.colorScheme.outline),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.speaker_notes_off_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    log.reason!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('d MMM').format(log.day),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 24),
                  _Label('RECENT LOGS'),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    Text(
                      'Nothing logged yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...recent.take(10).map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  switch (LogStatus.fromDb(log.status)) {
                                    LogStatus.done =>
                                      Icons.check_circle_rounded,
                                    LogStatus.late => Icons.schedule_rounded,
                                    LogStatus.skipped =>
                                      Icons.remove_circle_rounded,
                                  },
                                  size: 18,
                                  color: switch (LogStatus.fromDb(log.status)) {
                                    LogStatus.done => const Color(0xFF22C55E),
                                    LogStatus.late => const Color(0xFFF59E0B),
                                    LogStatus.skipped =>
                                      const Color(0xFFEF4444),
                                  },
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('EEEE, d MMMM').format(log.day),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SingleDeedHeatmap extends StatelessWidget {
  const _SingleDeedHeatmap({
    required this.deed,
    required this.logs,
    required this.today,
  });

  final db.Deed deed;
  final List<db.DeedLog> logs;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = <String, LogStatus>{
      for (final log in logs)
        '${log.day.year}-${log.day.month}-${log.day.day}':
            LogStatus.fromDb(log.status),
    };
    final start = today.subtract(const Duration(days: 29));
    final days = List.generate(
      30,
      (index) => start.add(Duration(days: index)),
    );

    return Column(
      children: [
        Row(
          children: days.map((day) {
            final key = '${day.year}-${day.month}-${day.day}';
            final status = index[key];
            Color? color;
            if (status != null) {
              color = switch (status) {
                LogStatus.done => const Color(0xFF22C55E),
                LogStatus.late => const Color(0xFFF59E0B),
                LogStatus.skipped => const Color(0xFFEF4444),
              };
            } else if (isScheduledOn(deed, day) &&
                day.isBefore(today) &&
                !frequencyOf(deed).isCountBased) {
              color =
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25);
            }
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color ??
                          theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('d MMM').format(start),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              DateFormat('d MMM').format(today),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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