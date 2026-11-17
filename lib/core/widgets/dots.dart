import 'package:flutter/material.dart';

/// A soft-glowing dot with a breathing pulse — used for "Active Now".
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    required this.color,
    this.size = 10,
    this.pulse = true,
  });

  final Color color;
  final double size;
  final bool pulse;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _scale =
      Tween(begin: 1.0, end: 1.35).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.55),
            blurRadius: widget.size * 1.1,
            spreadRadius: 1,
          ),
        ],
      ),
    );
    if (!widget.pulse) return dot;
    return ScaleTransition(scale: _scale, child: dot);
  }
}

/// Status dot that animates color changes smoothly.
class AnimatedStatusDot extends StatelessWidget {
  const AnimatedStatusDot({
    super.key,
    required this.color,
    required this.pulsing,
    this.size = 10,
  });

  final Color color;
  final bool pulsing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: color, end: color),
      duration: const Duration(milliseconds: 350),
      builder: (context, animatedColor, _) => PulsingDot(
        color: animatedColor ?? color,
        size: size,
        pulse: pulsing,
      ),
    );
  }
}
