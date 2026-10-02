import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/data/default_schedule.dart';
import 'package:reminder/data/line_parser.dart';
import 'package:reminder/models/enums.dart';
import 'package:reminder/services/reminder_planner.dart';
import 'package:reminder/services/schedule_service.dart';

import 'support/fakes.dart';

void main() {
  final acts = buildDefaultActivities();
  final mondayA = DateTime.utc(2026, 9, 28);
  final mondayB = DateTime.utc(2026, 10, 5);
  final tuesdayA = DateTime.utc(2026, 9, 29);
  final tuesdayB = DateTime.utc(2026, 10, 6);

  List<DayInstance> day(DateTime d, {Map<String, int> school = const {}}) =>
      ScheduleService.buildDay(
        activities: acts,
        date: d,
        settings: testSettings(school: school),
        doneIds: const <String>{},
      );

  test('only the Monday of the active week is shown', () {
    final a = day(mondayA);
    final b = day(mondayB);
    expect(a.length, 12);
    expect(b.length, 14);
    expect(a.every((i) => i.activity.weekType == WeekType.a), isTrue);
    expect(b.every((i) => i.activity.weekType == WeekType.b), isTrue);
    expect(a[1].activity.rawLine, 'تا 15:00 مدرسه');
    expect(b[1].activity.rawLine, 'تا 13:00 مدرسه');
  });

  test('Monday school keeps unknown start, known end, no invented time', () {
    final school = day(mondayA)[1];
    expect(school.start, isNull);
    expect(school.end, 15 * 60);
    expect(school.needsSetup, isTrue);
  });

  test('Tuesday/Wednesday ambiguous school text is preserved', () {
    final tue = day(tuesdayA);
    expect(tue.length, 12);
    final school = tue[1];
    expect(school.activity.rawLine, 'مدرسه تا 13:00 یا 15:00، مطابق هفته');
    expect(school.activity.scheduleNote, 'مدرسه تا 13:00 یا 15:00، مطابق هفته');
    expect(school.start, isNull);
    expect(school.end, isNull);
    expect(school.timeLabel, 'مدرسه تا 13:00 یا 15:00، مطابق هفته');
    expect(school.needsSetup, isTrue);
    expect(school.conflict, isFalse);
  });

  test('school times for A and B are independent per day', () {
    final s = <String, int>{'tue_a_end': 15 * 60, 'tue_b_end': 13 * 60};
    expect(day(tuesdayA, school: s)[1].end, 15 * 60);
    expect(day(tuesdayB, school: s)[1].end, 13 * 60);
    // Wednesday is not derived from Tuesday or Monday.
    expect(day(DateTime.utc(2026, 9, 30), school: s)[1].end, isNull);
  });

  test('school until 15:00 conflicts with the 14:00 activity, nothing removed', () {
    final tue = day(tuesdayA, school: <String, int>{'tue_a_end': 15 * 60});
    expect(tue.length, 12);
    expect(tue[1].conflict, isTrue);
    expect(tue[2].activity.rawLine, '14:00–15:00 فیزیک — ویدئوی آموزشی');
    expect(tue[2].conflict, isTrue);
    expect(tue[2].start, 14 * 60, reason: 'time not moved');
    expect(tue[0].conflict, isFalse, reason: 'wake-up is momentary');
    final early = day(tuesdayA, school: <String, int>{'tue_a_end': 13 * 60});
    expect(early.any((i) => i.conflict), isFalse);
  });

  test('default Saturday has no false conflicts (touching ranges)', () {
    expect(day(DateTime.utc(2026, 9, 26)).any((i) => i.conflict), isFalse);
  });

  test('unknown school start gets no reminder until it is set', () {
    final now = DateTime.utc(2026, 9, 28, 0, 0);
    final plan = ReminderPlanner.plan(
      activities: acts,
      settings: testSettings(),
      completions: const {},
      now: now,
      days: 1,
    );
    expect(plan.any((p) => p.activity.id == 'mon_a-02'), isFalse);
    expect(plan.any((p) => p.activity.id == 'mon_a-01'), isTrue);

    final withStart = ReminderPlanner.plan(
      activities: acts,
      settings: testSettings(school: <String, int>{'mon_a_start': 7 * 60}),
      completions: const {},
      now: now,
      days: 1,
    );
    final r = withStart.firstWhere((p) => p.activity.id == 'mon_a-02');
    expect(r.fireAt, DateTime.utc(2026, 9, 28, 7, 0));
  });

  test('overdue activities are kept and flagged, never auto-completed', () {
    final now = DateTime.utc(2026, 9, 26, 10, 0);
    final list = day(DateTime.utc(2026, 9, 26));
    final overdue = ScheduleService.overdue(list, now);
    expect(overdue.map((i) => i.activity.id), <String>['sat-01', 'sat-02']);
    expect(list.length, 14);
    expect(list.where((i) => i.done), isEmpty);
    expect(ScheduleService.current(list, now)!.activity.id, 'sat-03');
  });

  test('next activity is the first not-done item after the ticked one', () {
    final list = ScheduleService.buildDay(
      activities: acts,
      date: DateTime.utc(2026, 9, 26),
      settings: testSettings(),
      doneIds: const <String>{'sat-03', 'sat-04'},
    );
    expect(ScheduleService.nextAfter(list, 'sat-03')!.activity.id, 'sat-05');
    final all = ScheduleService.buildDay(
      activities: acts,
      date: DateTime.utc(2026, 9, 26),
      settings: testSettings(),
      doneIds: acts.where((a) => a.day == 0).map((a) => a.id).toSet(),
    );
    expect(ScheduleService.nextAfter(all, 'sat-01'), isNull);
  });

  test('parser keeps titles and never invents times', () {
    final p = parsePlanLine('06:30 بیدار شدن');
    expect(p.startMinute, 390);
    expect(p.endMinute, isNull);
    final q = parsePlanLine('22:45–23:30 وقت آزاد و خواب');
    expect(q.title, 'وقت آزاد و خواب');
    expect(q.endMinute, 23 * 60 + 30);
  });
}
