import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static SharedPreferences? _prefs;
  
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load Theme Mode
    final isDark = _prefs?.getBool('is_dark_mode') ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static void toggle() {
    themeMode.value = (themeMode.value == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    // Persist in background without blocking the UI thread
    _prefs?.setBool('is_dark_mode', themeMode.value == ThemeMode.dark);
  }

  static Future<void> resetToDefaults() async {
    await _prefs?.remove('is_dark_mode');
    themeMode.value = ThemeMode.light;
  }
}
