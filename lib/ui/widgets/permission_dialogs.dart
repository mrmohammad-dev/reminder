import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'تأیید',
  String cancel = 'انصراف',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828))
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Explains, in Persian, why the notification permission is needed, then
/// shows the Android 13+ system prompt.
Future<void> askNotificationPermission(
  BuildContext context,
  AppController c,
) async {
  final ok = await confirmDialog(
    context,
    title: 'اجازه نمایش اعلان',
    message:
        'برای اینکه سر ساعت هر فعالیت یادآوری بگیری، Reminder باید اجازه '
        'نمایش اعلان داشته باشد.\n\nیادآورها کاملاً روی خود گوشی ساخته '
        'می‌شوند و به اینترنت یا سرور نیازی ندارند.',
    confirm: 'ادامه',
    cancel: 'فعلاً نه',
  );
  if (ok) await c.requestNotificationPermission();
}

/// Opens the Android "Alarms & reminders" settings page.
Future<void> askExactAlarmPermission(
  BuildContext context,
  AppController c,
) async {
  final ok = await confirmDialog(
    context,
    title: 'یادآوری دقیق سر ساعت',
    message:
        'برای اینکه یادآورها دقیقاً سر ساعت برسند، اندروید دسترسی '
        '«هشدارها و یادآوری‌ها» را لازم دارد. در صفحه بعد، Reminder را '
        'فعال کن و برگرد.\n\nاگر اجازه ندهی، یادآورها با زمان‌بندی تقریبی '
        'ارسال می‌شوند و ممکن است چند دقیقه دیرتر برسند.',
    confirm: 'باز کردن تنظیمات',
    cancel: 'فعلاً نه',
  );
  if (ok) await c.requestExactAlarmPermission();
}
