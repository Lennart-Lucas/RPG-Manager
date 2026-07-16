import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'app_theme_id';

  AppThemeId _themeId = AppThemeId.defaultTheme;
  bool _ready = false;

  AppThemeId get themeId => _themeId;
  bool get ready => _ready;
  ThemeData get themeData => AppThemes.forId(_themeId);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _themeId = AppThemeId.fromStorage(prefs.getString(_prefsKey));
    _ready = true;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeId id) async {
    if (_themeId == id) {
      return;
    }
    _themeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id.storageValue);
  }
}
