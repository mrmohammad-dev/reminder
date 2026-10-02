import '../util/dates.dart';
import 'enums.dart';

const Object _keep = Object();

class AppSettings {
  const AppSettings({
    required this.onboarded,
    required this.baseSaturdayKey,
    required this.baseWeekType,
    required this.remindersEnabled,
    required this.leadMinutes,
    required this.snoozeMinutes,
    required this.useTehranTimezone,
    required this.schoolTimes,
  });

  factory AppSettings.defaults() => const AppSettings(
    onboarded: false,
    baseSaturdayKey: null,
    baseWeekType: WeekType.a,
    remindersEnabled: true,
    leadMinutes: 0,
    snoozeMinutes: 10,
    useTehranTimezone: false,
    schoolTimes: <String, int>{},
  );

  static const List<int> allowedLeadMinutes = <int>[0, 5, 10, 15];
  static const List<int> allowedSnoozeMinutes = <int>[5, 10, 15];

  /// Keys for school times that the plan leaves open.
  /// Monday end times are fixed by the plan (A: 15:00, B: 13:00).
  static const List<String> schoolTimeKeys = <String>[
    'mon_a_start',
    'mon_b_start',
    'tue_a_start',
    'tue_a_end',
    'tue_b_start',
    'tue_b_end',
    'wed_a_start',
    'wed_a_end',
    'wed_b_start',
    'wed_b_end',
  ];

  final bool onboarded;

  /// Reference Saturday (yyyy-MM-dd) and its week type (A or B).
  final String? baseSaturdayKey;
  final WeekType baseWeekType;
  final bool remindersEnabled;
  final int leadMinutes;
  final int snoozeMinutes;
  final bool useTehranTimezone;
  final Map<String, int> schoolTimes;

  DateTime? get baseSaturday =>
      baseSaturdayKey == null ? null : parseDateKey(baseSaturdayKey!);

  int? schoolTime(String schoolKey, WeekType week, String edge) =>
      schoolTimes['${schoolKey}_${week.name}_$edge'];

  AppSettings copyWith({
    bool? onboarded,
    Object? baseSaturdayKey = _keep,
    WeekType? baseWeekType,
    bool? remindersEnabled,
    int? leadMinutes,
    int? snoozeMinutes,
    bool? useTehranTimezone,
    Map<String, int>? schoolTimes,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      baseSaturdayKey: identical(baseSaturdayKey, _keep)
          ? this.baseSaturdayKey
          : baseSaturdayKey as String?,
      baseWeekType: baseWeekType ?? this.baseWeekType,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      useTehranTimezone: useTehranTimezone ?? this.useTehranTimezone,
      schoolTimes: schoolTimes ?? this.schoolTimes,
    );
  }

  AppSettings withSchoolTime(String key, int? minute) {
    final map = Map<String, int>.from(schoolTimes);
    if (minute == null) {
      map.remove(key);
    } else {
      map[key] = minute;
    }
    return copyWith(schoolTimes: map);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'onboarded': onboarded,
    'baseSaturday': baseSaturdayKey,
    'baseWeekType': baseWeekType.name,
    'remindersEnabled': remindersEnabled,
    'leadMinutes': leadMinutes,
    'snoozeMinutes': snoozeMinutes,
    'useTehranTimezone': useTehranTimezone,
    'schoolTimes': schoolTimes,
  };

  /// Strict parser (used for backups and stored settings).
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final onboarded = json['onboarded'];
    final base = json['baseSaturday'];
    final baseWeek = json['baseWeekType'];
    final reminders = json['remindersEnabled'];
    final lead = json['leadMinutes'];
    final snooze = json['snoozeMinutes'];
    final tehran = json['useTehranTimezone'];
    final school = json['schoolTimes'];

    if (onboarded is! bool) throw const FormatException('onboarded');
    if (base != null) {
      if (base is! String || !isValidDateKey(base)) {
        throw const FormatException('baseSaturday');
      }
      if (dayIndexOf(parseDateKey(base)) != 0) {
        throw const FormatException('baseSaturday must be a Saturday');
      }
    }
    if (baseWeek is! String) throw const FormatException('baseWeekType');
    final week = weekTypeFromName(baseWeek);
    if (week == WeekType.both) throw const FormatException('baseWeekType');
    if (reminders is! bool) throw const FormatException('remindersEnabled');
    if (lead is! int || !allowedLeadMinutes.contains(lead)) {
      throw const FormatException('leadMinutes');
    }
    if (snooze is! int || !allowedSnoozeMinutes.contains(snooze)) {
      throw const FormatException('snoozeMinutes');
    }
    if (tehran is! bool) throw const FormatException('useTehranTimezone');
    if (school is! Map) throw const FormatException('schoolTimes');
    final times = <String, int>{};
    school.forEach((k, v) {
      if (k is! String || !schoolTimeKeys.contains(k)) {
        throw const FormatException('schoolTimes key');
      }
      if (v is! int || !isValidMinute(v)) {
        throw const FormatException('schoolTimes value');
      }
      times[k] = v;
    });
    return AppSettings(
      onboarded: onboarded,
      baseSaturdayKey: base as String?,
      baseWeekType: week,
      remindersEnabled: reminders,
      leadMinutes: lead,
      snoozeMinutes: snooze,
      useTehranTimezone: tehran,
      schoolTimes: times,
    );
  }
}
