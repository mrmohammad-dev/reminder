/// Abstraction over the platform notification plugin so the reminder logic
/// can be tested without a device.
class NotificationSpec {
  const NotificationSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.payload,
    required this.exact,
    required this.snoozeMinutes,
    required this.useTehran,
  });

  final int id;
  final String title;
  final String body;

  /// Wall-clock time in the schedule timezone.
  final DateTime fireAt;
  final String payload;
  final bool exact;
  final int snoozeMinutes;
  final bool useTehran;
}

class PendingNotification {
  const PendingNotification({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

abstract class NotificationGateway {
  /// Absolute instant (epoch ms) of a wall-clock time.
  int epochMillisFor(DateTime wall, {required bool useTehran});

  /// Schedules (or replaces, same id) a reminder with action buttons.
  Future<void> schedule(NotificationSpec spec);

  Future<void> cancel(int id);

  Future<List<PendingNotification>> pending();

  /// Immediate short info notification (e.g. «فعالیت بعدی»).
  Future<void> showInfo(int id, String title, String body);

  Future<bool> notificationsEnabled();

  Future<bool> canScheduleExact();

  Future<bool> requestNotificationPermission();

  Future<void> requestExactAlarmPermission();
}
