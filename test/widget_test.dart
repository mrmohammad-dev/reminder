import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/app.dart';
import 'package:reminder/models/settings.dart';
import 'package:reminder/state/app_controller.dart';

import 'support/fakes.dart';

Future<AppController> _controller(WidgetTester tester, AppSettings s) async {
  final rig = TestRig(settings: s, now: DateTime.utc(2026, 9, 26, 6, 0));
  final c = AppController(
    repo: rig.repo,
    settingsStore: rig.store,
    gateway: rig.gateway,
    clock: rig.clock,
  );
  await tester.runAsync(c.init);
  return c;
}

Future<void> _pump(WidgetTester tester, AppController c) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appControllerProvider.overrideWith((ref) => c)],
      child: const ReminderApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('home is RTL Persian with full titles and week type', (
    tester,
  ) async {
    final c = await _controller(tester, testSettings());
    await _pump(tester, c);

    final ctx = tester.element(find.text('برنامه امروز'));
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(find.text('امروز شنبه'), findsOneWidget);
    expect(find.text('هفته A'), findsWidgets);
    expect(find.text('فعالیت بعدی'), findsOneWidget);

    final title = find.text('ریاضی — ویدئوی آموزشی یوتیوب');
    expect(title, findsWidgets);
    final widget = tester.widget<Text>(title.first);
    expect(widget.overflow, isNot(TextOverflow.ellipsis));
    expect(widget.maxLines, isNull);
    expect(find.byType(Checkbox), findsWidgets);
  });

  testWidgets('first run shows the A/B onboarding', (tester) async {
    final c = await _controller(tester, AppSettings.defaults());
    await _pump(tester, c);
    expect(find.text('به Reminder خوش آمدی'), findsOneWidget);
    expect(find.text('برنامه هفتگی مطالعه و فعالیت محمد'), findsOneWidget);
  });
}
