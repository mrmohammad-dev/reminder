import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'background.dart';
import 'data/sqlite_repository.dart';
import 'data/settings_store.dart';
import 'services/clock.dart';
import 'services/local_notifications_gateway.dart';
import 'services/reminder_engine.dart';

/// Wires real implementations together (UI isolate and background isolates).
class AppDeps {
  AppDeps._(this.repo, this.settingsStore, this.gateway, this.clock);

  final SqliteActivityRepository repo;
  final PrefsSettingsStore settingsStore;
  final LocalNotificationsGateway gateway;
  final WallClock clock;

  ReminderEngine get engine => ReminderEngine(
    repo: repo,
    settingsStore: settingsStore,
    gateway: gateway,
    clock: clock,
  );

  static Future<AppDeps> create({
    DidReceiveNotificationResponseCallback? onResponse,
  }) async {
    final gateway = await LocalNotificationsGateway.create(
      onResponse: onResponse,
      onBackgroundResponse: notificationActionBackground,
    );
    final repo = await SqliteActivityRepository.open();
    final store = await PrefsSettingsStore.create();
    return AppDeps._(repo, store, gateway, const SystemWallClock());
  }
}
