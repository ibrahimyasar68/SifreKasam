import 'package:flutter/material.dart';

import 'security.dart';

/// Tema seçimi: Sistem / Açık / Koyu. Seçim cihazda saklanır.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  ThemeMode mode = ThemeMode.system;

  Future<void> init() async {
    mode = switch (await Security.instance.themeMode()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    await Security.instance.setThemeMode(m.name);
  }
}
