import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/deed_repository.dart';
import '../domain/enums.dart';

/// Overridden in main() with the initialized database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final repositoryProvider = Provider<DeedRepository>(
  (ref) => DeedRepository(ref.watch(databaseProvider)),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(repositoryProvider).watchCategories(),
);

final deedsProvider = StreamProvider<List<Deed>>(
  (ref) => ref.watch(repositoryProvider).watchDeeds(),
);

/// All logs, used by the stats screen.
final allLogsProvider = StreamProvider<List<DeedLog>>(
  (ref) => ref.watch(repositoryProvider).watchAllLogs(),
);

/// The day currently shown on the Today screen.
class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);
}

final selectedDayProvider =
    NotifierProvider<SelectedDay, DateTime>(SelectedDay.new);

final logsForDayProvider =
    StreamProvider.family<Map<int, DeedLog>, DateTime>((ref, day) {
  return ref.watch(repositoryProvider).watchLogsForDay(day);
});