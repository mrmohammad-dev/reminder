import '../util/dates.dart';

/// "Done" state of one activity on one local date.
/// (activityId, dateKey) is unique.
class Completion {
  const Completion({
    required this.activityId,
    required this.dateKey,
    required this.completedAtMillis,
  });

  final String activityId;
  final String dateKey;
  final int completedAtMillis;

  Map<String, Object?> toMap() => <String, Object?>{
    'activity_id': activityId,
    'date': dateKey,
    'completed_at': completedAtMillis,
  };

  factory Completion.fromMap(Map<String, Object?> map) {
    final a = map['activity_id'];
    final d = map['date'];
    final t = map['completed_at'];
    if (a is! String || a.isEmpty) throw const FormatException('activity_id');
    if (d is! String || !isValidDateKey(d)) throw const FormatException('date');
    if (t is! int) throw const FormatException('completed_at');
    return Completion(activityId: a, dateKey: d, completedAtMillis: t);
  }
}
