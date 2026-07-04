import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import '../providers/battery_provider.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final batteryProvider = Provider.of<BatteryProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final int batteryLevel = batteryProvider.batteryLevel;
    final bool isCharging = batteryProvider.batteryState == BatteryState.charging;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildBatteryIndicator(batteryLevel, isCharging),
              const SizedBox(height: 30),
              // রিয়েল-টাইম ডাটাগুলো এখানে পাঠানো হচ্ছে
              _buildStatusCards(batteryProvider, isCharging),
              const SizedBox(height: 30),
              _buildProfileSummaryCard(settingsProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryIndicator(int batteryLevel, bool isCharging) {
    return Center(
      child: CircularPercentIndicator(
        radius: 130.0,
        lineWidth: 18.0,
        animation: true,
        animateFromLastPercent: true,
        percent: batteryLevel / 100.0,
        center: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCharging ? Icons.bolt : Icons.battery_std,
              size: 50,
              color: isCharging ? Colors.amberAccent : Colors.greenAccent,
            ),
            Text(
              "$batteryLevel%",
              style: const TextStyle(fontSize: 48.0, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        circularStrokeCap: CircularStrokeCap.round,
        progressColor: isCharging ? Colors.amberAccent : Colors.greenAccent,
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  // রিয়েল-টাইম স্ট্যাটাস কার্ড লজিক
  Widget _buildStatusCards(BatteryProvider provider, bool isCharging) {
    // ভোল্টেজ লজিক: চার্জে থাকলে বর্তমান ভোল্টেজ, না থাকলে লাস্ট সেভ করা ভোল্টেজ
    int displayVoltage = isCharging ? provider.currentVoltage : provider.lastChargingVoltage;
    String voltageStr = displayVoltage > 0 ? "${(displayVoltage / 1000).toStringAsFixed(1)} V" : "-- V";

    // টেম্পারেচার লজিক (রিয়েল টাইম)
    String tempStr = provider.temperature > 0 ? "${provider.temperature.toStringAsFixed(1)}°C" : "--°C";

    // টেম্পারেচার অনুযায়ী কালার (বেশি গরম হলে লাল)
    Color tempColor = provider.temperature >= 40.0 ? Colors.redAccent : Colors.amberAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _infoCard("Health", provider.healthStatus, Icons.favorite, Colors.greenAccent),
        _infoCard("Voltage", voltageStr, Icons.electric_meter, Colors.blueAccent),
        _infoCard("Temp", tempStr, Icons.thermostat, tempColor),
      ],
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        ],
      ),
    );
  }

  // মডার্ন প্রোফাইল সামারি কার্ড (Expandable)
  Widget _buildProfileSummaryCard(SettingsProvider settings) {
    bool isMasterActive = settings.isAlarmEnabled;
    Color borderColor = isMasterActive ? Colors.blueAccent : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.grey,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Text(
            settings.profileName,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              settings.profileDescription,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMasterActive ? "ACTIVE" : "INACTIVE",
                style: TextStyle(
                  color: isMasterActive ? Colors.blueAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 5),
              Switch(
                value: isMasterActive,
                activeColor: Colors.blueAccent,
                inactiveThumbColor: Colors.redAccent,
                inactiveTrackColor: Colors.redAccent.withOpacity(0.3),
                onChanged: (val) => settings.toggleAlarm(val),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF161616),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(settings, 'Connected', 'connected'),
                  const Divider(color: Colors.white12, height: 25),
                  _buildSummaryRow(settings, 'Disconnected', 'disconnected'),
                  const Divider(color: Colors.white12, height: 25),
                  _buildSummaryRow(settings, 'Full Battery', 'full'),
                  const Divider(color: Colors.white12, height: 25),
                  _buildSummaryRow(settings, 'Low Battery', 'low'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // প্রতিটি মোডের স্ট্যাটাস দেখানোর লজিক
  Widget _buildSummaryRow(SettingsProvider settings, String title, String modeKey) {
    bool isActive = settings.getSetting(modeKey, 'isActive', false);
    String soundType = settings.getSetting(modeKey, 'soundType', 'default');

    String soundTitle = "Default Ringtone";
    String soundDetail = "App Default Sound";

    if (soundType == 'file') {
      soundTitle = "Custom Audio File";
      String path = settings.getSetting(modeKey, 'customAudioPath', '');
      soundDetail = path.isNotEmpty ? path.split('/').last : "No file selected";
    } else if (soundType == 'tts') {
      soundTitle = "Text to Speech";
      soundDetail = 'Saying: "${settings.getSetting(modeKey, 'ttsText', '')}"';
    }
    else {
      // Default Ringtone এর ক্ষেত্রে সিলেক্ট করা নাম দেখানো
      soundTitle = "Built-in Sound";
      String defaultSound = settings.getSetting(modeKey, 'defaultSound', 'aabe_saale.mp3');
      if (defaultSound == 'yamate_kudesai.mp3') soundDetail = "Yamate Kudesai";
      else if (defaultSound == 'henta_ahh.mp3') soundDetail = "Henta Ahhh";
      else if (defaultSound == 'aabe_saale.mp3') soundDetail = "Aabe Saale";
      else if (defaultSound == 'ab_tu_gya_beta.mp3') soundDetail = "Ab Tu Gya Beta";
      else if (defaultSound == 'abhi_maja_ayega_na_bhidu.mp3') soundDetail = "Abhi Maja Ayega Na Bhidu";
      else if (defaultSound == 'chala_ja_bhosadike.mp3') soundDetail = "Chala Ja Bhosadike";
      else if (defaultSound == 'eh_eh_eh_ehhhhhh.mp3') soundDetail = "Eh Eh Eh Ehhhhhh";
      else if (defaultSound == 'glup_glup_glup.mp3') soundDetail = "Glup Glup Glup";
      else if (defaultSound == 'haat_be.mp3') soundDetail = "Haat Be";
      else if (defaultSound == 'khane_ko_de_de.mp3') soundDetail = "Khane Ko De De";
      else if (defaultSound == 'khatam.mp3') soundDetail = "Khatam";
      else if (defaultSound == 'maal_agaya.mp3') soundDetail = "Maal Agaya";
      else if (defaultSound == 'maayi_ke_chodu.mp3') soundDetail = "Maayi Ke Chodu";
      else if (defaultSound == 'nani.mp3') soundDetail = "Nani";
      else if (defaultSound == 'nikal_laude.mp3') soundDetail = "Nikal Laude";
      else if (defaultSound == 'oh_my_god_wow.mp3') soundDetail = "Oh My God Wow";
      else if (defaultSound == 'omaiga_meme.mp3') soundDetail = "Omaiga Meme";
      else if (defaultSound == 'pubg_let_s_go.mp3') soundDetail = "PUBG Let's Go";
      else if (defaultSound == 'rom_rom_bhaiyo.mp3') soundDetail = "Rom Rom Bhaiyo";
      else if (defaultSound == 'system_phar_denge.mp3') soundDetail = "System Phar Denge";
      else if (defaultSound == 'todowww.mp3') soundDetail = "Todowww";
      else if (defaultSound == 'uia.mp3') soundDetail = "UIA";


      else soundDetail = defaultSound;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(soundTitle, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(soundDetail, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isActive ? "ON" : "OFF",
            style: TextStyle(color: isActive ? Colors.blueAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}