import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/widgets/controls.dart';
import '../core/widgets/glass.dart';
import '../data/db.dart';
import '../state/providers.dart';

/// Add friend: username search.
class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  bool _busy = false;
  String? _message;
  int _messageTone = 0; // 0 neutral, 1 error, 2 success
  Map<String, dynamic>? _foundProfile;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.trim().length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _busy = false;
      _message = null;
      _foundProfile = null;
    });
  }

  void _setMessage(String? m, int tone) {
    setState(() {
      _message = m;
      _messageTone = tone;
    });
  }

  String _sanitize(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      if (RegExp(r'[a-z0-9_]').hasMatch(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  Future<void> _search() async {
    if (_busy) return;
    final me = Db.currentUser;
    if (me == null) return;
    final username = _sanitize(_searchController.text);
    if (username.length < 3) {
      _setMessage('Enter at least 3 characters', 1);
      return;
    }
    setState(() => _busy = true);
    try {
      final uid = await Db.findUidByUsername(username);
      if (uid == null) {
        _setMessage('No Spark user named "$username"', 1);
        setState(() => _foundProfile = null);
      } else if (uid == me.uid) {
        _setMessage('That\'s you 🙂', 0);
        setState(() => _foundProfile = null);
      } else {
        final snap = await Db.userRef(uid).get();
        if (snap.exists) {
          setState(() {
            _foundProfile = {
              ...Map<String, dynamic>.from(snap.value as Map),
              '__uid': uid,
            };
          });
          _setMessage(null, 0);
        } else {
          _setMessage('Profile not found', 1);
          setState(() => _foundProfile = null);
        }
      }
    } catch (_) {
      _setMessage('Search failed — check your connection', 1);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendRequest(String toUid) async {
    if (_busy) return;
    final me = Db.currentUser;
    if (me == null || toUid.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Db.sendFriendRequest(fromUid: me.uid, toUid: toUid, via: 'search');
      if (mounted) {
        setState(() {
          _foundProfile = null;
          _busy = false;
        });
        _setMessage('Request sent — they\'ll approve it shortly', 2);
      }
    } catch (_) {
      _setMessage('Could not send request', 1);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptRequest(String fromUid) async {
    if (_busy) return;
    final me = Db.currentUser;
    if (me == null || fromUid.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Db.acceptRequest(meUid: me.uid, fromUid: fromUid);
      if (mounted) {
        setState(() {
          _foundProfile = null;
          _busy = false;
        });
        _setMessage('Friend request accepted!', 2);
      }
    } catch (_) {
      _setMessage('Failed to accept request', 1);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? const {};
    final sent = ref.watch(sentRequestsProvider).valueOrNull ?? const {};

    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + MediaQuery.paddingOf(context).bottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add a friend',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Both of you must approve before signals are visible.',
              style: TextStyle(color: SparkColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _search(),
              onChanged: (_) {
                if (_message != null || _foundProfile != null) {
                  _reset();
                }
              },
              decoration: InputDecoration(
                hintText: 'Search by username (e.g. alex)',
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _reset();
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SparkButton(
              label: 'Find user',
              icon: Icons.search_rounded,
              onPressed: _search,
              enabled: !_busy,
            ),
            if (_foundProfile != null) ...[
              const SizedBox(height: 16),
              _buildFoundCard(
                uid: _foundProfile!['__uid'] as String,
                name: (_foundProfile!['displayName'] as String?) ?? 'Spark user',
                username: (_foundProfile!['username'] as String?) ?? '',
                colorIndex: (_foundProfile!['avatarColorIndex'] as int?) ?? 0,
                isFriend: friends.contains(_foundProfile!['__uid']),
                isIncoming: incoming.containsKey(_foundProfile!['__uid']),
                isSent: sent.containsKey(_foundProfile!['__uid']),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 14),
              _MessageBanner(text: _message!, tone: _messageTone),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFoundCard({
    required String uid,
    required String name,
    required String username,
    required int colorIndex,
    required bool isFriend,
    required bool isIncoming,
    required bool isSent,
  }) {
    return GlassRow(
      child: Row(
        children: [
          SparkAvatar(
            name: name,
            colorIndex: colorIndex,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@$username',
                  style: const TextStyle(color: SparkColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SparkColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SparkColors.emerald.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Friends',
                style: TextStyle(
                  color: SparkColors.emerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (isIncoming)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SparkColors.emerald,
                foregroundColor: const Color(0xFF03130D),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _acceptRequest(uid),
              child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            )
          else if (isSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SparkColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SparkColors.amber.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  color: SparkColors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SparkColors.amber,
                foregroundColor: const Color(0xFF181200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _sendRequest(uid),
              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.text, required this.tone});
  final String text;
  final int tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      1 => SparkColors.danger,
      2 => SparkColors.emerald,
      _ => SparkColors.textSecondary,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            tone == 2 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
