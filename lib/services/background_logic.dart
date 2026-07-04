import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';

class BackgroundLogic {
  static final BackgroundLogic _instance = BackgroundLogic._internal();
  factory BackgroundLogic() => _instance;
  BackgroundLogic._internal();

  final Battery _battery = Battery();
  final AudioService _audioService = AudioService();

  // 🔴 স্প্ল্যাশ স্ক্রিনের ডেডলক ঠেকানোর জন্য SharedPreferences ক্যাশ করা হলো
  SharedPreferences? _prefs;

  BatteryState _previousState = BatteryState.unknown;
  String? _lastTriggeredMode;
  int? _lastLowBatteryMilestone;

  Future<void> checkBatteryAndAlarm() async {
    try {
      // 🔴 বারবার getInstance() কল না করে একবার কল করে মেমোরিতে ধরে রাখা হচ্ছে
      _prefs ??= await SharedPreferences.getInstance();

      // 🔴 শুধু ডাটা রিলোড হবে, ফলে ডেডলক হবে না!
      await _prefs!.reload();

      bool isMasterEnabled = _prefs!.getBool('isAlarmEnabled') ?? true;
      if (!isMasterEnabled) {
        _audioService.stopAlarm();
        _lastTriggeredMode = null;
        _lastLowBatteryMilestone = null;
        return;
      }

      int batteryLevel = await _battery.batteryLevel;
      BatteryState batteryState = await _battery.batteryState;

      // সেটিংস থেকে লেটেস্ট স্ট্যাটাস পড়া হচ্ছে
      bool fullActive = _prefs!.getBool('full_isActive') ?? false;
      bool lowActive = _prefs!.getBool('low_isActive') ?? false;
      bool connActive = _prefs!.getBool('connected_isActive') ?? false;
      bool disconnActive = _prefs!.getBool('disconnected_isActive') ?? false;

      String? triggeredMode;
      bool forcePlayLowBattery = false;

      // ১. Full Battery
      if (fullActive && (batteryState == BatteryState.charging || batteryState == BatteryState.full)) {
        int fullThreshold = _prefs!.getInt('full_threshold') ?? 100;
        if (batteryLevel >= fullThreshold) triggeredMode = 'full';
      }

      // ২. Low Battery
      if (triggeredMode == null && lowActive && batteryState == BatteryState.discharging) {
        int lowThreshold = _prefs!.getInt('low_threshold') ?? 20;

        if (batteryLevel <= lowThreshold) {
          int currentMilestone = -1;
          if (batteryLevel <= 2) {
            currentMilestone = 2;
          } else {
            int diff = lowThreshold - batteryLevel;
            int steps = diff ~/ 5;
            currentMilestone = lowThreshold - (steps * 5);
          }

          if (_lastLowBatteryMilestone != currentMilestone) {
            triggeredMode = 'low';
            _lastLowBatteryMilestone = currentMilestone;
            forcePlayLowBattery = true;
          } else {
            triggeredMode = 'low_silent';
          }
        }
      } else {
        _lastLowBatteryMilestone = null;
      }

      // ৩. Connected
      if (triggeredMode == null && connActive && batteryState == BatteryState.charging && _previousState != BatteryState.charging && _previousState != BatteryState.unknown) {
        triggeredMode = 'connected';
      }

      // ৪. Disconnected
      if (triggeredMode == null && disconnActive && batteryState == BatteryState.discharging && _previousState == BatteryState.charging) {
        triggeredMode = 'disconnected';
      }

      // ফাইনাল সাউন্ড বাজানোর লজিক
      if (triggeredMode != null && triggeredMode != 'low_silent') {
        if (forcePlayLowBattery || _lastTriggeredMode != triggeredMode) {
          _lastTriggeredMode = triggeredMode;

          String soundType = _prefs!.getString('${triggeredMode}_soundType') ?? 'default';
          String customPath = _prefs!.getString('${triggeredMode}_customAudioPath') ?? '';
          String ttsText = _prefs!.getString('${triggeredMode}_ttsText') ?? 'Battery Alert';
          String defaultSound = _prefs!.getString('${triggeredMode}_defaultSound') ?? 'alarm.mp3';

          _audioService.playAlarm(
            soundType: soundType,
            audioPath: customPath,
            ttsText: ttsText,
            defaultSound: defaultSound,
          );
        }
      } else if (triggeredMode == null) {
        _lastTriggeredMode = null;
      }

      // পরের বারের চেক করার জন্য বর্তমান স্টেট সেভ করে রাখা
      _previousState = batteryState;

    } catch (e) {
      // কোনো কারণে এরর হলে ব্যাকগ্রাউন্ড সার্ভিস যেন ক্র্যাশ না করে
      print("Background logic error: $e");
    }
  }
}