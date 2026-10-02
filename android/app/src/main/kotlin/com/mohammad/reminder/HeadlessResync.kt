package com.mohammad.reminder

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Starts `backgroundResyncMain` (lib/main.dart) without any UI. */
object HeadlessResync {
    private const val TAG = "ReminderResync"
    private const val CHANNEL = "com.mohammad.reminder/resync"
    private const val ENTRYPOINT = "backgroundResyncMain"
    private const val TIMEOUT_MS = 25_000L

    private var running = false

    fun run(context: Context, onDone: () -> Unit) {
        if (running) {
            onDone()
            return
        }
        running = true
        val main = Handler(Looper.getMainLooper())
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            if (!loader.initialized()) {
                loader.startInitialization(context)
            }
            loader.ensureInitializationCompleteAsync(context, null, main) {
                val engine = FlutterEngine(context)
                var finished = false
                val finish = Runnable {
                    if (!finished) {
                        finished = true
                        try {
                            engine.destroy()
                        } catch (e: Exception) {
                            Log.w(TAG, "engine destroy failed", e)
                        }
                        running = false
                        onDone()
                    }
                }
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .setMethodCallHandler { call, result ->
                        if (call.method == "done") {
                            result.success(null)
                            main.post(finish)
                        } else {
                            result.notImplemented()
                        }
                    }
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                )
                main.postDelayed(finish, TIMEOUT_MS)
            }
        } catch (e: Exception) {
            Log.e(TAG, "headless resync failed", e)
            running = false
            onDone()
        }
    }
}
