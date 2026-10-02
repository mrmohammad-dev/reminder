import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

/// Light settings + the "last ticked activity" anchor per day.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);

  /// Last ticked activity, used to show the next one after it.
  Future<({String dateKey, String activityId})?> getAnchor();
  Future<void> setAnchor(String dateKey, String activityId);
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  static const String _settingsKey = 'settings_v1';
  static const String _anchorKey = 'anchor_v1';

  final SharedPreferences _prefs;

  static Future<PrefsSettingsStore> create() async =>
      PrefsSettingsStore(await SharedPreferences.getInstance());

  @override
  Future<AppSettings> load() async {
    // Another isolate (notification action / background resync) may have
    // written new values; reload from disk first.
    await _prefs.reload();
    final text = _prefs.getString(_settingsKey);
    if (text == null) return AppSettings.defaults();
    try {
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) return AppSettings.fromJson(json);
    } on Object {
      // Corrupted settings fall back to defaults instead of crashing.
    }
    return AppSettings.defaults();
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<({String dateKey, String activityId})?> getAnchor() async {
    await _prefs.reload();
    final v = _prefs.getString(_anchorKey);
    if (v == null) return null;
    final i = v.indexOf('|');
    if (i <= 0) return null;
    return (dateKey: v.substring(0, i), activityId: v.substring(i + 1));
  }

  @override
  Future<void> setAnchor(String dateKey, String activityId) async {
    await _prefs.setString(_anchorKey, '$dateKey|$activityId');
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([AppSettings? initial])
    : settings = initial ?? AppSettings.defaults();

  AppSettings settings;
  ({String dateKey, String activityId})? anchor;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings s) async {
    settings = s;
  }

  @override
  Future<({String dateKey, String activityId})?> getAnchor() async => anchor;

  @override
  Future<void> setAnchor(String dateKey, String activityId) async {
    anchor = (dateKey: dateKey, activityId: activityId);
  }
}
