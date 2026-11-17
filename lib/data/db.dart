import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/presence.dart';

/// Firebase Realtime Database data access for Spark.
///
/// Top-level layout:
/// ```
/// usernames/{usernameLower}            -> uid
/// users/{uid}                          -> profile (username, displayName, ...)
/// users/{uid}/friends/{friendUid}      -> {since: ts}
/// users/{uid}/visibility/{friendUid}   -> "full" | "lastSeenOnly" | "hidden"
/// presence/{uid}                       -> {state, lastChanged, lastSeen, device}
/// friendRequests/{toUid}/{fromUid}     -> {from, ts, status, via, code?}
/// sentRequests/{fromUid}/{toUid}       -> ts
/// inviteCodes/{code}                   -> {uid, ts}
/// ```
abstract final class Db {
  static const String databaseUrl =
      'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com';

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );

  static DatabaseReference ref(String path) => _db.ref(path);

  static DatabaseReference userRef(String uid) => ref('users/$uid');
  static DatabaseReference presenceRef(String uid) => ref('presence/$uid');

  // ---------- Profile ----------

  static Stream<DatabaseEvent> profileStream(String uid) =>
      userRef(uid).onValue;

  static Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    required int avatarColorIndex,
  }) async {
    final now = ServerValue.timestamp;
    await _db.ref().update({
      'usernames/$username': uid,
      'users/$uid/username': username,
      'users/$uid/usernameLower': username, // usernames are stored lowercase
      'users/$uid/displayName': displayName,
      'users/$uid/avatarColorIndex': avatarColorIndex,
      'users/$uid/createdAt': now,
    });
  }

  static Future<void> updateDisplayName(String uid, String name) =>
      userRef(uid).update({'displayName': name});

  static Future<void> updateAvatarColor(String uid, int index) =>
      userRef(uid).update({'avatarColorIndex': index});

  // ---------- Username ----------

  static Future<bool> isUsernameTaken(String usernameLower) async {
    final snap = await ref('usernames/$usernameLower').get();
    return snap.exists;
  }

  /// Atomically claims [usernameLower] for [uid] using a transaction.
  static Future<bool> claimUsername(String usernameLower, String uid) async {
    final nameRef = ref('usernames/$usernameLower');
    var committed = false;
    await nameRef.runTransaction((current) {
      if (current == null) {
        committed = true;
        return Transaction.success(uid);
      }
      return Transaction.abort();
    });
    return committed;
  }

  static Future<void> releaseUsername(String usernameLower, String uid) async {
    final nameRef = ref('usernames/$usernameLower');
    final snap = await nameRef.get();
    if (snap.exists && snap.value == uid) {
      await nameRef.remove();
    }
  }

  static Future<String?> findUidByUsername(String usernameLower) async {
    final snap = await ref('usernames/$usernameLower').get();
    if (!snap.exists) return null;
    return snap.value as String?;
  }

  // ---------- Friends ----------

  static Stream<DatabaseEvent> friendsStream(String uid) =>
      userRef(uid).child('friends').onValue;

  static Map<String, dynamic> friendsFromSnapshot(Object? value) {
    if (value is! Map) return const {};
    return Map<String, dynamic>.from(value);
  }

  static Future<void> removeFriend(String uid, String friendUid) async {
    await _db.ref().update({
      'users/$uid/friends/$friendUid': null,
      'users/$friendUid/friends/$uid': null,
    });
  }

  // ---------- Visibility ----------

  static String localVisibilityKey(String friendUid) => 'spark_visibility_$friendUid';

  static Future<String?> getLocalVisibility(String friendUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(localVisibilityKey(friendUid));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLocalVisibility(String friendUid, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(localVisibilityKey(friendUid), value);
    } catch (_) {}
  }

  static Stream<DatabaseEvent> visibilityStream(String uid, String friendUid) =>
      userRef(uid).child('visibility/$friendUid').onValue;

  static Future<void> setVisibility(String uid, String friendUid, String value) async {
    await setLocalVisibility(friendUid, value);
    await userRef(uid).child('visibility/$friendUid').set(value);
  }

  static Future<void> setBlocked(String uid, String friendUid, bool blocked) async {
    final value = blocked ? 'blocked' : 'unblocked';
    await setVisibility(uid, friendUid, value);
  }

  // ---------- Favorites ----------

  static String localFavoriteKey(String friendUid) => 'spark_favorite_$friendUid';

  static Future<bool> isLocallyFavorited(String friendUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(localFavoriteKey(friendUid)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setLocalFavorite(String friendUid, bool isFav) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isFav) {
        await prefs.setBool(localFavoriteKey(friendUid), true);
      } else {
        await prefs.remove(localFavoriteKey(friendUid));
      }
    } catch (_) {}
  }

  static Stream<DatabaseEvent> favoritesStream(String uid) =>
      userRef(uid).child('favorites').onValue;

  static Future<void> setFavorite(String uid, String friendUid, bool isFav) async {
    await setLocalFavorite(friendUid, isFav);
    await userRef(uid).child('favorites/$friendUid').set(isFav ? true : null);
  }

  // ---------- Requests ----------

  static Stream<DatabaseEvent> incomingRequestsStream(String uid) =>
      ref('friendRequests/$uid').onValue;

  static Stream<DatabaseEvent> sentRequestsStream(String uid) =>
      ref('sentRequests/$uid').onValue;

  static Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
    required String via,
    String? code,
  }) async {
    assert(via == 'search' || (via == 'code' && code != null));
    final now = ServerValue.timestamp;
    await _db.ref().update({
      'friendRequests/$toUid/$fromUid': {
        'from': fromUid,
        'ts': now,
        'status': 'pending',
        'via': via,
        if (code != null) 'code': code,
      },
      'sentRequests/$fromUid/$toUid': now,
    });
  }

  static Future<void> cancelSentRequest({required String fromUid, required String toUid}) async {
    await _db.ref().update({
      'friendRequests/$toUid/$fromUid': null,
      'sentRequests/$fromUid/$toUid': null,
    });
  }

  static Future<void> acceptRequest({required String meUid, required String fromUid}) async {
    final now = ServerValue.timestamp;
    try {
      await _db.ref().update({
        'users/$meUid/friends/$fromUid': {'since': now},
        'users/$fromUid/friends/$meUid': {'since': now},
        'friendRequests/$meUid/$fromUid': null,
        'sentRequests/$fromUid/$meUid': null,
      });
    } catch (_) {
      // In case cross-user write is guarded by rule differences, write me-side first:
      await _db.ref('users/$meUid/friends/$fromUid').set({'since': now});
      await _db.ref('friendRequests/$meUid/$fromUid').remove();
    }
  }

  static Future<void> declineRequest({required String meUid, required String fromUid}) async {
    await _db.ref().update({
      'friendRequests/$meUid/$fromUid': null,
      'sentRequests/$fromUid/$meUid': null,
    });
  }

  // ---------- Invite codes ----------

  static const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static Future<String> ensureInviteCode(String uid) async {
    final list = await ref('inviteCodes').orderByChild('uid').equalTo(uid).get();
    if (list.exists && list.value is Map) {
      final map = Map<String, dynamic>.from(list.value as Map);
      return map.keys.first;
    }
    final code = _generateCode();
    await ref('inviteCodes/$code').set({'uid': uid, 'ts': ServerValue.timestamp});
    return code;
  }

  static String _generateCode() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    var x = rnd;
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
      buf.write(inviteAlphabet[x % inviteAlphabet.length]);
    }
    return buf.toString();
  }

  static Future<String?> resolveInviteCode(String code) async {
    final snap = await ref('inviteCodes/$code').get();
    if (!snap.exists) return null;
    final map = Map<String, dynamic>.from(snap.value as Map);
    return map['uid'] as String?;
  }

  // ---------- Presence ----------

  static Stream<DatabaseEvent> presenceStream(String uid) => presenceRef(uid).onValue;

  static PresenceData parsePresence(Object? value) => PresenceData.fromMap(value);

  /// Instantly writes presence state from the app.
  static Future<void> setPresenceState(String uid, String state) async {
    try {
      final map = <String, dynamic>{
        'state': state,
        'lastChanged': ServerValue.timestamp,
        'device': 'android',
      };
      if (state == 'active') {
        map['lastSeen'] = DateTime.now().millisecondsSinceEpoch;
      }
      await presenceRef(uid).update(map);
    } catch (_) {}
  }

  // ---------- Account deletion ----------

  /// Removes every Spark trace of [uid]. Returns the list of friend uids
  /// whose edges we cleaned (for UI progress messages).
  static Future<List<String>> wipeAccountData(String uid, String usernameLower) async {
    // Collect edges first.
    final friendsSnap = await userRef(uid).child('friends').get();
    final friends = friendsFromSnapshot(friendsSnap.value).keys.toList();

    final sentSnap = await ref('sentRequests/$uid').get();
    final sent = sentSnap.exists && sentSnap.value is Map
        ? Map<String, dynamic>.from(sentSnap.value as Map).keys.toList()
        : <String>[];

    final updates = <String, dynamic>{
      'usernames/$usernameLower': null,
      'users/$uid': null,
      'presence/$uid': null,
      'sentRequests/$uid': null,
      'friendRequests/$uid': null,
    };
    for (final f in friends) {
      updates['users/$f/friends/$uid'] = null;
    }
    for (final to in sent) {
      updates['friendRequests/$to/$uid'] = null;
    }
    await _db.ref().update(updates);
    return friends;
  }

  // ---------- Auth ----------

  static final firebaseAuth = auth.FirebaseAuth.instance;

  static Stream<auth.User?> authStream() => firebaseAuth.authStateChanges();

  static auth.User? get currentUser => firebaseAuth.currentUser;
}
