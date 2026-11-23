import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../db/app_database.dart';

class DeedRepository {
  DeedRepository(this._db);

  final AppDatabase _db;

  // ---------- Categories ----------

  Stream<List<Category>> watchCategories() {
    final query = _db.select(_db.categories)
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);
    return query.watch();
  }

  Future<List<Category>> allCategories() =>
      (_db.select(_db.categories)
            ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
          .get();

  Future<Category?> categoryById(int id) =>
      (_db.select(_db.categories)..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  Future<int> createCategory({
    required String name,
    String icon = 'star',
    String color = '#1B6CFF',
    int sortOrder = 0,
  }) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            icon: Value(icon),
            color: Value(color),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  // ---------- Deeds ----------

  Stream<List<Deed>> watchDeeds() {
    final query = _db.select(_db.deeds)
      ..where((row) => row.archivedAt.isNull())
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.name),
      ]);
    return query.watch();
  }

  Future<List<Deed>> allDeeds() =>
      (_db.select(_db.deeds)
            ..where((row) => row.archivedAt.isNull())
            ..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .get();

  Future<Deed?> deedById(int id) =>
      (_db.select(_db.deeds)..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  Future<int> createDeed(DeedsCompanion companion) =>
      _db.into(_db.deeds).insert(companion);

  Future<void> updateDeed(Deed deed, DeedsCompanion changes) =>
      (_db.update(_db.deeds)..where((row) => row.id.equals(deed.id)))
          .write(changes);

  Future<void> archiveDeed(int id) =>
      (_db.update(_db.deeds)..where((row) => row.id.equals(id)))
          .write(DeedsCompanion(archivedAt: Value(DateTime.now())));

  // ---------- Logs ----------

  Stream<Map<int, DeedLog>> watchLogsForDay(DateTime day) {
    final query = _db.select(_db.deedLogs)
      ..where((row) => row.day.equals(dateOnly(day)));
    return query.watch().map(
          (rows) => {for (final row in rows) row.deedId: row},
        );
  }

  Stream<List<DeedLog>> watchAllLogs() {
    final query = _db.select(_db.deedLogs);
    return query.watch();
  }

  Stream<List<DeedLog>> watchLogsForDeed(int deedId) {
    final query = _db.select(_db.deedLogs)
      ..where((row) => row.deedId.equals(deedId));
    return query.watch();
  }

  Future<List<DeedLog>> logsBetween(DateTime from, DateTime to) =>
      (_db.select(_db.deedLogs)
            ..where((row) =>
                row.day.isBiggerOrEqualValue(dateOnly(from)) &
                row.day.isSmallerOrEqualValue(dateOnly(to))))
          .get();

  Future<void> setLog(
    int deedId,
    DateTime day,
    LogStatus status, {
    String? reason,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.deedLogs)
            ..where((row) =>
                row.deedId.equals(deedId) &
                row.day.equals(dateOnly(day))))
          .go();
      await _db.into(_db.deedLogs).insert(
            DeedLogsCompanion.insert(
              deedId: deedId,
              day: dateOnly(day),
              status: status.dbValue,
              reason: Value(reason),
            ),
          );
    });
  }

  Future<void> clearLog(int deedId, DateTime day) =>
      (_db.delete(_db.deedLogs)
            ..where((row) =>
                row.deedId.equals(deedId) &
                row.day.equals(dateOnly(day))))
          .go();

  // ---------- Notes ----------

  Stream<List<Note>> watchNotes() {
    final query = _db.select(_db.notes)
      ..orderBy([
        (row) => OrderingTerm.desc(row.pinned),
        (row) => OrderingTerm.desc(row.updatedAt),
      ]);
    return query.watch();
  }

  Future<Note?> noteById(int id) =>
      (_db.select(_db.notes)..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  Future<int> createNote(NotesCompanion companion) =>
      _db.into(_db.notes).insert(companion);

  Future<void> updateNote(Note note, NotesCompanion changes) =>
      (_db.update(_db.notes)..where((row) => row.id.equals(note.id)))
          .write(changes);

  Future<void> deleteNote(int id) =>
      (_db.delete(_db.notes)..where((row) => row.id.equals(id))).go();

  // ---------- Seed ----------

  /// Inserts starter content the first time the database is used.
  Future<void> ensureSeeded() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;

    final health = await createCategory(
      name: 'Health',
      icon: 'fitness_center',
      color: '#22C55E',
      sortOrder: 0,
    );
    final learning = await createCategory(
      name: 'Learning',
      icon: 'menu_book',
      color: '#3B82F6',
      sortOrder: 1,
    );
    final work = await createCategory(
      name: 'Work',
      icon: 'work',
      color: '#F59E0B',
      sortOrder: 2,
    );
    await createCategory(
      name: 'Social',
      icon: 'groups',
      color: '#EC4899',
      sortOrder: 3,
    );

    await _db.batch((batch) {
      batch.insertAll(_db.deeds, [
        DeedsCompanion.insert(
          name: 'Exercise 20 min',
          categoryId: Value(health),
          frequencyType: Value(FrequencyType.weekdays.dbValue),
          weekdays: const Value('1,2,3,4,5'),
          reminderTime: const Value('06:30'),
        ),
        DeedsCompanion.insert(
          name: 'Read 20 pages',
          categoryId: Value(learning),
        ),
        DeedsCompanion.insert(
          name: 'Deep work 90 min',
          categoryId: Value(work),
          frequencyType: Value(FrequencyType.weekdays.dbValue),
          weekdays: const Value('1,2,3,4,5'),
          reminderTime: const Value('09:00'),
        ),
        DeedsCompanion.insert(
          name: 'Plan tomorrow',
          categoryId: Value(work),
          reminderTime: const Value('21:00'),
        ),
      ]);
    });
  }
}