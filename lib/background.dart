import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_deps.dart';

/// Called by flutter_local_notifications in a background isolate when a
/// notification action («انجام شد» / «تعویق») is pressed. Works without
/// opening the app UI.
@pragma('vm:entry-point')
Future<void> notificationActionBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final deps = await AppDeps.create();
  await deps.engine.handleAction(response.actionId, response.payload);
}

const MethodChannel _resyncChannel = MethodChannel(
  'com.mohammad.reminder/resync',
);

/// Started from native code (ResyncReceiver.kt) on boot, app update,
/// time/timezone change, exact-alarm permission change and once per day.
/// Re-plans the rolling 14-day reminder window.
Future<void> runBackgroundResync() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    final deps = await AppDeps.create();
    await deps.engine.resync();
  } on Object catch (e) {
    debugPrint('background resync failed: $e');
  } finally {
    try {
      await _resyncChannel.invokeMethod<void>('done');
    } on Object {
      // Native side has a timeout and will clean up anyway.
    }
  }
}
