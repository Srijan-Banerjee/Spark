import 'package:flutter/material.dart';

import '../theme.dart';

/// The Spark wordmark — amber bolt in a glass ring.
class SparkLogo extends StatelessWidget {
  const SparkLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB800), Color(0xFFFF8F00)],
        ),
        boxShadow: [
          BoxShadow(
            color: SparkColors.amber.withValues(alpha: 0.45),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(Icons.bolt_rounded, color: const Color(0xFF1B1400), size: size * 0.62),
    );
  }
}
