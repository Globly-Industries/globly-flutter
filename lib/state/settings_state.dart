import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences, persisted on the device:
/// - app language: null = follow the device, otherwise 'en' or 'lv';
/// - feed view: full-screen pages (the default) or the card list.
class SettingsState extends ChangeNotifier {
  static const _localeKey = 'locale';
  static const _immersiveFeedKey = 'immersiveFeed';

  Locale? _locale;
  Locale? get locale => _locale;

  bool _immersiveFeed = true;
  bool get immersiveFeed => _immersiveFeed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    _locale = code == null ? null : Locale(code);
    _immersiveFeed = prefs.getBool(_immersiveFeedKey) ?? true;
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

  Future<void> setImmersiveFeed(bool immersive) async {
    _immersiveFeed = immersive;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_immersiveFeedKey, immersive);
  }
}
