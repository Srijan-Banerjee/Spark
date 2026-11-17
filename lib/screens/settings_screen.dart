import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/widgets/controls.dart';
import '../core/widgets/glass.dart';
import '../data/db.dart';
import '../services/native_bridge.dart';
import '../state/providers.dart';
import 'delete_account_screen.dart';

/// Settings: profile, signaling, permissions, privacy, account actions.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  bool _batteryOk = false;
  bool _notifOk = false;
  bool _usageOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final battery = await SparkNative.isIgnoringBatteryOptimizations();
    final notif = await SparkNative.hasNotificationPermission();
    final usage = await SparkNative.hasUsagePermission();
    if (!mounted) return;
    setState(() {
      _batteryOk = battery;
      _notifOk = notif;
      _usageOk = usage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull ?? const <String, dynamic>{};
    final displayName = (profile['displayName'] as String?) ?? '';
    final username = (profile['username'] as String?) ?? '';
    final colorIndex = (profile['avatarColorIndex'] as int?) ?? 0;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 110 + MediaQuery.paddingOf(context).bottom),
      children: [
        // ---- Profile ----
        const SectionHeader(title: 'PROFILE'),
        GlassCard(
          padding: const EdgeInsets.all(18),
          blur: 12,
          child: Row(
            children: [
              SparkAvatar(name: displayName, colorIndex: colorIndex, size: 50),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isEmpty ? 'You' : displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@$username',
                      style: const TextStyle(color: SparkColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- Permissions ----
        const SectionHeader(title: 'PERMISSIONS'),
        GlassCard(
          padding: const EdgeInsets.all(18),
          blur: 12,
          child: Column(
            children: [
              GlassRow(
                child: Row(
                  children: [
                    Icon(
                      _notifOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 19,
                      color: _notifOk ? SparkColors.emerald : SparkColors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _notifOk ? 'Notification permission granted' : 'Notification permission needed',
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    if (!_notifOk)
                      TextButton(
                        onPressed: () async {
                          await SparkNative.requestNotificationPermission();
                          await _refresh();
                        },
                        child: const Text('Allow'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassRow(
                child: Row(
                  children: [
                    Icon(
                      _batteryOk ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                      size: 19,
                      color: _batteryOk ? SparkColors.emerald : SparkColors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _batteryOk ? 'Battery optimization exempt' : 'Battery optimization may interrupt Spark',
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    if (!_batteryOk)
                      TextButton(
                        onPressed: () async {
                          await SparkNative.requestIgnoreBatteryOptimizations();
                          await _refresh();
                        },
                        child: const Text('Exempt'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassRow(
                child: Row(
                  children: [
                    Icon(
                      _usageOk ? Icons.apps_rounded : Icons.app_blocking_rounded,
                      size: 19,
                      color: _usageOk ? SparkColors.emerald : SparkColors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _usageOk ? 'Active app & idle detection active' : 'Usage access needed for app detection',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _usageOk
                                ? 'Friends see what app you\'re using or if you\'re idle'
                                : 'Allow Spark to detect your foreground app in real time',
                            style: const TextStyle(fontSize: 11.5, color: SparkColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!_usageOk)
                      TextButton(
                        onPressed: () async {
                          await SparkNative.requestUsagePermission();
                          await _refresh();
                        },
                        child: const Text('Allow'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- Privacy ----
        const SectionHeader(title: 'PRIVACY'),
        GlassCard(
          padding: const EdgeInsets.all(18),
          blur: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What Spark reads and shares',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              _bullet('Reads only screen on/off, unlock and shutdown events.'),
              _bullet('Never reads messages, photos, contacts or location.'),
              _bullet('Only friends you approved can see your status.'),
              _bullet('Turn your signal on or off anytime with a single tap.'),
              _bullet('Per-friend visibility: full, last-seen-only, or hidden.'),
              _bullet('Account deletion wipes your profile, presence and all connections.'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---- Account ----
        const SectionHeader(title: 'ACCOUNT'),
        GlassCard(
          padding: const EdgeInsets.all(18),
          blur: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: SparkColors.textPrimary,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  await SparkNative.stopSignaling();
                  await Db.firebaseAuth.signOut();
                },
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SparkColors.danger,
                  side: BorderSide(color: SparkColors.danger.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 19),
                label: const Text('Delete account', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Center(
          child: Text(
            'Spark 1.0 · your signal, your people',
            style: TextStyle(color: SparkColors.textFaint, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.fiber_manual_record, size: 5, color: SparkColors.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: SparkColors.textSecondary, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
