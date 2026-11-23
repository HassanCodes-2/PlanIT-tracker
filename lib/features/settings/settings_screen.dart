import 'package:material_ui/material_ui.dart';

/// M0 placeholder — settings become functional in M6.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = [
      ('Appearance', 'Dark theme (Light in M6)', Icons.palette_outlined),
      ('Week starts on', 'Monday (M6)', Icons.calendar_view_week_rounded),
      ('Reasons tracking', 'Global toggle (M6)', Icons.psychology_outlined),
      ('Reminders', 'Local notifications (M6)', Icons.notifications_outlined),
      ('Account', 'Not signed in (M1)', Icons.person_outline_rounded),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (title, subtitle, icon) = tiles[index];
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}