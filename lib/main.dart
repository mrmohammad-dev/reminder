import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_deps.dart';
import 'background.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AppController controller;
  final deps = await AppDeps.create(
    // Notification action pressed while the app is running.
    onResponse: (response) async {
      await controller.engine.handleAction(
        response.actionId,
        response.payload,
      );
      await controller.refresh();
    },
  );
  controller = AppController(
    repo: deps.repo,
    settingsStore: deps.settingsStore,
    gateway: deps.gateway,
    clock: deps.clock,
  );
  runApp(
    ProviderScope(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
      child: const ReminderApp(),
    ),
  );
  unawaited(controller.init());
}

/// Native entry point used by ResyncReceiver.kt (headless FlutterEngine).
/// Must stay in main.dart so the default library lookup finds it.
@pragma('vm:entry-point')
Future<void> backgroundResyncMain() => runBackgroundResync();
