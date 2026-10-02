import '../models/activity.dart';
import '../models/completion.dart';
import 'repository.dart';

/// In-memory repository with the same semantics as the SQLite one.
/// Used by automated tests.
class InMemoryActivityRepository implements ActivityRepository {
  InMemoryActivityRepository([List<Activity> initial = const <Activity>[]]) {
    for (final a in initial) {
      _activities[a.id] = a;
    }
  }

  final Map<String, Activity> _activities = <String, Activity>{};
  final Map<String, Completion> _completions = <String, Completion>{};

  String _k(String id, String date) => '$id|$date';

  @override
  Future<List<Activity>> getActivities() async {
    final list = _activities.values.toList();
    list.sort((a, b) {
      final d = a.day.compareTo(b.day);
      return d != 0 ? d : a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  @override
  Future<void> upsertActivity(Activity activity) async {
    _activities[activity.id] = activity;
  }

  @override
  Future<void> deleteActivity(String id) async {
    _activities.remove(id);
  }

  @override
  Future<void> updateSortOrders(Map<String, int> orders) async {
    orders.forEach((id, order) {
      final a = _activities[id];
      if (a != null) _activities[id] = a.copyWith(sortOrder: order);
    });
  }

  @override
  Future<void> replaceActivities(List<Activity> activities) async {
    _activities
      ..clear()
      ..addEntries(activities.map((a) => MapEntry(a.id, a)));
  }

  @override
  Future<void> replaceAll(
    List<Activity> activities,
    List<Completion> history,
  ) async {
    await replaceActivities(activities);
    _completions
      ..clear()
      ..addEntries(
        history.map((c) => MapEntry(_k(c.activityId, c.dateKey), c)),
      );
  }

  @override
  Future<int> nextNotifKey() async {
    var max = 0;
    for (final a in _activities.values) {
      if (a.notifKey > max) max = a.notifKey;
    }
    return max + 1;
  }

  @override
  Future<void> setCompleted(
    String activityId,
    String dateKey,
    bool done,
    int atMillis,
  ) async {
    final key = _k(activityId, dateKey);
    if (done) {
      _completions.putIfAbsent(
        key,
        () => Completion(
          activityId: activityId,
          dateKey: dateKey,
          completedAtMillis: atMillis,
        ),
      );
    } else {
      _completions.remove(key);
    }
  }

  @override
  Future<Set<String>> completedIdsOn(String dateKey) async => _completions
      .values
      .where((c) => c.dateKey == dateKey)
      .map((c) => c.activityId)
      .toSet();

  @override
  Future<Map<String, Set<String>>> completedIdsBetween(
    String fromKey,
    String toKey,
  ) async {
    final map = <String, Set<String>>{};
    for (final c in _completions.values) {
      if (c.dateKey.compareTo(fromKey) >= 0 && c.dateKey.compareTo(toKey) <= 0) {
        map.putIfAbsent(c.dateKey, () => <String>{}).add(c.activityId);
      }
    }
    return map;
  }

  @override
  Future<List<Completion>> allCompletions() async {
    final list = _completions.values.toList();
    list.sort((a, b) {
      final d = a.dateKey.compareTo(b.dateKey);
      return d != 0 ? d : a.activityId.compareTo(b.activityId);
    });
    return list;
  }

  int get completionCount => _completions.length;
}
