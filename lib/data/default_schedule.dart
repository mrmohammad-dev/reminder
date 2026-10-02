import '../models/activity.dart';
import 'default_schedule_data.dart';
import 'line_parser.dart';

export 'default_schedule_data.dart';

const List<String> _schoolKeyByDay = <String>['', '', 'mon', 'tue', 'wed', '', ''];

/// Builds the 108 default activity definitions (both Monday variants
/// included). Ids and notification keys are stable across installs.
List<Activity> buildDefaultActivities() {
  final result = <Activity>[];
  var notifKey = 1;
  for (final section in defaultSections) {
    // Monday B rows are ordered after Monday A rows of the same day.
    final orderBase = section.idPrefix == 'mon_b' ? 100 : 0;
    for (var i = 0; i < section.lines.length; i++) {
      final line = section.lines[i];
      final parsed = parsePlanLine(line);
      final schoolKey = parsed.isSchool &&
              parsed.startMinute == null &&
              _schoolKeyByDay[section.day].isNotEmpty
          ? _schoolKeyByDay[section.day]
          : null;
      result.add(
        Activity(
          id: '${section.idPrefix}-${(i + 1).toString().padLeft(2, '0')}',
          notifKey: notifKey++,
          title: parsed.title,
          rawLine: line,
          day: section.day,
          weekType: section.weekType,
          startMinute: parsed.startMinute,
          endMinute: parsed.endMinute,
          category: categoryForTitle(parsed.title),
          sortOrder: orderBase + i,
          reminderEnabled: true,
          scheduleNote: parsed.scheduleNote,
          schoolKey: schoolKey,
        ),
      );
    }
  }
  return result;
}
