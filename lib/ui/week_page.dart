import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../services/schedule_service.dart';
import '../state/app_controller.dart';
import '../util/persian.dart';
import 'day_page.dart';
import 'widgets/activity_tile.dart';

/// Weekly plan Saturday..Friday. Viewing A or B never changes the real week.
class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({super.key});

  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  WeekType? _view;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final realWeek = c.weekTypeOf(c.today);
    final view = _view ?? realWeek;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه هفتگی'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DayPage(initialDate: c.today),
              ),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text('مرور روزها'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            'هفته واقعی امروز: ${realWeek == WeekType.a ? 'A' : 'B'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<WeekType>(
            segments: const <ButtonSegment<WeekType>>[
              ButtonSegment<WeekType>(value: WeekType.a, label: Text('هفته A')),
              ButtonSegment<WeekType>(value: WeekType.b, label: Text('هفته B')),
            ],
            selected: <WeekType>{view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 12),
          for (var day = 0; day < 7; day++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                day == 2
                    ? 'دوشنبه — هفته ${view == WeekType.a ? 'A' : 'B'}'
                    : persianDayNames[day],
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final i in ScheduleService.buildForWeek(
              activities: c.activities,
              day: day,
              week: view,
              settings: c.settings,
              referenceDate: c.today,
            ))
              ActivityTile(
                key: ValueKey<String>('week-${i.activity.id}'),
                instance: i,
                now: c.now,
                showCheckbox: false,
                showStatus: false,
              ),
          ],
        ],
      ),
    );
  }
}
