import 'package:flutter/material.dart';

import '../core/presentation/app_colors.dart';
import '../core/presentation/app_radii.dart';
import '../core/presentation/app_spacing.dart';
import '../core/presentation/app_text_styles.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: AppColors.darkAccent,
          onPrimary: Color(0xFF052E2B),
          primaryContainer: AppColors.darkAccentSoft,
          onPrimaryContainer: Color(0xFFD8FBF5),
          secondary: Color(0xFF93C5FD),
          onSecondary: Color(0xFF0F172A),
          secondaryContainer: Color(0xFF172554),
          onSecondaryContainer: Color(0xFFDBEAFE),
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkText,
          surfaceContainerHighest: AppColors.darkSurfaceMuted,
          onSurfaceVariant: AppColors.darkTextMuted,
          outline: AppColors.darkBorderStrong,
          outlineVariant: AppColors.darkBorder,
          error: Color(0xFFFCA5A5),
          onError: Color(0xFF450A0A),
        )
      : const ColorScheme.light(
          primary: AppColors.accent,
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: AppColors.accentSoft,
          onPrimaryContainer: AppColors.text,
          secondary: Color(0xFF2563EB),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFEFF6FF),
          onSecondaryContainer: AppColors.text,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          surfaceContainerHighest: AppColors.surfaceMuted,
          onSurfaceVariant: AppColors.textMuted,
          outline: AppColors.borderStrong,
          outlineVariant: AppColors.border,
          error: AppColors.danger,
          onError: Color(0xFFFFFFFF),
        );
  final scaffoldBackgroundColor = isDark
      ? AppColors.darkBackground
      : AppColors.background;
  final textTheme = AppTextStyles.textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    visualDensity: VisualDensity.compact,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.panel,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      contentPadding: AppSpacing.controlPadding,
      border: OutlineInputBorder(
        borderRadius: AppRadii.control,
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.control,
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.control,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.control,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.control,
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outline),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppSpacing.iconButtonSize),
        minimumSize: const Size.square(AppSpacing.iconButtonSize),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide(color: colorScheme.outlineVariant),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    ),
    navigationRailTheme: NavigationRailThemeData(
      minWidth: 80,
      minExtendedWidth: 220,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    dialogTheme: DialogThemeData(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
    ),
  );
}
