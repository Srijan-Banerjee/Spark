package com.spark.spark

import android.content.Context
import android.content.Intent
import java.util.concurrent.TimeUnit
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.firebase.auth.FirebaseAuth

/**
 * 15-minute watchdog: if signaling is enabled and the user is signed in but
 * the service died (battery saver, crash, boot restriction), restart it.
 */
class SignalWatchdogWorker(
    appContext: Context,
    params: WorkerParameters
) : Worker(appContext, params) {

    override fun doWork(): Result {
        return try {
            val prefs = applicationContext
                .getSharedPreferences(SparkForegroundService.PREFS, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(SparkForegroundService.KEY_ENABLED, false)
            val signedIn = try {
                FirebaseAuth.getInstance().currentUser != null
            } catch (_: Exception) {
                false
            }

            if (enabled && signedIn && !SparkForegroundService.isRunning) {
                val intent = Intent(applicationContext, SparkForegroundService::class.java)
                    .setAction(SparkForegroundService.ACTION_START)
                try {
                    ContextCompat.startForegroundService(applicationContext, intent)
                } catch (_: Exception) {
                }
            }
            Result.success()
        } catch (_: Throwable) {
            Result.success()
        }
    }

    companion object {
        fun schedule(context: Context) {
            try {
                val request = PeriodicWorkRequestBuilder<SignalWatchdogWorker>(15, TimeUnit.MINUTES)
                    .build()
                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    "spark_signal_watchdog",
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
            } catch (_: Throwable) {
                // Safeguard: Never let watchdog scheduling break the app
            }
        }
    }
}
