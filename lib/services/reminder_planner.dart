import 'dart:convert';

import '../models/activity.dart';
import '../models/settings.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'schedule_service.dart';

/// Data stored inside each notification. It lets background handlers know
/// which activity instance a notification belongs to, and lets the sync
/// detect whether an already-pending notification is still up to date.
class ReminderPayload {
  const ReminderPayload({
    required this.kind,
    required this.activityId,
    required this.dateKey,
    this.atMillis,
    this.exact,
    this.snoozeMinutes,
  });

  static const String reminder = 'r';
  static const String snooze = 's';

  final String kind;
  final String activityId;
  final String dateKey;
  final int? atMillis;
  final bool? exact;
  final int? snoozeMinutes;

  String encode() => jsonEncode(<String, Object?>{
    'k': kind,
    'a': activityId,
    'd': dateKey,
    if (atMillis != null) 'at': atMillis,
    if (exact != null) 'x': exact! ? 1 : 0,
    if (snoozeMinutes != null) 'z': snoozeMinutes,
  });

  static ReminderPayload? tryDecode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final m = jsonDecode(text);
      if (m is! Map) return null;
      final k = m['k'];
      final a = m['a'];
      final d = m['d'];
      if (k is! String || a is! String || d is! String) return null;
      if (!isValidDateKey(d)) return null;
      final at = m['at'];
      final x = m['x'];
      final z = m['z'];
      return ReminderPayload(
        kind: k,
        activityId: a,
        dateKey: d,
        atMillis: at is int ? at : null,
        exact: x is int ? x == 1 : null,
        snoozeMinutes: z is int ? z : null,
      );
    } on FormatException {
      return null;
    }
  }
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.activity,
    required this.date,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  final int id;
  final Activity activity;
  final DateTime date;

  /// Wall-clock fire time in the schedule timezone.
  final DateTime fireAt;
  final String title;
  final String body;
}

class ReminderPlanner {
  const ReminderPlanner._();

  /// Rolling scheduling window. It is refreshed on app start/resume, after
  /// every change, on boot/update/time change and once a day by a native
  /// inexact alarm (see android/.../ResyncReceiver.kt).
  static const int windowDays = 14;

  /// Fixed id for the short «فعالیت بعدی» notification.
  static const int nextInfoId = 2100000000;

  /// Stable, unique id per (activity, date). notifKey < 2,000,000 and the
  /// date part repeats only every 1000 days, far beyond the 14-day window.
  static int reminderId(int notifKey, DateTime date) =>
      notifKey * 1000 + (epochDay(date) % 1000);

  static int snoozeId(int notifKey, DateTime date) =>
      -reminderId(notifKey, date) - 1;

  static String bodyFor(DayInstance i, int leadMinutes) {
    final timing = leadMinutes == 0
        ? 'زمان شروع'
        : '${faDigits(leadMinutes)} دقیقه تا شروع';
    return 'ساعت ${i.timeLabel} • $timing';
  }

  /// Pure planning: which reminders should exist right now.
  /// Instances whose reminder time already passed are skipped, so opening
  /// the app or unticking never fires a burst of late notifications.
  static List<PlannedReminder> plan({
    required List<Activity> activities,
    required AppSettings settings,
    required Map<String, Set<String>> completions,
    required DateTime now,
    int days = windowDays,
  }) {
    if (!settings.remindersEnabled) return const <PlannedReminder>[];
    final today = dateOnly(now);
    final result = <PlannedReminder>[];
    for (var d = 0; d < days; d++) {
      final date = addDays(today, d);
      final key = dateKey(date);
      final instances = ScheduleService.buildDay(
        activities: activities,
        date: date,
        settings: settings,
        doneIds: completions[key] ?? const <String>{},
      );
      for (final i in instances) {
        final start = i.start;
        if (start == null || i.done || !i.activity.reminderEnabled) continue;
        final fire = atMinute(
          date,
          start,
        ).subtract(Duration(minutes: settings.leadMinutes));
        if (!fire.isAfter(now)) continue;
        result.add(
          PlannedReminder(
            id: reminderId(i.activity.notifKey, date),
            activity: i.activity,
            date: date,
            fireAt: fire,
            title: i.activity.title,
            body: bodyFor(i, settings.leadMinutes),
          ),
        );
      }
    }
    result.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return result;
  }
}
