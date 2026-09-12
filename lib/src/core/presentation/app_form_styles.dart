import 'package:flutter/material.dart';

import 'app_radii.dart';
import 'app_spacing.dart';

class AppFormStyles {
  const AppFormStyles._();

  static const double controlHeight = AppSpacing.controlHeight;
  static const double controlFontSize = 12;
  static const double controlIconSize = 16;
  static const EdgeInsets pagePadding = AppSpacing.pagePadding;
  static const EdgeInsets panelPadding = AppSpacing.panelPadding;
  static const EdgeInsets compactPanelPadding = AppSpacing.compactPanelPadding;
  static const BoxConstraints iconConstraints = BoxConstraints(
    minWidth: 34,
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
      contentPadding: AppSpacing.controlPadding,
      border: const OutlineInputBorder(borderRadius: AppRadii.control),
      isDense: true,
    );
  }
}
