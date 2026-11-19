import 'package:flutter/material.dart';

class AppColors {
  // As telas consultam esta paleta para acompanhar a preferência de tema.
  static AppPalette of(BuildContext context) => AppPalette(Theme.of(context));
  static const Color background = Color(0xFF050505);
  static const Color neon = Color(0xFF3DF026);
  static const Color button = Color(0xFF8DF03C);
  static const Color textSecondary = Color(0xFFB5B5B5);
  static const Color dotInactive = Color(0xFF3A3A3A);
  static const Color outline = Color(0xFF3A3A3A);
  // Cores específicas do dashboard.
  static const Color dashboardExpense = Color(0xFFE34F45);
  static const Color dashboardSurface = Color(0xFF171816);
  static const Color dashboardTrack = Color(0xFF292A27);
  static const Color dashboardText = Colors.white;

  // Fundos e bordas dos avisos de limite.
  static final Color limitExceededBackground = dashboardExpense.withValues(
    alpha: 0.14,
  );
  static final Color limitExceededBorder = dashboardExpense.withValues(
    alpha: 0.55,
  );
  static final Color limitWithinBackground = neon.withValues(alpha: 0.07);
  static final Color limitWithinBorder = neon.withValues(alpha: 0.65);
}

class AppPalette {
  final ThemeData theme;
  const AppPalette(this.theme);
  Color get background => theme.scaffoldBackgroundColor;
  Color get neon => theme.colorScheme.primary;
  Color get button => theme.colorScheme.primary;
  Color get onButton => theme.colorScheme.onPrimary;
  Color get textSecondary => theme.colorScheme.onSurfaceVariant;
  Color get dotInactive => theme.colorScheme.outlineVariant;
  Color get outline => theme.colorScheme.outline;
  Color get dashboardExpense => theme.colorScheme.error;
  Color get dashboardSurface => theme.colorScheme.surface;
  Color get dashboardTrack => theme.colorScheme.surfaceContainerHighest;
  Color get dashboardText => theme.colorScheme.onSurface;
  Color get cardFill => theme.colorScheme.surface;
  Color get fieldFill => theme.colorScheme.surfaceContainerLow;
  Color get limitExceededBackground => dashboardExpense.withValues(alpha: 0.10);
  Color get limitExceededBorder => dashboardExpense.withValues(alpha: 0.55);
  Color get limitWithinBackground => neon.withValues(alpha: 0.07);
  Color get limitWithinBorder => neon.withValues(alpha: 0.65);
}
