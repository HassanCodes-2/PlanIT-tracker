import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backup/backup_service.dart';
import '../../core/prefs/prefs_providers.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<Color> _accentPresets = [
    Color(0xFF1B6CFF),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFF84CC16),
  ];

  static const List<String> _accentNames = [
    'Blue',
    'Violet',
    'Emerald',
    'Amber',
    'Rose',
    'Cyan',
    'Orange',
    'Lime',
  ];

  String _accentName(Color color) {
    final index = _accentPresets
        .indexWhere((preset) => preset.toARGB32() == color.toARGB32());
    return index == -1 ? 'Custom accent' : '${_accentNames[index]} accent';
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: ref.read(userNameProvider));
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'How should we greet you?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await ref.read(userNameProvider.notifier).set(name);
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(backupServiceProvider)
          .shareBackup(ref.read(repositoryProvider));
      messenger.showSnackBar(
        const SnackBar(content: Text('Export shared successfully.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final digital =
        ref.watch(themeStyleProvider) == AppThemeStyle.digital;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
        children: [
          _Label('APPEARANCE'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final large =
                    MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
                        constraints.maxWidth < 300;
                String labelFor(ThemeMode mode) => switch (mode) {
                      ThemeMode.system => 'System',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    };
                if (large) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ThemeMode.values
                        .map(
                          (item) => ChoiceChip(
                            label: Text(labelFor(item)),
                            selected: item == mode,
                            onSelected: (_) => ref
                                .read(themeModeProvider.notifier)
                                .setMode(item),
                          ),
                        )
                        .toList(),
                  );
                }
                return SegmentedButton<ThemeMode>(
                  segments: ThemeMode.values
                      .map(
                        (item) => ButtonSegment(
                          value: item,
                          label: Text(labelFor(item)),
                        ),
                      )
                      .toList(),
                  selected: {mode},
                  showSelectedIcon: true,
                  onSelectionChanged: (selection) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(selection.first),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _Label('THEME STYLE'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stack =
                  constraints.maxWidth < 300 || textScale > 1.4;
              final midnight = _StyleCard(
                title: 'Midnight',
                subtitle: _accentName(accent),
                selected:
                    ref.watch(themeStyleProvider) == AppThemeStyle.midnight,
                previewColor: AppTheme.ensureVisible(
                  accent,
                  theme.colorScheme.surface,
                  theme.brightness,
                  ratio: 3.0,
                ),
                onTap: () => ref
                    .read(themeStyleProvider.notifier)
                    .setStyle(AppThemeStyle.midnight),
              );
              final digitalCard = _StyleCard(
                title: 'Digital',
                subtitle: 'Monochrome HUD',
                selected:
                    ref.watch(themeStyleProvider) == AppThemeStyle.digital,
                previewColor: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                onTap: () => ref
                    .read(themeStyleProvider.notifier)
                    .setStyle(AppThemeStyle.digital),
              );
              if (stack) {
                return Column(
                  children: [
                    midnight,
                    const SizedBox(height: 10),
                    digitalCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: midnight),
                  const SizedBox(width: 10),
                  Expanded(child: digitalCard),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _Label('ACCENT PRESETS'),
          const SizedBox(height: 10),
          if (!digital) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 520 ? 8 : 4;
                return GridView.count(
                  crossAxisCount: count,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.5,
                  children: List.generate(_accentPresets.length, (index) {
                    final color = _accentPresets[index];
                    final selected = accent.toARGB32() == color.toARGB32();
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: 'Accent color ${_accentNames[index]}',
                      child: InkResponse(
                        radius: 24,
                        onTap: () => ref
                            .read(accentColorProvider.notifier)
                            .setColor(color),
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.outline,
                                width: selected ? 2.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.45),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? Icon(
                                    AppIcons.check,
                                    size: 16,
                                    color: AppTheme.onColor(color),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-tuned for contrast. Used for buttons, progress and selections.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ] else
            Text(
              'Accent presets apply to the Midnight style.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 24),
          _Label('YOU'),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                AppIcons.person,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Your name'),
              subtitle: Text(
                ref.watch(userNameProvider).isEmpty
                    ? 'Not set'
                    : ref.watch(userNameProvider),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              onTap: () => _editName(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          _Label('DATA'),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                AppIcons.share,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Export my data'),
              subtitle: Text(
                'Save a copy of every deed and note as a file',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              onTap: () => _backup(context, ref),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                AppIcons.restore,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Archived deeds'),
              subtitle: Text(
                'Restore deeds you archived earlier',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              onTap: () => context.push('/archived'),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                AppIcons.restore,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Run setup again'),
              subtitle: Text(
                'Revisit focus areas and starter deeds. Existing data is kept.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Run setup again?'),
                    content: const Text(
                      'You can pick focus areas and add starter deeds again. '
                      'Nothing you already have will be deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Run setup'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await ref.read(onboardedProvider.notifier).reset();
                if (context.mounted) context.go('/welcome');
              },
            ),
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: AppIcons.storage,
            title: 'Storage',
            subtitle:
                'Stored only on this phone. Export shares a copy you can keep.',
          ),
          const SizedBox(height: 24),
          _Label('NOTIFICATIONS'),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                AppIcons.bell,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Notification permission'),
              subtitle: Text(
                'Needed for deed reminders and focus-timer alerts',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final allowed =
                      await NotificationService.instance.ensurePermission();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        allowed == true
                            ? 'Notifications are enabled.'
                            : 'Notifications are off. Enable them in Android settings.',
                      ),
                    ),
                  );
                },
                child: const Text('Check'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Label('ABOUT'),
          const SizedBox(height: 10),
          _InfoTile(
            icon: AppIcons.apps,
            title: 'PlanIT',
            subtitle: 'Habit & deed tracker v1.6.0',
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.previewColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color previewColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title style, $subtitle${selected ? ', active' : ''}',
      excludeSemantics: true,
      child: Material(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF050506)
                      : const Color(0xFFF0F0F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF26262B)
                        : const Color(0xFFD8D8DE),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: previewColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    selected
                        ? AppIcons.done
                        : Icons.circle_outlined,
                    size: 14,
                    color: selected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    selected ? 'Active' : 'Use',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
