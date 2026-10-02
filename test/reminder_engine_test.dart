import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/data/default_schedule.dart';
import 'package:reminder/services/reminder_engine.dart';
import 'package:reminder/services/reminder_planner.dart';
import 'package:reminder/util/dates.dart';

import 'support/fakes.dart';

void main() {
  final saturday = DateTime.utc(2026, 9, 26);
  final nextSaturday = DateTime.utc(2026, 10, 3);
  final defaults = {for (final a in buildDefaultActivities()) a.id: a};

  int rid(String id, DateTime date) =>
      ReminderPlanner.reminderId(defaults[id]!.notifKey, date);

  test('ticks are independent per date', () async {
    final rig = TestRig();
    await rig.engine.setDone('sat-01', saturday, true);
    expect(await rig.repo.completedIdsOn('2026-09-26'), {'sat-01'});
    expect(await rig.repo.completedIdsOn('2026-10-03'), isEmpty);
  });

  test('tick then untick; ticking twice creates no duplicate rows', () async {
    final rig = TestRig();
    await rig.engine.setDone('sat-05', saturday, true);
    await rig.engine.setDone('sat-05', saturday, true);
    expect(rig.repo.completionCount, 1);
    await rig.engine.setDone('sat-05', saturday, false);
    expect(await rig.repo.completedIdsOn('2026-09-26'), isEmpty);
  });

  test('ticking cancels that instance reminder only', () async {
    final rig = TestRig();
    await rig.engine.resync();
    expect(rig.gateway.scheduled.containsKey(rid('sat-05', saturday)), isTrue);
    await rig.engine.setDone('sat-05', saturday, true);
    expect(rig.gateway.scheduled.containsKey(rid('sat-05', saturday)), isFalse);
    expect(rig.gateway.cancelled, contains(rid('sat-05', saturday)));
    // Same activity next week is still scheduled.
    expect(
      rig.gateway.scheduled.containsKey(rid('sat-05', nextSaturday)),
      isTrue,
    );
  });

  test('unticking a future activity restores its reminder', () async {
    final rig = TestRig();
    await rig.engine.setDone('sat-05', saturday, true);
    await rig.engine.setDone('sat-05', saturday, false);
    final spec = rig.gateway.scheduled[rid('sat-05', saturday)]!;
    expect(spec.fireAt, DateTime.utc(2026, 9, 26, 15, 45));
  });

  test('unticking a past activity sends no immediate notification', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 12, 0));
    await rig.engine.setDone('sat-01', saturday, true);
    final shownBefore = rig.gateway.shown.length;
    await rig.engine.setDone('sat-01', saturday, false);
    expect(rig.gateway.shown.length, shownBefore);
    expect(rig.gateway.scheduled.containsKey(rid('sat-01', saturday)), isFalse);
  });

  test('early or late ticks never move any times', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 8, 0));
    await rig.engine.setDone('sat-03', saturday, true); // early
    var r = await rig.engine.setDone('sat-04', saturday, true); // early
    expect(r.next!.activity.id, 'sat-05');
    expect(r.next!.start, 15 * 60 + 45);
    rig.clock.value = DateTime.utc(2026, 9, 26, 22, 50);
    r = await rig.engine.setDone('sat-05', saturday, true); // late
    expect(r.next!.activity.id, 'sat-06');
    expect(r.nextOverdue, isTrue);
    final acts = await rig.repo.getActivities();
    for (final a in acts) {
      expect(a.startMinute, defaults[a.id]!.startMinute);
      expect(a.endMinute, defaults[a.id]!.endMinute);
    }
    final sleep = rig.gateway.scheduled[rid('sat-14', saturday)]!;
    expect(sleep.fireAt, DateTime.utc(2026, 9, 26, 23, 0));
  });

  test('«فعالیت بعدی» notification after ticking', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 15, 0));
    await rig.engine.setDone('sat-04', saturday, true);
    final info = rig.gateway.shown.last;
    expect(info.id, ReminderPlanner.nextInfoId);
    expect(info.title, 'فعالیت بعدی');
    expect(info.body, contains('ریاضی — ویدئوی آموزشی یوتیوب'));
    expect(info.body, contains('۱۵:۴۵'));
  });

  test('no info notification without permission', () async {
    final rig = TestRig();
    rig.gateway.enabled = false;
    await rig.engine.setDone('sat-01', saturday, true);
    expect(rig.gateway.shown, isEmpty);
  });

  test('last activity done -> «برنامه امروز تمام شد»', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 23, 10));
    final r = await rig.engine.setDone('sat-14', saturday, true);
    expect(r.next, isNull);
    expect(rig.gateway.shown.last.body, 'برنامه امروز تمام شد');
  });

  test('resync is idempotent: no duplicate notifications', () async {
    final rig = TestRig();
    final first = await rig.engine.resync();
    final count = rig.gateway.scheduled.length;
    expect(count, first.plannedCount);
    final second = await rig.engine.resync();
    expect(rig.gateway.scheduled.length, count);
    expect(second.scheduledNow, 0, reason: 'up-to-date entries are skipped');
    final ids = rig.gateway.scheduled.keys.toList();
    expect(ids.toSet().length, ids.length);
  });

  test('14-day window is planned and refreshed as days pass', () async {
    final rig = TestRig();
    await rig.engine.resync();
    final dates = rig.gateway.scheduled.values.map((s) => dateOnly(s.fireAt));
    expect(dates.reduce((a, b) => a.isAfter(b) ? a : b), DateTime.utc(2026, 10, 9));
    rig.clock.value = DateTime.utc(2026, 10, 1, 4, 0);
    await rig.engine.resync();
    final later = rig.gateway.scheduled.values.map((s) => dateOnly(s.fireAt));
    expect(later.reduce((a, b) => a.isAfter(b) ? a : b), DateTime.utc(2026, 10, 14));
  });

  test('deleting an activity cancels its notifications', () async {
    final rig = TestRig();
    await rig.engine.resync();
    expect(rig.gateway.scheduled.containsKey(rid('sat-11', saturday)), isTrue);
    await rig.repo.deleteActivity('sat-11');
    await rig.engine.resync();
    expect(rig.gateway.scheduled.containsKey(rid('sat-11', saturday)), isFalse);
    expect(rig.gateway.scheduled.containsKey(rid('sat-11', nextSaturday)), isFalse);
  });

  test('editing a time replaces the old notification (same id)', () async {
    final rig = TestRig();
    await rig.engine.resync();
    final a = defaults['sat-11']!;
    await rig.repo.upsertActivity(a.copyWith(startMinute: 21 * 60 + 5));
    await rig.engine.resync();
    expect(
      rig.gateway.scheduled[rid('sat-11', saturday)]!.fireAt,
      DateTime.utc(2026, 9, 26, 21, 5),
    );
  });

  test('lead time shifts only the notification, not the activity', () async {
    final rig = TestRig(settings: testSettings(lead: 10));
    await rig.engine.resync();
    expect(
      rig.gateway.scheduled[rid('sat-05', saturday)]!.fireAt,
      DateTime.utc(2026, 9, 26, 15, 35),
    );
    expect((await rig.repo.getActivities()).firstWhere((x) => x.id == 'sat-05').startMinute, 15 * 60 + 45);
  });

  test('snooze moves only that notification', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 15, 45));
    await rig.engine.resync();
    final before = Map.of(rig.gateway.scheduled)
      ..remove(rid('sat-05', saturday));
    await rig.engine.snooze('sat-05', '2026-09-26');
    final sid = ReminderPlanner.snoozeId(defaults['sat-05']!.notifKey, saturday);
    expect(rig.gateway.scheduled[sid]!.fireAt, DateTime.utc(2026, 9, 26, 15, 55));
    for (final e in before.entries) {
      expect(rig.gateway.scheduled[e.key]!.fireAt, e.value.fireAt);
    }
    final a = (await rig.repo.getActivities()).firstWhere((x) => x.id == 'sat-05');
    expect(a.startMinute, 15 * 60 + 45);
    expect(a.endMinute, 16 * 60 + 30);
    // Ticking after a snooze cancels the snoozed notification too.
    await rig.engine.setDone('sat-05', saturday, true);
    expect(rig.gateway.scheduled.containsKey(sid), isFalse);
  });

  test('snooze survives resync but is dropped for deleted activity', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 15, 45));
    await rig.engine.snooze('sat-05', '2026-09-26');
    final sid = ReminderPlanner.snoozeId(defaults['sat-05']!.notifKey, saturday);
    await rig.engine.resync();
    expect(rig.gateway.scheduled.containsKey(sid), isTrue);
    await rig.repo.deleteActivity('sat-05');
    await rig.engine.resync();
    expect(rig.gateway.scheduled.containsKey(sid), isFalse);
  });

  test('«انجام شد» action from a notification saves and announces next', () async {
    final rig = TestRig(now: DateTime.utc(2026, 9, 26, 15, 46));
    await rig.engine.resync();
    final spec = rig.gateway.scheduled[rid('sat-06', saturday)]!;
    await rig.engine.handleAction(ReminderEngine.actionDone, spec.payload);
    expect(await rig.repo.completedIdsOn('2026-09-26'), {'sat-06'});
    expect(rig.gateway.shown.last.title, 'فعالیت بعدی');
    expect(rig.gateway.shown.last.body, contains('آماده شدن برای کلاس'));
  });

  test('reminders disabled -> nothing scheduled', () async {
    final rig = TestRig(settings: testSettings(reminders: false));
    await rig.engine.resync();
    expect(rig.gateway.scheduled, isEmpty);
  });

  test('ids are unique across the window', () {
    final plan = ReminderPlanner.plan(
      activities: defaults.values.toList(),
      settings: testSettings(),
      completions: const {},
      now: DateTime.utc(2026, 9, 26),
    );
    expect(plan.map((p) => p.id).toSet().length, plan.length);
    expect(plan.every((p) => p.id > 0 && p.id < ReminderPlanner.nextInfoId), isTrue);
  });
}
