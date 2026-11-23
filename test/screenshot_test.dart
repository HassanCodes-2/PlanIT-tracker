import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planit/core/prefs/prefs_providers.dart';
import 'package:planit/core/theme/app_theme.dart';
import 'package:planit/data/db/app_database.dart';
import 'package:planit/data/providers.dart';
import 'package:planit/features/deeds/create_deed_screen.dart';
import 'package:planit/features/notes/notes_screen.dart';
import 'package:planit/features/onboarding/onboarding_screen.dart';
import 'package:planit/features/settings/settings_screen.dart';
import 'package:planit/features/stats/stats_screen.dart';
import 'package:planit/features/today/today_screen.dart';

const _fontDir =
    'C:/Users/fahad/AppData/Local/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFont(String family, String file) async {
  final path = file.contains(':') ? file : '$_fontDir/$file';
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

final DateTime today = DateTime.now();
final DateTime todayOnly = DateTime(today.year, today.month, today.day);
final GlobalKey captureKey = GlobalKey();

final List<Category> categories = [
  Category(
      id: 1, name: 'Health', icon: 'fitness_center', color: '#22C55E', sortOrder: 0),
  Category(
      id: 2, name: 'Learning', icon: 'menu_book', color: '#3B82F6', sortOrder: 1),
  Category(
      id: 3, name: 'Work', icon: 'work', color: '#F59E0B', sortOrder: 2),
  Category(
      id: 4, name: 'Social', icon: 'groups', color: '#EC4899', sortOrder: 3),
];

final List<Deed> deeds = [
  Deed(
      id: 1,
      categoryId: 1,
      name: 'Exercise 20 min',
      frequencyType: 'weekdays',
      weekdays: '1,2,3,4,5',
      reasonsEnabled: false,
      sortOrder: 0,
      createdAt: DateTime(2026, 10, 1)),
  Deed(
      id: 2,
      categoryId: 1,
      name: 'Drink 2L water',
      frequencyType: 'daily',
      reasonsEnabled: false,
      sortOrder: 1,
      createdAt: DateTime(2026, 10, 1)),
  Deed(
      id: 3,
      categoryId: 2,
      name: 'Read 20 pages',
      frequencyType: 'daily',
      reasonsEnabled: false,
      sortOrder: 2,
      createdAt: DateTime(2026, 10, 1)),
  Deed(
      id: 4,
      categoryId: 3,
      name: 'Deep work 90 min',
      frequencyType: 'weekdays',
      weekdays: '1,2,3,4,5',
      reasonsEnabled: true,
      sortOrder: 3,
      createdAt: DateTime(2026, 10, 1)),
  Deed(
      id: 5,
      categoryId: 3,
      name: 'Plan tomorrow',
      frequencyType: 'daily',
      reasonsEnabled: false,
      sortOrder: 4,
      createdAt: DateTime(2026, 10, 1)),
  Deed(
      id: 6,
      categoryId: 4,
      name: 'Call family',
      frequencyType: 'times_per_week',
      timesPerPeriod: 2,
      reasonsEnabled: false,
      sortOrder: 5,
      createdAt: DateTime(2026, 10, 1)),
];

final Map<int, DeedLog> todayLogs = {
  1: DeedLog(
      id: 1000,
      deedId: 1,
      day: todayOnly,
      status: 'done',
      loggedAt: todayOnly),
  3: DeedLog(
      id: 1001,
      deedId: 3,
      day: todayOnly,
      status: 'late',
      loggedAt: todayOnly),
  4: DeedLog(
      id: 1002,
      deedId: 4,
      day: todayOnly,
      status: 'skipped',
      reason: 'Meeting ran long',
      loggedAt: todayOnly),
};

List<DeedLog> _history() {
  final result = <DeedLog>[...todayLogs.values];
  var id = 1;
  for (var offset = 1; offset < 30; offset++) {
    final day = todayOnly.subtract(Duration(days: offset));
    final weekend = day.weekday >= 6;

    if (!weekend) {
      result.add(DeedLog(
          id: id++,
          deedId: 1,
          day: day,
          status: offset % 7 == 0 ? 'skipped' : 'done',
          loggedAt: day));
    }
    if (offset % 3 != 0) {
      result.add(DeedLog(
          id: id++, deedId: 2, day: day, status: 'done', loggedAt: day));
    }
    result.add(DeedLog(
        id: id++,
        deedId: 3,
        day: day,
        status: offset % 5 == 0 ? 'late' : 'done',
        loggedAt: day));
    if (!weekend) {
      result.add(DeedLog(
          id: id++,
          deedId: 4,
          day: day,
          status: offset % 4 == 0 ? 'skipped' : 'done',
          loggedAt: day));
    }
    if (offset % 2 == 0) {
      result.add(DeedLog(
          id: id++, deedId: 5, day: day, status: 'done', loggedAt: day));
    }
  }
  return result;
}

final List<DeedLog> allLogs = _history();

final List<Note> notes = [
  Note(
    id: 1,
    title: 'App ideas',
    body: 'Add a weekly review screen. Maybe widgets next.',
    color: '#1B6CFF',
    pinned: true,
    createdAt: todayOnly.subtract(const Duration(days: 2)),
    updatedAt: todayOnly.subtract(const Duration(hours: 3)),
  ),
  Note(
    id: 2,
    title: 'Groceries',
    body: 'Oats, bananas, coffee, olive oil',
    color: '#22C55E',
    pinned: false,
    createdAt: todayOnly.subtract(const Duration(days: 1)),
    updatedAt: todayOnly.subtract(const Duration(hours: 5)),
  ),
  Note(
    id: 3,
    title: 'Book notes',
    body:
        'Atomic Habits: systems over goals. Make it obvious, attractive, easy, satisfying.',
    color: '#8B5CF6',
    pinned: false,
    createdAt: todayOnly.subtract(const Duration(days: 4)),
    updatedAt: todayOnly.subtract(const Duration(days: 1)),
  ),
  Note(
    id: 4,
    title: 'Trip plan',
    body: 'Weekend plan: sunrise at the wadi, seafood market, beach camp.',
    color: '#F59E0B',
    pinned: false,
    createdAt: todayOnly.subtract(const Duration(days: 6)),
    updatedAt: todayOnly.subtract(const Duration(days: 2)),
  ),
];

ThemeData _fontTheme(ThemeData base) => base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle:
            base.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

Widget _app({
  required Widget child,
  required ThemeData theme,
  int navIndex = 0,
  bool withNav = true,
}) {
  final key = captureKey;
  return ProviderScope(
    overrides: [
      categoriesProvider.overrideWith((ref) => Stream.value(categories)),
      deedsProvider.overrideWith((ref) => Stream.value(deeds)),
      logsForDayProvider
          .overrideWith((ref, day) => Stream.value(todayLogs)),
      allLogsProvider.overrideWith((ref) => Stream.value(allLogs)),
      notesProvider.overrideWith((ref) => Stream.value(notes)),
      clockProvider.overrideWith(
        (ref) => Stream.value(DateTime(2026, 11, 24, 9, 41)),
      ),
      sharedPreferencesProvider
          .overrideWithValue(_prefs()),
    ],
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _fontTheme(theme),
        home: Scaffold(
          body: child,
          bottomNavigationBar: withNav
              ? NavigationBar(
                  selectedIndex: navIndex,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.checklist_rounded),
                        label: 'Today'),
                    NavigationDestination(
                        icon: Icon(Icons.sticky_note_2_outlined),
                        label: 'Notes'),
                    NavigationDestination(
                        icon: Icon(Icons.bar_chart_rounded),
                        label: 'Stats'),
                    NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        label: 'Settings'),
                  ],
                )
              : null,
        ),
      ),
    ),
  );
}

SharedPreferences? _prefsCache;
SharedPreferences _prefs() {
  // Set by setUpAll.
  return _prefsCache!;
}

Future<void> _prepare(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', 'roboto-regular.ttf');
    await _loadFont('Roboto', 'roboto-medium.ttf');
    await _loadFont('Roboto', 'roboto-bold.ttf');
    await _loadFont('MaterialIcons', 'MaterialIcons-Regular.otf');
    await _loadFont(
      'PhosphorBold',
      'D:/Projects/PlanIT/assets/fonts/Phosphor-Bold.ttf',
    );
    SharedPreferences.setMockInitialValues({});
    _prefsCache = await SharedPreferences.getInstance();
  });

  testWidgets('today dark', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(child: const TodayScreen(), theme: AppTheme.dark),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/today_dark.png'),
    );
  });

  testWidgets('today light', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(child: const TodayScreen(), theme: AppTheme.light),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/today_light.png'),
    );
  });

  testWidgets('today digital', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(child: const TodayScreen(), theme: AppTheme.digitalDark),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/today_digital.png'),
    );
  });

  testWidgets('create deed', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(
        child: const CreateDeedScreen(),
        theme: AppTheme.dark,
        withNav: false,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/create_deed.png'),
    );
  });

  testWidgets('notes', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(child: const NotesScreen(), theme: AppTheme.dark, navIndex: 1),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/notes.png'),
    );
  });

  testWidgets('stats', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(
        child: const StatsScreen(),
        theme: AppTheme.dark,
        navIndex: 2,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/stats.png'),
    );
  });

  testWidgets('stats digital', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(
        child: const StatsScreen(),
        theme: AppTheme.digitalDark,
        navIndex: 2,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/stats_digital.png'),
    );
  });

  testWidgets('settings', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      _app(
        child: const SettingsScreen(),
        theme: AppTheme.dark,
        navIndex: 3,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/settings.png'),
    );
  });

  testWidgets('welcome', (tester) async {
    await _prepare(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_prefs()),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _fontTheme(AppTheme.dark),
            home: const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/welcome.png'),
    );
  });
}