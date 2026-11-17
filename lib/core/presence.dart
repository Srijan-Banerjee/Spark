/// Canonical presence states written by the native Android signaling service.
enum PresenceState {
  /// Screen unlocked & device interactive — the user is using the phone.
  active('active'),

  /// Screen powered on but the keyguard is still locked.
  screenOn('screenOn'),

  /// Screen off — device is reachable but idle.
  inactive('inactive'),

  /// Connection dropped / service stopped / device offline.
  offline('offline'),

  /// The user paused broadcasting with Ghost Mode.
  ghost('ghost');

  const PresenceState(this.wire);
  final String wire;

  static PresenceState fromWire(String? wire) => PresenceState.values.firstWhere(
        (s) => s.wire == wire,
        orElse: () => PresenceState.offline,
      );
}

/// Parsed snapshot of /presence/{uid}.
class PresenceData {
  const PresenceData({
    required this.state,
    required this.updatedAt,
    required this.lastSeen,
    this.app,
    this.isIdle = false,
  });

  final PresenceState state;
  final int updatedAt; // server ms — last real state change
  final int lastSeen; // ms — last moment the user was reachable
  final String? app; // Currently open foreground app, e.g. "WhatsApp", "YouTube", "Idle"
  final bool isIdle; // true if resting on home screen or idle in state

  static PresenceData fromMap(Object? value) {
    final map = value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      return 0;
    }

    final appRaw = map['app'] as String?;
    final isIdleRaw = (map['isIdle'] as bool?) ?? false;

    return PresenceData(
      state: PresenceState.fromWire(map['state'] as String?),
      updatedAt: asInt(map['lastChanged']),
      lastSeen: asInt(map['lastSeen']),
      app: appRaw,
      isIdle: isIdleRaw || appRaw == 'Idle',
    );
  }

  bool get isEmpty => updatedAt == 0;
}

/// How "fresh" a live state is considered on the client.
const freshWindow = Duration(minutes: 3);

/// Human label + tone for a friend's presence.
class PresenceDisplay {
  const PresenceDisplay(
    this.label,
    this.color, {
    this.pulsing = false,
    this.app,
    this.isIdle = false,
  });
  final String label;
  final int color;
  final bool pulsing;
  final String? app;
  final bool isIdle;
}

/// Helper to extract what visibility setting a friend granted to `myUid`.
/// Returns 'blocked' if the friend blocked me, or 'unblocked' otherwise.
String friendVisibilityForMe(Map<String, dynamic>? friendProfile, String? myUid) {
  if (friendProfile == null || myUid == null) return 'unblocked';
  final visibilityMap = friendProfile['visibility'];
  if (visibilityMap is Map) {
    final v = visibilityMap[myUid];
    if (v is String) {
      if (v == 'blocked' || v == 'hidden') return 'blocked';
      return 'unblocked';
    }
  }
  return 'unblocked';
}

/// Applies visibility masking so friends only see what they were granted.
PresenceData? effectivePresenceForFriend(PresenceData? raw, String visibility) {
  if (raw == null || raw.isEmpty) return null;
  if (visibility == 'blocked' || visibility == 'hidden') {
    return null; // Blocked: friend is denied access to all activity
  }
  if (visibility == 'lastSeenOnly') {
    return PresenceData(
      state: raw.state == PresenceState.offline ? PresenceState.offline : PresenceState.inactive,
      updatedAt: raw.updatedAt,
      lastSeen: raw.lastSeen,
      app: null,
      isIdle: false,
    );
  }
  return raw;
}

PresenceDisplay displayFor(
  PresenceData? data, {
  required bool isFriend,
  String visibility = 'unblocked',
}) {
  if (!isFriend) {
    return const PresenceDisplay('Not connected', 0xFF64748B);
  }
  if (visibility == 'blocked' || visibility == 'hidden') {
    return const PresenceDisplay('Blocked', 0xFFEF4444);
  }
  if (data == null || data.isEmpty) {
    return const PresenceDisplay('Offline (Signal off)', 0xFF64748B);
  }
  final effective = visibility == 'lastSeenOnly'
      ? (data.state == PresenceState.offline
          ? PresenceState.offline
          : PresenceState.inactive)
      : data.state;

  switch (effective) {
    case PresenceState.active:
      final idle = data.isIdle || data.app == 'Idle';
      final appName = !idle && data.app != null && data.app!.trim().isNotEmpty
          ? data.app!.trim()
          : null;
      return PresenceDisplay(
        'Active Now',
        0xFF10B981,
        pulsing: true,
        app: appName,
        isIdle: idle,
      );
    case PresenceState.screenOn:
      return const PresenceDisplay('Lockscreen On', 0xFFFFB800);
    case PresenceState.inactive:
      return const PresenceDisplay('Offline (Signal on)', 0xFF38BDF8);
    case PresenceState.offline:
    case PresenceState.ghost:
      return const PresenceDisplay('Offline (Signal off)', 0xFF64748B);
  }
}
