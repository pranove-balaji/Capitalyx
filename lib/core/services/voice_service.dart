import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String get _apiKey =>
      dotenv.env['GOOGLE_CLOUD_API_KEY'] ??
      dotenv.env['google_cloud_api_key'] ??
      "";

  bool _isRequestingPermission = false;

  Future<bool> hasPermission() async {
    if (_isRequestingPermission) return false;

    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    try {
      _isRequestingPermission = true;
      status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print("Permission request error: $e");
      return false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/temp_recording.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1, // Google STT prefers Mono
      );

      print("VoiceService: Starting recording to $path");
      await _audioRecorder.start(config, path: path);
    }
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    print("VoiceService: Recording stopped, path: $path");
    return path;
  }

  Future<void> stopPlayer() async {
    await _audioPlayer.stop();
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }

  /// STT: Transcribe audio file using Google Cloud Speech-to-Text
  Future<String?> transcribe(String filePath, String languageCode) async {
    final file = File(filePath);
    if (!await file.exists()) {
      print("VoiceService Error: Audio file does not exist at $filePath");
      return null;
    }
    final fileSize = await file.length();
    print("VoiceService: Audio file size: $fileSize bytes");

    if (fileSize < 100) {
      print(
          "VoiceService Warning: Audio file is too small (likely silence or header only).");
      return null;
    }

    final audioBytes = await file.readAsBytes();
    final audioBase64 = base64Encode(audioBytes);

    final url = Uri.parse(
        'https://speech.googleapis.com/v1/speech:recognize?key=$_apiKey');

    // Mapping flutter locales to Google STT locales if needed.
    // 'ta' -> 'ta-IN', 'hi' -> 'hi-IN', etc.
    String sttLang = _mapToSttLocale(languageCode);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'config': {
          // 'encoding': 'LINEAR16', // Removed: Let Google auto-detect WAV header
          // 'sampleRateHertz': 16000, // Removed: Let Google auto-detect from WAV header
          'languageCode': sttLang,
          'enableAutomaticPunctuation': true,
        },
        'audio': {'content': audioBase64}
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      print("STT Response: $jsonResponse"); // Debug log

      if (jsonResponse['results'] != null &&
          (jsonResponse['results'] as List).isNotEmpty) {
        return jsonResponse['results'][0]['alternatives'][0]['transcript'];
      }
      print("STT Warning: Valid 200 response but no results found.");
    } else {
      print('STT Error: ${response.statusCode} - ${response.body}');
    }
    return null;
  }

  /// TTS: Convert Text to Speech using Google Cloud Text-to-Speech
  Future<void> speak(String text, String languageCode) async {
    final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey');

    String ttsLang = _mapToSttLocale(
        languageCode); // reuse mapping for now locale is 'en-US', 'ta-IN' etc.

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {'languageCode': ttsLang, 'ssmlGender': 'NEUTRAL'},
        'audioConfig': {'audioEncoding': 'MP3'}
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final audioContent = jsonResponse['audioContent'];
      if (audioContent != null) {
        final bytes = base64Decode(audioContent);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_output.mp3');
        await file.writeAsBytes(bytes);

        await _audioPlayer.play(DeviceFileSource(file.path));
      }
    } else {
      print('TTS Error: ${response.body}');
    }
  }

  String _mapToSttLocale(String simpleLangCode) {
    switch (simpleLangCode) {
      case 'ta':
        return 'ta-IN';
      case 'hi':
        return 'hi-IN';
      case 'ml':
        return 'ml-IN';
      case 'te':
        return 'te-IN';
      case 'kn':
        return 'kn-IN';
      case 'mr':
        return 'mr-IN';
      case 'en':
      default:
        return 'en-US';
    }
  }
}
