import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = const Color(0xFFB71C1C); // Corporate red (deep) by default

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  void toggleDark(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setSeed(Color color) {
    if (color.value == _seedColor.value) return;
    _seedColor = color;
    notifyListeners();
  }

  // Common palette used by the theme panel
  static const List<Color> palette = <Color>[
    Color(0xFFB71C1C), // Corporate Red (Deep) – login gradient start
    Color(0xFFE53935), // Corporate Red (Bright) – login gradient end
    Color(0xFF1E88E5), // Blue
    Color(0xFF8E24AA), // Purple
    Color(0xFFF4511E), // Orange
    Color(0xFF2E7D32), // Green
    Color(0xFF00897B), // Teal
  ];
}
