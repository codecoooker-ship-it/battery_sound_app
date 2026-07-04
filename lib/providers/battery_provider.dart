import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';

class BatteryProvider with ChangeNotifier {
  final Battery _battery = Battery();
  final AudioService _audioService = AudioService();

  // অ্যান্ড্রয়েডের সাথে কথা বলার চ্যানেল
  static const platform = MethodChannel('com.example.bsn.bsn/battery');

  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  BatteryState _previousState = BatteryState.unknown;

  String? _lastTriggeredMode;
  int? _lastLowBatteryMilestone;

  // রিয়েল-টাইম ডাটা রাখার ভ্যারিয়েবল
  String _healthStatus = "Good";
  double _temperature = 0.0;
  int _currentVoltage = 0;
  int _lastChargingVoltage = 0;

  late StreamSubscription<BatteryState> _batteryStateSubscription;
  Timer? _pollingTimer;

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;

  String get healthStatus => _healthStatus;
  double get temperature => _temperature;
  int get currentVoltage => _currentVoltage;
  int get lastChargingVoltage => _lastChargingVoltage;

  BatteryProvider() {
    _initBattery();
  }

  Future<void> _initBattery() async {
    final prefs = await SharedPreferences.getInstance();
    // অ্যাপ রিস্টার্ট হলেও যেন লাস্ট ভোল্টেজ মনে থাকে
    _lastChargingVoltage = prefs.getInt('lastChargingVoltage') ?? 0;

    _batteryLevel = await _battery.batteryLevel;
    await _fetchNativeBatteryInfo(); // শুরুতে একবার ডাটা নিয়ে আসা
    notifyListeners();

    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((BatteryState state) {
      _previousState = _batteryState;
      _batteryState = state;
      _updateBatteryLevel();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateBatteryLevel();
    });
  }

  Future<void> _updateBatteryLevel() async {
    _batteryLevel = await _battery.batteryLevel;
    await _fetchNativeBatteryInfo(); // রিয়েল-টাইম ডাটা আপডেট করা
    await _checkAlarmCondition();
    notifyListeners();
  }

  // রিয়েল-টাইম ডাটা আনার ম্যাজিক ফাংশন
  Future<void> _fetchNativeBatteryInfo() async {
    try {
      final Map<dynamic, dynamic> info = await platform.invokeMethod('getBatteryInfo');
      _temperature = info['temp'] ?? 0.0;
      _currentVoltage = info['voltage'] ?? 0;
      int healthCode = info['health'] ?? 0;

      // হেলথ কোড কনভার্ট করা
      switch (healthCode) {
        case 2: _healthStatus = "Good"; break;
        case 3: _healthStatus = "Overheat"; break;
        case 4: _healthStatus = "Dead"; break;
        case 5: _healthStatus = "Over Voltage"; break;
        case 7: _healthStatus = "Cold"; break;
        default: _healthStatus = "Unknown";
      }

      // ভোল্টেজ লজিক: চার্জে থাকলে মেমোরিতে সেভ করো
      if (_batteryState == BatteryState.charging) {
        _lastChargingVoltage = _currentVoltage;
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('lastChargingVoltage', _currentVoltage);
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get battery info: '${e.message}'.");
    }
  }

  // ... (বাকি অ্যালার্ম লজিক আগের মতোই)
  Future<void> _checkAlarmCondition() async {
    final prefs = await SharedPreferences.getInstance();
    bool isMasterEnabled = prefs.getBool('isAlarmEnabled') ?? false;

    if (!isMasterEnabled) {
      _audioService.stopAlarm();
      _lastTriggeredMode = null;
      _lastLowBatteryMilestone = null;
      return;
    }

    bool fullActive = prefs.getBool('full_isActive') ?? false;
    bool lowActive = prefs.getBool('low_isActive') ?? false;
    bool connActive = prefs.getBool('connected_isActive') ?? false;
    bool disconnActive = prefs.getBool('disconnected_isActive') ?? false;

    String? triggeredMode;
    bool forcePlayLowBattery = false;

    if (fullActive && (_batteryState == BatteryState.charging || _batteryState == BatteryState.full)) {
      int fullThreshold = prefs.getInt('full_threshold') ?? 100;
      if (_batteryLevel >= fullThreshold) triggeredMode = 'full';
    }

    if (triggeredMode == null && lowActive && _batteryState == BatteryState.discharging) {
      int lowThreshold = prefs.getInt('low_threshold') ?? 20;

      if (_batteryLevel <= lowThreshold) {
        int currentMilestone = -1;
        if (_batteryLevel <= 2) {
          currentMilestone = 2;
        } else {
          int diff = lowThreshold - _batteryLevel;
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

    if (triggeredMode == null && connActive && _batteryState == BatteryState.charging && _previousState != BatteryState.charging) {
      triggeredMode = 'connected';
    }

    if (triggeredMode == null && disconnActive && _batteryState == BatteryState.discharging && _previousState == BatteryState.charging) {
      triggeredMode = 'disconnected';
    }

    if (triggeredMode != null && triggeredMode != 'low_silent') {
      if (forcePlayLowBattery || _lastTriggeredMode != triggeredMode) {
        _lastTriggeredMode = triggeredMode;

        String soundType = prefs.getString('${triggeredMode}_soundType') ?? 'default';
        String customPath = prefs.getString('${triggeredMode}_customAudioPath') ?? '';
        String ttsText = prefs.getString('${triggeredMode}_ttsText') ?? 'Battery Alert';
        String defaultSound = prefs.getString('${triggeredMode}_defaultSound') ?? 'aabe_saale.mp3';
        _audioService.playAlarm(soundType: soundType, audioPath: customPath, ttsText: ttsText,defaultSound: defaultSound);
      }
    } else if (triggeredMode == null) {
      _lastTriggeredMode = null;
    }
  }

  void stopManualAlarm() => _audioService.stopAlarm();

  @override
  void dispose() {
    _batteryStateSubscription.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}