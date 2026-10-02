import '../models/enums.dart';

class ParsedLine {
  const ParsedLine({
    required this.title,
    this.startMinute,
    this.endMinute,
    this.scheduleNote,
    this.isSchool = false,
  });

  final String title;
  final int? startMinute;
  final int? endMinute;
  final String? scheduleNote;
  final bool isSchool;
}

final RegExp _range = RegExp(r'^(\d{2}):(\d{2})–(\d{2}):(\d{2}) (.+)$');
final RegExp _single = RegExp(r'^(\d{2}):(\d{2}) (.+)$');
final RegExp _until = RegExp(r'^تا (\d{2}):(\d{2}) (.+)$');

const String ambiguousSchoolPrefix = 'مدرسه تا ';
const String schoolTitle = 'مدرسه';
const String unknownSchoolStartNote =
    'ساعت شروع مدرسه در برنامه اصلی مشخص نشده است؛ از بخش تنظیمات تعیین کنید.';

int _hm(String h, String m) => int.parse(h) * 60 + int.parse(m);

/// Parses one line of the original plan without inventing any time.
ParsedLine parsePlanLine(String line) {
  final r = _range.firstMatch(line);
  if (r != null) {
    final title = r.group(5)!;
    return ParsedLine(
      title: title,
      startMinute: _hm(r.group(1)!, r.group(2)!),
      endMinute: _hm(r.group(3)!, r.group(4)!),
      isSchool: title == schoolTitle,
    );
  }
  final u = _until.firstMatch(line);
  if (u != null) {
    final title = u.group(3)!;
    return ParsedLine(
      title: title,
      endMinute: _hm(u.group(1)!, u.group(2)!),
      scheduleNote: title == schoolTitle ? unknownSchoolStartNote : null,
      isSchool: title == schoolTitle,
    );
  }
  if (line.startsWith(ambiguousSchoolPrefix)) {
    // «مدرسه تا 13:00 یا 15:00، مطابق هفته» : keep the sentence as the note.
    return ParsedLine(title: schoolTitle, scheduleNote: line, isSchool: true);
  }
  final s = _single.firstMatch(line);
  if (s != null) {
    final title = s.group(3)!;
    return ParsedLine(
      title: title,
      startMinute: _hm(s.group(1)!, s.group(2)!),
      isSchool: title == schoolTitle,
    );
  }
  return ParsedLine(title: line);
}

ActivityCategory categoryForTitle(String title) {
  if (title.contains('المپیاد')) return ActivityCategory.olympiad;
  if (title.contains('بیدار') || title.contains('خواب')) {
    return ActivityCategory.sleep;
  }
  if (title.contains('باشگاه')) return ActivityCategory.gym;
  if (title.startsWith('مدرسه') ||
      title.startsWith('تکالیف') ||
      title.contains('دروس مدرسه')) {
    return ActivityCategory.school;
  }
  if (title.contains('ریاضی')) return ActivityCategory.math;
  if (title.contains('فیزیک')) return ActivityCategory.physics;
  if (title.contains('شیمی')) return ActivityCategory.chemistry;
  if (title.contains('آلمانی')) return ActivityCategory.german;
  if (title.contains('انگلیسی')) return ActivityCategory.english;
  if (title.contains('پایتون')) return ActivityCategory.python;
  if (title.contains('استراحت') ||
      title.contains('ناهار') ||
      title.contains('شام') ||
      title.contains('صبحانه') ||
      title.contains('وقت آزاد')) {
    return ActivityCategory.rest;
  }
  return ActivityCategory.other;
}
