import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'drift_database.g.dart';

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant('#1a1a2e'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false)).named('is_pinned')();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false)).named('is_archived')();
  BoolColumn get isChecklist => boolean().withDefault(const Constant(false)).named('is_checklist')();
  TextColumn get labels => text().withDefault(const Constant('[]'))();
  TextColumn get shareToken => text().nullable().named('share_token')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().named('note_id')();
  TextColumn get payerId => text().named('payer_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalExpenseItems extends Table {
  TextColumn get id => text()();
  TextColumn get expenseId => text().named('expense_id')();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get price => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalItemParticipants extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().named('item_id')();
  TextColumn get userId => text().named('user_id')();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get localId => integer().autoIncrement()();
  TextColumn get operation => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  IntColumn get retryCount => integer().withDefault(const Constant(0)).named('retry_count')();
}

@DriftDatabase(tables: [LocalNotes, LocalExpenses, LocalExpenseItems, LocalItemParticipants, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );

  /// Wipe every table. Called on sign-out so the next user never sees
  /// stale data from the previous account.
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(localNotes).go();
      await delete(localExpenses).go();
      await delete(localExpenseItems).go();
      await delete(localItemParticipants).go();
      await delete(syncQueue).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'keepbillnotes.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
