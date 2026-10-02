import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/default_schedule.dart';
import '../models/enums.dart';
import '../services/week_service.dart';
import '../state/app_controller.dart';
import '../util/persian.dart';
import 'settings_page.dart';
import 'widgets/permission_dialogs.dart';

/// First run: choose the reference Saturday and whether it is week A or B.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  DateTime? _saturday;
  WeekType _type = WeekType.a;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final sat = _saturday ?? WeekService.saturdayOf(c.today);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('به Reminder خوش آمدی')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(defaultScheduleTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'برنامه هفتگی از همین حالا آماده است. فقط مشخص کن کدام هفته A است '
            'تا دوشنبه‌ها (و ساعت مدرسه) درست نمایش داده شوند. هفته از شنبه شروع '
            'می‌شود و از تاریخ مبنا به بعد، A و B یک‌درمیان تغییر می‌کنند.',
            softWrap: true,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('شنبه مبنا'),
            subtitle: Text('${formatJalali(sat)} • ${formatGregorian(sat)}'),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final d = await pickSaturday(context, sat);
              if (d != null) setState(() => _saturday = d);
            },
          ),
          const Text('این هفته کدام است؟'),
          const SizedBox(height: 6),
          SegmentedButton<WeekType>(
            segments: const <ButtonSegment<WeekType>>[
              ButtonSegment<WeekType>(value: WeekType.a, label: Text('هفته A')),
              ButtonSegment<WeekType>(value: WeekType.b, label: Text('هفته B')),
            ],
            selected: <WeekType>{_type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    // Ask for permissions here, at the moment reminders
                    // start to matter, with a Persian explanation first.
                    if (!c.notificationsAllowed) {
                      await askNotificationPermission(context, c);
                    }
                    if (!context.mounted) return;
                    if (!c.exactAllowed) {
                      await askExactAlarmPermission(context, c);
                    }
                    // Completing onboarding replaces this page with Home.
                    await c.completeOnboarding(sat, _type);
                  },
            child: const Text('شروع'),
          ),
        ],
      ),
    );
  }
}
