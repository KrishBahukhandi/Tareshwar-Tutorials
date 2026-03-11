// ─────────────────────────────────────────────────────────────
//  app_theme.dart  –  Material 3 design system theme
//
//  Tokens used across the app:
//    • AppSpacing   – standard spacing scale
//    • AppRadius    – border-radius scale
//    • AppShadows   – layered box-shadow tokens
//    • AppTheme     – light + dark ThemeData
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

// ── Spacing scale ─────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xxs  = 4;
  static const double xs   = 8;
  static const double sm   = 12;
  static const double md   = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 48;
}

// ── Radius scale ──────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double xs  = 6.0;
  static const double sm  = 10.0;
  static const double md  = 14.0;
  static const double lg  = 18.0;
  static const double xl  = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  static BorderRadius get xsAll  => BorderRadius.circular(xs);
  static BorderRadius get smAll  => BorderRadius.circular(sm);
  static BorderRadius get mdAll  => BorderRadius.circular(md);
  static BorderRadius get lgAll  => BorderRadius.circular(lg);
  static BorderRadius get xlAll  => BorderRadius.circular(xl);
  static BorderRadius get xxlAll => BorderRadius.circular(xxl);
  static BorderRadius get circle => BorderRadius.circular(full);
}

// ── Shadow tokens ─────────────────────────────────────────────
class AppShadows {
  AppShadows._();

  /// Barely visible lift — cards, tiles
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  /// Standard card elevation
  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  /// Hero / banner lift
  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 28,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  /// Coloured glow — pass a color
  static List<BoxShadow> glow(Color color, {double intensity = 0.28}) => [
    BoxShadow(
      color: color.withValues(alpha: intensity),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // ── Shared text theme ──────────────────────────────────────
  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.interTextTheme(base).copyWith(
      // Display & headline use Poppins
      displayLarge:  GoogleFonts.poppins(
          fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.25),
      displayMedium: GoogleFonts.poppins(
          fontSize: 45, fontWeight: FontWeight.w700),
      displaySmall:  GoogleFonts.poppins(
          fontSize: 36, fontWeight: FontWeight.w600),
      headlineLarge:  GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall:  GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge:  GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      titleSmall:  GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      // Body & label use Inter
      bodyLarge:   GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium:  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall:   GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge:  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall:  GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }

  // ── Light theme ────────────────────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary:           AppColors.primary,
      onPrimary:         Colors.white,
      primaryContainer:  const Color(0xFFEBE9FF),
      onPrimaryContainer: AppColors.primaryDark,
      secondary:         AppColors.secondary,
      onSecondary:       Colors.white,
      surface:           AppColors.surface,
      onSurface:         AppColors.textPrimary,
      surfaceContainerLow: const Color(0xFFF4F4FC),
      surfaceContainer:    AppColors.surfaceVariant,
      error:             AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _buildTextTheme(Brightness.light).apply(
        bodyColor:    AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // ── AppBar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
            color: AppColors.textPrimary, size: 22),
      ),

      // ── Card ────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── Input ───────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(
              color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide:
              const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textHint),
        labelStyle: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textSecondary),
        floatingLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w500),
      ),

      // ── Elevated button ──────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.primary.withValues(alpha: 0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.sm + 2),
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Outlined button ──────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.sm + 2),
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Text button ──────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        ),
      ),

      // ── Chip ─────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        disabledColor: AppColors.border,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smAll),
        labelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),

      // ── BottomSheet ──────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        dragHandleSize: Size(36, 4),
        elevation: 0,
      ),

      // ── Dialog ───────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),

      // ── SnackBar ─────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle:
            GoogleFonts.inter(fontSize: 13, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── Tab bar ──────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
      ),

      // ── Divider ──────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ─────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
        shape:
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        minLeadingWidth: 0,
      ),

      // ── Navigation bar (bottom) ──────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor:
            AppColors.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight:
                active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? AppColors.primary
                : AppColors.textHint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AppColors.primary : AppColors.textHint,
            size: 22,
          );
        }),
      ),

      // ── Progress indicator ───────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0xFFE8E6FF),
        circularTrackColor: Color(0xFFE8E6FF),
        linearMinHeight: 4,
      ),

      // ── Switch ───────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textHint),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border),
      ),
    );
  }

  // ── Dark theme ─────────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary:           const Color(0xFF9D97FF),
      onPrimary:         const Color(0xFF1A0073),
      primaryContainer:  const Color(0xFF3D35B0),
      onPrimaryContainer: const Color(0xFFE0DCFF),
      secondary:         const Color(0xFFFFB3C1),
      surface:           AppColors.surfaceDark,
      onSurface:         const Color(0xFFE6E1FF),
      surfaceContainerLow: const Color(0xFF13131F),
      surfaceContainer: const Color(0xFF1F1F30),
      error:             const Color(0xFFFF8A80),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _buildTextTheme(Brightness.dark).apply(
        bodyColor:    const Color(0xFFE6E1FF),
        displayColor: Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme:
            const IconThemeData(color: Colors.white, size: 22),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackgroundDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F1F30),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        border: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide:
              const BorderSide(color: Color(0xFF9D97FF), width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D97FF),
          foregroundColor: const Color(0xFF1A0073),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.sm + 2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.cardBackgroundDark,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: Colors.white.withValues(alpha: 0.3),
        dragHandleSize: const Size(36, 4),
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A2A40),
        contentTextStyle:
            GoogleFonts.inter(fontSize: 13, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        behavior: SnackBarBehavior.floating,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF9D97FF),
        unselectedLabelColor: Colors.white54,
        indicatorColor: const Color(0xFF9D97FF),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w500),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor:
            const Color(0xFF9D97FF).withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight:
                active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? const Color(0xFF9D97FF)
                : Colors.white38,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active
                ? const Color(0xFF9D97FF)
                : Colors.white38,
            size: 22,
          );
        }),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF9D97FF),
        linearMinHeight: 4,
      ),
    );
  }
}
