import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../util/dates.dart';
import '../../util/persian.dart';
import 'permission_dialogs.dart';

class ReminderStatusCard extends StatelessWidget {
  const ReminderStatusCard({super.key, required this.c});

  final AppController c;

  @override
  Widget build(BuildContext context) {
    final nearest = c.nearestReminder;
    String nearestText;
    if (!c.settings.remindersEnabled) {
      nearestText = 'یادآورها خاموش هستند';
    } else if (nearest == null) {
      nearestText = 'یادآوری در ۱۴ روز آینده تنظیم نشده';
    } else {
      final day = dateOnly(nearest.fireAt);
      final when = day == c.today
          ? 'امروز'
          : day == addDays(c.today, 1)
          ? 'فردا'
          : '${dayName(day)} ${formatJalali(day)}';
      nearestText =
          '$when ساعت ${faTime(minuteOfDay(nearest.fireAt))}: ${nearest.title}';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'وضعیت یادآورها',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            _row(
              context,
              ok: c.settings.remindersEnabled,
              okText: 'یادآورها فعال است',
              badText: 'یادآورها غیرفعال است (از تنظیمات روشن کن)',
            ),
            _row(
              context,
              ok: c.notificationsAllowed,
              okText: 'اجازه اعلان داده شده',
              badText: 'اجازه اعلان داده نشده؛ یادآوری نمایش داده نمی‌شود',
              action: c.notificationsAllowed
                  ? null
                  : TextButton(
                      onPressed: () => askNotificationPermission(context, c),
                      child: const Text('اجازه دادن'),
                    ),
            ),
            _row(
              context,
              ok: c.exactAllowed,
              okText: 'یادآوری دقیق سر ساعت فعال است',
              badText:
                  'هشدار دقیق مجاز نیست؛ یادآورها تقریبی‌اند و ممکن است دیرتر برسند',
              action: c.exactAllowed
                  ? null
                  : TextButton(
                      onPressed: () => askExactAlarmPermission(context, c),
                      child: const Text('فعال‌سازی'),
                    ),
            ),
            const Divider(),
            Text(
              'نزدیک‌ترین یادآور آینده: $nearestText',
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required bool ok,
    required String okText,
    required String badText,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(ok ? okText : badText, softWrap: true)),
          if (action != null) action,
        ],
      ),
    );
  }
}
