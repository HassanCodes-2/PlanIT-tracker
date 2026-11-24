import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/icons.dart';

/// Bottom navigation shell: Today / Notes / Stats / Settings.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.today),
            selectedIcon: Icon(AppIcons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.notes),
            selectedIcon: Icon(AppIcons.notes),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.stats),
            selectedIcon: Icon(AppIcons.stats),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.gear),
            selectedIcon: Icon(AppIcons.gear),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}