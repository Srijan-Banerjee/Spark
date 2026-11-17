package com.spark.spark

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue

/**
 * 24/7 foreground service that owns Spark's presence signal.
 *
 * - Listens to SCREEN_ON / SCREEN_OFF / USER_PRESENT / SHUTDOWN broadcasts.
 * - Detects screen unlock instantly using reactive broadcasts and an interactive poller.
 * - Writes presence to Firebase Realtime Database in real time.
 * - Arms an onDisconnect() handler so friends see "offline" if this device
 *   ever loses connectivity.
 * - Shows a persistent notification with the user's live status and
 *   a direct "Turn off" action.
 *
 * Runs on its own (START_STICKY) even after the Flutter app is terminated.
 */
class SparkForegroundService : Service() {

    companion object {
        const val PREFS = "spark_native"
        const val KEY_ENABLED = "signaling_enabled"

        const val ACTION_START = "com.spark.spark.action.START"
        const val ACTION_STOP = "com.spark.spark.action.STOP"

        const val CHANNEL_ID = "spark_status"
        const val NOTIFICATION_ID = 4242

        const val DATABASE_URL = "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com"

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var instance: SparkForegroundService? = null
            private set

        fun notifyAppActive() {
            instance?.let { s ->
                s.handler.post {
                    s.handler.removeCallbacks(s.unlockCheckRunnable)
                    s.publish("active")
                }
            }
        }
    }

    private var receiver: BroadcastReceiver? = null
    private var connectedListener: com.google.firebase.database.ValueEventListener? = null
    private var presenceRef: com.google.firebase.database.DatabaseReference? = null
    private var lastState: String = "inactive"

    private val handler = Handler(Looper.getMainLooper())

    private var lastReportedApp: String? = null
    private var lastReportedIdle: Boolean = false
    private var lastReportedPkg: String? = null

    private val appPollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning || lastState != "active") return
            val (currentApp, isIdle) = detectCurrentApp()
            if (currentApp != lastReportedApp || isIdle != lastReportedIdle) {
                lastReportedApp = currentApp
                lastReportedIdle = isIdle
                writePresence("active", currentApp, isIdle, "active")
                updateNotification(describe("active", currentApp, isIdle))
            }
            handler.postDelayed(this, 2500L)
        }
    }

    private val heartbeat = object : Runnable {
        override fun run() {
            // While the user keeps the screen unlocked, refresh timestamp periodically.
            if (lastState == "active") {
                val (app, isIdle) = detectCurrentApp()
                writePresence("active", app, isIdle, "active")
            }
            handler.postDelayed(this, 60_000L)
        }
    }

    /**
     * Ticks every 750ms only while the screen is powered on but locked (screenOn),
     * ensuring immediate transition to "active" as soon as the user unlocks with
     * fingerprint, face, pattern, PIN, or swipe — even on OEMs where ACTION_USER_PRESENT is delayed.
     */
    val unlockCheckRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm?.isInteractive != true) {
                publish("inactive")
                return
            }
            if (isScreenUnlocked()) {
                publish("active")
                return
            }
            handler.postDelayed(this, 750L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        CrashSaver.install(this)
        isRunning = true
        instance = this
        createChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification("Signal broadcasting…"),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification("Signal broadcasting…"))
        }
        registerScreenReceiver()
        connectToFirebase()
        handler.postDelayed(heartbeat, 60_000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = prefs()
        when (intent?.action) {
            ACTION_STOP -> {
                stopSignaling()
                return START_NOT_STICKY
            }

            else -> { // ACTION_START or restart after process death
                prefs.edit().putBoolean(KEY_ENABLED, true).apply()
                if (FirebaseAuth.getInstance().currentUser == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                connectToFirebase()
                detectAndWriteCurrentState()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSignaling()
    }

    override fun onDestroy() {
        isRunning = false
        if (instance == this) instance = null
        handler.removeCallbacks(heartbeat)
        handler.removeCallbacks(unlockCheckRunnable)
        handler.removeCallbacks(appPollRunnable)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(NOTIFICATION_ID)
        } catch (_: Throwable) {
        }
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        connectedListener?.let {
            try {
                FirebaseDatabase.getInstance(DATABASE_URL).getReference(".info/connected")
                    .removeEventListener(it)
            } catch (_: Exception) {
            }
        }
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
    }

    // ------------------------------------------------------------------ core

    private fun prefs(): SharedPreferences =
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun uid(): String? = FirebaseAuth.getInstance().currentUser?.uid

    private fun connectToFirebase() {
        val user = uid() ?: return
        try {
            val ref = FirebaseDatabase.getInstance(DATABASE_URL)
                .getReference("presence").child(user)
            presenceRef = ref

            // Arm the offline fallback: if this device ever loses connection
            // without a graceful stop, mark offline server-side, but preserve the true last active time.
            ref.onDisconnect().updateChildren(
                mapOf(
                    "state" to "offline",
                    "lastChanged" to ServerValue.TIMESTAMP,
                    "device" to "android",
                    "app" to "",
                    "isIdle" to false
                )
            )

            val listener = object : com.google.firebase.database.ValueEventListener {
                override fun onDataChange(snapshot: com.google.firebase.database.DataSnapshot) {
                    val connected = snapshot.getValue(Boolean::class.java) ?: false
                    if (connected) {
                        ref.onDisconnect().updateChildren(
                            mapOf(
                                "state" to "offline",
                                "lastChanged" to ServerValue.TIMESTAMP,
                                "device" to "android",
                                "app" to "",
                                "isIdle" to false
                            )
                        )
                        detectAndWriteCurrentState()
                    }
                }

                override fun onCancelled(error: com.google.firebase.database.DatabaseError) {}
            }
            connectedListener = listener
            FirebaseDatabase.getInstance(DATABASE_URL).getReference(".info/connected")
                .addValueEventListener(listener)
        } catch (_: Throwable) {
        }
    }

    private fun registerScreenReceiver() {
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_USER_PRESENT -> {
                        handler.removeCallbacks(unlockCheckRunnable)
                        publish("active")
                    }

                    Intent.ACTION_SCREEN_ON -> {
                        if (isScreenUnlocked()) {
                            publish("active")
                        } else {
                            publish("screenOn")
                        }
                    }

                    Intent.ACTION_SCREEN_OFF -> {
                        handler.removeCallbacks(unlockCheckRunnable)
                        publish("inactive")
                    }

                    Intent.ACTION_SHUTDOWN -> {
                        handler.removeCallbacks(unlockCheckRunnable)
                        writePresence("offline", previousState = lastState)
                    }
                }
            }
        }
        receiver = r
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SHUTDOWN)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(r, filter)
            }
        } catch (_: Throwable) {
            try {
                registerReceiver(r, filter)
            } catch (_: Throwable) {
                try {
                    ContextCompat.registerReceiver(this, r, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun isScreenUnlocked(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (pm?.isInteractive != true) return false
        val km = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
        return !(km?.isKeyguardLocked ?: false)
    }

    private fun detectAndWriteCurrentState() {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val state = when {
            pm?.isInteractive != true -> "inactive"
            !isScreenUnlocked() -> "screenOn"
            else -> "active"
        }
        publish(state)
    }

    private fun publish(state: String) {
        val previousState = lastState
        lastState = state
        handler.removeCallbacks(unlockCheckRunnable)
        handler.removeCallbacks(appPollRunnable)
        if (state == "screenOn") {
            lastReportedApp = null
            lastReportedIdle = false
            lastReportedPkg = null
            writePresence("screenOn", "", false, previousState)
            updateNotification(describe("screenOn"))
            handler.postDelayed(unlockCheckRunnable, 750L)
        } else if (state == "active") {
            val (currentApp, isIdle) = detectCurrentApp()
            lastReportedApp = currentApp
            lastReportedIdle = isIdle
            writePresence("active", currentApp, isIdle, previousState)
            updateNotification(describe("active", currentApp, isIdle))
            handler.postDelayed(appPollRunnable, 2500L)
        } else {
            lastReportedApp = null
            lastReportedIdle = false
            lastReportedPkg = null
            writePresence(state, "", false, previousState)
            updateNotification(describe(state))
        }
    }

    private fun writePresence(
        state: String,
        app: String? = null,
        isIdle: Boolean = false,
        previousState: String? = null
    ) {
        try {
            val user = uid() ?: return
            val ref = presenceRef ?: FirebaseDatabase.getInstance(DATABASE_URL)
                .getReference("presence").child(user)
            val map = mutableMapOf<String, Any>(
                "state" to state,
                "lastChanged" to ServerValue.TIMESTAMP,
                "device" to "android"
            )

            // Only update lastSeen when active, or at the exact moment of transitioning from active to inactive.
            // Never update lastSeen for screenOn (lockscreen), and never while already inactive/offline.
            if (state == "active" || (state == "inactive" && previousState == "active")) {
                map["lastSeen"] = System.currentTimeMillis()
            }

            if (state == "active") {
                if (isIdle || app == "Idle") {
                    map["isIdle"] = true
                    map["app"] = "Idle"
                } else if (!app.isNullOrBlank()) {
                    map["isIdle"] = false
                    map["app"] = app
                } else {
                    map["isIdle"] = false
                    map["app"] = ""
                }
            } else {
                map["isIdle"] = false
                map["app"] = ""
            }
            ref.updateChildren(map)
        } catch (_: Throwable) {
        }
    }

    private fun describe(state: String, app: String? = null, isIdle: Boolean = false): String = when (state) {
        "active" -> {
            if (isIdle || app == "Idle") {
                "Active now — Idle"
            } else if (!app.isNullOrBlank()) {
                "Active now — Using $app"
            } else {
                "Active now — screen unlocked"
            }
        }
        "screenOn" -> "Lockscreen On — screen lit"
        "inactive" -> "Offline (Signal on) — screen off"
        "offline" -> "Offline (Signal off)"
        else -> "Spark signal broadcasting"
    }

    private fun stopSignaling() {
        isRunning = false
        prefs().edit().putBoolean(KEY_ENABLED, false).apply()
        handler.removeCallbacks(unlockCheckRunnable)
        handler.removeCallbacks(appPollRunnable)
        handler.removeCallbacks(heartbeat)
        try {
            writePresence("offline", previousState = lastState)
            presenceRef?.onDisconnect()?.cancel()
        } catch (_: Throwable) {
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(NOTIFICATION_ID)
        } catch (_: Throwable) {
        }
        stopSelf()
    }

    private fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            false
        }
    }

    private var launcherPackagesCache: Set<String>? = null

    private fun getLauncherPackages(): Set<String> {
        launcherPackagesCache?.let { return it }
        val pkgs = mutableSetOf(
            "com.google.android.apps.nexuslauncher",
            "com.android.launcher3",
            "com.android.launcher",
            "com.miui.home",
            "com.sec.android.app.launcher",
            "com.huawei.android.launcher",
            "com.oppo.launcher",
            "com.oneplus.launcher",
            "com.transsion.hilauncher",
            "com.transsion.XOSLauncher",
            "com.motorola.launcher3"
        )
        try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, 0)
            }
            for (ri in resolveInfos) {
                ri.activityInfo?.packageName?.let { pkgs.add(it) }
            }
        } catch (_: Throwable) {
        }
        launcherPackagesCache = pkgs
        return pkgs
    }

    private fun isLauncherPackage(pkg: String): Boolean {
        return getLauncherPackages().contains(pkg)
    }

    private fun getAppLabel(pkg: String): String {
        return try {
            val ai = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(pkg, 0)
            }
            packageManager.getApplicationLabel(ai).toString()
        } catch (_: Throwable) {
            pkg.substringAfterLast('.').replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }
    }

    private fun detectCurrentApp(): Pair<String?, Boolean> {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (pm?.isInteractive != true || !isScreenUnlocked()) {
            return Pair(null, false)
        }

        if (!hasUsageStatsPermission()) {
            return Pair(null, false)
        }

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return Pair(null, false)

        val now = System.currentTimeMillis()
        val events = try {
            usm.queryEvents(now - 2 * 60 * 60 * 1000L, now)
        } catch (_: Throwable) {
            null
        }

        var currentPkg: String? = null
        if (events != null) {
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    currentPkg = event.packageName
                }
            }
        }

        if (currentPkg.isNullOrEmpty()) {
            val statsList = try {
                usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 24 * 60 * 60 * 1000L, now)
            } catch (_: Throwable) {
                null
            }
            currentPkg = statsList?.maxByOrNull { it.lastTimeUsed }?.packageName
        }

        if (currentPkg.isNullOrEmpty()) {
            currentPkg = lastReportedPkg
        }

        if (currentPkg.isNullOrEmpty()) {
            return Pair("Idle", true)
        }

        lastReportedPkg = currentPkg

        if (isLauncherPackage(currentPkg) || currentPkg == "com.android.systemui") {
            return Pair("Idle", true)
        }

        if (currentPkg == packageName) {
            return Pair("Spark", false)
        }

        val label = getAppLabel(currentPkg)
        return Pair(label, false)
    }

    // ------------------------------------------------------- notification UI

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Spark status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows your live activity signal status and lets you turn it off"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val turnOff = NotificationCompat.Action(
            R.drawable.ic_spark,
            "Turn off",
            PendingIntent.getService(
                this, 2,
                Intent(this, SparkForegroundService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_spark)
            .setContentTitle("Spark")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(openApp)
            .setOngoing(true)
            .setSilent(true)
            .setColor(0xFFFFB800.toInt())
            .addAction(turnOff)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(text: String) {
        val enabled = prefs().getBoolean(KEY_ENABLED, false)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (!enabled || !isRunning || lastState == "offline") {
            try {
                nm?.cancel(NOTIFICATION_ID)
            } catch (_: Throwable) {
            }
            return
        }
        try {
            nm?.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {
        }
    }
}
