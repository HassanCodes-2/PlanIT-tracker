import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/notifications/notification_service.dart';
import 'core/prefs/prefs_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';

class PlanItApp extends ConsumerStatefulWidget {
  const PlanItApp({super.key});

  @override
  ConsumerState<PlanItApp> createState() => _PlanItAppState();
}

class _PlanItAppState extends ConsumerState<PlanItApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifications = ref.read(notificationServiceProvider);
      await notifications.ensurePermission();
      final deeds = await ref.read(repositoryProvider).allDeeds();
      await notifications.syncAll(deeds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(themeStyleProvider);
    final isDigital = style == AppThemeStyle.digital;
    final accent = ref.watch(accentColorProvider);

    return MaterialApp.router(
      title: 'PlanIT',
      debugShowCheckedModeBanner: false,
      theme: isDigital ? AppTheme.digitalLight : AppTheme.lightWith(accent),
      darkTheme: isDigital ? AppTheme.digitalDark : AppTheme.darkWith(accent),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}