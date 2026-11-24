import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
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
    final digital = context.appStyle.isDigital;
    final repository = ref.read(repositoryProvider);
    final deedAsync = ref.watch(deedByIdProvider(deedId));
    final cachedDeed = deedAsync.value;
    final archived = cachedDeed?.archivedAt != null;
    final deedFuture = deedAsync.hasValue
        ? Future<db.Deed?>.value(cachedDeed)
        : ref.watch(deedByIdProvider(deedId).future);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deed'),
        actions: [
          if (cachedDeed == null)
            const SizedBox.shrink()
          else if (archived)
            IconButton(
              tooltip: 'Restore deed',
              icon: const Icon(AppIcons.restore),
              onPressed: () async {
                await repository.unarchiveDeed(deedId);
                await ref
                    .read(notificationServiceProvider)
                    .syncAll(await repository.allDeeds());
                ref.invalidate(deedByIdProvider(deedId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deed restored to Today')),
                  );
                }
              },
            )
          else ...[
            IconButton(
              tooltip: 'Start focus session',
              icon: const Icon(AppIcons.focus),
              onPressed: () => context.push('/focus?id=$deedId'),
            ),
            IconButton(
              tooltip: 'Edit deed',
              icon: const Icon(AppIcons.edit),
              onPressed: () => context.push('/create-deed?id=$deedId'),
            ),
          ],
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
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.notePencil,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This deed no longer exists',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'It may have been archived.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () => context.go('/today'),
                      child: const Text('Back to Today'),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = categoriesAsync.value ?? const <db.Category>[];
          db.Category? category;
          for (final candidate in categories) {
            if (candidate.id == deed.categoryId) category = candidate;
          }
          final accent = digital || category == null
              ? theme.colorScheme.primary
              : AppTheme.ensureVisible(
                  colorFromHex(category.color),
                  theme.cardTheme.color ?? theme.colorScheme.surface,
                  theme.brightness,
                  ratio: 3.2,
                );

          return StreamBuilder<List<db.DeedLog>>(
            stream: repository.watchLogsForDeed(deedId),
            builder: (context, logsSnapshot) {
              final logs = logsSnapshot.data ?? const <db.DeedLog>[];
              final today = dateOnly(DateTime.now());
              final from = today.subtract(const Duration(days: 13));
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
                  if (deed.archivedAt != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(context.appStyle.cardRadius),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.history,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Archived deed',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Archived ${DateFormat('d MMM yyyy').format(deed.archivedAt!)}. Restore it to log again.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await repository.unarchiveDeed(deedId);
                              await ref
                                  .read(notificationServiceProvider)
                                  .syncAll(await repository.allDeeds());
                              ref.invalidate(deedByIdProvider(deedId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Deed restored to Today'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: digital ? 0.10 : 0.12),
                            shape: digital
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            borderRadius: digital
                                ? BorderRadius.circular(12)
                                : null,
                          ),
                          child: Icon(
                            iconForDeed(
                              deedIcon: deed.icon,
                              categoryIcon: category?.icon,
                              name: deed.name,
                            ),
                            color: accent,
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
                  _Label('LAST 14 DAYS'),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.card),
                      child: _SingleDeedHeatmap(
                        deed: deed,
                        logs: logs,
                        today: today,
                      ),
                    ),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 20),
                    _Label('14-DAY SUMMARY'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                            label: 'Done',
                            value: '${stats.done}',
                            color: AppColors.outcome(LogStatus.done, theme,
                                digital: digital)),
                        _MiniStat(
                            label: 'Late',
                            value: '${stats.late}',
                            color: AppColors.outcome(LogStatus.late, theme,
                                digital: digital)),
                        _MiniStat(
                            label: 'Skipped',
                            value: '${stats.skipped}',
                            color: AppColors.outcome(LogStatus.skipped, theme,
                                digital: digital)),
                        _MiniStat(
                            label: 'Missed',
                            value: '${stats.missed}',
                            color: AppColors.missed(theme, digital: digital)),
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
                                  statusIcon(
                                    LogStatus.fromDb(log.status),
                                    digital: digital,
                                  ),
                                  size: 18,
                                  semanticLabel:
                                      LogStatus.fromDb(log.status).label,
                                  color: AppColors.outcome(
                                      LogStatus.fromDb(log.status),
                                      theme,
                                      digital: digital,
                                    ),
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

  Widget _legendItem(
    ThemeData theme,
    IconData icon,
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digital = context.appStyle.isDigital;
    final index = <String, LogStatus>{
      for (final log in logs)
        '${log.day.year}-${log.day.month}-${log.day.day}':
            LogStatus.fromDb(log.status),
    };
    final start = today.subtract(const Duration(days: 13));
    final days = List.generate(
      14,
      (index) => start.add(Duration(days: index)),
    );

    return Column(
      children: [
        Row(
          children: days.map((day) {
            final key = '${day.year}-${day.month}-${day.day}';
            final status = index[key];
            final missed = status == null &&
                isScheduledOn(deed, day) &&
                day.isBefore(today) &&
                !frequencyOf(deed).isCountBased;
            Color? color;
            Color? glyphColor;
            IconData? glyph;
            if (status != null) {
              color = AppColors.outcome(status, theme, digital: digital);
              glyph = statusIcon(status, digital: digital);
              glyphColor = AppTheme.onColor(color);
            } else if (missed) {
              color = theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: digital ? 0.16 : 0.10);
              glyph = digital ? AppIcons.missedSquare : AppIcons.missed;
              glyphColor = AppColors.missed(theme, digital: digital);
            } else {
              color = theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.08);
            }
            return Expanded(
              child: Semantics(
                label:
                    '${DateFormat('d MMM').format(day)}, ${status?.label ?? (missed ? 'missed' : 'no deed')}',
                child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: missed
                          ? Border.all(color: theme.colorScheme.outline)
                          : null,
                    ),
                    child: glyph == null
                        ? null
                        : Icon(glyph, size: 13, color: glyphColor),
                  ),
                ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _legendItem(theme, statusIcon(LogStatus.done, digital: digital), 'Done',
                AppColors.outcome(LogStatus.done, theme, digital: digital)),
            _legendItem(theme, statusIcon(LogStatus.late, digital: digital), 'Late',
                AppColors.outcome(LogStatus.late, theme, digital: digital)),
            _legendItem(theme, statusIcon(LogStatus.skipped, digital: digital), 'Skipped',
                AppColors.outcome(LogStatus.skipped, theme, digital: digital)),
            _legendItem(theme, digital ? AppIcons.missedSquare : AppIcons.missed, 'Missed',
                AppColors.missed(theme, digital: digital)),
          ],
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