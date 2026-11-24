import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backup/backup_service.dart';
import '../../core/prefs/prefs_providers.dart';
import '../../core/theme/app_spacing.dart';
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).setMode(selection.first),
            ),
          ),
          const SizedBox(height: 24),
          _Label('THEME STYLE'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StyleCard(
                  title: 'Midnight',
                  subtitle: _accentName(accent),
                  selected:
                      ref.watch(themeStyleProvider) == AppThemeStyle.midnight,
                  previewColor: accent,
                  onTap: () => ref
                      .read(themeStyleProvider.notifier)
                      .setStyle(AppThemeStyle.midnight),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StyleCard(
                  title: 'Digital',
                  subtitle: 'Monochrome HUD',
                  selected:
                      ref.watch(themeStyleProvider) == AppThemeStyle.digital,
                  previewColor: Colors.white,
                  onTap: () => ref
                      .read(themeStyleProvider.notifier)
                      .setStyle(AppThemeStyle.digital),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Label('ACCENT COLOR'),
          const SizedBox(height: 10),
          Opacity(
            opacity: digital ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: digital,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children:
                    List.generate(_accentPresets.length, (index) {
                  final color = _accentPresets[index];
                  final selected = accent.toARGB32() == color.toARGB32();
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: Semantics(
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
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color:
                                            color.withValues(alpha: 0.45),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: color.computeLuminance() > 0.45
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            digital
                ? 'Digital is monochrome — the accent applies to Midnight.'
                : 'Used for buttons, progress, highlights and selected states.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _Label('YOU'),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.person_outline_rounded,
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
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.file_download_outlined,
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
          _InfoTile(
            icon: Icons.storage_rounded,
            title: 'Data',
            subtitle:
                'Stored only on this phone. Export keeps a safe copy.',
          ),
          const SizedBox(height: 24),
          _Label('ABOUT'),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.apps_rounded,
            title: 'PlanIT',
            subtitle: 'Habit & deed tracker · v1.1.0',
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.notifications_none_rounded,
            title: 'Reminders',
            subtitle: 'Per-deed reminder times are saved with each deed.',
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
    return Material(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.medium),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF050506),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF26262B)),
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
                        ? Icons.check_circle_rounded
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
        borderRadius: BorderRadius.circular(16),
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
