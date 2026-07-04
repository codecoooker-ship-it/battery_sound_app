import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../services/audio_service.dart'; // সাউন্ড প্রিভিউ করার জন্য এটি ইমপোর্ট করা হলো

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _nameController = TextEditingController(text: settings.profileName);
    _descController = TextEditingController(text: settings.profileDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveGlobalSettings() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.updateGlobalSetting('profileName', _nameController.text);
    settings.updateGlobalSetting('profileDescription', _descController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile Info Saved!'), backgroundColor: Colors.green),
    );
  }

  // Bottom Sheet for Editing Specific Mode
  void _openModeEditor(BuildContext context, String mode, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return _ModeEditBottomSheet(mode: mode, title: title);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Alarm Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PROFILE INFO", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _buildProfileInfoCard(),
            const SizedBox(height: 30),
            const Text("ALARM MODES", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _buildModeTile(context, settings, 'Connected', 'connected', Icons.cable),
            _buildModeTile(context, settings, 'Disconnected', 'disconnected', Icons.power_off),
            _buildModeTile(context, settings, 'Full Battery', 'full', Icons.battery_charging_full),
            _buildModeTile(context, settings, 'Low Battery', 'low', Icons.battery_alert),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: "Profile Name", labelStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
              onEditingComplete: _saveGlobalSettings,
            ),
            const Divider(color: Colors.grey),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
              onEditingComplete: _saveGlobalSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTile(BuildContext context, SettingsProvider settings, String title, String modeKey, IconData icon) {
    bool isActive = settings.getSetting(modeKey, 'isActive', false);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isActive ? Colors.blueAccent.withOpacity(0.5) : Colors.transparent, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(icon, color: isActive ? Colors.blueAccent : Colors.grey),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text("Tap to edit settings", style: TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Switch(
          value: isActive,
          activeColor: Colors.blueAccent,
          onChanged: (val) {
            settings.updateSetting(modeKey, 'isActive', val);
          },
        ),
        onTap: () => _openModeEditor(context, modeKey, title),
      ),
    );
  }
}

// Bottom Sheet UI (Edit individual mode settings)
class _ModeEditBottomSheet extends StatefulWidget {
  final String mode;
  final String title;
  const _ModeEditBottomSheet({required this.mode, required this.title});

  @override
  State<_ModeEditBottomSheet> createState() => _ModeEditBottomSheetState();
}

class _ModeEditBottomSheetState extends State<_ModeEditBottomSheet> {
  late String _soundType;
  late String _customAudioPath;
  late TextEditingController _ttsController;
  late int _threshold;
  late String _defaultSound;

  // আপনার ফোল্ডারে থাকা অডিও ফাইলগুলোর নাম এখানে দিন
  final List<Map<String, String>> _appRingtones = [
    {'name': 'Yamate Kudesai', 'file': 'yamate_kudesai.mp3'},
    {'name': 'hent ah', 'file': 'henta_ahh.mp3'},
    {'name': 'Aabe Saale', 'file': 'aabe_saale.mp3'},
    {'name': 'Ab Tu Gya Beta', 'file': 'ab_tu_gya_beta.mp3'},
    {'name': 'Abhi Maja Ayega Na Bhidu', 'file': 'abhi_maja_ayega_na_bhidu.mp3'},
    {'name': 'Chala Ja Bhosadike', 'file': 'chala_ja_bhosadike.mp3'},
    {'name': 'Eh Eh Eh Ehhhhhh', 'file': 'eh_eh_eh_ehhhhhh.mp3'},
    {'name': 'Glup Glup Glup', 'file': 'glup_glup_glup.mp3'},
    {'name': 'Haat Be', 'file': 'haat_be.mp3'},
    {'name': 'Khane Ko De De', 'file': 'khane_ko_de_de.mp3'},
    {'name': 'Khatam', 'file': 'khatam.mp3'},
    {'name': 'Maal Agaya', 'file': 'maal_agaya.mp3'},
    {'name': 'Maayi Ke Chodu', 'file': 'maayi_ke_chodu.mp3'},
    {'name': 'Nani', 'file': 'nani.mp3'},
    {'name': 'Nikal Laude', 'file': 'nikal_laude.mp3'},
    {'name': 'Oh My God Wow', 'file': 'oh_my_god_wow.mp3'},
    {'name': 'Omaiga Meme', 'file': 'omaiga_meme.mp3'},
    {'name': 'PUBG Let\'s Go', 'file': 'pubg_let_s_go.mp3'},
    {'name': 'Rom Rom Bhaiyo', 'file': 'rom_rom_bhaiyo.mp3'},
    {'name': 'System Phar Denge', 'file': 'system_phar_denge.mp3'},
    {'name': 'Todowww', 'file': 'todowww.mp3'},
    {'name': 'UIA', 'file': 'uia.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _soundType = settings.getSetting(widget.mode, 'soundType', 'default');
    _customAudioPath = settings.getSetting(widget.mode, 'customAudioPath', '');
    _defaultSound = settings.getSetting(widget.mode, 'defaultSound', 'aabe_saale.mp3');
    _ttsController = TextEditingController(text: settings.getSetting(widget.mode, 'ttsText', 'Alert for ${widget.mode}'));

    if (widget.mode == 'full') {
      _threshold = settings.getSetting(widget.mode, 'threshold', 100);
    } else if (widget.mode == 'low') {
      _threshold = settings.getSetting(widget.mode, 'threshold', 20);
    } else {
      _threshold = 0;
    }
  }

  void _saveData() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.updateSetting(widget.mode, 'soundType', _soundType);
    settings.updateSetting(widget.mode, 'customAudioPath', _customAudioPath);
    settings.updateSetting(widget.mode, 'ttsText', _ttsController.text);
    settings.updateSetting(widget.mode, 'defaultSound', _defaultSound);
    if (widget.mode == 'full' || widget.mode == 'low') {
      settings.updateSetting(widget.mode, 'threshold', _threshold);
    }
    AudioService().stopAlarm();
    Navigator.pop(context);
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _customAudioPath = result.files.single.path!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      // এখানে মূল কন্টেন্টকে SingleChildScrollView এর ভেতরে রাখা হলো
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${widget.title} Settings", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      AudioService().stopAlarm(); // পপ-আপ ক্লোজ করার সময় সাউন্ড থামিয়ে দেবে
                      Navigator.pop(context);
                    }
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),

            if (widget.mode == 'full' || widget.mode == 'low') ...[
              Text(widget.mode == 'full' ? "Alert when battery is >=" : "Alert when battery is <=", style: const TextStyle(color: Colors.grey)),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _threshold.toDouble(), min: 5, max: 100, divisions: 95,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _threshold = val.toInt()),
                    ),
                  ),
                  Text("$_threshold%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 20),
            ],

            const Text("Sound Option", style: TextStyle(color: Colors.grey)),

            // ==============================================
            // Default App Ringtone Option & List
            // ==============================================
            RadioListTile(
              title: const Text("Default App Ringtone", style: TextStyle(color: Colors.white)),
              value: 'default', groupValue: _soundType, activeColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _soundType = val.toString()),
            ),

            // সাব-লিস্ট: যখন 'default' সিলেক্ট করা থাকবে, তখন এই লিস্টটি দেখাবে
            if (_soundType == 'default')
              Container(
                margin: const EdgeInsets.only(left: 20, bottom: 10, right: 10),
                // ম্যাজিক এখানে: লিস্টের সর্বোচ্চ উচ্চতা ঠিক করে দেওয়া হয়েছে যাতে স্ক্রল করা যায়
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _appRingtones.map((ringtone) {
                      return RadioListTile<String>(
                        title: Text(ringtone['name']!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        value: ringtone['file']!,
                        groupValue: _defaultSound,
                        activeColor: Colors.greenAccent,
                        dense: true,
                        onChanged: (val) {
                          setState(() => _defaultSound = val!);
                          // ইউজার সিলেক্ট করলেই সাউন্ডটি একবার বেজে উঠবে (Preview)
                          AudioService().previewDefaultSound(val!);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            // ==============================================

            RadioListTile(
              title: const Text("Audio File (Custom)", style: TextStyle(color: Colors.white)),
              value: 'file', groupValue: _soundType, activeColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _soundType = val.toString()),
            ),
            if (_soundType == 'file')
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(_customAudioPath.isEmpty ? "No file selected" : _customAudioPath.split('/').last, style: const TextStyle(color: Colors.grey), maxLines: 1)),
                    TextButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder, color: Colors.blueAccent), label: const Text("Select File", style: TextStyle(color: Colors.blueAccent)))
                  ],
                ),
              ),
            RadioListTile(
              title: const Text("Text To Speech (TTS)", style: TextStyle(color: Colors.white)),
              value: 'tts', groupValue: _soundType, activeColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _soundType = val.toString()),
            ),
            if (_soundType == 'tts')
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: TextField(
                  controller: _ttsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter text here...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true, fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text("SAVE SETTINGS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}