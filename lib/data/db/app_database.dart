import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Deed categories shown as sections on the Today screen.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('star'))();
  TextColumn get color => text().withDefault(const Constant('#1B6CFF'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Recurring deeds.
class Deeds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get parentId => integer().nullable().references(Deeds, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get frequencyType =>
      text().withDefault(const Constant('daily'))();
  /// CSV of weekdays (1=Mon .. 7=Sun) for the `weekdays` frequency.
  TextColumn get weekdays => text().nullable()();
  IntColumn get timesPerPeriod => integer().nullable()();
  BoolColumn get reasonsEnabled =>
      boolean().withDefault(const Constant(false))();
  /// Local reminder time as "HH:mm".
  TextColumn get reminderTime => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// One outcome per deed per day.
class DeedLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deedId =>
      integer().references(Deeds, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get day => dateTime()();
  TextColumn get status => text()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get loggedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {deedId, day},
      ];
}

/// Quick-capture notes & ideas (Keep-style: colors, pinning, search).
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant('#1B6CFF'))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Categories, Deeds, DeedLogs, Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(notes);
          }
        },
      );
}