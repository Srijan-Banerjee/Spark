import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/widgets/controls.dart';
import '../core/widgets/glass.dart';
import '../data/db.dart';
import '../services/native_bridge.dart';
import '../state/providers.dart';

/// Full account deletion with re-authentication — Play Store policy compliant.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    final user = Db.currentUser;
    final profile = ref.read(profileProvider).valueOrNull ?? const <String, dynamic>{};
    final username = (profile['username'] as String?) ?? '';

    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm');
      return;
    }
    if (_confirmController.text.trim() != username) {
      setState(() => _error = 'Type your username "$username" exactly to confirm');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = user?.email;
      if (user == null || email == null) throw Exception('no user');

      // 1) Re-authenticate (Play Store requirement for account deletion).
      final cred = EmailAuthProvider.credential(email: email, password: _passwordController.text);
      await user.reauthenticateWithCredential(cred);

      // 2) Stop signaling so nothing re-writes presence after wipe.
      await SparkNative.stopSignaling();

      // 3) Wipe every database trace (profile, username, presence, edges, requests).
      final usernameLower = username.toLowerCase();
      await Db.wipeAccountData(user.uid, usernameLower);

      // 4) Delete the auth account itself.
      await user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your Spark account and data were deleted')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'wrong-password' || 'invalid-credential' => 'Incorrect password.',
          'too-many-requests' => 'Too many attempts — wait a moment.',
          _ => e.message ?? 'Deletion failed. Try again.',
        };
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Deletion failed — check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull ?? const <String, dynamic>{};
    final username = (profile['username'] as String?) ?? '';
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            blur: 12,
            borderColor: SparkColors.danger.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SparkColors.dangerDim,
                    border: Border.all(color: SparkColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: SparkColors.danger, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'This permanently deletes your Spark account. It cannot be undone.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'What gets deleted',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          _row('Your profile and unique username'),
          _row('Your activity signal and history'),
          _row('All ${friends.length} connections'),
          _row('Every pending friend request'),
          _row('The sign-in account itself'),
          const SizedBox(height: 26),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Your password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            decoration: InputDecoration(
              hintText: 'Type "$username" to confirm',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: SparkColors.dangerDim,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: SparkColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: SparkColors.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: SparkColors.danger, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SparkButton(
            label: 'Delete everything',
            danger: true,
            enabled: !_busy,
            onPressed: _busy ? null : _delete,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text(
              'Keep my account',
              style: TextStyle(color: SparkColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _row(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.close_rounded, size: 12, color: SparkColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: SparkColors.textSecondary, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
