import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontSizePref { small, medium, large }
enum MatchingSensitivity { strict, normal, loose }

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  FontSizePref _font = FontSizePref.medium;
  MatchingSensitivity _sensitivity = MatchingSensitivity.normal;
  bool _vibration = true;
  bool _soundAlert = false;
  double _autoScrollSpeed = 1.0;

  ThemeMode get themeMode => _themeMode;
  FontSizePref get font => _font;
  MatchingSensitivity get sensitivity => _sensitivity;
  bool get vibration => _vibration;
  bool get soundAlert => _soundAlert;
  double get autoScrollSpeed => _autoScrollSpeed;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[sp.getInt('themeMode') ?? ThemeMode.system.index];
    _font = FontSizePref.values[sp.getInt('font') ?? FontSizePref.medium.index];
    _sensitivity = MatchingSensitivity.values[sp.getInt('sensitivity') ?? MatchingSensitivity.normal.index];
    _vibration = sp.getBool('vibration') ?? true;
    _soundAlert = sp.getBool('soundAlert') ?? false;
    _autoScrollSpeed = sp.getDouble('autoScrollSpeed') ?? 1.0;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('themeMode', m.index);
    notifyListeners();
  }

  Future<void> setFont(FontSizePref f) async {
    _font = f;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('font', f.index);
    notifyListeners();
  }

  Future<void> setSensitivity(MatchingSensitivity s) async {
    _sensitivity = s;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('sensitivity', s.index);
    notifyListeners();
  }

  Future<void> setVibration(bool v) async {
    _vibration = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('vibration', v);
    notifyListeners();
  }

  Future<void> setSoundAlert(bool v) async {
    _soundAlert = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('soundAlert', v);
    notifyListeners();
  }

  Future<void> setAutoScrollSpeed(double v) async {
    _autoScrollSpeed = v.clamp(0.5, 2.0);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('autoScrollSpeed', _autoScrollSpeed);
    notifyListeners();
  }

  double fontSizeForBody() {
    switch (_font) {
      case FontSizePref.small:
        return 16;
      case FontSizePref.medium:
        return 20;
      case FontSizePref.large:
        return 26;
    }
  }

  double fontSizeForScript() {
    switch (_font) {
      case FontSizePref.small:
        return 20;
      case FontSizePref.medium:
        return 26;
      case FontSizePref.large:
        return 32;
    }
  }

  double thresholdForMatching() {
    switch (_sensitivity) {
      case MatchingSensitivity.strict:
        return 0.7;
      case MatchingSensitivity.normal:
        return 0.6;
      case MatchingSensitivity.loose:
        return 0.5;
    }
  }
}
