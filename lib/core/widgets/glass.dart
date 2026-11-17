import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Frosted-glass container used across the Spark UI.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.blur = 16,
    this.fill = SparkColors.glassFill,
    this.borderColor = SparkColors.glassBorder,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;
  final Color fill;
  final Color borderColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x08FFFFFF), Color(0x00000000)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small frosted panel for rows inside larger cards.
class GlassRow extends StatelessWidget {
  const GlassRow({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SparkColors.glassFillStrong,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SparkColors.glassBorder),
      ),
      child: child,
    );
  }
}
