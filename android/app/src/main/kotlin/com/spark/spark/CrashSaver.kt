package com.spark.spark

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Persists uncaught exceptions to the public Download folder so on-device
 * builds without adb can still be diagnosed. Files land in /sdcard/Download
 * as spark-crash-<timestamp>.txt (or Download/SparkLogs/ on API < 29).
 */
object CrashSaver {

    private val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US)
    private var lastWrite = 0L
    private var writes = 0

    fun now(): String = stamp.format(Date())

    /** Installs a global uncaught-exception handler that persists the trace. */
    fun install(context: Context) {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            write(
                context,
                "Uncaught exception on thread \"${thread.name}\":\n\n${describe(throwable)}"
            )
            previous?.uncaughtException(thread, throwable)
        }
    }

    fun describe(t: Throwable): String {
        val sw = StringWriter()
        t.printStackTrace(PrintWriter(sw))
        return sw.toString()
    }

    /** Writes a named file into the Download folder. Never throws. */
    @Synchronized
    fun writeFile(context: Context, baseName: String, text: String) {
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                var ok = false
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, "$baseName.txt")
                        put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    }
                    val uri = context.contentResolver
                        .insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    if (uri != null) {
                        context.contentResolver.openOutputStream(uri)?.use { out ->
                            out.write(text.toByteArray())
                        }
                        ok = true
                    }
                } catch (_: Throwable) {
                }
                if (ok) return
                // Some OEM builds block the Downloads collection; try the
                // generic Files collection pointed at the same folder.
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, "$baseName.txt")
                        put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    }
                    val uri = context.contentResolver.insert(
                        MediaStore.Files.getContentUri("external"), values
                    )
                    if (uri != null) {
                        context.contentResolver.openOutputStream(uri)?.use { out ->
                            out.write(text.toByteArray())
                        }
                        ok = true
                    }
                } catch (_: Throwable) {
                }
                if (ok) return
            }
            // Last resort: app-scoped external dir (not readable by Termux but
            // survives as evidence and is reachable via adb).
            @Suppress("DEPRECATION")
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "SparkLogs"
            )
            try {
                dir.mkdirs()
                File(dir, "$baseName.txt").writeText(text)
            } catch (_: Throwable) {
                val fallback = File(context.getExternalFilesDir(null), "SparkLogs")
                fallback.mkdirs()
                File(fallback, "$baseName.txt").writeText(text)
            }
        } catch (_: Throwable) {
            // Diagnostics must never become the crash themselves.
        }
    }

    /** Best-effort synchronous write of a crash report. Never throws. */
    fun write(context: Context, text: String) {
        val now = System.currentTimeMillis()
        // Rate limit so a repeating Dart error cannot flood Download.
        if (writes >= 25 || now - lastWrite < 3_000) return
        lastWrite = now
        writes++
        writeFile(context, "spark-crash-${now()}", text)
    }
}
