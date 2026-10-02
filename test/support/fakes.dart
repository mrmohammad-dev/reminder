import 'package:reminder/data/default_schedule.dart';
import 'package:reminder/data/memory_repository.dart';
import 'package:reminder/data/settings_store.dart';
import 'package:reminder/models/enums.dart';
import 'package:reminder/models/settings.dart';
import 'package:reminder/services/clock.dart';
import 'package:reminder/services/notification_gateway.dart';
import 'package:reminder/services/reminder_engine.dart';

class FakeGateway implements NotificationGateway {
  final Map<int, NotificationSpec> scheduled = <int, NotificationSpec>{};
  final List<int> cancelled = <int>[];
  final List<({int id, String title, String body})> shown =
      <({int id, String title, String body})>[];
  int scheduleCalls = 0;
  bool enabled = true;
  bool exact = true;

  @override
  int epochMillisFor(DateTime wall, {required bool useTehran}) =>
      wall.millisecondsSinceEpoch;

  @override
  Future<void> schedule(NotificationSpec spec) async {
    scheduleCalls++;
    scheduled[spec.id] = spec; // same id replaces, like Android
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<List<PendingNotification>> pending() async => scheduled.values
      .map(
        (s) => PendingNotification(
          id: s.id,
          title: s.title,
          body: s.body,
          payload: s.payload,
        ),
      )
      .toList();

  @override
  Future<void> showInfo(int id, String title, String body) async {
    shown.add((id: id, title: title, body: body));
  }

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<bool> requestNotificationPermission() async => enabled = true;

  @override
  Future<void> requestExactAlarmPermission() async {
    exact = true;
  }
}

/// 2026-09-26 is a Saturday. We define it as week A.
final DateTime baseSaturday = DateTime.utc(2026, 9, 26);

AppSettings testSettings({
  int lead = 0,
  bool reminders = true,
  Map<String, int> school = const <String, int>{},
}) => AppSettings.defaults().copyWith(
  onboarded: true,
  baseSaturdayKey: '2026-09-26',
  baseWeekType: WeekType.a,
  leadMinutes: lead,
  remindersEnabled: reminders,
  schoolTimes: school,
);

class TestRig {
  TestRig({AppSettings? settings, DateTime? now})
    : repo = InMemoryActivityRepository(buildDefaultActivities()),
      store = MemorySettingsStore(settings ?? testSettings()),
      gateway = FakeGateway(),
      clock = FixedWallClock(now ?? DateTime.utc(2026, 9, 26, 6, 0)) {
    engine = ReminderEngine(
      repo: repo,
      settingsStore: store,
      gateway: gateway,
      clock: clock,
    );
  }

  final InMemoryActivityRepository repo;
  final MemorySettingsStore store;
  final FakeGateway gateway;
  final FixedWallClock clock;
  late final ReminderEngine engine;
}
