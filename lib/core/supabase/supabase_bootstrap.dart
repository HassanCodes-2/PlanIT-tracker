import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration comes from --dart-define at build time:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
///
/// SUPABASE_KEY accepts a publishable key (sb_publishable_...) or a legacy
/// anon key from the Supabase dashboard.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

bool get isSupabaseConfigured =>
    supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

/// Initializes Supabase when credentials are provided.
/// The app still runs with mock data when they are absent (useful during M0).
Future<void> initSupabase() async {
  if (!isSupabaseConfigured) return;
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
}