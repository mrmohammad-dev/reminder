import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../services/schedule_service.dart';
import '../state/app_controller.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'widgets/activity_tile.dart';

/// Any past or future date with its own independent ticks.
class DayPage extends ConsumerStatefulWidget {
  const DayPage({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  late DateTime _date = dateOnly(widget.initialDate);
  Set<String> _done = const <String>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = ref.read(appControllerProvider);
    final done = await c.doneOn(_date);
    if (!mounted) return;
    setState(() {
      _done = done;
      _loaded = true;
    });
  }

  void _move(int days) {
    setState(() {
      _date = addDays(_date, days);
      _loaded = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final now = c.now;
    final list = c.dayInstances(_date, _done);
    final week = c.weekTypeOf(_date);
    final doneCount = list.where((i) => i.done).length;
    final isToday = _date == c.today;
    final current = isToday ? ScheduleService.current(list, now) : null;

    return Scaffold(
      appBar: AppBar(title: Text('${dayName(_date)} ${formatJalali(_date)}')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'روز قبل',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _move(-1),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        '${formatGregorian(_date)} • ${week == WeekType.a ? 'هفته A' : 'هفته B'}',
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${isToday ? 'امروز • ' : ''}${faDigits(doneCount)} از ${faDigits(list.length)} انجام شد',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'روز بعد',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _move(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: <Widget>[
                      for (final i in list)
                        ActivityTile(
                          key: ValueKey<String>('day-${i.activity.id}'),
                          instance: i,
                          now: now,
                          isCurrent: current?.activity.id == i.activity.id,
                          onToggle: (v) async {
                            await c.setDone(i, v);
                            await _load();
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
