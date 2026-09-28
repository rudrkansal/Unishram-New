import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'cloud_speech.dart';
import 'indic_script.dart';
import 'voice_config.dart';

/// How a line ended up being spoken, so the UI can be honest about it.
enum SpeechRoute {
  /// A real voice for the chosen language.
  native,

  /// No voice for this language, so the text was re-encoded as Devanagari and
  /// read by a Hindi voice. Still the user's own words, in their own language,
  /// with an approximate accent.
  transliterated,

  /// A cloud engine produced the audio.
  cloud,

  /// Nothing could be spoken.
  unavailable,
}

/// Reads screen copy aloud. Low-literacy users depend on this, so every failure
/// path has to end somewhere audible or visibly explained — never in silence
/// with the button stuck on "Listening…".
class TtsService {
  TtsService({VoiceConfig? config})
      : config = config ?? VoiceConfig.fromEnvironment() {
    _cloud = this.config.usesCloudTts ? CloudSpeech(this.config) : null;
  }

  final VoiceConfig config;
  final FlutterTts _tts = FlutterTts();
  CloudSpeech? _cloud;

  bool _ready = false;
  List<String> _deviceLanguages = const [];
  Timer? _watchdog;
  StreamSubscription<void>? _cloudCompletion;

  bool speaking = false;
  SpeechRoute lastRoute = SpeechRoute.native;
  VoidCallback? onStateChanged;

  Future<void> _ensureReady() async {
    if (_ready) return;
    _ready = true;

    // Each step is guarded separately on purpose. These calls are not supported
    // by every engine — `awaitSpeakCompletion` is Android/iOS only — and a
    // single throw used to skip everything after it, leaving no completion
    // handler and an empty language list, which made the app refuse to speak
    // at all.
    await _attempt(() => _tts.awaitSpeakCompletion(true));
    await _attempt(() async {
      _tts.setCompletionHandler(() => _set(false));
      _tts.setCancelHandler(() => _set(false));
      _tts.setErrorHandler((_) => _set(false));
    });
    await _attempt(() => _tts.setSpeechRate(config.speechRate));
    await _attempt(() => _tts.setPitch(1.0));
    await _attempt(() => _tts.setVolume(1.0));
    await _loadDeviceLanguages();
  }

  /// The platform's voice catalogue is not always ready the instant the app
  /// starts — on the web especially, the browser loads it asynchronously and a
  /// query made in that window comes back empty. Queried once with no retry,
  /// that empty result used to get cached for the rest of the session: a
  /// language with a perfectly good voice would look unsupported for however
  /// long the app happened to stay open, and which languages were affected
  /// depended on nothing more meaningful than which one the user tapped first.
  /// A few short retries closes that window without a real device ever
  /// noticeably delaying speech.
  Future<void> _loadDeviceLanguages() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      var found = false;
      await _attempt(() async {
        final languages = await _tts.getLanguages;
        if (languages is List && languages.isNotEmpty) {
          _deviceLanguages =
              languages.map((e) => e.toString()).toList(growable: false);
          found = true;
        }
      });
      if (found) return;
    }
  }

  static Future<void> _attempt(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // Unsupported on this engine; the remaining setup still applies.
    }
  }

  /// Finds a device language tag matching [languageTag], comparing loosely
  /// because engines report `hi-IN`, `hi_IN` or plain `hi` depending on vendor.
  ///
  /// When the engine will not list its languages, assume the requested one
  /// works: most engines speak it anyway, and refusing to try guarantees
  /// silence.
  String? _match(String languageTag) {
    if (_deviceLanguages.isEmpty) return languageTag;
    final wanted = _normalise(languageTag);
    final base = wanted.split('_').first;

    for (final candidate in _deviceLanguages) {
      if (_normalise(candidate) == wanted) return candidate;
    }
    for (final candidate in _deviceLanguages) {
      if (_normalise(candidate).split('_').first == base) return candidate;
    }
    return null;
  }

  static String _normalise(String tag) =>
      tag.toLowerCase().replaceAll('-', '_').trim();

  /// Speaks [text] in [languageTag].
  ///
  /// The app only offers voice for languages it can do properly, so there is no
  /// substituting one language for another here: either the words are spoken in
  /// the user's own language, or nothing is.
  Future<SpeechRoute> speak(
    String text,
    String languageTag, {
    String? languageCode,
  }) async {
    if (text.trim().isEmpty) return SpeechRoute.unavailable;
    await stop();
    await _ensureReady();

    // A cloud engine covers languages no phone ships; try it first when set up.
    final cloud = _cloud;
    if (cloud != null) {
      _set(true, SpeechRoute.cloud);
      _cloudCompletion ??= cloud.onComplete.listen((_) => _set(false));
      if (await cloud.speak(text, languageCode ?? 'en')) {
        _armWatchdog(text);
        return SpeechRoute.cloud;
      }
      // Fall through to the device engine rather than going quiet.
      _set(false);
    }

    final native = _match(languageTag);
    var spokenText = text;
    var route = SpeechRoute.native;
    var engineLanguage = native;

    if (native == null) {
      // A Brahmic script can be re-encoded so a Hindi voice reads the same
      // words. Anything else stays unspoken rather than switching language.
      final hindi = _match('hi-IN');
      if (hindi != null && isBrahmic(text)) {
        engineLanguage = hindi;
        spokenText = toDevanagari(text, languageCode: languageCode);
        route = SpeechRoute.transliterated;
      } else {
        _set(false, SpeechRoute.unavailable);
        return SpeechRoute.unavailable;
      }
    }

    try {
      if (engineLanguage != null) await _tts.setLanguage(engineLanguage);
      _set(true, route);
      await _tts.speak(spokenText);
      _armWatchdog(spokenText);
      return route;
    } catch (_) {
      _set(false, SpeechRoute.unavailable);
      return SpeechRoute.unavailable;
    }
  }

  /// Some engines never report completion. Clear the speaking state after a
  /// generous estimate so the button cannot stick.
  void _armWatchdog(String text) {
    _watchdog?.cancel();
    final seconds = (text.length / 9).ceil().clamp(4, 45);
    _watchdog = Timer(Duration(seconds: seconds + 2), () {
      if (speaking) _set(false);
    });
  }

  Future<void> stop() async {
    _watchdog?.cancel();
    try {
      await _tts.stop();
    } catch (_) {}
    await _cloud?.stop();
    _set(false);
  }

  Future<SpeechRoute> toggle(
    String text,
    String languageTag, {
    String? languageCode,
  }) async {
    if (speaking) {
      await stop();
      return SpeechRoute.unavailable;
    }
    return speak(text, languageTag, languageCode: languageCode);
  }

  void _set(bool value, [SpeechRoute? route]) {
    if (route != null) lastRoute = route;
    if (speaking == value) return;
    speaking = value;
    onStateChanged?.call();
  }

  void dispose() {
    _watchdog?.cancel();
    _cloudCompletion?.cancel();
    _cloud?.dispose();
  }
}
