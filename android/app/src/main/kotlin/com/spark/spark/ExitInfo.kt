package com.spark.spark

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build

/**
 * Dumps the system's record of why this process previously exited
 * (ApplicationExitInfo, API 30+). This is the only window into a native
 * crash (SIGSEGV/SIGABRT) when logcat is unavailable. Called from
 * SparkApplication.attachBaseContext — before any content provider runs.
 */
object ExitInfo {

    fun dumpPrevious(context: Context) {
        try {
            if (Build.VERSION.SDK_INT < 30) return
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val records = am.getHistoricalProcessExitReasons(context.packageName, 0, 5)
            if (records.isEmpty()) return
            val newest = records[0]
            val reason = newest.reason
            val interesting = reason == ApplicationExitInfo.REASON_CRASH ||
                reason == ApplicationExitInfo.REASON_CRASH_NATIVE ||
                reason == ApplicationExitInfo.REASON_SIGNALED ||
                reason == ApplicationExitInfo.REASON_ANR ||
                reason == ApplicationExitInfo.REASON_LOW_MEMORY ||
                reason == ApplicationExitInfo.REASON_INITIALIZATION_FAILURE
            if (!interesting) return

            val prefs = context.getSharedPreferences(
                SparkForegroundService.PREFS, Context.MODE_PRIVATE
            )
            if (newest.timestamp <= prefs.getLong("last_exit_reported", 0L)) return
            prefs.edit().putLong("last_exit_reported", newest.timestamp).apply()

            val sb = StringBuilder()
            for (r in records) {
                sb.append("reason=${reasonName(r.reason)} status=${r.status} at=${r.timestamp} ")
                    .append("desc=${r.description ?: "-"}\n")
                if (r.reason == ApplicationExitInfo.REASON_CRASH ||
                    r.reason == ApplicationExitInfo.REASON_CRASH_NATIVE ||
                    r.reason == ApplicationExitInfo.REASON_SIGNALED ||
                    r.reason == ApplicationExitInfo.REASON_ANR
                ) {
                    try {
                        val trace = r.traceInputStream?.use { input -> input.readBytes() }
                        if (trace != null && trace.isNotEmpty()) {
                            val capped = if (trace.size > 65536) trace.copyOf(65536) else trace
                            sb.append("\n--- trace ---\n")
                                .append(String(capped))
                                .append("\n--- end trace ---\n")
                        }
                    } catch (_: Throwable) {
                    }
                }
            }
            CrashSaver.writeFile(
                context,
                "spark-exitinfo-${CrashSaver.now()}",
                "Previous process exit records:\n\n$sb"
            )
            LaunchTrace.step(context, "exitinfo:reason=${reasonName(reason)}")
        } catch (_: Throwable) {
        }
    }

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
        ApplicationExitInfo.REASON_CRASH -> "CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "PACKAGE_STATE_CHANGE"
        ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "PACKAGE_UPDATED"
        ApplicationExitInfo.REASON_FREEZER -> "FREEZER"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        else -> "OTHER($reason)"
    }
}
