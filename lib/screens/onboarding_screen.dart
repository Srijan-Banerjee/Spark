import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../core/widgets/logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      icon: Icons.bolt_rounded,
      accent: SparkColors.amber,
      title: 'See who\'s active',
      body: 'Spark shares one simple signal with the people you approve: '
          'whether your phone is unlocked and in use right now — or resting.',
      bullets: ['Live activity status', 'Works around the clock', 'Zero messages or files'],
    ),
    _OnboardingPage(
      icon: Icons.phone_android_rounded,
      accent: SparkColors.emerald,
      title: 'One tiny permission',
      body: 'Android requires Spark to run a background service to observe screen '
          'on/off and unlock events. That is all it reads — nothing else.',
      bullets: [
        'Reads screen state only — never your messages, photos or location',
        'A persistent notification keeps the signal alive',
        'Allow "ignore battery optimization" when Android asks, so Spark never sleeps',
      ],
    ),
    _OnboardingPage(
      icon: Icons.shield_rounded,
      accent: SparkColors.emerald,
      title: 'Consent first, always',
      body: 'Only friends you approve can see your signal. You can turn it on '
          'or off anytime with one tap, and you can delete everything whenever you want.',
      bullets: [
        'Mutual approval required',
        'Turn signaling on or off anytime',
        'Full account deletion built in',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onFinished();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final contentWidth = width < 560 ? width : 560.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SparkLogo(size: 34),
                const SizedBox(width: 10),
                Text(
                  'Spark',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.accent.withValues(alpha: 0.10),
                            border: Border.all(color: p.accent.withValues(alpha: 0.35), width: 1.4),
                            boxShadow: [
                              BoxShadow(color: p.accent.withValues(alpha: 0.25), blurRadius: 40),
                            ],
                          ),
                          child: Icon(p.icon, color: p.accent, size: 44),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentWidth - 56),
                          child: Text(
                            p.body,
                            style: const TextStyle(
                              color: SparkColors.textSecondary,
                              fontSize: 15,
                              height: 1.55,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...p.bullets.map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 17, color: p.accent.withValues(alpha: 0.9)),
                                const SizedBox(width: 9),
                                Flexible(
                                  child: Text(
                                    b,
                                    style: const TextStyle(
                                      color: SparkColors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? SparkColors.amber : SparkColors.glassBorder,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: SparkColors.amber,
                        foregroundColor: const Color(0xFF181200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      onPressed: _next,
                      child: Text(_page == _pages.length - 1 ? 'Get started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.bullets,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final List<String> bullets;
}
