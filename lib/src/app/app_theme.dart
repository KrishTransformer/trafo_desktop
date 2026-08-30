import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  // Mirrors tf-web's teal, navy, mint, and slate visual language.
  const colorScheme = ColorScheme.light(
    primary: Color(0xFF207A82),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD8ECE9),
    onPrimaryContainer: Color(0xFF183D54),
    secondary: Color(0xFF315C8D),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE8F4),
    onSecondaryContainer: Color(0xFF183D54),
    surface: Color(0xFFFBFFFE),
    onSurface: Color(0xFF183D54),
    surfaceContainerHighest: Color(0xFFE9F6F3),
    onSurfaceVariant: Color(0xFF56767C),
    outline: Color(0xFF27777A),
    outlineVariant: Color(0xFFC5E2DF),
    error: Color(0xFFC62828),
    onError: Color(0xFFFFFFFF),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFE9F6F3),
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFFFBFFFE),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: Color(0xFFC5E2DF)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFFAFFFE),
      labelStyle: TextStyle(color: Color(0xFF56767C)),
      hintStyle: TextStyle(color: Color(0xFF6B8A91)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFAFD7D4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF21666E), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: const BorderSide(color: Color(0xFFC5E2DF)),
      labelStyle: const TextStyle(color: Color(0xFF285567)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
