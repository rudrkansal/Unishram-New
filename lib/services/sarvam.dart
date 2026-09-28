import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Client for Sarvam AI — speech synthesis (Bulbul) and recognition (Saarika)
/// for Indian languages.
///
/// Chosen over self-hosting AI4Bharat because it is a hosted API with one
/// vendor for both directions and Indian data residency, which matters for
/// DPDP. The trade-off is cost per request and a network dependency, so every
/// call falls back to the on-device engine rather than failing the user.
///
/// Endpoints and payload shapes are implemented from Sarvam's published
/// contract and are deliberately tolerant about response shapes. Verify against
/// the current documentation before you ship.
class SarvamClient {
  SarvamClient({
    required this.apiKey,
    this.baseUrl = 'https://api.sarvam.ai',
    this.ttsModel = 'bulbul:v2',
    this.asrModel = 'saarika:v2',
    this.speaker = 'anushka',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final String ttsModel;
  final String asrModel;
  final String speaker;
  final http.Client _client;

  /// Language codes Sarvam accepts. Note Odia is `od-IN`, not `or-IN`.
  ///
  /// This map is the whole story: a language either has a real voice here or
  /// the app offers no voice for it at all. Reading Bengali to an Assamese
  /// speaker, or Marathi to a Konkani one, sounds careless rather than helpful.
  static const Map<String, String> _languageCodes = {
    'en': 'en-IN',
    'hi': 'hi-IN',
    'bn': 'bn-IN',
    'gu': 'gu-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'mr': 'mr-IN',
    'or': 'od-IN',
    'pa': 'pa-IN',
    'ta': 'ta-IN',
    'te': 'te-IN',
  };

  /// Maps an app language code onto a Sarvam language code, or null when the
  /// language has no voice.
  static String? languageCodeFor(String appLanguage) =>
      _languageCodes[appLanguage];

  static bool supports(String appLanguage) =>
      _languageCodes.containsKey(appLanguage);

  /// The languages the app offers voice for. Everything else hides the Listen
  /// and microphone buttons rather than speaking in the wrong language.
  static Set<String> get supportedLanguages => _languageCodes.keys.toSet();

  Map<String, String> get _headers => {
        'api-subscription-key': apiKey,
        'Content-Type': 'application/json',
      };

  /// Synthesises [text]. Returns null on any failure, which the caller treats
  /// as "use the device voice instead".
  Future<Uint8List?> synthesise({
    required String text,
    required String languageCode,
    double pace = 1.0,
  }) async {
    if (apiKey.isEmpty || text.trim().isEmpty) return null;
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/text-to-speech'),
            headers: _headers,
            body: jsonEncode({
              'inputs': [text],
              'target_language_code': languageCode,
              'speaker': speaker,
              'pace': pace,
              'model': ttsModel,
              'enable_preprocessing': true,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map) return null;

      final audios = body['audios'];
      final encoded = (audios is List && audios.isNotEmpty)
          ? audios.first
          : body['audio'] ?? body['audio_base64'];
      return encoded is String ? base64Decode(encoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// Transcribes a recorded clip. Saarika takes short audio, which suits
  /// one-shot commands.
  Future<String?> transcribe({
    required File audio,
    required String languageCode,
  }) async {
    if (apiKey.isEmpty || !await audio.exists()) return null;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/speech-to-text'),
      )
        ..headers['api-subscription-key'] = apiKey
        ..fields['model'] = asrModel
        ..fields['language_code'] = languageCode
        ..files.add(await http.MultipartFile.fromPath('file', audio.path));

      final streamed =
          await request.send().timeout(const Duration(seconds: 20));
      if (streamed.statusCode != 200) return null;

      final body = jsonDecode(await streamed.stream.bytesToString());
      if (body is! Map) return null;
      final transcript = body['transcript'] ?? body['text'] ?? body['output'];
      return transcript is String && transcript.trim().isNotEmpty
          ? transcript.trim()
          : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
