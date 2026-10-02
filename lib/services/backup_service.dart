import 'dart:convert';

import '../data/default_schedule.dart';
import '../data/repository.dart';
import '../data/settings_store.dart';
import '../models/activity.dart';
import '../models/completion.dart';
import '../models/settings.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupData {
  const BackupData({
    required this.settings,
    required this.activities,
    required this.completions,
  });

  final AppSettings settings;
  final List<Activity> activities;
  final List<Completion> completions;
}

class BackupService {
  const BackupService._();

  static const String format = 'com.mohammad.reminder.backup';
  static const int formatVersion = 1;

  static Future<String> export(
    ActivityRepository repo,
    SettingsStore store, {
    DateTime? exportedAt,
  }) async {
    final settings = await store.load();
    final activities = await repo.getActivities();
    final history = await repo.allCompletions();
    final map = <String, Object?>{
      'format': format,
      'version': formatVersion,
      'title': defaultScheduleTitle,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'settings': settings.toJson(),
      'activities': activities.map((a) => a.toMap()).toList(),
      'completions': history.map((c) => c.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Validates the whole structure before anything is written.
  static BackupData parse(String text) {
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException('فایل JSON معتبر نیست.');
    }
    if (json is! Map) {
      throw const BackupFormatException('ساختار فایل پشتیبان درست نیست.');
    }
    if (json['format'] != format) {
      throw const BackupFormatException('این فایل، پشتیبان اپ Reminder نیست.');
    }
    final version = json['version'];
    if (version is! int || version < 1 || version > formatVersion) {
      throw const BackupFormatException('نسخه فایل پشتیبان پشتیبانی نمی‌شود.');
    }
    final rawActs = json['activities'];
    final rawComps = json['completions'];
    final rawSettings = json['settings'];
    if (rawActs is! List || rawComps is! List || rawSettings is! Map) {
      throw const BackupFormatException('بخش‌های لازم در پشتیبان کامل نیست.');
    }
    try {
      final settings = AppSettings.fromJson(
        Map<String, Object?>.from(rawSettings),
      );
      final acts = <Activity>[
        for (final a in rawActs) Activity.fromMap(_asMap(a)),
      ];
      final ids = <String>{};
      final keys = <int>{};
      for (final a in acts) {
        if (!ids.add(a.id)) throw FormatException('duplicate id ${a.id}');
        if (!keys.add(a.notifKey)) {
          throw FormatException('duplicate notif_key ${a.notifKey}');
        }
      }
      final comps = <Completion>[
        for (final c in rawComps) Completion.fromMap(_asMap(c)),
      ];
      final seen = <String>{};
      for (final c in comps) {
        if (!seen.add('${c.activityId}|${c.dateKey}')) {
          throw const FormatException('duplicate completion');
        }
      }
      return BackupData(
        settings: settings,
        activities: acts,
        completions: comps,
      );
    } on BackupFormatException {
      rethrow;
    } on Object catch (e) {
      throw BackupFormatException('داده‌های پشتیبان معتبر نیست: $e');
    }
  }

  static Map<String, Object?> _asMap(Object? v) {
    if (v is! Map) throw const FormatException('item is not an object');
    return Map<String, Object?>.from(v);
  }

  /// Destructive: replaces everything. The UI asks for confirmation first.
  static Future<void> apply(
    BackupData data,
    ActivityRepository repo,
    SettingsStore store,
  ) async {
    await repo.replaceAll(data.activities, data.completions);
    await store.save(data.settings);
  }
}
