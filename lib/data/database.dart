import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'default_schedule.dart';

/// SQLite schema and migrations.
class AppDatabase {
  const AppDatabase._();

  static const String fileName = 'reminder.db';

  /// Bump this and add an entry to [_migrations] for schema changes.
  static const int version = 1;

  /// version -> migration that upgrades from (version - 1).
  /// Example for a future v2:
  ///   2: (db) async => db.execute('ALTER TABLE activities ADD COLUMN color INTEGER'),
  static final Map<int, Future<void> Function(Database db)> _migrations =
      <int, Future<void> Function(Database db)>{};

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, fileName),
      version: version,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        notif_key INTEGER NOT NULL UNIQUE,
        title TEXT NOT NULL,
        raw_line TEXT NOT NULL,
        day INTEGER NOT NULL,
        week_type TEXT NOT NULL,
        start_minute INTEGER,
        end_minute INTEGER,
        category TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        reminder_enabled INTEGER NOT NULL,
        schedule_note TEXT,
        school_key TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE completions (
        activity_id TEXT NOT NULL,
        date TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        PRIMARY KEY (activity_id, date)
      )
    ''');
    await db.execute('CREATE INDEX idx_completions_date ON completions(date)');
  }

  /// The default plan is inserted only here, i.e. once per install.
  /// Opening the app later never re-inserts or overwrites user edits.
  static Future<void> _onCreate(Database db, int v) async {
    await db.transaction((txn) async {
      await createSchema(txn);
      final batch = txn.batch();
      for (final a in buildDefaultActivities()) {
        batch.insert('activities', a.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    for (var v = oldV + 1; v <= newV; v++) {
      final m = _migrations[v];
      if (m != null) await m(db);
    }
  }
}
