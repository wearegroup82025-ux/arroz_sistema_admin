import 'package:flutter/material.dart';

enum AppLanguage {
  tagalog,
  english,
}

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.tagalog;

  AppLanguage get language => _language;

  bool get isEnglish => _language == AppLanguage.english;

  void toggleLanguage() {
    if (_language == AppLanguage.tagalog) {
      _language = AppLanguage.english;
    } else {
      _language = AppLanguage.tagalog;
    }

    notifyListeners();
  }

  void setLanguage(AppLanguage language) {
    _language = language;
    notifyListeners();
  }
}