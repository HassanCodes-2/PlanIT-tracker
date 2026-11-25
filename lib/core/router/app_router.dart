import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs/prefs_providers.dart';
import '../../features/deeds/archived_deeds_screen.dart';
import '../../features/deeds/create_deed_screen.dart';
import '../../features/deeds/deed_detail_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/notes/note_editor_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/categories_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/today/today_screen.dart';

final GoRouter appRouter = _createRouter(onboarded: true);

/// Rebuilt when onboarding state changes so the start screen is correct.
final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.watch(onboardedProvider);
  return _createRouter(onboarded: onboarded);
});

GoRouter _createRouter({required bool onboarded}) {
  return GoRouter(
    initialLocation: onboarded ? '/today' : '/welcome',
    redirect: (context, state) {
      final path = state.uri.path;
      if (!onboarded && path != '/welcome') return '/welcome';
      if (onboarded && path == '/welcome') return '/today';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                builder: (context, state) => const NotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/create-deed',
        builder: (context, state) => CreateDeedScreen(
          deedId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/archived',
        builder: (context, state) => const ArchivedDeedsScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/note',
        builder: (context, state) => NoteEditorScreen(
          noteId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/focus',
        builder: (context, state) => FocusScreen(
          deedId: int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0,
          date: DateTime.tryParse(state.uri.queryParameters['day'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/deed',
        builder: (context, state) => DeedDetailScreen(
          deedId: int.tryParse(state.uri.queryParameters['id'] ?? '') ?? 0,
        ),
      ),
    ],
  );
}