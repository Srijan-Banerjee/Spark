import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/native_bridge.dart';

/// Set when the native Firebase configuration (google-services.json) is
/// missing or invalid, so the app can show a friendly setup screen instead of
/// crashing.
bool kFirebaseInitFailed = false;

/// The exception that made [kFirebaseInitFailed] true, for display.
String? kFirebaseInitError;

void _report(String what) {
  // Fire-and-forget; never let diagnostics break the app.
  SparkNative.saveCrashLog(what);
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SparkNative.traceStep('dart:main');

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _report('FlutterError: ${details.exceptionAsString()}\n\n${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _report('Uncaught Dart error: $error\n\n$stack');
      return true;
    };

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    await SparkNative.traceStep('dart:ui-ready');

    try {
      await Firebase.initializeApp();
      try {
        FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
        ).setPersistenceEnabled(true);
      } catch (_) {}
      await SparkNative.traceStep('dart:firebase-ok');
    } catch (e, s) {
      kFirebaseInitFailed = true;
      kFirebaseInitError = e.toString();
      await SparkNative.traceStep('dart:firebase-fail');
      _report('Firebase init failed: $e\n\n$s');
    }

    runApp(const ProviderScope(child: SparkApp()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SparkNative.traceStep('dart:first-frame');
    });
  }, (error, stack) {
    _report('Uncaught zone error: $error\n\n$stack');
  });
}
