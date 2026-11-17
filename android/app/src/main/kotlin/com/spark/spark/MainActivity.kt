package com.spark.spark

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter host. Exposes the native signaling layer to Dart over the
 * "spark/native" MethodChannel and schedules the 24/7 watchdog.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "spark/native"
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        // Crash persistence is installed before anything else can fail.
        CrashSaver.install(this)
        LaunchTrace.step(this, "activity:attachBaseContext")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        LaunchTrace.step(this, "onCreate:pre-super")
        super.onCreate(savedInstanceState)
        LaunchTrace.step(this, "onCreate:post-super")
    }

    override fun onResume() {
        super.onResume()
        val prefs = getSharedPreferences(SparkForegroundService.PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(SparkForegroundService.KEY_ENABLED, false)) {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                nm?.cancel(SparkForegroundService.NOTIFICATION_ID)
            } catch (_: Throwable) {
            }
        }
        if (SparkForegroundService.isRunning) {
            SparkForegroundService.notifyAppActive()
        }
    }

    /**
     * Native crash visibility without logcat lives in [ExitInfo], dumped from
     * SparkApplication.attachBaseContext — the earliest hook available.
     */

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        LaunchTrace.step(this, "engine:configure-start")
        super.configureFlutterEngine(flutterEngine)
        LaunchTrace.step(this, "engine:configured")

        try {
            SignalWatchdogWorker.schedule(this)
            LaunchTrace.step(this, "watchdog:scheduled")
        } catch (t: Throwable) {
            CrashSaver.write(this, "Watchdog scheduling failed:\n\n${CrashSaver.describe(t)}")
        }

        try {
            val prefs = getSharedPreferences(SparkForegroundService.PREFS, MODE_PRIVATE)
            if (prefs.getBoolean(SparkForegroundService.KEY_ENABLED, false) &&
                FirebaseAuth.getInstance().currentUser != null &&
                !SparkForegroundService.isRunning
            ) {
                val intent = Intent(this, SparkForegroundService::class.java)
                    .setAction(SparkForegroundService.ACTION_START)
                ContextCompat.startForegroundService(this, intent)
            }
        } catch (_: Throwable) {
        }

        try {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
                .setMethodCallHandler { call, result ->
                    try {
                        handle(call.method, call.arguments, result)
                    } catch (t: Throwable) {
                        CrashSaver.write(
                            this,
                            "Channel call '${call.method}' failed:\n\n${CrashSaver.describe(t)}"
                        )
                        result.error("NATIVE_ERROR", t.message, null)
                    }
                }
            LaunchTrace.step(this, "engine:channel-ready")
        } catch (t: Throwable) {
            CrashSaver.write(this, "Channel setup failed:\n\n${CrashSaver.describe(t)}")
        }
    }

    private fun handle(method: String, arguments: Any?, result: MethodChannel.Result) {
        val prefs = getSharedPreferences(SparkForegroundService.PREFS, MODE_PRIVATE)
        when (method) {
            "saveCrashLog" -> {
                CrashSaver.write(this, arguments as? String ?: "empty crash log")
                result.success(true)
            }

            "traceStep" -> {
                LaunchTrace.step(this, arguments as? String ?: "unknown-step")
                result.success(true)
            }

            "startSignaling" -> {
                prefs.edit().putBoolean(SparkForegroundService.KEY_ENABLED, true).commit()
                SparkForegroundService.isRunning = true
                val intent = Intent(this, SparkForegroundService::class.java)
                    .setAction(SparkForegroundService.ACTION_START)
                try {
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                } catch (e: Exception) {
                    prefs.edit().putBoolean(SparkForegroundService.KEY_ENABLED, false).commit()
                    SparkForegroundService.isRunning = false
                    result.success(false)
                }
            }

            "stopSignaling" -> {
                prefs.edit().putBoolean(SparkForegroundService.KEY_ENABLED, false).commit()
                SparkForegroundService.isRunning = false
                try {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                    nm?.cancel(SparkForegroundService.NOTIFICATION_ID)
                } catch (_: Throwable) {
                }
                val intent = Intent(this, SparkForegroundService::class.java)
                    .setAction(SparkForegroundService.ACTION_STOP)
                try {
                    startService(intent)
                } catch (_: Exception) {
                }
                result.success(true)
            }

            "isSignalingActive" -> {
                val enabled = prefs.getBoolean(SparkForegroundService.KEY_ENABLED, false)
                result.success(enabled)
            }

            "hasNotificationPermission" -> result.success(areNotificationsEnabled())

            "requestNotificationPermission" -> {
                if (areNotificationsEnabled()) {
                    result.success(true)
                } else if (Build.VERSION.SDK_INT >= 33) {
                    pendingNotificationResult = result
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATIONS
                    )
                } else {
                    result.success(true)
                }
            }

            "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBattery())

            "requestIgnoreBatteryOptimizations" -> {
                try {
                    if (!isIgnoringBattery()) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            .setData(Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            "hasUsagePermission" -> result.success(hasUsagePermission())

            "requestUsagePermission" -> result.success(requestUsagePermission())

            else -> result.notImplemented()
        }
    }

    private fun areNotificationsEnabled(): Boolean =
        NotificationManagerCompat.from(this).areNotificationsEnabled()

    private fun isIgnoringBattery(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? android.app.AppOpsManager
            ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsagePermission(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        }
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 4210
    }
}
