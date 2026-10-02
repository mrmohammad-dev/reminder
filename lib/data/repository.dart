import '../models/activity.dart';
import '../models/completion.dart';

/// Storage for activity templates and per-date completion history.
abstract class ActivityRepository {
  Future<List<Activity>> getActivities();

  /// Insert or update one activity (matched by id).
  Future<void> upsertActivity(Activity activity);

  /// Deletes the template. Completion history is kept.
  Future<void> deleteActivity(String id);

  /// Persists new sort orders: activityId -> sortOrder.
  Future<void> updateSortOrders(Map<String, int> orders);

  /// Replaces all templates (used by "restore default plan").
  /// Completion history is kept.
  Future<void> replaceActivities(List<Activity> activities);

  /// Replaces templates and history at once (used by backup restore).
  Future<void> replaceAll(List<Activity> activities, List<Completion> history);

  Future<int> nextNotifKey();

  Future<void> setCompleted(
    String activityId,
    String dateKey,
    bool done,
    int atMillis,
  );

  Future<Set<String>> completedIdsOn(String dateKey);

  /// Inclusive range of date keys -> done activity ids.
  Future<Map<String, Set<String>>> completedIdsBetween(
    String fromKey,
    String toKey,
  );

  Future<List<Completion>> allCompletions();
}
