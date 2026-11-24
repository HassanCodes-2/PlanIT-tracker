import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/prefs/prefs_providers.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'data/db/app_database.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final prefs = await SharedPreferences.getInstance();
  final database = AppDatabase(driftDatabase(name: 'planit'));

  final notifications = NotificationService.instance;
  try {
    await notifications.init();
  } catch (_) {
    // Reminders are optional; the app still works without them.
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PlanItApp(),
    ),
  );
}