package com.mohammad.reminder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opening the app (e.g. after a Force stop) re-arms the daily refresh.
        DailyResyncScheduler.schedule(applicationContext)
    }
}
