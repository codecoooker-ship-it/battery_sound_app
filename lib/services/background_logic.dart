import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';

class BackgroundLogic {
  static final BackgroundLogic _instance = BackgroundLogic._internal();
  factory BackgroundLogic() => _instance;
  BackgroundLogic._internal();

  final Battery _battery = Battery();
  final AudioService _audioService = AudioService();

  BatteryState _previousState = BatteryState.unknown;
  String? _lastTriggeredMode;
  int? _lastLowBatteryMilestone;

  Future<void> checkBatteryAndAlarm() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔴 ম্যাজিক ফিক্স ১: ব্যাকগ্রাউন্ড সার্ভিসকে জোর করে লেটেস্ট সেটিংস পড়ানো হচ্ছে
    await prefs.reload();

    // 🔴 ম্যাজিক ফিক্স ২: ডিফল্ট ভ্যালু false এর জায়গায় true করা হলো, যাতে ব্যাকগ্রাউন্ড এটিকে অটোমেটিক ব্লক না করে
    bool isMasterEnabled = prefs.getBool('isAlarmEnabled') ?? true;
    if (!isMasterEnabled) {
      _audioService.stopAlarm();
      _lastTriggeredMode = null;
      _lastLowBatteryMilestone = null;
      return;
    }

    int batteryLevel = await _battery.batteryLevel;
    BatteryState batteryState = await _battery.batteryState;

    // সেটিংস থেকে লেটেস্ট স্ট্যাটাস পড়া হচ্ছে
    bool fullActive = prefs.getBool('full_isActive') ?? false;
    bool lowActive = prefs.getBool('low_isActive') ?? false;
    bool connActive = prefs.getBool('connected_isActive') ?? false;
    bool disconnActive = prefs.getBool('disconnected_isActive') ?? false;

    String? triggeredMode;
    bool forcePlayLowBattery = false;

    // ১. Full Battery
    if (fullActive && (batteryState == BatteryState.charging || batteryState == BatteryState.full)) {
      int fullThreshold = prefs.getInt('full_threshold') ?? 100;
      if (batteryLevel >= fullThreshold) triggeredMode = 'full';
    }

    // ২. Low Battery
    if (triggeredMode == null && lowActive && batteryState == BatteryState.discharging) {
      int lowThreshold = prefs.getInt('low_threshold') ?? 20;

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

        String soundType = prefs.getString('${triggeredMode}_soundType') ?? 'default';
        String customPath = prefs.getString('${triggeredMode}_customAudioPath') ?? '';
        String ttsText = prefs.getString('${triggeredMode}_ttsText') ?? 'Battery Alert';
        String defaultSound = prefs.getString('${triggeredMode}_defaultSound') ?? 'alarm.mp3';

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
  }
}