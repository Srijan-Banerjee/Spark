# Spark — Real-Time Activity & Signaling (Android)

**Spark** is a real-time activity signaling Flutter application for Android that lets trusted friends, partners, and family stay connected with live presence states.

Built with a dark glassmorphic design language, 24/7 background native Android service, and real-time synchronization over Firebase.

---

## Key Features

- **Live Activity States:**
  - **Active Now:** Shows when friends unlock and actively use their phone, including the currently active foreground app (e.g. *Using WhatsApp*, *Using YouTube*) or if they are *Idle* on their home screen.
  - **Lockscreen On:** Instantly indicates when a friend's screen powers on but remains locked with keyguard.
  - **Offline (Signal on):** Indicates the device is reachable and screen is off, displaying the exact compound time since last active (e.g. `12m ago`, `1h 24m ago`, `2d 4h ago`).
  - **Offline (Signal off):** Indicates broadcasting is turned off or device is disconnected.
- **Detailed Compound Relative Time:**
  - Accurate, compact formatting: minutes as `m`, hours as `h`, days as `d`, months as `mo`, years as `y` (e.g., `5m ago`, `1h 15m ago`, `1d 4h ago`, `2mo 12d ago`).
  - Strict preservation of the true last active time—never resets on lockscreen wakes or background watchdog checks.
- **Smart Privacy & Visibility:**
  - Instant **Block / Unblock** control per friend with smooth sliding highlighted toggle.
  - Blocked users are completely denied visibility into activity signals.
- **Favorites & Search:**
  - Star friends to pin them to the top of your activity list (persisted in database).
  - Fast, smart real-time friends search bar.
- **Background Signaling Service:**
  - Native Kotlin foreground service running 24/7 with zero battery drain.
  - Screen on/off and unlock detection with auto-recovering WorkManager watchdog.
- **Account Controls:**
  - Complete in-app account deletion with cascade cleanup across all friendships and requests.

---

## Tech Stack & Architecture

- **Frontend:** Flutter (Dart 3.x, Riverpod state management)
- **Backend:** Firebase Authentication (Email/Password) + Firebase Realtime Database
- **Android Native:** Kotlin `SparkForegroundService`, `UsageStatsManager`, `BroadcastReceiver`, `WorkManager`
- **Design:** Custom dark glassmorphism with emerald (`#10B981`) and amber (`#FFB800`) accents

---

## Project Structure

```
spark/
├── lib/
│   ├── app.dart                   # Root MaterialApp & theme configuration
│   ├── main.dart                  # Entry point & error handlers
│   ├── core/
│   │   ├── presence.dart          # Presence models, state parser, visibility logic
│   │   ├── theme.dart             # Spark dark glassmorphic theme palette
│   │   ├── time.dart              # Detailed compound relative time formatting
│   │   └── widgets/               # GlassCard, StatusChip, AppActivityTag, SignalSwitch
│   ├── data/
│   │   └── db.dart                # Firebase Realtime Database queries & models
│   ├── state/
│   │   └── providers.dart         # Riverpod providers for presence, friends, signaling
│   ├── services/
│   │   └── native_bridge.dart     # MethodChannel bridge to Android Kotlin layer
│   └── screens/
│       ├── home_screen.dart       # Live status toggle & friends activity list
│       ├── friends_screen.dart    # Friend list, search bar, favorites, requests
│       ├── friend_detail_screen.dart # Friend activity detail & block/unblock
│       └── settings_screen.dart   # Permissions & account management
├── android/
│   └── app/src/main/kotlin/com/spark/spark/
│       ├── MainActivity.kt        # MethodChannel handler
│       ├── SparkForegroundService.kt # 24/7 signaling service & open app detector
│       └── SignalWatchdogWorker.kt# WorkManager periodic service watchdog
└── db_rules.json                  # Hardened Firebase Realtime Database rules
```

---

## Getting Started

### 1. Prerequisites
- Flutter SDK (>= 3.14.0)
- Android SDK (API level 24+)
- A Firebase project

### 2. Configure Firebase

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an **Android app** with package name `com.spark.activitychecker`.
3. Download `google-services.json` and place it in `android/app/google-services.json`.
4. Enable **Authentication** → **Email/Password**.
5. Enable **Realtime Database** and set your database rules using `db_rules.json`.
6. Update the database URL in:
   - `lib/data/db.dart` (`databaseUrl`)
   - `lib/main.dart` (`databaseURL`)
   - `android/app/src/main/kotlin/com/spark/spark/SparkForegroundService.kt` (`DATABASE_URL`)

### 3. Build & Run

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK (ARM64)
flutter build apk --release --target-platform android-arm64
```

---

## Permissions Used

- `android.permission.FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_SPECIAL_USE`: For the 24/7 presence broadcast service.
- `android.permission.POST_NOTIFICATIONS`: To show the persistent service status notification.
- `android.permission.PACKAGE_USAGE_STATS`: Optional permission to detect and display current active app (e.g. *Using WhatsApp*) to approved friends.
- `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Prevents aggressive OEM battery managers from killing the signaling service.
- `android.permission.RECEIVE_BOOT_COMPLETED`: Restarts the broadcast service upon device reboot.

---

## License

This project is open source and available under the [MIT License](LICENSE).
