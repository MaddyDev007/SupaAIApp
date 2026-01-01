import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeService {
  static const _boxName = 'themeBox';
  static const _key = 'themeMode';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static ThemeMode loadTheme() {
    final box = Hive.box(_boxName);
    final value = box.get(_key, defaultValue: 'system');

    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveTheme(ThemeMode mode) async {
    final box = Hive.box(_boxName);
    await box.put(_key, mode.name); // light / dark / system
  }
}
