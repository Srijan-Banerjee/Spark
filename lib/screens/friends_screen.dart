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
import 'add_friend_screen.dart';
import 'friend_detail_screen.dart';

/// Friends tab: search, favorites, approved friends, incoming & outgoing requests.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final friends = ref.watch(friendsProvider);
    final favorites = ref.watch(favoritesProvider);
    final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? const {};
    final sent = ref.watch(sentRequestsProvider).valueOrNull ?? const {};

    final isSearching = _searchQuery.isNotEmpty;

    // Collect friend profiles to enable instant name / username search
    final friendEntries = <(String, String, String)>[];
    for (final uid in friends) {
      final prof = ref.watch(friendProfileProvider(uid)).valueOrNull;
      final name = (prof?['displayName'] as String?) ?? '';
      final uname = (prof?['username'] as String?) ?? '';
      friendEntries.add((uid, name, uname));
    }

    // Filter by query
    final matching = isSearching
        ? friendEntries.where((e) {
            final q = _searchQuery.toLowerCase();
            return e.$2.toLowerCase().contains(q) || e.$3.toLowerCase().contains(q);
          }).toList()
        : friendEntries;

    // Sort: favorites always first, then alphabetical by displayName
    matching.sort((a, b) {
      final favA = favorites.contains(a.$1);
      final favB = favorites.contains(b.$1);
      if (favA != favB) return favA ? -1 : 1;
      return a.$2.toLowerCase().compareTo(b.$2.toLowerCase());
    });

    // Split matching list into favorites and others for crystal clear grouping
    final favList = <String>[];
    final otherList = <String>[];
    for (final e in matching) {
      if (favorites.contains(e.$1)) {
        favList.add(e.$1);
      } else {
        otherList.add(e.$1);
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 110 + MediaQuery.paddingOf(context).bottom),
      children: [
        // ---- Search bar ----
        _SearchBar(
          controller: _searchController,
          hasQuery: isSearching,
          onChanged: (val) {
            setState(() => _searchQuery = val.trim());
          },
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: 16),

        if (!isSearching && incoming.isNotEmpty) ...[
          const SectionHeader(title: 'FRIEND REQUESTS'),
          ...incoming.entries.map((e) => _IncomingRequestCard(
                fromUid: e.key,
                request: e.value,
                meUid: user!.uid,
              )),
          const SizedBox(height: 20),
        ],

        if (isSearching) ...[
          SectionHeader(title: 'SEARCH RESULTS (${matching.length})'),
          if (matching.isEmpty)
            EmptyState(
              icon: Icons.person_search_rounded,
              title: 'No friends match "$_searchQuery"',
              subtitle: 'Looking for someone new? Try searching all Spark users to connect.',
              actionLabel: 'Search all users',
              onAction: () => showAddFriendSheet(context, initialQuery: _searchQuery),
            )
          else ...[
            if (favList.isNotEmpty) ...[
              const SectionHeader(title: 'FAVORITES'),
              ...favList.map((uid) => _FriendListCard(uid: uid, isFavorite: true)),
              const SizedBox(height: 14),
            ],
            if (otherList.isNotEmpty) ...[
              if (favList.isNotEmpty) const SectionHeader(title: 'OTHER FRIENDS'),
              ...otherList.map((uid) => _FriendListCard(uid: uid, isFavorite: false)),
            ],
          ],
        ] else ...[
          if (friends.isEmpty)
            const EmptyState(
              icon: Icons.handshake_outlined,
              title: 'Your circle is empty',
              subtitle: 'Add friends by username search. '
                  'Every connection needs approval from both sides.',
            )
          else ...[
            if (favList.isNotEmpty) ...[
              const SectionHeader(title: 'FAVORITES'),
              ...favList.map((uid) => _FriendListCard(uid: uid, isFavorite: true)),
              const SizedBox(height: 14),
            ],
            SectionHeader(title: favList.isNotEmpty ? 'ALL FRIENDS' : 'MY PEOPLE'),
            ...otherList.map((uid) => _FriendListCard(uid: uid, isFavorite: false)),
          ],
        ],

        if (!isSearching && sent.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'PENDING INVITES'),
          ...sent.keys.map((toUid) => _SentRequestCard(fromUid: user!.uid, toUid: toUid)),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      radius: 18,
      blur: 14,
      borderColor: hasQuery
          ? SparkColors.amber.withValues(alpha: 0.5)
          : SparkColors.glassBorder,
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: hasQuery ? SparkColors.amber : SparkColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14.5),
              decoration: const InputDecoration(
                hintText: 'Search friends by name or @username...',
                hintStyle: TextStyle(color: SparkColors.textFaint, fontSize: 13.5),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (hasQuery)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: SparkColors.textSecondary),
              tooltip: 'Clear search',
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _IncomingRequestCard extends ConsumerWidget {
  const _IncomingRequestCard({
    required this.fromUid,
    required this.request,
    required this.meUid,
  });

  final String fromUid;
  final Map<String, dynamic> request;
  final String meUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(fromUid));
    final profile = profileAsync.valueOrNull;
    final name = (profile?['displayName'] as String?) ?? 'Spark user';
    final username = (profile?['username'] as String?) ?? '';
    final colorIndex = (profile?['avatarColorIndex'] as int?) ?? 0;
    final via = (request['via'] as String?) ?? 'search';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        blur: 12,
        child: Column(
          children: [
            Row(
              children: [
                SparkAvatar(name: name, colorIndex: colorIndex, size: 44),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        '@$username · wants to see your signal ($via)',
                        style: const TextStyle(color: SparkColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SparkColors.textSecondary,
                      side: const BorderSide(color: SparkColors.glassBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Db.declineRequest(meUid: meUid, fromUid: fromUid),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: SparkColors.amber,
                      foregroundColor: const Color(0xFF181200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      try {
                        await Db.acceptRequest(meUid: meUid, fromUid: fromUid);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentRequestCard extends ConsumerWidget {
  const _SentRequestCard({required this.fromUid, required this.toUid});
  final String fromUid;
  final String toUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(toUid));
    final profile = profileAsync.valueOrNull;
    final name = (profile?['displayName'] as String?) ?? '…';
    final username = (profile?['username'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassRow(
        child: Row(
          children: [
            SparkAvatar(name: name, colorIndex: (profile?['avatarColorIndex'] as int?) ?? 0, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      overflow: TextOverflow.ellipsis),
                  Text('@$username · waiting for approval',
                      style: const TextStyle(color: SparkColors.textFaint, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Db.cancelSentRequest(fromUid: fromUid, toUid: toUid),
              child: const Text('Cancel',
                  style: TextStyle(color: SparkColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendListCard extends ConsumerWidget {
  const _FriendListCard({required this.uid, this.isFavorite = false});
  final String uid;
  final bool isFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(friendProfileProvider(uid));
    final profile = profileAsync.valueOrNull ?? const <String, dynamic>{};
    final presence = ref.watch(presenceProvider(uid)).valueOrNull;
    final displayName = (profile['displayName'] as String?) ?? '…';
    final username = (profile['username'] as String?) ?? '';
    final vis = friendVisibilityForMe(profile, me?.uid);
    final isBlocked = vis == 'blocked';
    final effective = effectivePresenceForFriend(presence, vis);
    final d = displayFor(effective, isFriend: true, visibility: vis);

    final sub = isBlocked
        ? 'Blocked'
        : effective == null || effective.isEmpty
            ? 'Offline (Signal off)'
            : effective.state == PresenceState.active
                ? (effective.isIdle || effective.app == 'Idle'
                    ? 'Active now · Idle'
                    : (effective.app != null && effective.app!.isNotEmpty)
                        ? 'Active now · In ${effective.app}'
                        : 'Active now')
                : effective.state == PresenceState.screenOn
                    ? 'Lockscreen On'
                    : effective.state == PresenceState.inactive
                        ? 'Offline (Signal on) · ${relativeTime(effective.lastSeen)}'
                        : 'Offline (Signal off) · ${relativeTime(effective.lastSeen)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        blur: 12,
        borderColor: isFavorite
            ? SparkColors.amber.withValues(alpha: 0.35)
            : SparkColors.glassBorder,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FriendDetailScreen(friendUid: uid)),
            );
          },
          child: Row(
            children: [
              SparkAvatar(
                name: displayName,
                colorIndex: (profile['avatarColorIndex'] as int?) ?? 0,
                size: 46,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (isFavorite) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.star_rounded, size: 16, color: SparkColors.amber),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username${sub.isEmpty ? '' : ' · $sub'}',
                      style: TextStyle(
                        color: isBlocked ? SparkColors.danger : SparkColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: isBlocked ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isBlocked && effective?.state == PresenceState.active) ...[
                AppActivityTag(
                  app: effective?.app,
                  isIdle: effective?.isIdle ?? false,
                ),
                const SizedBox(width: 6),
              ],
              StatusChip(display: d, compact: true),
              const SizedBox(width: 4),
              IconButton(
                iconSize: 22,
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey(isFavorite),
                    color: isFavorite ? SparkColors.amber : SparkColors.textFaint,
                    size: 22,
                  ),
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final meUid = me?.uid;
                  if (meUid == null) return;
                  await Db.setFavorite(meUid, uid, !isFavorite);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the add-friend bottom sheet from anywhere in the shell.
void showAddFriendSheet(BuildContext context, {String? initialQuery}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddFriendSheet(initialQuery: initialQuery),
  );
}
