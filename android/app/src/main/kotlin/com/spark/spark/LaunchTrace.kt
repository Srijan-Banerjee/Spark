package com.spark.spark

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Writes an append-only breadcrumb file per process run into the Download
 * folder, so a silent native death can be located to a specific lifecycle
 * stage without logcat access. Each run gets its own file:
 * spark-launch-<timestamp>.log
 */
object LaunchTrace {
    private var uri: Uri? = null

    fun step(context: Context, tag: String) {
        try {
            if (Build.VERSION.SDK_INT < 29) return
            val line = System.currentTimeMillis().toString() + "  " + tag + "\n"

            // Reuse this run's file for appending.
            var u = uri
            if (u != null) {
                try {
                    context.contentResolver.openOutputStream(u, "wa")?.use { out ->
                        out.write(line.toByteArray())
                    }
                    return
                } catch (_: Throwable) {
                    uri = null
                }
            }

            // First write of this run: create the file in Downloads.
            try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, "spark-launch-${CrashSaver.now()}.log")
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                u = context.contentResolver
                    .insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (u != null) {
                    context.contentResolver.openOutputStream(u, "wa")?.use { out ->
                        out.write(line.toByteArray())
                    }
                    uri = u
                    return
                }
            } catch (_: Throwable) {
            }

            // OEM-blocked Downloads: try the generic Files collection.
            try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, "spark-launch-${CrashSaver.now()}.log")
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                u = context.contentResolver.insert(
                    MediaStore.Files.getContentUri("external"), values
                )
                if (u != null) {
                    context.contentResolver.openOutputStream(u, "wa")?.use { out ->
                        out.write(line.toByteArray())
                    }
                    uri = u
                    return
                }
            } catch (_: Throwable) {
            }

            // Last resort: app-scoped dir (evidence survives; reachable via adb).
            try {
                val dir = File(context.getExternalFilesDir(null), "SparkLogs")
                dir.mkdirs()
                File(dir, "spark-launch.log").appendText(line)
            } catch (_: Throwable) {
            }
        } catch (_: Throwable) {
            // Tracing must never break the app.
        }
    }
}
