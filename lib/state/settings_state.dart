import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language: null = follow the device, otherwise 'en' or 'lv'. Persisted locally.
class SettingsState extends ChangeNotifier {
  static const _localeKey = 'locale';

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final code = (await SharedPreferences.getInstance()).getString(_localeKey);
    _locale = code == null ? null : Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }
}
