import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presence.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../core/widgets/controls.dart';
import '../core/widgets/dots.dart';
import '../core/widgets/glass.dart';
import '../services/native_bridge.dart';
import '../state/providers.dart';
import 'friend_detail_screen.dart';
import 'friends_screen.dart' show showAddFriendSheet;

/// Home dashboard: your live signal toggle and friends' real-time activity.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh relative times (e.g. "Just now", "2m ago") live every 25 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(signalingProvider.notifier).refresh();
    }
  }

  Future<void> _setSignaling(bool value) async {
    final user = ref.read(currentUserProvider);
    ref.read(signalingProvider.notifier).setSignaling(value, user?.uid);

    if (value) {
      final notifOk = await SparkNative.hasNotificationPermission();
      if (!notifOk) {
        final granted = await SparkNative.requestNotificationPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Allow notifications so Spark can keep your signal broadcasting'),
            duration: Duration(seconds: 3),
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull ?? const <String, dynamic>{};
    final friends = ref.watch(friendsProvider);
    final requests = ref.watch(incomingRequestsProvider).valueOrNull ?? const {};
    final ownPresence = ref.watch(ownPresenceProvider).valueOrNull;
    final signalingActive = ref.watch(signalingProvider);

    final displayName = (profile['displayName'] as String?) ?? '';
    final username = (profile['username'] as String?) ?? '';
    final colorIndex = (profile['avatarColorIndex'] as int?) ?? 0;

    return RefreshIndicator(
      color: SparkColors.amber,
      onRefresh: () async {
        await ref.read(signalingProvider.notifier).refresh();
        ref.invalidate(ownPresenceProvider);
        ref.invalidate(profileProvider);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(
              wide ? 28 : 18, 8, wide ? 28 : 18, 110 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              // ----- Your signal card -----
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SparkAvatar(name: displayName, colorIndex: colorIndex, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isEmpty ? 'You' : displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  color: SparkColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        requests.isNotEmpty
                            ? _RequestsBadge(count: requests.length)
                            : const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _OwnStatusRow(
                      presence: ownPresence,
                      signalingActive: signalingActive,
                    ),
                    const SizedBox(height: 16),
                    GlassRow(
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: signalingActive
                                  ? SparkColors.emerald.withValues(alpha: 0.16)
                                  : SparkColors.textFaint.withValues(alpha: 0.12),
                              border: Border.all(
                                color: signalingActive
                                    ? SparkColors.emerald.withValues(alpha: 0.5)
                                    : SparkColors.glassBorder,
                              ),
                            ),
                            child: Icon(
                              signalingActive
                                  ? Icons.sensors_rounded
                                  : Icons.sensors_off_rounded,
                              color: signalingActive
                                  ? SparkColors.emerald
                                  : SparkColors.textFaint,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Signal Broadcasting',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  signalingActive
                                      ? 'Broadcasting 24/7 · Friends see your live status'
                                      : 'Broadcasting off · You appear offline',
                                  style: const TextStyle(
                                    color: SparkColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SignalSwitch(
                            value: signalingActive,
                            onChanged: _setSignaling,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ----- Friends' live activity -----
              SectionHeader(
                title: 'LIVE NOW',
                action: TextButton.icon(
                  onPressed: () => showAddFriendSheet(context),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 17),
                  label: const Text('Add friend'),
                  style: TextButton.styleFrom(
                    foregroundColor: SparkColors.amber,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              if (friends.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No friends yet',
                  subtitle: 'Search their username to connect. '
                      'Once they accept, their live activity appears here.',
                )
              else
                _FriendsActivityGrid(friends: friends, wide: wide),
            ],
          );
        },
      ),
    );
  }
}

class _RequestsBadge extends StatelessWidget {
  const _RequestsBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SparkColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SparkColors.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active_rounded, size: 15, color: SparkColors.amber),
          const SizedBox(width: 6),
          Text(
            '$count pending',
            style: const TextStyle(
              color: SparkColors.amber,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnStatusRow extends StatelessWidget {
  const _OwnStatusRow({
    required this.presence,
    required this.signalingActive,
  });

  final PresenceData? presence;
  final bool signalingActive;

  @override
  Widget build(BuildContext context) {
    String label;
    String sub;
    int color;
    bool pulse;

    if (!signalingActive) {
      label = 'Offline (Signal off)';
      sub = 'Broadcasting disabled · Turn on below';
      color = SparkColors.textFaint.toARGB32();
      pulse = false;
    } else {
      final d = displayFor(presence, isFriend: true);
      label = d.label;
      final idle = presence?.isIdle == true || presence?.app == 'Idle';
      final hasApp = !idle && presence?.app != null && presence!.app!.trim().isNotEmpty;
      sub = presence?.state == PresenceState.active
          ? (idle
              ? 'Live · Idle'
              : hasApp
                  ? 'Live · Using ${presence!.app}'
                  : 'Live · Screen unlocked and in use')
          : presence?.state == PresenceState.screenOn
              ? 'Live · Lockscreen On'
              : 'Live · Screen off · Signal is on';
      color = d.color;
      pulse = d.pulsing;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(color).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(color).withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          AnimatedStatusDot(color: Color(color), pulsing: pulse, size: 11),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: TextStyle(
                      color: Color(color),
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(color: SparkColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsActivityGrid extends ConsumerWidget {
  const _FriendsActivityGrid({required this.friends, required this.wide});
  final List<String> friends;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final favorites = ref.watch(favoritesProvider);
    // Sort: favorites first, active first, then by lastSeen desc, blocked last.
    final entries = <(String, PresenceData?, String)>[];
    for (final uid in friends) {
      final p = ref.watch(presenceProvider(uid)).valueOrNull;
      final prof = ref.watch(friendProfileProvider(uid)).valueOrNull;
      final vis = friendVisibilityForMe(prof, me?.uid);
      final effective = effectivePresenceForFriend(p, vis);
      entries.add((uid, effective, vis));
    }
    entries.sort((a, b) {
      final da = a.$2, db = b.$2;
      final visa = a.$3, visb = b.$3;
      if (visa == 'blocked' && visb != 'blocked') return 1;
      if (visa != 'blocked' && visb == 'blocked') return -1;

      final favA = favorites.contains(a.$1);
      final favB = favorites.contains(b.$1);
      if (favA != favB) return favA ? -1 : 1;

      int rank(PresenceData? d) {
        if (d == null || d.isEmpty) return 5;
        return switch (d.state) {
          PresenceState.active => 0,
          PresenceState.screenOn => 1,
          PresenceState.ghost => 2,
          PresenceState.inactive => 3,
          PresenceState.offline => 4,
        };
      }

      final r = rank(da).compareTo(rank(db));
      if (r != 0) return r;
      return (db?.lastSeen ?? 0).compareTo(da?.lastSeen ?? 0);
    });

    final cards = entries
        .map((e) => _FriendActivityCard(uid: e.$1, presence: e.$2, visibility: e.$3))
        .toList();

    if (wide) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: cards,
      );
    }
    return Column(children: List.generate(cards.length, (i) {
      return Padding(
        padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 12),
        child: cards[i],
      );
    }));
  }
}

class _FriendActivityCard extends ConsumerWidget {
  const _FriendActivityCard({
    required this.uid,
    required this.presence,
    required this.visibility,
  });
  final String uid;
  final PresenceData? presence;
  final String visibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(uid));
    final profile = profileAsync.valueOrNull ?? const <String, dynamic>{};
    final displayName = (profile['displayName'] as String?) ?? '…';
    final colorIndex = (profile['avatarColorIndex'] as int?) ?? 0;
    final isBlocked = visibility == 'blocked';
    final isFav = ref.watch(favoritesProvider).contains(uid);
    final d = displayFor(presence, isFriend: true, visibility: visibility);

    final isOffline = !isBlocked &&
        (presence == null ||
            presence!.state == PresenceState.inactive ||
            presence!.state == PresenceState.offline ||
            presence!.state == PresenceState.ghost);
    final lastSeenStr = isOffline && presence != null && presence!.lastSeen > 0
        ? relativeTime(presence!.lastSeen)
        : null;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      blur: 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FriendDetailScreen(friendUid: uid)),
          );
        },
        child: Row(
          children: [
            SparkAvatar(name: displayName, colorIndex: colorIndex, size: 44),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFav) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.star_rounded, size: 16, color: SparkColors.amber),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      StatusChip(display: d, compact: true),
                      if (!isBlocked && presence?.state == PresenceState.active) ...[
                        const SizedBox(width: 6),
                        AppActivityTag(
                          app: presence?.app,
                          isIdle: presence?.isIdle ?? false,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (lastSeenStr != null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.chevron_right_rounded, color: SparkColors.textFaint, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    lastSeenStr,
                    style: const TextStyle(
                      color: SparkColors.textFaint,
                      fontSize: 11,
                    ),
                  ),
                ],
              )
            else
              const Icon(Icons.chevron_right_rounded, color: SparkColors.textFaint, size: 20),
          ],
        ),
      ),
    );
  }
}
