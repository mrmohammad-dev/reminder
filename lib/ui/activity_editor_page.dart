import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/enums.dart';
import '../state/app_controller.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'widgets/permission_dialogs.dart';

Future<int?> pickTime(BuildContext context, int? initial) async {
  final init = initial ?? 8 * 60;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: init ~/ 60, minute: init % 60),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return null;
  return t.hour * 60 + t.minute;
}

class ActivityEditorPage extends ConsumerStatefulWidget {
  const ActivityEditorPage({
    super.key,
    required this.initial,
    this.isNew = false,
  });

  final Activity initial;
  final bool isNew;

  @override
  ConsumerState<ActivityEditorPage> createState() => _ActivityEditorPageState();
}

class _ActivityEditorPageState extends ConsumerState<ActivityEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.initial.title,
  );
  late final TextEditingController _raw = TextEditingController(
    text: widget.initial.rawLine,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.initial.scheduleNote ?? '',
  );
  late int _day = widget.initial.day;
  late WeekType _week = widget.initial.weekType;
  late int? _start = widget.initial.startMinute;
  late int? _end = widget.initial.endMinute;
  late ActivityCategory _category = widget.initial.category;
  late bool _reminder = widget.initial.reminderEnabled;
  String? _timeError;

  @override
  void dispose() {
    _title.dispose();
    _raw.dispose();
    _note.dispose();
    super.dispose();
  }

  String _generatedRaw(String title) {
    final s = _start;
    final e = _end;
    if (s != null && e != null) return '${formatMinute(s)}–${formatMinute(e)} $title';
    if (s != null) return '${formatMinute(s)} $title';
    if (e != null) return 'تا ${formatMinute(e)} $title';
    return title;
  }

  Future<void> _save() async {
    setState(() => _timeError = null);
    if (!_formKey.currentState!.validate()) return;
    final s = _start;
    final e = _end;
    if (s != null && e != null && e <= s) {
      setState(() => _timeError = 'زمان پایان باید بعد از زمان شروع باشد.');
      return;
    }
    final title = _title.text.trim();
    final raw = _raw.text.trim().isEmpty ? _generatedRaw(title) : _raw.text;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final a = widget.initial.copyWith(
      title: title,
      rawLine: raw,
      day: _day,
      weekType: _week,
      startMinute: _start,
      endMinute: _end,
      category: _category,
      reminderEnabled: _reminder,
      scheduleNote: note,
    );
    final nav = Navigator.of(context);
    await ref.read(appControllerProvider).saveActivity(a);
    nav.pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'حذف فعالیت',
      message:
          '«${widget.initial.title}» حذف شود؟ یادآورهای آن لغو می‌شوند. تاریخچه تیک‌ها باقی می‌ماند.',
      confirm: 'حذف',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    await ref.read(appControllerProvider).deleteActivity(widget.initial.id);
    nav.pop();
  }

  Widget _timeTile(String label, int? value, ValueChanged<int?> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null ? 'تعیین نشده' : faTime(value)),
      onTap: () async {
        final t = await pickTime(context, value);
        if (t != null) onChanged(t);
      },
      trailing: value == null
          ? const Icon(Icons.schedule)
          : IconButton(
              tooltip: 'پاک کردن',
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSchoolRow = widget.initial.schoolKey != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'فعالیت جدید' : 'ویرایش فعالیت'),
        actions: <Widget>[
          if (!widget.isNew)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            TextFormField(
              controller: _title,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'عنوان کامل فعالیت',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'عنوان لازم است' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _day,
              decoration: const InputDecoration(
                labelText: 'روز هفته',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                for (var d = 0; d < 7; d++)
                  DropdownMenuItem<int>(
                    value: d,
                    child: Text(persianDayNames[d]),
                  ),
              ],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: 12),
            const Text('کاربرد در هفته‌ها'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final w in WeekType.values)
                  ChoiceChip(
                    label: Text(w.label),
                    selected: _week == w,
                    onSelected: (_) => setState(() => _week = w),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _timeTile('زمان شروع', _start, (v) => setState(() => _start = v)),
            _timeTile(
              'زمان پایان (اختیاری)',
              _end,
              (v) => setState(() => _end = v),
            ),
            if (isSchoolRow)
              const Text(
                'برای مدرسه، اگر زمان این‌جا خالی بماند، ساعت تعیین‌شده در تنظیمات (برای هفته A و B) استفاده می‌شود.',
                softWrap: true,
              ),
            if (_timeError != null)
              Text(
                _timeError!,
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'دسته‌بندی',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<ActivityCategory>>[
                for (final cat in ActivityCategory.values)
                  DropdownMenuItem<ActivityCategory>(
                    value: cat,
                    child: Text(cat.label),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('یادآور این فعالیت'),
              subtitle: const Text(
                'بدون زمان شروع، یادآوری ارسال نمی‌شود.',
                softWrap: true,
              ),
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'توضیح زمان‌بندی (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _raw,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'متن اصلی سطر (اگر خالی بماند، خودکار ساخته می‌شود)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}
