import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;

  SettingsProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  // ==========================================
  // মাস্টার সুইচ (Master Switch) লজিক
  // ==========================================
  bool get isAlarmEnabled => _prefs?.getBool('isAlarmEnabled') ?? false;

  Future<void> toggleAlarm(bool value) async {
    if (_prefs != null) {
      await _prefs!.setBool('isAlarmEnabled', value);
      notifyListeners();

      // মাস্টার সুইচ অফ করলে সাথে সাথে বাজতে থাকা অ্যালার্মও বন্ধ হয়ে যাবে
      if (!value) {
        AudioService().stopAlarm();
      }
    }
  }

  // ==========================================
  // ৪টি আলাদা মোডের (Mode) জন্য ডাটাবেস লজিক
  // ==========================================
  dynamic getSetting(String mode, String key, dynamic defaultValue) {
    if (_prefs == null) return defaultValue;
    String fullKey = '${mode}_$key';

    if (defaultValue is bool) return _prefs!.getBool(fullKey) ?? defaultValue;
    if (defaultValue is String) return _prefs!.getString(fullKey) ?? defaultValue;
    if (defaultValue is int) return _prefs!.getInt(fullKey) ?? defaultValue;
    return defaultValue;
  }

  Future<void> updateSetting(String mode, String key, dynamic value) async {
    if (_prefs == null) return;
    String fullKey = '${mode}_$key';

    if (value is bool) await _prefs!.setBool(fullKey, value);
    if (value is String) await _prefs!.setString(fullKey, value);
    if (value is int) await _prefs!.setInt(fullKey, value);

    notifyListeners();
  }

  // ==========================================
  // গ্লোবাল সেটিংস (নাম এবং ডেসক্রিপশন)
  // ==========================================
  // ==========================================
  // গ্লোবাল সেটিংস (নাম এবং ডেসক্রিপশন)
  // ==========================================
  String get profileName => _prefs?.getString('profileName') ?? "Battery Notification Status";
  String get profileDescription => _prefs?.getString('profileDescription') ?? "Tap to See Current Status";

  Future<void> updateGlobalSetting(String key, String value) async {
    await _prefs?.setString(key, value);
    notifyListeners();
  }
}