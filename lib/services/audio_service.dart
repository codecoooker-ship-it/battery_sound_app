import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // অ্যালার্ম প্লে করার আপডেট করা ফাংশন (defaultSound যুক্ত করা হয়েছে)
  Future<void> playAlarm({
    required String soundType,
    String? audioPath,
    String? ttsText,
    String? defaultSound,
  }) async {
    await stopAlarm();
    _isPlaying = true;

    if (soundType == 'tts' && ttsText != null) {
      await _setupTts();
      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
      });
      await _flutterTts.speak(ttsText);
    }
    else if (soundType == 'file' && audioPath != null && audioPath.isNotEmpty) {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _audioPlayer.onPlayerComplete.listen((event) {
        _isPlaying = false;
      });
      await _audioPlayer.play(DeviceFileSource(audioPath));
    }
    else {
      // Default রিংটোনের লিস্ট থেকে যেটি সিলেক্ট করা আছে সেটি বাজবে
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _audioPlayer.onPlayerComplete.listen((event) {
        _isPlaying = false;
      });

      String assetFile = (defaultSound != null && defaultSound.isNotEmpty) ? defaultSound : 'aabe_saale.mp3';
      await _audioPlayer.play(AssetSource('audio/$assetFile'));
    }
  }

  // Settings থেকে সিলেক্ট করার সাথে সাথে Preview শোনানোর ফাংশন
  Future<void> previewDefaultSound(String fileName) async {
    await stopAlarm();
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.play(AssetSource('audio/$fileName'));
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> stopAlarm() async {
    if (_isPlaying) {
      _isPlaying = false;
      await _audioPlayer.stop();
      await _flutterTts.stop();
    }
  }
}