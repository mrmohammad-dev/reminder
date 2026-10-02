import '../data/repository.dart';
import '../data/settings_store.dart';
import '../models/activity.dart';
import '../models/settings.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'clock.dart';
import 'notification_gateway.dart';
import 'reminder_planner.dart';
import 'schedule_service.dart';

class SyncReport {
  const SyncReport({
    required this.plannedCount,
    required this.scheduledNow,
    required this.exact,
    required this.nearest,
  });

  final int plannedCount;

  /// How many notifications had to be (re)scheduled in this run.
  final int scheduledNow;
  final bool exact;
  final PlannedReminder? nearest;
}

class DoneResult {
  const DoneResult({required this.next, required this.nextOverdue});
  final DayInstance? next;
  final bool nextOverdue;
}

/// Core reminder logic shared by the UI isolate and background isolates
/// (notification actions, boot, time change, daily refresh).
class ReminderEngine {
  ReminderEngine({
    required this.repo,
    required this.settingsStore,
    required this.gateway,
    required this.clock,
  });

  final ActivityRepository repo;
  final SettingsStore settingsStore;
  final NotificationGateway gateway;
  final WallClock clock;

  Future<List<PlannedReminder>> computePlan(AppSettings settings) async {
    final now = clock.now(useTehran: settings.useTehranTimezone);
    final today = dateOnly(now);
    final completions = await repo.completedIdsBetween(
      dateKey(today),
      dateKey(addDays(today, ReminderPlanner.windowDays - 1)),
    );
    return ReminderPlanner.plan(
      activities: await repo.getActivities(),
      settings: settings,
      completions: completions,
      now: now,
    );
  }

  /// Makes the pending notifications match the plan:
  /// * cancels reminders that are no longer planned (deleted/edited/done),
  /// * cancels snoozes of done or deleted activities,
  /// * (re)schedules planned reminders that are missing or out of date.
  /// Ids are stable, so running this any number of times never creates
  /// duplicate notifications.
  Future<SyncReport> resync() async {
    final settings = await settingsStore.load();
    final planned = await computePlan(settings);
    final activities = await repo.getActivities();
    final byId = <String, Activity>{for (final a in activities) a.id: a};
    final exact = await gateway.canScheduleExact();

    final wanted = <int, NotificationSpec>{};
    for (final p in planned) {
      final at = gateway.epochMillisFor(
        p.fireAt,
        useTehran: settings.useTehranTimezone,
      );
      wanted[p.id] = NotificationSpec(
        id: p.id,
        title: p.title,
        body: p.body,
        fireAt: p.fireAt,
        payload: ReminderPayload(
          kind: ReminderPayload.reminder,
          activityId: p.activity.id,
          dateKey: dateKey(p.date),
          atMillis: at,
          exact: exact,
          snoozeMinutes: settings.snoozeMinutes,
        ).encode(),
        exact: exact,
        snoozeMinutes: settings.snoozeMinutes,
        useTehran: settings.useTehranTimezone,
      );
    }

    final upToDate = <int>{};
    for (final p in await gateway.pending()) {
      final payload = ReminderPayload.tryDecode(p.payload);
      if (payload == null) continue;
      if (payload.kind == ReminderPayload.reminder) {
        final w = wanted[p.id];
        if (w == null) {
          await gateway.cancel(p.id);
        } else if (w.payload == p.payload &&
            w.title == p.title &&
            w.body == p.body) {
          upToDate.add(p.id);
        }
      } else if (payload.kind == ReminderPayload.snooze) {
        final a = byId[payload.activityId];
        final done = await repo.completedIdsOn(payload.dateKey);
        if (a == null ||
            !a.reminderEnabled ||
            !settings.remindersEnabled ||
            done.contains(a.id)) {
          await gateway.cancel(p.id);
        }
      }
    }

    var scheduled = 0;
    for (final spec in wanted.values) {
      if (upToDate.contains(spec.id)) continue;
      await gateway.schedule(spec);
      scheduled++;
    }
    return SyncReport(
      plannedCount: planned.length,
      scheduledNow: scheduled,
      exact: exact,
      nearest: planned.isEmpty ? null : planned.first,
    );
  }

  /// Ticks / unticks one activity on one date.
  ///
  /// Never changes any activity time. Ticking early or late only affects
  /// this instance; the next activities keep their own original times.
  Future<DoneResult> setDone(
    String activityId,
    DateTime date,
    bool done, {
    bool announceNext = true,
  }) async {
    final settings = await settingsStore.load();
    final now = clock.now(useTehran: settings.useTehranTimezone);
    final activities = await repo.getActivities();
    Activity? activity;
    for (final a in activities) {
      if (a.id == activityId) activity = a;
    }
    final key = dateKey(date);
    if (activity == null) {
      return const DoneResult(next: null, nextOverdue: false);
    }
    await repo.setCompleted(
      activityId,
      key,
      done,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (done) {
      await gateway.cancel(ReminderPlanner.reminderId(activity.notifKey, date));
      await gateway.cancel(ReminderPlanner.snoozeId(activity.notifKey, date));
      await settingsStore.setAnchor(key, activityId);
    }

    final day = ScheduleService.buildDay(
      activities: activities,
      date: date,
      settings: settings,
      doneIds: await repo.completedIdsOn(key),
    );
    final next = done ? ScheduleService.nextAfter(day, activityId) : null;
    final nextOverdue = next != null && ScheduleService.isOverdue(next, now);

    final isToday = dateOnly(date) == dateOnly(now);
    if (done && announceNext && isToday && await gateway.notificationsEnabled()) {
      await gateway.showInfo(
        ReminderPlanner.nextInfoId,
        'فعالیت بعدی',
        nextText(next, nextOverdue),
      );
    }
    // Re-plans everything: an unticked activity whose reminder time is
    // still ahead gets its reminder back; a past one gets no instant alert.
    await resync();
    return DoneResult(next: next, nextOverdue: nextOverdue);
  }

  static String nextText(DayInstance? next, bool overdue) {
    if (next == null) return 'برنامه امروز تمام شد';
    final status = overdue ? ' (عقب‌افتاده)' : '';
    return '${next.activity.title} • ساعت ${next.timeLabel}$status';
  }

  /// Moves only this activity's notification; the plan is untouched.
  Future<void> snooze(String activityId, String dateKeyValue) async {
    final settings = await settingsStore.load();
    final now = clock.now(useTehran: settings.useTehranTimezone);
    Activity? activity;
    for (final a in await repo.getActivities()) {
      if (a.id == activityId) activity = a;
    }
    if (activity == null) return;
    if ((await repo.completedIdsOn(dateKeyValue)).contains(activityId)) return;
    final date = parseDateKey(dateKeyValue);
    final day = ScheduleService.buildDay(
      activities: <Activity>[activity],
      date: date,
      settings: settings,
      doneIds: const <String>{},
    );
    final timeLabel = day.isEmpty ? '' : day.first.timeLabel;
    final fire = now.add(Duration(minutes: settings.snoozeMinutes));
    final exact = await gateway.canScheduleExact();
    await gateway.cancel(ReminderPlanner.reminderId(activity.notifKey, date));
    await gateway.schedule(
      NotificationSpec(
        id: ReminderPlanner.snoozeId(activity.notifKey, date),
        title: activity.title,
        body: 'یادآوری دوباره (تعویق ${faDigits(settings.snoozeMinutes)} دقیقه) • ساعت $timeLabel',
        fireAt: fire,
        payload: ReminderPayload(
          kind: ReminderPayload.snooze,
          activityId: activityId,
          dateKey: dateKeyValue,
        ).encode(),
        exact: exact,
        snoozeMinutes: settings.snoozeMinutes,
        useTehran: settings.useTehranTimezone,
      ),
    );
  }

  /// Handles the action buttons of a notification.
  Future<void> handleAction(String? actionId, String? payloadText) async {
    final payload = ReminderPayload.tryDecode(payloadText);
    if (payload == null) return;
    if (actionId == actionDone) {
      await setDone(payload.activityId, parseDateKey(payload.dateKey), true);
    } else if (actionId == actionSnooze) {
      await snooze(payload.activityId, payload.dateKey);
    }
  }

  static const String actionDone = 'done';
  static const String actionSnooze = 'snooze';
}
