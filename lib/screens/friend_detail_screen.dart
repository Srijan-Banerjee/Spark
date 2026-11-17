import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presence.dart';
import '../core/theme.dart';
import '../core/time.dart';
import '../core/widgets/controls.dart';
import '../core/widgets/glass.dart';
import '../data/db.dart';
import '../state/providers.dart';

/// Per-friend detail: live status hero + block/unblock visibility toggle + removal.
class FriendDetailScreen extends ConsumerStatefulWidget {
  const FriendDetailScreen({super.key, required this.friendUid});
  final String friendUid;

  @override
  ConsumerState<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  String? _selectedVisibility;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLocalVisibility();
  }

  Future<void> _loadLocalVisibility() async {
    final local = await Db.getLocalVisibility(widget.friendUid);
    if (local != null && mounted) {
      setState(() => _selectedVisibility = local);
    }
  }

  Future<void> _updateBlocked(String meUid, bool blocked, bool serverValue) async {
    final v = blocked ? 'blocked' : 'unblocked';
    if (_saving && _selectedVisibility == v) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedVisibility = v;
      _saving = true;
    });

    try {
      await Db.setBlocked(meUid, widget.friendUid, blocked);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  blocked ? Icons.block_rounded : Icons.check_circle_rounded,
                  color: blocked ? SparkColors.danger : SparkColors.emerald,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    blocked
                        ? 'Friend blocked. They cannot see your activity.'
                        : 'Friend unblocked. Full activity restored.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 1800),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedVisibility = serverValue ? 'blocked' : 'unblocked';
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update block status: $e'),
            backgroundColor: SparkColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(friendProfileProvider(widget.friendUid));
    final profile = profileAsync.valueOrNull ?? const <String, dynamic>{};
    final rawPresence = ref.watch(presenceProvider(widget.friendUid)).valueOrNull;
    final myProfile = ref.watch(profileProvider).valueOrNull ?? const <String, dynamic>{};

    final displayName = (profile['displayName'] as String?) ?? '…';
    final username = (profile['username'] as String?) ?? '';

    // What this friend allows me to see:
    final visFromFriend = friendVisibilityForMe(profile, me?.uid);
    final isBlockedByFriend = visFromFriend == 'blocked';
    final effectivePresence = effectivePresenceForFriend(rawPresence, visFromFriend);
    final d = displayFor(effectivePresence, isFriend: true, visibility: visFromFriend);

    // What I have set for this friend:
    final visibilityMap = myProfile['visibility'] is Map
        ? Map<String, dynamic>.from(myProfile['visibility'] as Map)
        : <String, dynamic>{};
    final serverVisibility = (visibilityMap[widget.friendUid] as String?) ?? 'unblocked';
    final currentVisibility = _selectedVisibility ?? serverVisibility;
    final isBlocked = currentVisibility == 'blocked' || currentVisibility == 'hidden';
    final serverBlocked = serverVisibility == 'blocked' || serverVisibility == 'hidden';
    final isFav = ref.watch(favoritesProvider).contains(widget.friendUid);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey(isFav),
                color: isFav ? SparkColors.amber : SparkColors.textSecondary,
                size: 24,
              ),
            ),
            onPressed: () async {
              final meUid = me?.uid;
              if (meUid == null) return;
              HapticFeedback.lightImpact();
              final next = !isFav;
              await Db.setFavorite(meUid, widget.friendUid, next);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          next ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: SparkColors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          next ? '$displayName added to favorites' : '$displayName removed from favorites',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 1500),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 6, 20, 36 + MediaQuery.paddingOf(context).bottom),
          children: [
            // ---- Hero status ----
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SparkAvatar(
                    name: displayName,
                    colorIndex: (profile['avatarColorIndex'] as int?) ?? 0,
                    size: 78,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: const TextStyle(color: SparkColors.textSecondary, fontSize: 13.5),
                  ),
                  const SizedBox(height: 18),
                  StatusChip(display: d),
                  if (!isBlockedByFriend && effectivePresence?.state == PresenceState.active) ...[
                    const SizedBox(height: 12),
                    AppActivityTag(
                      app: effectivePresence?.app,
                      isIdle: effectivePresence?.isIdle ?? false,
                      compact: false,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _subline(effectivePresence, isBlocked: isBlockedByFriend),
                    style: TextStyle(
                      color: isBlockedByFriend ? SparkColors.danger : SparkColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isBlockedByFriend ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ---- Block / Unblock Toggle ----
            const SectionHeader(title: 'WHAT THEY SEE'),
            GlassCard(
              padding: const EdgeInsets.all(18),
              blur: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your visibility for this friend',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Block or unblock access to your live activity.',
                              style: TextStyle(color: SparkColors.textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      if (_saving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BlockUnblockToggle(
                    isBlocked: isBlocked,
                    onChanged: (blocked) {
                      final meUid = me?.uid;
                      if (meUid == null) return;
                      _updateBlocked(meUid, blocked, serverBlocked);
                    },
                  ),
                  const SizedBox(height: 14),
                  GlassRow(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isBlocked ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                          size: 17,
                          color: isBlocked ? SparkColors.danger : SparkColors.emerald,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isBlocked
                                ? 'Blocked — this user cannot see your activity and will see that they are blocked.'
                                : 'Unblocked — this friend can view your activity signal normally.',
                            style: TextStyle(
                              color: isBlocked
                                  ? SparkColors.danger
                                  : SparkColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ---- Danger zone ----
            const SectionHeader(title: 'MANAGE'),
            GlassCard(
              padding: const EdgeInsets.all(18),
              blur: 12,
              borderColor: SparkColors.danger.withValues(alpha: 0.25),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SparkColors.dangerDim,
                          border: Border.all(color: SparkColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.person_remove_rounded,
                            color: SparkColors.danger, size: 19),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Disconnect',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              'Removes the connection on both sides.',
                              style: TextStyle(color: SparkColors.textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SparkButton(
                    label: 'Remove friend',
                    danger: true,
                    expanded: true,
                    onPressed: () => _confirmRemove(context, ref, displayName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subline(PresenceData? p, {bool isBlocked = false}) {
    if (isBlocked) return 'You are blocked by this user';
    if (p == null || p.isEmpty) return 'No signal received yet';
    return switch (p.state) {
      PresenceState.active => p.isIdle || p.app == 'Idle'
          ? 'Device unlocked · Idle'
          : (p.app != null && p.app!.isNotEmpty)
              ? 'Device unlocked · Using ${p.app}'
              : 'Device unlocked and in use',
      PresenceState.screenOn => 'Lockscreen On · Screen lit, locked',
      PresenceState.inactive => 'Offline (Signal on) · Last seen ${relativeTime(p.lastSeen)}',
      PresenceState.offline => 'Offline (Signal off) · Last seen ${relativeTime(p.lastSeen)}',
      PresenceState.ghost => 'Offline (Signal off) · Last seen ${relativeTime(p.lastSeen)}',
    };
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, String name) async {
    final me = ref.read(currentUserProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
          'You will both disappear from each other\'s lists immediately. '
          'You can always reconnect later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: SparkColors.danger),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && me != null && context.mounted) {
      await Db.removeFriend(me.uid, widget.friendUid);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _BlockUnblockToggle extends StatelessWidget {
  const _BlockUnblockToggle({
    required this.isBlocked,
    required this.onChanged,
  });

  final bool isBlocked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SparkColors.bgElevated.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SparkColors.glassBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Smooth sliding background highlight pill
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: isBlocked ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: halfWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? SparkColors.danger.withValues(alpha: 0.22)
                        : SparkColors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBlocked
                          ? SparkColors.danger.withValues(alpha: 0.75)
                          : SparkColors.amber.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isBlocked ? SparkColors.danger : SparkColors.amber)
                            .withValues(alpha: 0.18),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // Segment touch targets & labels
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onChanged(false),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_open_rounded,
                                size: 18,
                                color: !isBlocked
                                    ? SparkColors.amber
                                    : SparkColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Unblocked',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      !isBlocked ? FontWeight.w700 : FontWeight.w500,
                                  color: !isBlocked
                                      ? SparkColors.amber
                                      : SparkColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onChanged(true),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 18,
                                color: isBlocked
                                    ? SparkColors.danger
                                    : SparkColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Blocked',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      isBlocked ? FontWeight.w700 : FontWeight.w500,
                                  color: isBlocked
                                      ? SparkColors.danger
                                      : SparkColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
