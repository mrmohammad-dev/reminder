import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/data/default_schedule.dart';
import 'package:reminder/models/enums.dart';

import 'support/original_plan_text.dart';

void main() {
  final sections = originalPlanText.trim().split('\n\n');

  test('has exactly 108 default definitions', () {
    expect(buildDefaultActivities().length, 108);
  });

  test('per-section line counts match the plan', () {
    final counts = <String, int>{
      for (final s in defaultSections) s.heading: s.lines.length,
    };
    expect(counts, <String, int>{
      'شنبه': 14,
      'یکشنبه': 12,
      'دوشنبه — هفته A': 12,
      'دوشنبه — هفته B': 14,
      'سه‌شنبه': 12,
      'چهارشنبه': 14,
      'پنجشنبه': 15,
      'جمعه': 15,
    });
  });

  test('every original line, its text and its order are preserved exactly', () {
    expect(defaultSections.length, sections.length);
    final acts = buildDefaultActivities();
    var k = 0;
    for (var s = 0; s < sections.length; s++) {
      final lines = sections[s].split('\n');
      expect('${defaultSections[s].heading}:', lines.first);
      expect(defaultSections[s].lines, lines.sublist(1));
      for (final line in lines.sublist(1)) {
        expect(acts[k].rawLine, line, reason: 'row $k');
        k++;
      }
    }
    expect(k, 108);
  });

  test('titles are kept in full and times are parsed without invention', () {
    final acts = buildDefaultActivities();
    final sat = acts.where((a) => a.id.startsWith('sat-')).toList();
    expect(sat.first.title, 'بیدار شدن');
    expect(sat.first.startMinute, 6 * 60 + 30);
    expect(sat.first.endMinute, isNull, reason: 'wake-up is momentary');
    expect(sat[4].title, 'ریاضی — ویدئوی آموزشی یوتیوب');
    expect(sat[4].startMinute, 15 * 60 + 45);
    expect(sat[4].endMinute, 16 * 60 + 30);

    final sleep = acts.firstWhere((a) => a.id == 'sat-14');
    expect(sleep.rawLine, '23:00–23:30 خواب');
    expect(sleep.startMinute, 23 * 60);
    expect(sleep.endMinute, 23 * 60 + 30);
  });

  test('ids and notification keys are unique and stable', () {
    final a = buildDefaultActivities();
    final b = buildDefaultActivities();
    expect(a.map((x) => x.id).toSet().length, 108);
    expect(a.map((x) => x.notifKey).toSet().length, 108);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].id, b[i].id);
      expect(a[i].notifKey, b[i].notifKey);
    }
  });

  test('Monday rows are tagged A / B and other days apply to both', () {
    final acts = buildDefaultActivities();
    expect(acts.where((a) => a.weekType == WeekType.a).length, 12);
    expect(acts.where((a) => a.weekType == WeekType.b).length, 14);
    expect(acts.where((a) => a.day == 2 && a.weekType == WeekType.both), isEmpty);
  });

  test('every default category is one of the defined categories', () {
    final acts = buildDefaultActivities();
    expect(
      acts.firstWhere((a) => a.id == 'sat-03').category,
      ActivityCategory.school,
    );
    expect(
      acts.firstWhere((a) => a.id == 'tue-06').category,
      ActivityCategory.olympiad,
    );
    expect(
      acts.firstWhere((a) => a.id == 'sun-08').category,
      ActivityCategory.gym,
    );
  });
}
