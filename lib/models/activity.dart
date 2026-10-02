import '../util/dates.dart';
import 'enums.dart';

const Object _keep = Object();

/// A weekly activity template (one row of the weekly plan).
class Activity {
  const Activity({
    required this.id,
    required this.notifKey,
    required this.title,
    required this.rawLine,
    required this.day,
    required this.weekType,
    required this.startMinute,
    required this.endMinute,
    required this.category,
    required this.sortOrder,
    required this.reminderEnabled,
    this.scheduleNote,
    this.schoolKey,
  });

  /// Stable string id (e.g. `sat-03`). Never reused for another activity.
  final String id;

  /// Stable small integer used to derive notification ids.
  final int notifKey;

  /// Full title, never shortened.
  final String title;

  /// Original line of the plan exactly as written.
  final String rawLine;

  /// 0 = Saturday ... 6 = Friday.
  final int day;
  final WeekType weekType;

  /// Minutes from midnight. Null means "not specified" (no invented time).
  final int? startMinute;
  final int? endMinute;
  final ActivityCategory category;
  final int sortOrder;
  final bool reminderEnabled;

  /// Explanation for ambiguous timing, if any.
  final String? scheduleNote;

  /// For school rows whose times come from Settings: `mon`, `tue`, `wed`.
  final String? schoolKey;

  Activity copyWith({
    String? id,
    int? notifKey,
    String? title,
    String? rawLine,
    int? day,
    WeekType? weekType,
    Object? startMinute = _keep,
    Object? endMinute = _keep,
    ActivityCategory? category,
    int? sortOrder,
    bool? reminderEnabled,
    Object? scheduleNote = _keep,
    Object? schoolKey = _keep,
  }) {
    return Activity(
      id: id ?? this.id,
      notifKey: notifKey ?? this.notifKey,
      title: title ?? this.title,
      rawLine: rawLine ?? this.rawLine,
      day: day ?? this.day,
      weekType: weekType ?? this.weekType,
      startMinute: identical(startMinute, _keep)
          ? this.startMinute
          : startMinute as int?,
      endMinute: identical(endMinute, _keep) ? this.endMinute : endMinute as int?,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      scheduleNote: identical(scheduleNote, _keep)
          ? this.scheduleNote
          : scheduleNote as String?,
      schoolKey: identical(schoolKey, _keep)
          ? this.schoolKey
          : schoolKey as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'notif_key': notifKey,
    'title': title,
    'raw_line': rawLine,
    'day': day,
    'week_type': weekType.name,
    'start_minute': startMinute,
    'end_minute': endMinute,
    'category': category.name,
    'sort_order': sortOrder,
    'reminder_enabled': reminderEnabled ? 1 : 0,
    'schedule_note': scheduleNote,
    'school_key': schoolKey,
  };

  /// Strict parser used for database rows and backup files.
  factory Activity.fromMap(Map<String, Object?> map) {
    final id = map['id'];
    final notifKey = map['notif_key'];
    final title = map['title'];
    final rawLine = map['raw_line'];
    final day = map['day'];
    final week = map['week_type'];
    final start = map['start_minute'];
    final end = map['end_minute'];
    final category = map['category'];
    final sortOrder = map['sort_order'];
    final reminder = map['reminder_enabled'];
    final note = map['schedule_note'];
    final schoolKey = map['school_key'];

    if (id is! String || id.isEmpty) throw const FormatException('id');
    if (notifKey is! int || notifKey <= 0 || notifKey >= 2000000) {
      throw const FormatException('notif_key');
    }
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('title');
    }
    if (rawLine is! String) throw const FormatException('raw_line');
    if (day is! int || day < 0 || day > 6) throw const FormatException('day');
    if (week is! String) throw const FormatException('week_type');
    if (start != null && (start is! int || !isValidMinute(start))) {
      throw const FormatException('start_minute');
    }
    if (end != null && (end is! int || !isValidMinute(end))) {
      throw const FormatException('end_minute');
    }
    if (category is! String) throw const FormatException('category');
    if (sortOrder is! int) throw const FormatException('sort_order');
    if (reminder is! int && reminder is! bool) {
      throw const FormatException('reminder_enabled');
    }
    if (note != null && note is! String) {
      throw const FormatException('schedule_note');
    }
    if (schoolKey != null &&
        (schoolKey is! String || !schoolKeys.contains(schoolKey))) {
      throw const FormatException('school_key');
    }
    return Activity(
      id: id,
      notifKey: notifKey,
      title: title,
      rawLine: rawLine,
      day: day,
      weekType: weekTypeFromName(week),
      startMinute: start as int?,
      endMinute: end as int?,
      category: categoryFromName(category),
      sortOrder: sortOrder,
      reminderEnabled: reminder == true || reminder == 1,
      scheduleNote: note as String?,
      schoolKey: schoolKey as String?,
    );
  }

  static const List<String> schoolKeys = <String>['mon', 'tue', 'wed'];

  @override
  String toString() => 'Activity($id, $rawLine)';
}
