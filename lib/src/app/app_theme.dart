import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seedColor = Color(0xFF0B6E4F);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF5F7F8),
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      minWidth: 80,
      minExtendedWidth: 220,
      backgroundColor: Colors.white,
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
