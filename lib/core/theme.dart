import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Spark design tokens — dark-first, warm electric amber + emerald accents,
/// glassmorphism surfaces.
abstract final class SparkColors {
  // Base
  static const Color bg = Color(0xFF0A0E14);
  static const Color bgElevated = Color(0xFF10151F);
  static const Color surface = Color(0xFF121826);

  // Glass
  static const Color glassFill = Color(0x0FFFFFFF); // ~6% white
  static const Color glassFillStrong = Color(0x14FFFFFF); // ~8% white
  static const Color glassBorder = Color(0x1FFFFFFF); // hairline

  // Accents
  static const Color amber = Color(0xFFFFB800);
  static const Color amberDim = Color(0x33FFB800);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDim = Color(0x2610B981);
  static const Color violet = Color(0xFF8B5CF6); // ghost mode
  static const Color violetDim = Color(0x2E8B5CF6);

  // Text
  static const Color textPrimary = Color(0xFFF3F6FB);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textFaint = Color(0xFF64748B);

  // Feedback
  static const Color danger = Color(0xFFF43F5E);
  static const Color dangerDim = Color(0x26F43F5E);

  /// Avatar palette indexed by profile.avatarColorIndex.
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFFFB800), Color(0xFFF59E0B)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFFF43F5E), Color(0xFFE11D48)],
    [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
    [Color(0xFFFB7185), Color(0xFFF472B6)],
    [Color(0xFFA3E635), Color(0xFF84CC16)],
    [Color(0xFFFB923C), Color(0xFFF97316)],
  ];
}

ThemeData buildSparkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SparkColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: SparkColors.amber,
      onPrimary: Color(0xFF141001),
      secondary: SparkColors.emerald,
      onSecondary: Color(0xFF03130D),
      surface: SparkColors.surface,
      onSurface: SparkColors.textPrimary,
      error: SparkColors.danger,
      outlineVariant: SparkColors.glassBorder,
    ),
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: SparkColors.textPrimary,
    displayColor: SparkColors.textPrimary,
  );

  return base.copyWith(
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: SparkColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: SparkColors.glassFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: SparkColors.glassBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: SparkColors.glassBorder, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SparkColors.glassFill,
      hintStyle: const TextStyle(color: SparkColors.textFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SparkColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SparkColors.amber, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SparkColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SparkColors.danger, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SparkColors.bgElevated,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: SparkColors.glassBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SparkColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      barrierColor: Colors.black54,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SparkColors.bgElevated,
      modalBarrierColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      showDragHandle: true,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
