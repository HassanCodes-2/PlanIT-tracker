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
    final theme = Theme.of(context);
    final destinations = [
      NavigationDestination(
        icon: const Icon(AppIcons.today),
        selectedIcon: const Icon(AppIcons.today),
        label: 'Today',
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.notes),
        selectedIcon: const Icon(AppIcons.notes),
        label: 'Notes',
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.stats),
        selectedIcon: const Icon(AppIcons.stats),
        label: 'Stats',
      ),
      NavigationDestination(
        icon: const Icon(AppIcons.gear),
        selectedIcon: const Icon(AppIcons.gear),
        label: 'Settings',
      ),
    ];

    void onSelect(int index) {
      HapticFeedback.selectionClick();
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        const content = BoxConstraints(maxWidth: 720);
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: theme.colorScheme.surface,
                      indicatorColor: theme.colorScheme.primary,
                      selectedIndex: navigationShell.currentIndex,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: onSelect,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(AppIcons.today),
                          label: const Text('Today'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(AppIcons.notes),
                          label: const Text('Notes'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(AppIcons.stats),
                          label: const Text('Stats'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(AppIcons.gear),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: content,
                          child: navigationShell,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: content,
                    child: navigationShell,
                  ),
                ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: onSelect,
                  destinations: destinations,
                ),
        );
      },
    );
  }
}