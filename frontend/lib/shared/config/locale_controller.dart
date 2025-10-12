import 'package:flutter/material.dart';

class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void toggle() {
    _locale = _locale.languageCode == 'fr' ? const Locale('en') : const Locale('fr');
    notifyListeners();
  }

  String get shortLabel => _locale.languageCode.toUpperCase();
}
