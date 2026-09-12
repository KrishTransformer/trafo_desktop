import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';

class AppDecorations {
  const AppDecorations._();

  static BoxDecoration panel(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: AppRadii.panel,
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  );

  static BoxDecoration elevatedPanel(BuildContext context) => panel(context)
      .copyWith(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadow
                : AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration subtlePanel(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: AppRadii.compact,
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  );

  static BoxDecoration selectedNavigationItem(BuildContext context) =>
      BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: AppRadii.control,
      );

  static BoxDecoration table(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: AppRadii.panel,
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  );

  static BoxDecoration tableHeader(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.md)),
  );
}
