import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presence.dart';
import '../data/db.dart';
import '../services/native_bridge.dart';

/// Signed-in Firebase user, or null.
final authUserProvider = StreamProvider<auth.User?>((ref) => Db.authStream());

/// Raw Firebase auth user (non-null inside authenticated screens).
final currentUserProvider = Provider<auth.User?>((ref) {
  return ref.watch(authUserProvider).valueOrNull ?? Db.currentUser;
});

/// This user's profile snapshot (/users/{uid}).
final profileProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return Db.profileStream(user.uid).map(
    (e) => e.snapshot.value is Map
        ? Map<String, dynamic>.from(e.snapshot.value as Map)
        : <String, dynamic>{},
  );
});

/// Approved friend uids.
final friendsProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull ?? const {};
  final friends = Db.friendsFromSnapshot(profile['friends']);
  return friends.keys.toList();
});

/// Set of friend UIDs that this user has favorited.
final favoritesProvider = Provider<Set<String>>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull ?? const {};
  final favs = profile['favorites'];
  if (favs is Map) {
    return favs.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toSet();
  }
  return const {};
});

/// Presence for a single friend.
final presenceProvider = StreamProvider.family<PresenceData?, String>((ref, uid) {
  return Db.presenceStream(uid).map(
    (e) => e.snapshot.exists ? Db.parsePresence(e.snapshot.value) : null,
  );
});

/// Own live presence (mirrors what friends would see).
final ownPresenceProvider = StreamProvider<PresenceData?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return Db.presenceStream(user.uid).map(
    (e) => e.snapshot.exists ? Db.parsePresence(e.snapshot.value) : null,
  );
});

/// Incoming friend requests: uid -> request map.
final incomingRequestsProvider = StreamProvider<Map<String, Map<String, dynamic>>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return Db.incomingRequestsStream(user.uid).map((e) {
    if (e.snapshot.value is! Map) return const {};
    final raw = Map<String, dynamic>.from(e.snapshot.value as Map);
    return raw.map((k, v) => MapEntry(k, v is Map ? Map<String, dynamic>.from(v) : {}));
  });
});

/// Outgoing friend requests: uid -> ts.
final sentRequestsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return Db.sentRequestsStream(user.uid).map((e) {
    if (e.snapshot.value is! Map) return const {};
    return Map<String, dynamic>.from(e.snapshot.value as Map);
  });
});

/// Cached friend profile lookup (username, displayName, color).
final friendProfileProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return Db.profileStream(uid).map(
    (e) => e.snapshot.exists ? Map<String, dynamic>.from(e.snapshot.value as Map) : null,
  );
});

/// Real-time broadcast signaling state notifier.
/// Keeps frontend toggle synchronized across screens with zero latency.
class SignalingNotifier extends StateNotifier<bool> {
  SignalingNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    try {
      final active = await SparkNative.isSignalingActive();
      state = active;
    } catch (_) {}
  }

  Future<void> setSignaling(bool active, String? uid) async {
    if (state == active) return;
    // Immediate optimistic update for instant real-time UI feedback
    state = active;

    try {
      if (active) {
        if (uid != null) {
          unawaited(Db.setPresenceState(uid, 'active'));
        }
        await SparkNative.startSignaling();
      } else {
        if (uid != null) {
          unawaited(Db.setPresenceState(uid, 'offline'));
        }
        await SparkNative.stopSignaling();
      }
    } catch (_) {
      try {
        state = await SparkNative.isSignalingActive();
      } catch (_) {}
    }
  }

  Future<void> refresh() async {
    try {
      final active = await SparkNative.isSignalingActive();
      state = active;
    } catch (_) {}
  }
}

final signalingProvider = StateNotifierProvider<SignalingNotifier, bool>((ref) {
  return SignalingNotifier();
});
