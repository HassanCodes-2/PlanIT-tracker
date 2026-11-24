import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/load_error.dart';
import '../../data/providers.dart';

class ArchivedDeedsScreen extends ConsumerWidget {
  const ArchivedDeedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archivedAsync = ref.watch(archivedDeedsProvider);
    final archived = archivedAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Archived deeds')),
      body: archivedAsync.hasError
          ? LoadError(onRetry: () => ref.invalidate(archivedDeedsProvider))
          : archived == null
              ? const Center(child: CircularProgressIndicator())
              : archived.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.huge),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.history,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nothing archived',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Deeds you archive will appear here and can be restored.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.sm,
                      AppSpacing.screen,
                      AppSpacing.xxl),
                  itemCount: archived.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final deed = archived[index];
                    return Material(
                      color: theme.cardTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(
                          iconForName(deed.icon,
                              fallback: AppIcons.done),
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(deed.name),
                        subtitle: Text(
                          'Archived ${_date(deed.archivedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Restore deed',
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: () async {
                            await ref
                                .read(repositoryProvider)
                                .unarchiveDeed(deed.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '"${deed.name}" restored to Today'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    return DateFormat('d MMM yyyy').format(value);
  }
}