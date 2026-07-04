import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/battery_provider.dart';
import 'providers/settings_provider.dart';
import 'views/dashboard_screen.dart';
import 'services/background_logic.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // অ্যাপ ওপেন হওয়ার আগেই ব্যাকগ্রাউন্ড সার্ভিস চেক করবে
  await initializeService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BatteryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const DashboardScreen(),
    );
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 🔴 স্প্ল্যাশ স্ক্রিনে আটকে থাকার (Hang) সমস্যার ১০০% সমাধান:
  // সার্ভিস যদি আগে থেকেই চলতে থাকে, তবে আর নতুন করে কনফিগার করবে না। সরাসরি রিটার্ন করে অ্যাপ ওপেন করে দেবে।
  if (await service.isRunning()) {
    return;
  }

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'battery_channel_silent_v4',
    'Silent Battery Monitor',
    description: 'Keeps battery tracking alive smoothly.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // পারমিশন আগে থেকে দেওয়া আছে কি না তা চেক করে তারপর চাইবে (যাতে স্ক্রিন ব্লক না হয়)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'battery_channel_silent_v4',
      initialNotificationTitle: 'Battery Guard Active',
      initialNotificationContent: 'Monitoring battery safely...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: true),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // ফিক্সড (Un-swipeable) নোটিফিকেশন পুশ করা
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.show(
    888,
    'Battery System Active',
    'Monitoring your battery in background...',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'battery_channel_silent_v4',
        'Silent Battery Monitor',
        icon: '@mipmap/ic_launcher',
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        importance: Importance.low,
        priority: Priority.low,
      ),
    ),
  );

  final bgLogic = BackgroundLogic();

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    await bgLogic.checkBatteryAndAlarm();
  });
}