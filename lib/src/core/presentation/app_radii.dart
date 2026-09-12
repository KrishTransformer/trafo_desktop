import 'package:flutter/material.dart';

class AppRadii {
  const AppRadii._();

  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double pill = 999;

  static const BorderRadius panel = BorderRadius.all(Radius.circular(md));
  static const BorderRadius control = BorderRadius.all(Radius.circular(md));
  static const BorderRadius compact = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
