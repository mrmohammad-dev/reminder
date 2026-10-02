import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/default_schedule.dart';
import '../data/repository.dart';
import '../data/settings_store.dart';
import '../models/activity.dart';
import '../models/enums.dart';
import '../models/settings.dart';
import '../services/backup_service.dart';
import '../services/clock.dart';
import '../services/notification_gateway.dart';
import '../services/reminder_engine.dart';
import '../services/reminder_planner.dart';
import '../services/schedule_service.dart';
import '../services/week_service.dart';
import '../util/dates.dart';

/// Overridden in main() and in widget tests.
final appControllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError('appControllerProvider must be overridden'),
);

class AppController extends ChangeNotifier {
  AppController({
    required this.repo,
    required this.settingsStore,
    required this.gateway,
    required this.clock,
  }) : engine = ReminderEngine(
         repo: repo,
         settingsStore: settingsStore,
         gateway: gateway,
         clock: clock,
       );

  final ActivityRepository repo;
  final SettingsStore settingsStore;
  final NotificationGateway gateway;
  final WallClock clock;
  final ReminderEngine engine;

  bool loading = true;
  AppSettings settings = AppSettings.defaults();
  List<Activity> activities = const <Activity>[];
  Set<String> todayDone = const <String>{};
  String? anchorActivityId;
  bool notificationsAllowed = false;
  bool exactAllowed = false;
  PlannedReminder? nearestReminder;
  int plannedCount = 0;
  bool _disposed = false;

  DateTime get now => clock.now(useTehran: settings.useTehranTimezone);
  DateTime get today => dateOnly(now);

  WeekType weekTypeOf(DateTime date) => WeekService.forSettings(date, settings);

  Future<void> init() => refresh(resync: true);

  Future<void> refresh({bool resync = false}) async {
    settings = await settingsStore.load();
    activities = await repo.getActivities();
    final todayKey = dateKey(today);
    todayDone = await repo.completedIdsOn(todayKey);
    final anchor = await settingsStore.getAnchor();
    anchorActivityId = anchor != null && anchor.dateKey == todayKey
        ? anchor.activityId
        : null;
    notificationsAllowed = await gateway.notificationsEnabled();
    exactAllowed = await gateway.canScheduleExact();
    if (resync) {
      _applyReport(await engine.resync());
    }
    loading = false;
    _notify();
  }

  void _applyReport(SyncReport r) {
    nearestReminder = r.nearest;
    plannedCount = r.plannedCount;
    exactAllowed = r.exact;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<DayInstance> dayInstances(DateTime date, Set<String> doneIds) =>
      ScheduleService.buildDay(
        activities: activities,
        date: date,
        settings: settings,
        doneIds: doneIds,
      );

  List<DayInstance> get todayInstances => dayInstances(today, todayDone);

  Future<Set<String>> doneOn(DateTime date) =>
      repo.completedIdsOn(dateKey(date));

  Future<DoneResult> setDone(DayInstance instance, bool done) async {
    final r = await engine.setDone(instance.activity.id, instance.date, done);
    await refresh(resync: false);
    final plan = await engine.computePlan(settings);
    nearestReminder = plan.isEmpty ? null : plan.first;
    plannedCount = plan.length;
    _notify();
    return r;
  }

  // ---------- editing ----------

  Future<Activity> newActivityTemplate(int day) async {
    final key = await repo.nextNotifKey();
    final sameDay = activities.where((a) => a.day == day);
    final maxOrder = sameDay.isEmpty
        ? -1
        : sameDay.map((a) => a.sortOrder).reduce(max);
    final rnd = Random().nextInt(1 << 32).toRadixString(36);
    return Activity(
      id: 'u${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$rnd',
      notifKey: key,
      title: '',
      rawLine: '',
      day: day,
      weekType: WeekType.both,
      startMinute: null,
      endMinute: null,
      category: ActivityCategory.other,
      sortOrder: maxOrder + 1,
      reminderEnabled: true,
    );
  }

  Future<void> saveActivity(Activity a) async {
    await repo.upsertActivity(a);
    await refresh(resync: true);
  }

  Future<void> deleteActivity(String id) async {
    await repo.deleteActivity(id);
    await refresh(resync: true);
  }

  /// Reorders [visible] (a filtered subset of one day) by reusing the same
  /// sortOrder slots, so items outside the subset keep their positions.
  Future<void> reorder(List<Activity> visible, int oldIndex, int newIndex) async {
    final list = List<Activity>.from(visible);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    final slots = visible.map((a) => a.sortOrder).toList()..sort();
    final orders = <String, int>{
      for (var i = 0; i < list.length; i++) list[i].id: slots[i],
    };
    await repo.updateSortOrders(orders);
    await refresh(resync: false);
  }

  // ---------- settings ----------

  Future<void> updateSettings(AppSettings s) async {
    await settingsStore.save(s);
    await refresh(resync: true);
  }

  Future<void> completeOnboarding(DateTime saturday, WeekType type) async {
    await updateSettings(
      settings.copyWith(
        onboarded: true,
        baseSaturdayKey: dateKey(WeekService.saturdayOf(saturday)),
        baseWeekType: type,
      ),
    );
  }

  Future<bool> requestNotificationPermission() async {
    final ok = await gateway.requestNotificationPermission();
    await refresh(resync: true);
    return ok;
  }

  Future<void> requestExactAlarmPermission() async {
    await gateway.requestExactAlarmPermission();
    await refresh(resync: true);
  }

  Future<void> restoreDefaults() async {
    await repo.replaceActivities(buildDefaultActivities());
    await refresh(resync: true);
  }

  Future<String> exportBackup() => BackupService.export(repo, settingsStore);

  /// Throws [BackupFormatException] when the text is invalid.
  BackupData parseBackup(String text) => BackupService.parse(text);

  Future<void> applyBackup(BackupData data) async {
    await BackupService.apply(data, repo, settingsStore);
    await refresh(resync: true);
  }
}
