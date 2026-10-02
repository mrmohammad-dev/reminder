import 'package:sqflite/sqflite.dart';

import '../models/activity.dart';
import '../models/completion.dart';
import 'database.dart';
import 'repository.dart';

class SqliteActivityRepository implements ActivityRepository {
  SqliteActivityRepository(this._db);

  final Database _db;

  static Future<SqliteActivityRepository> open() async =>
      SqliteActivityRepository(await AppDatabase.open());

  @override
  Future<List<Activity>> getActivities() async {
    final rows = await _db.query('activities', orderBy: 'day, sort_order');
    return rows.map(Activity.fromMap).toList();
  }

  @override
  Future<void> upsertActivity(Activity activity) async {
    await _db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteActivity(String id) async {
    await _db.delete('activities', where: 'id = ?', whereArgs: <Object>[id]);
  }

  @override
  Future<void> updateSortOrders(Map<String, int> orders) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      orders.forEach((id, order) {
        batch.update(
          'activities',
          <String, Object?>{'sort_order': order},
          where: 'id = ?',
          whereArgs: <Object>[id],
        );
      });
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> replaceActivities(List<Activity> activities) async {
    await _db.transaction((txn) async {
      await txn.delete('activities');
      final batch = txn.batch();
      for (final a in activities) {
        batch.insert('activities', a.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> replaceAll(
    List<Activity> activities,
    List<Completion> history,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete('activities');
      await txn.delete('completions');
      final batch = txn.batch();
      for (final a in activities) {
        batch.insert('activities', a.toMap());
      }
      for (final c in history) {
        batch.insert(
          'completions',
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<int> nextNotifKey() async {
    final rows = await _db.rawQuery(
      'SELECT MAX(notif_key) AS m FROM activities',
    );
    final m = rows.first['m'];
    return (m is int ? m : 0) + 1;
  }

  @override
  Future<void> setCompleted(
    String activityId,
    String dateKey,
    bool done,
    int atMillis,
  ) async {
    if (done) {
      // UNIQUE(activity_id, date): ticking twice never creates duplicates.
      await _db.insert(
        'completions',
        Completion(
          activityId: activityId,
          dateKey: dateKey,
          completedAtMillis: atMillis,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await _db.delete(
        'completions',
        where: 'activity_id = ? AND date = ?',
        whereArgs: <Object>[activityId, dateKey],
      );
    }
  }

  @override
  Future<Set<String>> completedIdsOn(String dateKey) async {
    final rows = await _db.query(
      'completions',
      columns: <String>['activity_id'],
      where: 'date = ?',
      whereArgs: <Object>[dateKey],
    );
    return rows.map((r) => r['activity_id']! as String).toSet();
  }

  @override
  Future<Map<String, Set<String>>> completedIdsBetween(
    String fromKey,
    String toKey,
  ) async {
    final rows = await _db.query(
      'completions',
      columns: <String>['activity_id', 'date'],
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object>[fromKey, toKey],
    );
    final map = <String, Set<String>>{};
    for (final r in rows) {
      map
          .putIfAbsent(r['date']! as String, () => <String>{})
          .add(r['activity_id']! as String);
    }
    return map;
  }

  @override
  Future<List<Completion>> allCompletions() async {
    final rows = await _db.query('completions', orderBy: 'date, activity_id');
    return rows.map(Completion.fromMap).toList();
  }
}
