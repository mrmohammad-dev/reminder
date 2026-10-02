import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/default_schedule.dart';
import '../models/enums.dart';
import '../services/reminder_engine.dart';
import '../services/schedule_service.dart';
import '../state/app_controller.dart';
import '../util/dates.dart';
import '../util/persian.dart';
import 'day_page.dart';
import 'widgets/activity_tile.dart';
import 'widgets/reminder_status_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final now = c.now;
    final today = c.today;
    final week = c.weekTypeOf(today);
    final list = c.todayInstances;
    final current = ScheduleService.current(list, now);
    final next = ScheduleService.nextForHome(
      list,
      now,
      anchorActivityId: c.anchorActivityId,
    );
    final overdue = ScheduleService.overdue(list, now);
    final doneCount = list.where((i) => i.done).length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder')),
      body: RefreshIndicator(
        onRefresh: () => c.refresh(resync: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Text(
              defaultScheduleTitle,
              style: theme.textTheme.bodySmall,
              softWrap: true,
            ),
            const SizedBox(height: 4),
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'امروز ${dayName(today)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            week == WeekType.a ? 'هفته A' : 'هفته B',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${formatJalali(today)} • ${formatGregorian(today)}',
                      softWrap: true,
                    ),
                    Text('ساعت ${faTime(minuteOfDay(now))}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (current != null) ...<Widget>[
              Text('فعالیت فعلی', style: theme.textTheme.titleMedium),
              ActivityTile(
                instance: current,
                now: now,
                isCurrent: true,
                onToggle: (v) => _toggle(context, c, current, v),
              ),
              const SizedBox(height: 8),
            ],
            Text('فعالیت بعدی', style: theme.textTheme.titleMedium),
            if (next != null)
              ActivityTile(
                instance: next,
                now: now,
                onToggle: (v) => _toggle(context, c, next, v),
              )
            else
              Card(
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'برنامه امروز تمام شد',
                        style: theme.textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: () => _openDay(context, addDays(today, 1)),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('دیدن برنامه فردا'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'پیشرفت امروز: ${faDigits(doneCount)} از ${faDigits(list.length)} فعالیت انجام شد',
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: list.isEmpty ? 0 : doneCount / list.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    if (overdue.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'عقب‌افتاده: ${faDigits(overdue.length)} فعالیت',
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final o in overdue)
                        Text(
                          '• ${o.activity.title} (${o.timeLabel})',
                          softWrap: true,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ReminderStatusCard(c: c),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'برنامه امروز',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => _openDay(context, addDays(today, 1)),
                  child: const Text('برنامه فردا'),
                ),
              ],
            ),
            for (final i in list)
              ActivityTile(
                key: ValueKey<String>('today-${i.activity.id}'),
                instance: i,
                now: now,
                isCurrent: current?.activity.id == i.activity.id,
                onToggle: (v) => _toggle(context, c, i, v),
              ),
          ],
        ),
      ),
    );
  }

  void _openDay(BuildContext context, DateTime date) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => DayPage(initialDate: date)));
  }

  Future<void> _toggle(
    BuildContext context,
    AppController c,
    DayInstance i,
    bool done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await c.setDone(i, done);
    if (!done) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'فعالیت بعدی: ${ReminderEngine.nextText(r.next, r.nextOverdue)}',
          ),
        ),
      );
  }
}
