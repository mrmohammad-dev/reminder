import '../models/activity.dart';
import '../models/enums.dart';
import '../models/settings.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'week_service.dart';

/// One activity on one concrete date.
class DayInstance {
  const DayInstance({
    required this.activity,
    required this.date,
    required this.weekType,
    required this.start,
    required this.end,
    required this.done,
    required this.conflict,
  });

  final Activity activity;
  final DateTime date;
  final WeekType weekType;

  /// Resolved times (template time, or school time from settings).
  final int? start;
  final int? end;
  final bool done;

  /// Overlaps another activity of the same day (shown, never auto-fixed).
  final bool conflict;

  String get dateKeyValue => dateKey(date);

  /// Start time is unknown: stays in the checklist, no start reminder.
  bool get needsSetup => start == null;

  bool get isMomentary => start != null && end == null;

  /// Human readable time, Persian digits, 24h. Falls back to the original
  /// sentence when a time is not known (never invents a time).
  String get timeLabel {
    final s = start;
    final e = end;
    if (s != null && e != null) return '${faTime(s)}–${faTime(e)}';
    if (s != null) return faTime(s);
    if (e != null) return 'شروع: تعیین نشده • تا ${faTime(e)}';
    return activity.scheduleNote ?? 'زمان تعیین نشده';
  }
}

class ScheduleService {
  const ScheduleService._();

  static List<Activity> templatesForDay(
    List<Activity> all,
    int day,
    WeekType week,
  ) {
    final list = all
        .where(
          (a) =>
              a.day == day &&
              (a.weekType == WeekType.both || a.weekType == week),
        )
        .toList();
    list.sort((x, y) => x.sortOrder.compareTo(y.sortOrder));
    return list;
  }

  static int? resolvedStart(Activity a, WeekType week, AppSettings s) {
    if (a.startMinute != null) return a.startMinute;
    final key = a.schoolKey;
    if (key == null) return null;
    return s.schoolTime(key, week, 'start');
  }

  static int? resolvedEnd(Activity a, WeekType week, AppSettings s) {
    if (a.endMinute != null) return a.endMinute;
    final key = a.schoolKey;
    if (key == null || key == 'mon') return null;
    return s.schoolTime(key, week, 'end');
  }

  static List<DayInstance> buildDay({
    required List<Activity> activities,
    required DateTime date,
    required AppSettings settings,
    required Set<String> doneIds,
  }) {
    final d = dateOnly(date);
    final week = WeekService.forSettings(d, settings);
    return _build(activities, dayIndexOf(d), week, d, settings, doneIds);
  }

  /// Template view of a weekday for a chosen week type (A or B), without
  /// changing the real current week. [referenceDate] is only a label.
  static List<DayInstance> buildForWeek({
    required List<Activity> activities,
    required int day,
    required WeekType week,
    required AppSettings settings,
    required DateTime referenceDate,
  }) => _build(
    activities,
    day,
    week,
    dateOnly(referenceDate),
    settings,
    const <String>{},
  );

  static List<DayInstance> _build(
    List<Activity> activities,
    int day,
    WeekType week,
    DateTime d,
    AppSettings settings,
    Set<String> doneIds,
  ) {
    final templates = templatesForDay(activities, day, week);
    final starts = <int?>[];
    final ends = <int?>[];
    for (final a in templates) {
      starts.add(resolvedStart(a, week, settings));
      ends.add(resolvedEnd(a, week, settings));
    }
    final conflicts = _conflictIndexes(starts, ends);
    return <DayInstance>[
      for (var i = 0; i < templates.length; i++)
        DayInstance(
          activity: templates[i],
          date: d,
          weekType: week,
          start: starts[i],
          end: ends[i],
          done: doneIds.contains(templates[i].id),
          conflict: conflicts.contains(i),
        ),
    ];
  }

  /// Overlap detection. Items are compared in plan order.
  /// * Two ranges overlap when a.start < b.end and b.start < a.end.
  /// * A range with unknown start (e.g. «تا 15:00 مدرسه») conflicts with a
  ///   later item that starts before its end.
  /// * Momentary events (start only) are not ranges.
  static Set<int> _conflictIndexes(List<int?> starts, List<int?> ends) {
    final result = <int>{};
    for (var i = 0; i < starts.length; i++) {
      for (var j = i + 1; j < starts.length; j++) {
        final aS = starts[i];
        final aE = ends[i];
        final bS = starts[j];
        final bE = ends[j];
        var overlap = false;
        if (aS != null && aE != null && bS != null && bE != null) {
          overlap = aS < bE && bS < aE;
        } else if (aS == null && aE != null && bS != null) {
          overlap = bS < aE;
        }
        if (overlap) {
          result
            ..add(i)
            ..add(j);
        }
      }
    }
    return result;
  }

  static bool _passed(DateTime date, int minute, DateTime now) =>
      !atMinute(date, minute).isAfter(now);

  static bool hasStarted(DayInstance i, DateTime now) {
    final s = i.start;
    if (s == null) return dateOnly(now).isAfter(i.date);
    return _passed(i.date, s, now);
  }

  /// Not done and its time is over (end, or start for momentary events).
  /// Overdue items are never auto-completed or removed.
  static bool isOverdue(DayInstance i, DateTime now) {
    if (i.done) return false;
    final m = i.end ?? i.start;
    if (m == null) return dateOnly(now).isAfter(i.date);
    return _passed(i.date, m, now);
  }

  static DayInstance? current(List<DayInstance> day, DateTime now) {
    for (final i in day) {
      final s = i.start;
      final e = i.end;
      if (s == null || e == null) continue;
      if (_passed(i.date, s, now) && !_passed(i.date, e, now)) return i;
    }
    return null;
  }

  /// First not-done activity after [activityId] in the day's order.
  static DayInstance? nextAfter(List<DayInstance> day, String activityId) {
    final idx = day.indexWhere((i) => i.activity.id == activityId);
    if (idx < 0) return null;
    for (var k = idx + 1; k < day.length; k++) {
      if (!day[k].done) return day[k];
    }
    return null;
  }

  /// First not-done activity that has not started yet.
  static DayInstance? firstUpcoming(List<DayInstance> day, DateTime now) {
    for (final i in day) {
      if (i.done || i.start == null) continue;
      if (!hasStarted(i, now)) return i;
    }
    return null;
  }

  /// "Next activity" shown on the home screen: after the most recently
  /// ticked item when there is one, otherwise the first upcoming item.
  static DayInstance? nextForHome(
    List<DayInstance> day,
    DateTime now, {
    String? anchorActivityId,
  }) {
    if (anchorActivityId != null &&
        day.any((i) => i.activity.id == anchorActivityId)) {
      return nextAfter(day, anchorActivityId);
    }
    return firstUpcoming(day, now);
  }

  static List<DayInstance> overdue(List<DayInstance> day, DateTime now) =>
      day.where((i) => isOverdue(i, now)).toList();
}
