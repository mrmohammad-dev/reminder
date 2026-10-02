package com.mohammad.reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar

/**
 * Once-a-day inexact alarm that extends the rolling 14-day reminder window,
 * so reminders continue even if the app is not opened for weeks.
 * Inexact repeating alarms need no special permission. Alarms are cleared by
 * reboot and Force stop; they are re-armed on boot/update and on app start.
 */
object DailyResyncScheduler {
    const val ACTION = "com.mohammad.reminder.DAILY_RESYNC"
    private const val REQUEST_CODE = 7001

    fun schedule(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ResyncReceiver::class.java).setAction(ACTION)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val first = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 3)
            set(Calendar.MINUTE, 15)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            first.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent,
        )
    }
}
