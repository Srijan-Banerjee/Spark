package com.spark.spark

import android.app.Application
import android.content.Context
import androidx.work.Configuration

/**
 * Application shell. Its attachBaseContext runs BEFORE all content providers
 * (Firebase init, WorkManager init, Flutter initializer), so it is the
 * earliest possible point to install crash persistence and start the launch
 * breadcrumb trail.
 */
class SparkApplication : Application(), Configuration.Provider {

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(android.util.Log.INFO)
            .build()

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        CrashSaver.install(this)
        LaunchTrace.step(this, "app:attachBaseContext")
        ExitInfo.dumpPrevious(this)
        LaunchTrace.step(this, "app:exitinfo-checked")
    }

    override fun onCreate() {
        super.onCreate()
        LaunchTrace.step(this, "app:onCreate")
    }
}
