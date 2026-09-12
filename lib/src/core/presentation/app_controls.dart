import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

class AppControls {
  const AppControls._();

  static ButtonStyle primaryButton(BuildContext context) =>
      FilledButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        textStyle: Theme.of(context).textTheme.labelLarge,
      );

  static ButtonStyle secondaryButton(BuildContext context) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        textStyle: Theme.of(context).textTheme.labelLarge,
      );

  static ButtonStyle iconButton(BuildContext context) => IconButton.styleFrom(
    fixedSize: const Size.square(AppSpacing.iconButtonSize),
    minimumSize: const Size.square(AppSpacing.iconButtonSize),
    padding: EdgeInsets.zero,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
