package com.spark.spark

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Restarts signaling after device reboot so the signal is truly 24/7.
 * Only starts if the user had signaling enabled and is still signed in.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences(SparkForegroundService.PREFS, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(SparkForegroundService.KEY_ENABLED, false)
        val signedIn = try {
            com.google.firebase.auth.FirebaseAuth.getInstance().currentUser != null
        } catch (_: Exception) {
            false
        }

        if (!enabled || !signedIn) return

        val service = Intent(context, SparkForegroundService::class.java)
            .setAction(SparkForegroundService.ACTION_START)
        try {
            ContextCompat.startForegroundService(context, service)
        } catch (_: Exception) {
            // Some OEMs/versions restrict FGS start from boot; the periodic
            // SignalWatchdogWorker will retry within 15 minutes.
        }
    }
}
