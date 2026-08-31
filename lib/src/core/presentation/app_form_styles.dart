import 'package:flutter/material.dart';

class AppFormStyles {
  const AppFormStyles._();

  static const double controlHeight = 40;
  static const double controlFontSize = 12;
  static const double controlIconSize = 18;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 10, 16, 16);
  static const EdgeInsets panelPadding = EdgeInsets.all(14);
  static const EdgeInsets compactPanelPadding = EdgeInsets.all(10);
  static const BoxConstraints iconConstraints = BoxConstraints(
    minWidth: 36,
    minHeight: controlHeight,
  );

  static TextStyle? controlTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
      fontSize: controlFontSize,
      height: 1.2,
      color: theme.colorScheme.onSurface,
    );
  }

  static TextStyle? labelTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
      fontSize: controlFontSize,
      height: 1.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  static TextStyle? hintTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
      fontSize: controlFontSize,
      height: 1.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  static InputDecoration decoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: labelText == null ? null : labelTextStyle(context),
      hintText: hintText,
      hintStyle: hintText == null ? null : hintTextStyle(context),
      prefixIcon: prefixIcon,
      prefixIconConstraints: iconConstraints,
      suffixIcon: suffixIcon,
      suffixIconConstraints: iconConstraints,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }
}
