import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const TextTheme textTheme = TextTheme(
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.text,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: AppColors.text,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
    ),
  );

  static TextStyle? pageTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      );

  static TextStyle? sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      );

  static TextStyle? muted(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  static TextStyle? tableHeader(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.textMuted,
      );

  static TextStyle? tableCell(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );
}
