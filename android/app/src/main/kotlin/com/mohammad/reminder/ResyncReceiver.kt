package com.mohammad.reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/**
 * Handles boot, app update, clock/timezone change, exact-alarm permission
 * change and the daily refresh alarm by running the Dart resync logic in a
 * short-lived headless Flutter engine.
 */
class ResyncReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        DailyResyncScheduler.schedule(appContext)
        val pending = goAsync()
        Handler(Looper.getMainLooper()).post {
            HeadlessResync.run(appContext) { pending.finish() }
        }
    }
}
