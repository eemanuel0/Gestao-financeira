import 'package:flutter/material.dart';

import 'app_colors.dart';

// Altere as cores aqui para personalizar o app inteiro, sem editar cada tela.
ThemeData createAppTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF28643F),
        brightness: brightness,
      ).copyWith(
        primary: light ? const Color(0xFF24633D) : AppColors.neon,
        onPrimary: light ? Colors.white : AppColors.background,
        surface: light ? const Color(0xFFFEFFFC) : AppColors.dashboardSurface,
        onSurface: light ? const Color(0xFF1A281F) : AppColors.dashboardText,
        onSurfaceVariant: light
            ? const Color(0xFF526157)
            : AppColors.textSecondary,
        outline: light ? const Color(0xFF77867A) : const Color(0xFF7E877D),
        outlineVariant: light ? const Color(0xFFD4DED3) : AppColors.outline,
        surfaceContainerLow: light
            ? const Color(0xFFF0F4ED)
            : const Color(0xFF20221F),
        surfaceContainerHighest: light
            ? const Color(0xFFDCE5D8)
            : AppColors.dashboardTrack,
        error: light ? const Color(0xFFB42C2C) : const Color(0xFFFF8177),
        onError: light ? Colors.white : const Color(0xFF380000),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
  return base.copyWith(
    scaffoldBackgroundColor: light
        ? const Color(0xFFF3F6F0)
        : AppColors.background,
    textTheme: base.textTheme.apply(fontFamily: 'Poppins'),
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? const Color(0xFFF3F6F0) : AppColors.background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: border(scheme.outline),
      focusedBorder: border(scheme.primary)
          .copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: scheme.onSurface,
      ),
      actionTextColor: scheme.primary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
