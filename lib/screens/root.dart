import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/logo.dart';
import '../main.dart' show kFirebaseInitError, kFirebaseInitFailed;
import '../state/providers.dart';
import 'auth_screen.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';
import 'setup_screen.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  bool _retrying = false;
  String? _retryError;

  @override
  Widget build(BuildContext context) {
    if (kFirebaseInitFailed) {
      return _FirebaseMissingScreen(
        message: kFirebaseInitError,
        retrying: _retrying,
        retryError: _retryError,
        onRetry: _retryFirebase,
      );
    }

    final authAsync = ref.watch(authUserProvider);

    return authAsync.when(
      loading: () => const _Splash(),
      error: (e, _) => const _Splash(),
      data: (User? user) {
        if (user == null) return const _UnauthenticatedFlow();
        return const AuthenticatedFlow();
      },
    );
  }

  Future<void> _retryFirebase() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      await Firebase.initializeApp();
      kFirebaseInitFailed = false;
      kFirebaseInitError = null;
    } catch (e) {
      _retryError = e.toString();
    }
    if (mounted) setState(() => _retrying = false);
  }
}

/// Shown when Firebase could not initialize (e.g. Google Play services
/// missing or the APK's Firebase config is invalid).
class _FirebaseMissingScreen extends StatelessWidget {
  const _FirebaseMissingScreen({
    required this.message,
    required this.retrying,
    required this.retryError,
    required this.onRetry,
  });

  final String? message;
  final bool retrying;
  final String? retryError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SparkLogo(size: 64),
                const SizedBox(height: 24),
                const Text(
                  "Couldn't reach Spark's backend",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF2F6FA),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Make sure Google Play services are installed and up to '
                  'date, then try again. If this keeps happening, reinstall '
                  'the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8A94A6), fontSize: 14, height: 1.4),
                ),
                if (retryError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x33FF5252),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      retryError!,
                      style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: retrying ? null : onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB800),
                      foregroundColor: const Color(0xFF0A0E14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: retrying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF0A0E14),
                            ),
                          )
                        : const Text(
                            'Try again',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Splash shown while Firebase auth state resolves.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SparkLogo(size: 64),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFFFFB800), strokeWidth: 2.4),
          ],
        ),
      ),
    );
  }
}

/// Onboarding -> Auth, driven by a local "seen onboarding" flag.
class _UnauthenticatedFlow extends StatefulWidget {
  const _UnauthenticatedFlow();

  @override
  State<_UnauthenticatedFlow> createState() => _UnauthenticatedFlowState();
}

class _UnauthenticatedFlowState extends State<_UnauthenticatedFlow> {
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _seenOnboarding = p.getBool('spark_onboarding_done') ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seenOnboarding == null) return const _Splash();
    if (_seenOnboarding!) {
      return const AuthScreen();
    }
    return OnboardingScreen(
      onFinished: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool('spark_onboarding_done', true);
        if (!mounted) return;
        setState(() => _seenOnboarding = true);
      },
    );
  }
}

/// Ensures a profile exists, then shows the app shell.
class AuthenticatedFlow extends ConsumerWidget {
  const AuthenticatedFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const _Splash(),
      error: (e, _) => const _Splash(),
      data: (profile) {
        final hasUsername = (profile['username'] as String?)?.isNotEmpty ?? false;
        if (!hasUsername) return const ProfileSetupScreen();
        return const HomeShell();
      },
    );
  }
}
