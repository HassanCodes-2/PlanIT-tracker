import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/load_error.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const _colors = [
    '#22C55E',
    '#3B82F6',
    '#F59E0B',
    '#EC4899',
    '#8B5CF6',
    '#10B981',
    '#F97316',
    '#06B6D4',
  ];

  static const _colorNames = [
    'Green',
    'Blue',
    'Amber',
    'Pink',
    'Violet',
    'Emerald',
    'Orange',
    'Cyan',
  ];

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    db.Category? category,
    int sortOrder = 0,
  }) async {
    final name = TextEditingController(text: category?.name ?? '');
    final digital = context.appStyle.isDigital;
    var color = category?.color ?? _colors.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(category == null ? 'New category' : 'Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              if (!digital) ...[
                const SizedBox(height: 18),
                Text(
                  'COLOR',
                  style:
                      Theme.of(dialogContext).textTheme.labelMedium?.copyWith(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(_colors.length, (index) {
                    final value = _colors[index];
                    final selected =
                        value.toUpperCase() == color.toUpperCase();
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: '${_colorNames[index]} category color',
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: InkResponse(
                          radius: 24,
                          onTap: () => setDialogState(() => color = value),
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: colorFromHex(value),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? Theme.of(dialogContext)
                                          .colorScheme
                                          .onSurface
                                      : Theme.of(dialogContext)
                                          .colorScheme
                                          .outline,
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                              child: selected
                                  ? Icon(
                                      AppIcons.check,
                                      size: 18,
                                      color: AppTheme.onColor(
                                        colorFromHex(value),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final trimmed = name.text.trim();
    name.dispose();
    if (saved != true || trimmed.isEmpty) return;

    final repository = ref.read(repositoryProvider);
    try {
      if (category == null) {
        await repository.createCategory(
          name: trimmed,
          color: color,
          sortOrder: sortOrder,
        );
      } else {
        await repository.updateCategory(
          category.id,
          db.CategoriesCompanion(
            name: Value(trimmed),
            color: Value(color),
          ),
        );
      }
      if (context.mounted) {
        AppToast.show(
          context,
          category == null ? 'Category created.' : 'Category updated.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show(context, 'Could not save the category. Try again.',
            duration: const Duration(milliseconds: 3000));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    db.Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'Deeds in this category become uncategorized. Their history is kept.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(repositoryProvider).deleteCategory(category.id);
    if (context.mounted) {
      AppToast.show(context, '${category.name} deleted.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final deeds = ref.watch(deedsProvider).value ?? const <db.Deed>[];
    final categories = categoriesAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New category',
        onPressed: () => _edit(
          context,
          ref,
          sortOrder: (categories?.length ?? 0) * 10,
        ),
        child: const Icon(AppIcons.add),
      ),
      body: categoriesAsync.hasError
          ? LoadError(onRetry: () => ref.invalidate(categoriesProvider))
          : categories == null
              ? const Center(child: CircularProgressIndicator())
              : categories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.huge),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.tag,
                              size: 56,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No categories yet',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Group related deeds to keep Today tidy.',
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
                        AppSpacing.xxxl + 60,
                      ),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final digital = context.appStyle.isDigital;
                        final accent = digital
                            ? theme.colorScheme.onSurfaceVariant
                            : AppTheme.ensureVisible(
                                colorFromHex(category.color),
                                theme.cardTheme.color ??
                                    theme.colorScheme.surface,
                                theme.brightness,
                                ratio: 3.2,
                              );
                        final count = deeds
                            .where((deed) => deed.categoryId == category.id)
                            .length;
                        return Material(
                          color: theme.cardTheme.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              context.appStyle.cardRadius,
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () => _edit(
                              context,
                              ref,
                              category: category,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: context.appStyle.isDigital ? 0.10 : 0.14,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                iconForName(
                                  category.icon,
                                  fallback: AppIcons.tag,
                                ),
                                color: accent,
                                size: 21,
                              ),
                            ),
                            title: Text(category.name),
                            subtitle: Text(
                              count == 1 ? '1 deed' : '$count deeds',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Category actions',
                              icon: const Icon(AppIcons.more),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _edit(context, ref, category: category);
                                } else if (value == 'delete') {
                                  _delete(context, ref, category);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit category'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete category',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
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