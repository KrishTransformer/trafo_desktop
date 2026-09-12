import 'package:flutter/foundation.dart';

final appThemeController = AppThemeController();

class AppThemeController extends ChangeNotifier {
  AppThemeController({bool isDarkMode = true}) : _isDarkMode = isDarkMode;

  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;

  void setDarkMode(bool value) {
    if (value == _isDarkMode) {
      return;
    }

    _isDarkMode = value;
    notifyListeners();
  }

  void toggleDarkMode() => setDarkMode(!_isDarkMode);
}
