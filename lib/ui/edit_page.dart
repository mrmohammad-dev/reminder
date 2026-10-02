import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/enums.dart';
import '../state/app_controller.dart';
import '../util/persian.dart';
import 'activity_editor_page.dart';
import 'theme.dart';
import 'widgets/badge_chip.dart';
import 'widgets/permission_dialogs.dart';

/// Add / edit / delete / reorder activities.
class EditPage extends ConsumerStatefulWidget {
  const EditPage({super.key});

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
  int? _day;

  /// null = all weeks.
  WeekType? _filter;

  String _timeText(Activity a) {
    final s = a.startMinute;
    final e = a.endMinute;
    if (s != null && e != null) return '${faTime(s)}–${faTime(e)}';
    if (s != null) return faTime(s);
    if (e != null) return 'تا ${faTime(e)}';
    return a.scheduleNote ?? 'زمان تعیین نشده';
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final day = _day ?? (c.today.weekday + 1) % 7;
    final visible = c.activities
        .where(
          (a) =>
              a.day == day &&
              (_filter == null ||
                  a.weekType == WeekType.both ||
                  a.weekType == _filter),
        )
        .toList()
      ..sort((x, y) => x.sortOrder.compareTo(y.sortOrder));

    return Scaffold(
      appBar: AppBar(title: const Text('ویرایش برنامه')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final template = await c.newActivityTemplate(day);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ActivityEditorPage(initial: template, isNew: true),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('افزودن فعالیت'),
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                for (var d = 0; d < 7; d++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(persianDayNames[d]),
                      selected: d == day,
                      onSelected: (_) => setState(() {
                        _day = d;
                        _filter = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('همه هفته‌ها'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                ChoiceChip(
                  label: const Text('هفته A'),
                  selected: _filter == WeekType.a,
                  onSelected: (_) => setState(() => _filter = WeekType.a),
                ),
                ChoiceChip(
                  label: const Text('هفته B'),
                  selected: _filter == WeekType.b,
                  onSelected: (_) => setState(() => _filter = WeekType.b),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'برای تغییر ترتیب، دستگیره کنار هر فعالیت را بکش.',
              softWrap: true,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
              buildDefaultDragHandles: false,
              itemCount: visible.length,
              onReorder: (o, n) => c.reorder(visible, o, n),
              itemBuilder: (context, index) {
                final a = visible[index];
                final style = categoryStyle(a.category);
                return Card(
                  key: ValueKey<String>('edit-${a.id}'),
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: style.background,
                  child: ListTile(
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 4,
                    ),
                    title: Text(a.title, softWrap: true),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_timeText(a), softWrap: true),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            BadgeChip(a.category.label, color: style.accent),
                            BadgeChip(a.weekType.label),
                            if (!a.reminderEnabled)
                              const BadgeChip('یادآور خاموش'),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ActivityEditorPage(initial: a),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'حذف',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'حذف فعالیت',
                              message:
                                  '«${a.title}» از برنامه حذف شود؟ یادآورهای آن هم لغو می‌شوند. تاریخچه تیک‌ها باقی می‌ماند.',
                              confirm: 'حذف',
                              destructive: true,
                            );
                            if (ok) await c.deleteActivity(a.id);
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
