import 'package:flutter/services.dart';

/// Bridge to the native Android signaling layer.
///
/// The native `SparkForegroundService` owns all presence writes so that
/// signaling keeps working even when the Flutter app is terminated.
class SparkNative {
  static const _channel = MethodChannel('spark/native');

  /// Starts the 24/7 foreground signaling service.
  static Future<bool> startSignaling() => _invoke('startSignaling');

  /// Stops the service and writes an offline signal.
  static Future<bool> stopSignaling() => _invoke('stopSignaling');

  static Future<bool> isSignalingActive() => _invoke('isSignalingActive');

  static Future<bool> hasNotificationPermission() => _invoke('hasNotificationPermission');

  static Future<bool> requestNotificationPermission() => _invoke('requestNotificationPermission');

  static Future<bool> isIgnoringBatteryOptimizations() =>
      _invoke('isIgnoringBatteryOptimizations');

  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _invoke('requestIgnoreBatteryOptimizations');

  static Future<bool> hasUsagePermission() => _invoke('hasUsagePermission');

  static Future<bool> requestUsagePermission() => _invoke('requestUsagePermission');

  /// Persists a diagnostic message to /sdcard/Download via the native layer.
  static Future<void> saveCrashLog(String text) async {
    try {
      await _channel.invokeMethod<void>('saveCrashLog', text);
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  /// Writes a launch breadcrumb into the native launch-trace file.
  static Future<void> traceStep(String tag) async {
    try {
      await _channel.invokeMethod<void>('traceStep', tag);
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  static Future<bool> _invoke(String method, [Object? arg]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arg) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
