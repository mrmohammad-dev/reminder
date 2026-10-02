import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/settings.dart';
import '../services/backup_service.dart';
import '../services/week_service.dart';
import '../state/app_controller.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'activity_editor_page.dart';
import 'widgets/permission_dialogs.dart';
import 'widgets/reminder_status_card.dart';

const Map<String, String> _schoolLabels = <String, String>{
  'mon_a_start': 'دوشنبه هفته A: شروع مدرسه',
  'mon_b_start': 'دوشنبه هفته B: شروع مدرسه',
  'tue_a_start': 'سه‌شنبه هفته A: شروع مدرسه',
  'tue_a_end': 'سه‌شنبه هفته A: پایان مدرسه',
  'tue_b_start': 'سه‌شنبه هفته B: شروع مدرسه',
  'tue_b_end': 'سه‌شنبه هفته B: پایان مدرسه',
  'wed_a_start': 'چهارشنبه هفته A: شروع مدرسه',
  'wed_a_end': 'چهارشنبه هفته A: پایان مدرسه',
  'wed_b_start': 'چهارشنبه هفته B: شروع مدرسه',
  'wed_b_end': 'چهارشنبه هفته B: پایان مدرسه',
};

Future<DateTime?> pickSaturday(BuildContext context, DateTime initial) async {
  final init = WeekService.saturdayOf(initial);
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(init.year, init.month, init.day),
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
    helpText: 'یک شنبه (روز اول هفته) را انتخاب کن',
    selectableDayPredicate: (d) => d.weekday == DateTime.saturday,
  );
  if (picked == null) return null;
  return DateTime.utc(picked.year, picked.month, picked.day);
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final s = c.settings;
    final base = s.baseSaturday;

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _section(context, 'هفته مبنا (A/B)', <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('شنبه مبنا'),
              subtitle: Text(
                base == null
                    ? 'تعیین نشده'
                    : '${formatJalali(base)} • ${formatGregorian(base)}',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await pickSaturday(context, base ?? c.today);
                if (d != null) {
                  await c.updateSettings(
                    s.copyWith(baseSaturdayKey: dateKey(d)),
                  );
                }
              },
            ),
            const Text('نوع هفته مبنا:'),
            const SizedBox(height: 4),
            SegmentedButton<WeekType>(
              segments: const <ButtonSegment<WeekType>>[
                ButtonSegment<WeekType>(
                  value: WeekType.a,
                  label: Text('هفته A'),
                ),
                ButtonSegment<WeekType>(
                  value: WeekType.b,
                  label: Text('هفته B'),
                ),
              ],
              selected: <WeekType>{s.baseWeekType},
              onSelectionChanged: (v) =>
                  c.updateSettings(s.copyWith(baseWeekType: v.first)),
            ),
            const SizedBox(height: 6),
            Text(
              'هفته جاری: ${c.weekTypeOf(c.today) == WeekType.a ? 'A' : 'B'}',
            ),
          ]),
          _section(context, 'ساعت مدرسه در هفته‌های A و B', <Widget>[
            const Text(
              'پایان مدرسه دوشنبه طبق برنامه: هفته A تا ۱۵:۰۰ و هفته B تا ۱۳:۰۰. '
              'برای سه‌شنبه و چهارشنبه برنامه اصلی فقط می‌گوید «مدرسه تا 13:00 یا 15:00، مطابق هفته»؛ '
              'تا وقتی ساعت را این‌جا تعیین نکنی، همان عبارت نمایش داده می‌شود و یادآور شروع مدرسه غیرفعال می‌ماند.',
              softWrap: true,
            ),
            for (final key in AppSettings.schoolTimeKeys)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_schoolLabels[key]!, softWrap: true),
                subtitle: Text(
                  s.schoolTimes[key] == null
                      ? 'تعیین نشده'
                      : faTime(s.schoolTimes[key]!),
                ),
                onTap: () async {
                  final t = await pickTime(context, s.schoolTimes[key]);
                  if (t != null) {
                    await c.updateSettings(s.withSchoolTime(key, t));
                  }
                },
                trailing: s.schoolTimes[key] == null
                    ? const Icon(Icons.schedule)
                    : IconButton(
                        tooltip: 'پاک کردن',
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            c.updateSettings(s.withSchoolTime(key, null)),
                      ),
              ),
          ]),
          _section(context, 'یادآورها', <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('یادآورها فعال باشند'),
              value: s.remindersEnabled,
              onChanged: (v) =>
                  c.updateSettings(s.copyWith(remindersEnabled: v)),
            ),
            const Text('زمان یادآوری:'),
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final m in AppSettings.allowedLeadMinutes)
                  ChoiceChip(
                    label: Text(
                      m == 0 ? 'هنگام شروع' : '${faDigits(m)} دقیقه قبل',
                    ),
                    selected: s.leadMinutes == m,
                    onSelected: (_) =>
                        c.updateSettings(s.copyWith(leadMinutes: m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('مدت تعویق اعلان:'),
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final m in AppSettings.allowedSnoozeMinutes)
                  ChoiceChip(
                    label: Text('${faDigits(m)} دقیقه'),
                    selected: s.snoozeMinutes == m,
                    onSelected: (_) =>
                        c.updateSettings(s.copyWith(snoozeMinutes: m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('منطقه زمانی برنامه:'),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('زمان گوشی (پیش‌فرض)'),
              value: false,
              groupValue: s.useTehranTimezone,
              onChanged: (v) =>
                  c.updateSettings(s.copyWith(useTehranTimezone: false)),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Asia/Tehran'),
              value: true,
              groupValue: s.useTehranTimezone,
              onChanged: (v) =>
                  c.updateSettings(s.copyWith(useTehranTimezone: true)),
            ),
          ]),
          ReminderStatusCard(c: c),
          _section(context, 'پشتیبان‌گیری و بازیابی', <Widget>[
            const Text(
              'پشتیبان شامل فعالیت‌ها، تنظیمات و تاریخچه تیک‌هاست.',
              softWrap: true,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _exportFile(context, c),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('ذخیره فایل پشتیبان'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportClipboard(context, c),
                  icon: const Icon(Icons.copy),
                  label: const Text('کپی پشتیبان'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _importFile(context, c),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('بازیابی از فایل'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _importText(context, c),
                  icon: const Icon(Icons.paste),
                  label: const Text('بازیابی از متن'),
                ),
              ],
            ),
          ]),
          _section(context, 'برنامه پیش‌فرض', <Widget>[
            const Text(
              'همه فعالیت‌ها با برنامه اصلی جایگزین می‌شوند. تنظیمات و تاریخچه حفظ می‌شوند.',
              softWrap: true,
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'بازگردانی برنامه پیش‌فرض',
                  message:
                      'همه ویرایش‌های برنامه پاک می‌شود و ۱۰۸ تعریف برنامه اصلی دوباره وارد می‌شود. ادامه می‌دهی؟',
                  confirm: 'بازگردانی',
                  destructive: true,
                );
                if (ok) await c.restoreDefaults();
              },
              icon: const Icon(Icons.restore),
              label: const Text('بازگردانی برنامه پیش‌فرض'),
            ),
          ]),
          _section(context, 'محدودیت‌های واقعی یادآوری در اندروید', const <Widget>[
            Text(
              '• بستن معمولی اپ (کشیدن از لیست اخیر) یادآورها را متوقف نمی‌کند.\n'
              '• «توقف اجباری» (Force stop) از تنظیمات اندروید همه هشدارهای اپ را پاک می‌کند؛ تا دوباره اپ را باز نکنی، یادآوری نمی‌رسد.\n'
              '• بعضی سازندگان گوشی (مثل شیائومی، هواوی، سامسونگ، اوپو) محدودیت باتری دارند؛ بهتر است بهینه‌سازی باتری را برای Reminder خاموش کنی.\n'
              '• اگر اجازه اعلان یا هشدار دقیق داده نشود، رسیدن یادآور دقیقاً سر ساعت تضمین نمی‌شود.\n'
              '• یادآورها برای ۱۴ روز آینده تنظیم می‌شوند و هر روز، پس از راه‌اندازی مجدد گوشی، به‌روزرسانی اپ و تغییر ساعت یا منطقه زمانی، خودکار تمدید می‌شوند.',
              softWrap: true,
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _exportFile(BuildContext context, AppController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await c.exportBackup();
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره پشتیبان',
        fileName: 'reminder-backup-${dateKey(c.today)}.json',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(path == null ? 'ذخیره لغو شد' : 'پشتیبان ذخیره شد'),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('ذخیره فایل ممکن نشد: $e')),
      );
    }
  }

  Future<void> _exportClipboard(BuildContext context, AppController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await c.exportBackup();
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(content: Text('پشتیبان در حافظه موقت کپی شد')),
    );
  }

  Future<void> _importFile(BuildContext context, AppController c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      if (!context.mounted) return;
      await _confirmRestore(context, c, utf8.decode(bytes));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('خواندن فایل ممکن نشد: $e')),
      );
    }
  }

  Future<void> _importText(BuildContext context, AppController c) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('متن پشتیبان را این‌جا بچسبان'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          textDirection: TextDirection.ltr,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('بررسی'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await _confirmRestore(context, c, text);
  }

  Future<void> _confirmRestore(
    BuildContext context,
    AppController c,
    String text,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    BackupData data;
    try {
      data = c.parseBackup(text);
    } on BackupFormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'بازیابی پشتیبان',
      message:
          'پشتیبان معتبر است: ${faDigits(data.activities.length)} فعالیت و '
          '${faDigits(data.completions.length)} مورد تاریخچه.\n\n'
          'همه فعالیت‌ها، تنظیمات و تاریخچه فعلی جایگزین می‌شوند. ادامه می‌دهی؟',
      confirm: 'بازیابی',
      destructive: true,
    );
    if (!ok) return;
    await c.applyBackup(data);
    messenger.showSnackBar(const SnackBar(content: Text('بازیابی انجام شد')));
  }
}
