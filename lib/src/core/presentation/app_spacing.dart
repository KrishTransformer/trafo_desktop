import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double sidebarWidth = 248;
  static const double topBarHeight = 56;
  static const double controlHeight = 36;
  static const double compactControlHeight = 32;
  static const double iconButtonSize = 34;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 16);
  static const EdgeInsets panelPadding = EdgeInsets.all(14);
  static const EdgeInsets compactPanelPadding = EdgeInsets.all(10);
  static const EdgeInsets controlPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
}
