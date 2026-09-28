/// How speech is produced and recognised.
///
/// Device engines are free and work offline but cover few Indian languages.
/// Sarvam AI covers eleven properly and substitutes sensibly for the rest, at a
/// cost per request and only with a connection.
///
/// Configured at build time so no key is ever committed:
///
///   flutter run --dart-define=SARVAM_API_KEY=xxxxx
///
/// With no key the app uses device voices, which is the safe default.
class VoiceConfig {
  const VoiceConfig({
    this.apiKey = '',
    this.baseUrl = 'https://api.sarvam.ai',
    this.speechRate = 0.45,
    this.cloudSpeechOut = true,
    this.cloudSpeechIn = true,
  });

  final String apiKey;
  final String baseUrl;
  final double speechRate;

  /// Cloud synthesis for the Listen button.
  final bool cloudSpeechOut;

  /// Cloud recognition for spoken commands. Costs a request per command and
  /// sends a short audio clip to Sarvam, so it can be turned off separately.
  final bool cloudSpeechIn;

  bool get hasKey => apiKey.isNotEmpty;
  bool get usesCloudTts => hasKey && cloudSpeechOut;
  bool get usesCloudAsr => hasKey && cloudSpeechIn;

  static VoiceConfig fromEnvironment() {
    const key = String.fromEnvironment('SARVAM_API_KEY');
    const baseUrl = String.fromEnvironment('SARVAM_BASE_URL',
        defaultValue: 'https://api.sarvam.ai');
    const rate = String.fromEnvironment('TTS_RATE', defaultValue: '0.45');
    const speechOut =
        bool.fromEnvironment('CLOUD_SPEECH_OUT', defaultValue: true);
    const speechIn =
        bool.fromEnvironment('CLOUD_SPEECH_IN', defaultValue: true);
    return const VoiceConfig(
      apiKey: key,
      baseUrl: baseUrl,
      cloudSpeechOut: speechOut,
      cloudSpeechIn: speechIn,
    ).copyWith(speechRate: double.tryParse(rate) ?? 0.45);
  }

  VoiceConfig copyWith({double? speechRate}) => VoiceConfig(
        apiKey: apiKey,
        baseUrl: baseUrl,
        speechRate: speechRate ?? this.speechRate,
        cloudSpeechOut: cloudSpeechOut,
        cloudSpeechIn: cloudSpeechIn,
      );
}
