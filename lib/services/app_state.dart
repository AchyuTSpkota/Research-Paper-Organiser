import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  String _languageCode = 'en';
  bool _nightMode = false;

  String get languageCode => _languageCode;
  bool get nightMode => _nightMode;

  void setLanguage(String code) {
    _languageCode = code;
    notifyListeners();
  }

  void setNightMode(bool value) {
    _nightMode = value;
    notifyListeners();
  }
}