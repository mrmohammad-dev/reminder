import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../util/persian.dart';
import 'notification_gateway.dart';
import 'reminder_engine.dart';

/// Real implementation backed by flutter_local_notifications, which uses
/// Android AlarmManager for scheduled notifications. Nothing here depends on
/// Dart code staying alive: alarms are owned by the OS.
class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway._(this._plugin);

  static const String reminderChannelId = 'activity_reminders';
  static const String infoChannelId = 'next_activity';
  static const String smallIcon = 'ic_stat_reminder';

  final FlutterLocalNotificationsPlugin _plugin;

  static bool _tzReady = false;

  static void ensureTimeZones() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<LocalNotificationsGateway> create({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    ensureTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    final gateway = LocalNotificationsGateway._(plugin);
    final android = gateway._android;
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          reminderChannelId,
          'یادآور فعالیت‌ها',
          description: 'یادآوری شروع فعالیت‌های برنامه هفتگی',
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          infoChannelId,
          'فعالیت بعدی',
          description: 'اعلان کوتاه پس از تیک‌زدن یک فعالیت',
          importance: Importance.defaultImportance,
        ),
      );
    }
    return gateway;
  }

  Future<NotificationAppLaunchDetails?> launchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  @override
  int epochMillisFor(DateTime wall, {required bool useTehran}) =>
      toInstant(wall, useTehran: useTehran).millisecondsSinceEpoch;

  static tz.TZDateTime toInstant(DateTime wall, {required bool useTehran}) {
    ensureTimeZones();
    if (useTehran) {
      return tz.TZDateTime(
        tz.getLocation('Asia/Tehran'),
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      );
    }
    // Device timezone: let the OS resolve the local wall time.
    final local = DateTime(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    );
    return tz.TZDateTime.from(local, tz.UTC);
  }

  NotificationDetails _reminderDetails(String body, int snoozeMinutes) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        reminderChannelId,
        'یادآور فعالیت‌ها',
        channelDescription: 'یادآوری شروع فعالیت‌های برنامه هفتگی',
        importance: Importance.high,
        priority: Priority.high,
        icon: smallIcon,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(body),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            ReminderEngine.actionDone,
            'انجام شد',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            ReminderEngine.actionSnooze,
            'تعویق ${faDigits(snoozeMinutes)} دقیقه',
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> schedule(NotificationSpec spec) async {
    final when = toInstant(spec.fireAt, useTehran: spec.useTehran);
    if (!when.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    try {
      await _plugin.zonedSchedule(
        spec.id,
        spec.title,
        spec.body,
        when,
        _reminderDetails(spec.body, spec.snoozeMinutes),
        androidScheduleMode: spec.exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: spec.payload,
      );
    } on Object catch (e) {
      // e.g. exact alarm permission revoked between check and call:
      // fall back to inexact scheduling instead of losing the reminder.
      debugPrint('schedule failed for ${spec.id}: $e');
      if (spec.exact) {
        await _plugin.zonedSchedule(
          spec.id,
          spec.title,
          spec.body,
          when,
          _reminderDetails(spec.body, spec.snoozeMinutes),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: spec.payload,
        );
      }
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<List<PendingNotification>> pending() async {
    final list = await _plugin.pendingNotificationRequests();
    return list
        .map(
          (p) => PendingNotification(
            id: p.id,
            title: p.title,
            body: p.body,
            payload: p.payload,
          ),
        )
        .toList();
  }

  @override
  Future<void> showInfo(int id, String title, String body) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          infoChannelId,
          'فعالیت بعدی',
          channelDescription: 'اعلان کوتاه پس از تیک‌زدن یک فعالیت',
          icon: smallIcon,
          styleInformation: BigTextStyleInformation(body),
          timeoutAfter: 15 * 60 * 1000,
        ),
      ),
    );
  }

  @override
  Future<bool> notificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<bool> requestNotificationPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }
}
