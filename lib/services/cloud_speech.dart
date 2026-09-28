import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'sarvam.dart';
import 'voice_config.dart';

/// Plays Sarvam-synthesised audio, caching by phrase.
///
/// Screen titles and button labels repeat constantly, so caching keeps both
/// latency and spend down — a worker tapping Listen twice on the same screen
/// costs one request, not two.
class CloudSpeech {
  CloudSpeech(this.config, {SarvamClient? client, AudioPlayer? player})
      : _client = client ??
            SarvamClient(apiKey: config.apiKey, baseUrl: config.baseUrl),
        _player = player ?? AudioPlayer();

  final VoiceConfig config;
  final SarvamClient _client;
  final AudioPlayer _player;
  final Map<String, Uint8List> _cache = {};

  static const _maxCacheEntries = 60;

  SarvamClient get client => _client;
  Stream<void> get onComplete => _player.onPlayerComplete;

  /// Returns false when the cloud could not produce audio, which is the
  /// caller's signal to fall back to the device voice.
  Future<bool> speak(String text, String appLanguage) async {
    if (!config.usesCloudTts || text.trim().isEmpty) return false;

    final languageCode = SarvamClient.languageCodeFor(appLanguage);
    if (languageCode == null) return false;

    final key = '$languageCode|$text';
    final cached = _cache[key];
    if (cached != null) return _play(cached);

    final audio = await _client.synthesise(
      text: text,
      languageCode: languageCode,
      pace: config.speechRate,
    );
    if (audio == null || audio.isEmpty) return false;

    if (_cache.length >= _maxCacheEntries) _cache.remove(_cache.keys.first);
    _cache[key] = audio;
    return _play(audio);
  }

  Future<bool> _play(Uint8List audio) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(audio));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _client.dispose();
    _player.dispose();
  }
}
