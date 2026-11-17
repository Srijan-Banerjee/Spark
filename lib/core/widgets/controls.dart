import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../presence.dart';
import '../theme.dart';
import 'dots.dart';

/// Rounded amber primary button with haptic feedback.
class SparkButton extends StatelessWidget {
  const SparkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.danger = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? SparkColors.danger : SparkColors.amber;
    final fg = danger ? const Color(0xFF2B040C) : const Color(0xFF181200);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: expanded ? double.infinity : null,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: enabled ? bg : bg.withValues(alpha: 0.35),
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
          ),
          onPressed: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  onPressed?.call();
                }
              : null,
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text-only accent button.
class SparkTextButton extends StatelessWidget {
  const SparkTextButton({super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? SparkColors.amber,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

/// The signature Signal toggle switch — animated pill with emerald glow when active.
class SignalSwitch extends StatelessWidget {
  const SignalSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = value && enabled;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        width: 64,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? SparkColors.emerald.withValues(alpha: 0.22) : SparkColors.glassFillStrong,
          border: Border.all(
            color: active ? SparkColors.emerald.withValues(alpha: 0.70) : SparkColors.glassBorder,
            width: 1.2,
          ),
          boxShadow: active
              ? [BoxShadow(color: SparkColors.emerald.withValues(alpha: 0.40), blurRadius: 16)]
              : const [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? SparkColors.emerald : SparkColors.textFaint,
              boxShadow: [
                BoxShadow(
                  color: (active ? SparkColors.emerald : Colors.black).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              active ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              size: 16,
              color: active ? const Color(0xFF02160E) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

/// The signature Ghost Mode switch (alias / legacy).
class GhostSwitch extends StatelessWidget {
  const GhostSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = value && enabled;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        width: 64,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? SparkColors.violet.withValues(alpha: 0.22) : SparkColors.glassFillStrong,
          border: Border.all(
            color: active ? SparkColors.violet.withValues(alpha: 0.65) : SparkColors.glassBorder,
            width: 1.2,
          ),
          boxShadow: active
              ? [BoxShadow(color: SparkColors.violet.withValues(alpha: 0.35), blurRadius: 18)]
              : const [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? SparkColors.violet : SparkColors.textFaint,
              boxShadow: [
                BoxShadow(
                  color: (active ? SparkColors.violet : Colors.black).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              active ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 16,
              color: active ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live status chip with animated dot + crossfading label.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.display, this.compact = false});

  final PresenceDisplay display;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(display.color);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (context, t, _) => Opacity(
        opacity: 0.4 + 0.6 * t,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedStatusDot(color: color, pulsing: display.pulsing, size: compact ? 7 : 8),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  display.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient avatar from profile color index.
class SparkAvatar extends StatelessWidget {
  const SparkAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.size = 46,
  });

  final String name;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final grads = SparkColors.avatarGradients;
    final g = grads[(colorIndex < 0 || colorIndex >= grads.length ? 0 : colorIndex)];
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
        boxShadow: [BoxShadow(color: g.first.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFF101010),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Section heading with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SparkColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Friendly empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SparkColors.glassFillStrong,
                border: Border.all(color: SparkColors.glassBorder),
              ),
              child: Icon(icon, size: 30, color: SparkColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: SparkColors.textSecondary, fontSize: 13.5, height: 1.45),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SparkColors.amber,
                  foregroundColor: const Color(0xFF181200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onAction,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pill tag showing a user's real-time active application or idle state.
class AppActivityTag extends StatelessWidget {
  const AppActivityTag({
    super.key,
    required this.app,
    this.isIdle = false,
    this.compact = true,
  });

  final String? app;
  final bool isIdle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final idle = isIdle || app == 'Idle';
    final hasApp = !idle && app != null && app!.trim().isNotEmpty;

    if (!idle && !hasApp) return const SizedBox.shrink();

    final label = idle ? 'Idle' : 'In $app';
    final color = idle ? SparkColors.textSecondary : SparkColors.emerald;
    final bg = idle
        ? SparkColors.textSecondary.withValues(alpha: 0.12)
        : SparkColors.emerald.withValues(alpha: 0.12);
    final border = idle
        ? SparkColors.textSecondary.withValues(alpha: 0.28)
        : SparkColors.emerald.withValues(alpha: 0.35);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            idle ? Icons.bedtime_outlined : Icons.open_in_browser_rounded,
            size: compact ? 11.5 : 13.5,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
