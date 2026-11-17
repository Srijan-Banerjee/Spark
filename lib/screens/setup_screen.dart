import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/widgets/logo.dart';
import '../data/db.dart';

/// First-run profile: unique username, display name, avatar color.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  int _colorIndex = 0;
  bool _busy = false;
  bool _checking = false;
  String? _usernameError;
  String? _lastChecked;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _sanitize(String raw) {
    final lower = raw.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      if (RegExp(r'[a-z0-9_]').hasMatch(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  void _onUsernameChanged(String value) {
    final clean = _sanitize(value);
    if (clean != value) {
      final curOffset = _usernameController.selection.baseOffset;
      _usernameController.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: curOffset.clamp(0, clean.length)),
      );
    }
    setState(() {
      _usernameError = null;
      _lastChecked = null;
      _checking = clean.length >= 3;
    });
    _debounceCheck(clean);
  }

  Timer? _timer;
  void _debounceCheck(String clean) {
    _timer?.cancel();
    if (clean.length < 3) return;
    _timer = Timer(const Duration(milliseconds: 550), () async {
      final taken = await Db.isUsernameTaken(clean);
      if (!mounted || _sanitize(_usernameController.text) != clean) return;
      setState(() {
        _checking = false;
        _lastChecked = clean;
        _usernameError = taken ? '"$clean" is already taken' : null;
      });
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final user = Db.currentUser;
    if (user == null) return;

    final username = _sanitize(_usernameController.text);
    final display = _nameController.text.trim();

    if (!_formKey.currentState!.validate() || username.length < 3) {
      setState(() => _usernameError = 'Usernames need 3+ letters, numbers or _');
      return;
    }
    if (display.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a display name so friends recognize you')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await Db.claimUsername(username, user.uid);
      if (!ok) {
        setState(() {
          _busy = false;
          _usernameError = '"$username" was just taken — try another';
        });
        return;
      }
      await Db.createProfile(
        uid: user.uid,
        username: username,
        displayName: display,
        avatarColorIndex: _colorIndex,
      );
      // RootScreen picks up the profile stream and opens the app shell.
    } catch (e) {
      setState(() {
        _busy = false;
        _usernameError = 'Could not save profile — check your connection';
      });
      // Release a partial claim if profile write failed.
      try {
        await Db.releaseUsername(username, user.uid);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: SparkLogo(size: 64)),
                    const SizedBox(height: 22),
                    const Text(
                      'Set up your signal',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Friends find you by username. Pick something you\'re happy to share.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SparkColors.textSecondary, fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a display name' : null,
                      decoration: const InputDecoration(
                        hintText: 'Display name',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameController,
                      onChanged: _onUsernameChanged,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      validator: (v) {
                        final s = _sanitize(v ?? '');
                        if (s.length < 3) return '3–20 letters, numbers or _';
                        return _usernameError;
                      },
                      decoration: InputDecoration(
                        hintText: 'username (e.g. alex_99)',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                        suffixIcon: _usernameSuffix,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Avatar color',
                      style: TextStyle(
                        color: SparkColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(SparkColors.avatarGradients.length, (i) {
                        final selected = i == _colorIndex;
                        final grad = SparkColors.avatarGradients[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _colorIndex = i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: grad,
                              ),
                              border: Border.all(
                                color: selected ? Colors.white : Colors.transparent,
                                width: 2.4,
                              ),
                              boxShadow: selected
                                  ? [BoxShadow(color: grad.first.withValues(alpha: 0.5), blurRadius: 16)]
                                  : const [],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: SparkColors.amber,
                          foregroundColor: const Color(0xFF181200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4))
                            : const Text('Start broadcasting'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? get _usernameSuffix {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.only(right: 14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }
    if (_lastChecked == null) return null;
    final ok = _usernameError == null;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Icon(
        ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: ok ? SparkColors.emerald : SparkColors.danger,
        size: 20,
      ),
    );
  }
}
