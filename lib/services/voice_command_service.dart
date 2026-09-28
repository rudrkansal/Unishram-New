import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'sarvam.dart';
import 'voice_config.dart';

/// Why a listen attempt could not start, so the app can say something useful
/// instead of "didn't catch that".
enum VoiceFailure {
  /// Microphone permission refused, or no recogniser on the device.
  unavailable,

  /// Recognition works, but not for the language the user picked.
  languageUnsupported,
}

class VoiceListenResult {
  final bool started;
  final VoiceFailure? failure;
  final String? localeId;

  const VoiceListenResult.started(this.localeId)
      : started = true,
        failure = null;

  const VoiceListenResult.failed(this.failure)
      : started = false,
        localeId = null;
}

/// Spoken navigation. A worker who cannot read the labels can still say
/// "काम" and land on the jobs screen.
class VoiceCommandService {
  VoiceCommandService(
      {VoiceConfig? config, SarvamClient? sarvam, AudioRecorder? recorder})
      : config = config ?? VoiceConfig.fromEnvironment(),
        _recorder = recorder ?? AudioRecorder() {
    final resolved = this.config;
    _sarvam = sarvam ??
        (resolved.usesCloudAsr
            ? SarvamClient(apiKey: resolved.apiKey, baseUrl: resolved.baseUrl)
            : null);
  }

  final VoiceConfig config;
  final SpeechToText _speech = SpeechToText();
  final AudioRecorder _recorder;
  SarvamClient? _sarvam;

  bool _available = false;
  bool _initTried = false;
  List<LocaleName> _locales = const [];

  /// Set while a clip is being recorded for cloud recognition.
  String? _recordingPath;
  String? _recordingLanguage;
  Timer? _recordingTimeout;
  void Function(String transcript)? _pendingCommand;

  bool listening = false;
  bool transcribing = false;
  String heard = '';
  VoidCallback? onStateChanged;

  Future<bool> _init() async {
    if (_initTried) return _available;
    _initTried = true;
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            listening = false;
            onStateChanged?.call();
          }
        },
        onError: (_) {
          listening = false;
          onStateChanged?.call();
        },
      );
      if (_available) _locales = await _speech.locales();
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Android reports locales as `hi_IN`, iOS as `hi-IN`, and some devices as
  /// plain `hi`. Passing a tag the recogniser does not know silently falls back
  /// to the phone's default language, so a Tamil speaker gets recognised as
  /// English — match against the real list instead of guessing.
  String? resolveLocale(String languageTag) {
    if (_locales.isEmpty) return null;
    final wanted = _normalise(languageTag);
    final base = wanted.split('_').first;

    for (final locale in _locales) {
      if (_normalise(locale.localeId) == wanted) return locale.localeId;
    }
    for (final locale in _locales) {
      if (_normalise(locale.localeId).split('_').first == base) {
        return locale.localeId;
      }
    }
    return null;
  }

  static String _normalise(String tag) =>
      tag.toLowerCase().replaceAll('-', '_').trim();

  /// Starts listening in the user's own language, or not at all. Listening in
  /// a different language would mis-hear every command, which is worse than
  /// telling the user plainly that speech is unavailable here.
  Future<VoiceListenResult> listen({
    required String languageTag,
    required void Function(String transcript) onCommand,
    String? appLanguage,
  }) async {
    // Cloud recognition covers languages the phone does not, so prefer it when
    // it is configured and knows the language.
    final language = appLanguage ?? languageTag.split(RegExp('[-_]')).first;
    // Recording to a temp file has no equivalent on web; use the browser's own
    // recogniser there instead of failing.
    if (!kIsWeb && _sarvam != null && SarvamClient.supports(language)) {
      final started = await _listenViaCloud(language, onCommand);
      if (started != null) return started;
      // Recording failed (no permission, no microphone) — try the device.
    }
    return _listenOnDevice(languageTag, onCommand);
  }

  /// Records a short clip and sends it to Sarvam when the user stops. Returns
  /// null when recording could not start, so the caller falls back.
  Future<VoiceListenResult?> _listenViaCloud(
    String appLanguage,
    void Function(String transcript) onCommand,
  ) async {
    try {
      if (!await _recorder.hasPermission()) return null;

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/command_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      _recordingPath = path;
      _recordingLanguage = appLanguage;
      _pendingCommand = onCommand;
      heard = '';
      listening = true;
      onStateChanged?.call();

      // Commands are short; stop on their behalf so a forgotten tap does not
      // record — and bill — indefinitely.
      _recordingTimeout?.cancel();
      _recordingTimeout = Timer(const Duration(seconds: 7), stop);

      return VoiceListenResult.started(appLanguage);
    } catch (_) {
      _recordingPath = null;
      _pendingCommand = null;
      return null;
    }
  }

  Future<VoiceListenResult> _listenOnDevice(
    String languageTag,
    void Function(String transcript) onCommand,
  ) async {
    if (!await _init()) {
      return const VoiceListenResult.failed(VoiceFailure.unavailable);
    }

    final localeId = resolveLocale(languageTag);
    if (localeId == null) {
      return const VoiceListenResult.failed(VoiceFailure.languageUnsupported);
    }

    heard = '';
    listening = true;
    onStateChanged?.call();

    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          partialResults: true,
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          heard = result.recognizedWords;
          onStateChanged?.call();
          if (result.finalResult) {
            listening = false;
            onStateChanged?.call();
            onCommand(result.recognizedWords);
          }
        },
      );
    } catch (_) {
      listening = false;
      onStateChanged?.call();
      return const VoiceListenResult.failed(VoiceFailure.unavailable);
    }

    return VoiceListenResult.started(localeId);
  }

  /// Stops listening. For a cloud recording this is also "I have finished
  /// speaking", so the clip is transcribed here.
  Future<void> stop() async {
    _recordingTimeout?.cancel();

    if (_recordingPath != null) {
      await _finishCloudRecording();
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {}
    listening = false;
    heard = '';
    onStateChanged?.call();
  }

  Future<void> _finishCloudRecording() async {
    final path = _recordingPath;
    final language = _recordingLanguage;
    final onCommand = _pendingCommand;
    _recordingPath = null;
    _recordingLanguage = null;
    _pendingCommand = null;

    listening = false;
    transcribing = true;
    onStateChanged?.call();

    String? transcript;
    try {
      await _recorder.stop();
      final languageCode =
          language == null ? null : SarvamClient.languageCodeFor(language);
      final file = path == null ? null : File(path);
      if (file != null && languageCode != null) {
        transcript = await _sarvam?.transcribe(
          audio: file,
          languageCode: languageCode,
        );
      }
      // The clip has served its purpose; do not leave voice recordings around.
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      transcript = null;
    }

    transcribing = false;
    heard = transcript ?? '';
    onStateChanged?.call();
    if (transcript != null) onCommand?.call(transcript);
  }

  void dispose() {
    _recordingTimeout?.cancel();
    _recorder.dispose();
    _sarvam?.dispose();
  }
}

/// The commands the app understands.
enum VoiceIntent {
  jobs,
  applications,
  profile,
  ratings,
  postJob,
  findWorkers,
  calculator,
  search,
  prices,
  listings,
  back,
  apply,
  switchRole,
  read,
}

/// Command words per intent. Recognition returns the user's own language, so
/// every language the app can be used in needs its own words — otherwise a
/// Bengali speaker is understood by the recogniser and then ignored by the app.
const Map<VoiceIntent, List<String>> kVoicePhrases = {
  VoiceIntent.jobs: [
    'job',
    'jobs',
    'work',
    'काम',
    'नौकरी',
    'ਕੰਮ',
    'কাজ',
    'કામ',
    'ಕೆಲಸ',
    'ജോലി',
    'କାମ',
    'வேலை',
    'పని',
    'کام',
    'नोकरी',
  ],
  VoiceIntent.applications: [
    'application',
    'applications',
    'applied',
    'आवेदन',
    'ਅਰਜ਼ੀ',
    'আবেদন',
    'અરજી',
    'ಅರ್ಜಿ',
    'അപേക്ഷ',
    'ଆବେଦନ',
    'விண்णப்பம்',
    'దరఖాస్తు',
    'درخواست',
  ],
  VoiceIntent.profile: [
    'profile',
    'my profile',
    'प्रोफाइल',
    'प्रोफ़ाइल',
    'ਪ੍ਰੋਫ਼ਾਈਲ',
    'প্রোফাইল',
    'પ્રોફાઇલ',
    'ಪ್ರೊಫೈಲ್',
    'പ്രൊഫൈൽ',
    'ପ୍ରୋଫାଇଲ',
    'சுயவிவரம்',
    'ప్రొఫైల్',
    'پروفائل',
  ],
  VoiceIntent.ratings: [
    'rating',
    'ratings',
    'review',
    'reviews',
    'रेटिंग',
    'ਰੇਟਿੰਗ',
    'রেটিং',
    'રેટિંગ',
    'ರೇಟಿಂಗ್',
    'റേറ്റിംഗ്',
    'ରେଟିଂ',
    'மதிப்பீடு',
    'రేటింగ్',
    'ریٹنگ',
  ],
  VoiceIntent.postJob: [
    'post a job',
    'post job',
    'post',
    'काम पोस्ट',
    'पोस्ट',
    'ਪੋਸਟ',
    'পোস্ট',
    'પોસ્ટ',
    'ಪೋಸ್ಟ್',
    'പോസ്റ്റ്',
    'ପୋଷ୍ଟ',
    'பதிவு',
    'పోస్ట్',
    'پوسٹ',
  ],
  VoiceIntent.findWorkers: [
    'find workers',
    'find worker',
    'workers',
    'worker',
    'labour',
    'मजदूर',
    'मज़दूर',
    'ਮਜ਼ਦੂਰ',
    'শ্রমিক',
    'મજૂર',
    'ಕಾರ್ಮಿಕ',
    'തൊഴിലാളി',
    'ଶ୍ରମିକ',
    'தொழிலாளி',
    'కార్మికుడు',
    'مزدور',
  ],
  VoiceIntent.calculator: [
    'calculator',
    'calculate',
    'cost',
    'गणना',
    'कैलकुलेटर',
    'लागत',
    'ਗਣਨਾ',
    'হিসাব',
    'ગણતરી',
    'ಲೆಕ್ಕ',
    'കണക്ക്',
    'ହିସାବ',
    'கணக்கு',
    'ఖర్చు',
    'حساب',
  ],
  VoiceIntent.search: [
    'search',
    'find',
    'खोज',
    'खोजें',
    'ਖੋਜ',
    'খোঁজ',
    'શોધ',
    'ಹುಡುಕು',
    'തിരയുക',
    'ଖୋଜ',
    'தேடு',
    'వెతుకు',
    'تلاش',
  ],
  VoiceIntent.prices: [
    'price',
    'prices',
    'material',
    'materials',
    'मूल्य',
    'भाव',
    'सामान',
    'ਭਾਅ',
    'দাম',
    'ભાવ',
    'ಬೆಲೆ',
    'വില',
    'ଦାମ',
    'விலை',
    'ధర',
    'قیمت',
  ],
  VoiceIntent.listings: [
    'listing',
    'listings',
    'सूची',
    'ਸੂਚੀ',
    'তালিকা',
    'યાદી',
    'ಪಟ್ಟಿ',
    'പട്ടിക',
    'ତାଲିକା',
    'பட்டியல்',
    'జాబితా',
    'فہرست',
  ],
  VoiceIntent.back: [
    'back',
    'go back',
    'वापस',
    'पीछे',
    'ਵਾਪਸ',
    'ফিরে',
    'પાછળ',
    'ಹಿಂದೆ',
    'തിരികെ',
    'ପଛକୁ',
    'பின்',
    'వెనుకకు',
    'واپس',
  ],
  VoiceIntent.apply: [
    'apply',
    'आवेदन करें',
    'अप्लाई',
    'ਅਰਜ਼ੀ ਦਿਓ',
    'আবেদন করুন',
    'અરજી કરો',
    'ಅರ್ಜಿ ಹಾಕು',
    'അപേക്ഷിക്കുക',
    'ଆବେଦନ କର',
    'விண்ணப்பி',
    'దరఖాస్తు చేయి',
  ],
  VoiceIntent.switchRole: [
    'switch role',
    'change role',
    'भूमिका',
    'ਭੂਮਿਕਾ',
    'ভূমিকা',
    'ભૂમિકા',
    'ಪಾತ್ರ',
    'വേഷം',
    'ଭୂମିକା',
    'பங்கு',
    'పాత్ర',
    'کردار',
  ],
  VoiceIntent.read: [
    'read',
    'listen',
    'speak',
    'सुनाओ',
    'सुनें',
    'पढ़ो',
    'ਸੁਣੋ',
    'শোনো',
    'સાંભળો',
    'ಕೇಳು',
    'കേൾക്കുക',
    'ଶୁଣ',
    'கேள்',
    'విను',
    'سنو',
  ],
};

/// Matches a transcript to an intent.
///
/// Matching is on whole words, not substrings: "post" inside "posted" or a
/// short Devanagari word inside a longer one used to trigger the wrong screen.
/// Multi-word phrases are checked first so "post a job" wins over "job".
VoiceIntent? matchIntent(String transcript) {
  final text = transcript.toLowerCase().trim();
  if (text.isEmpty) return null;

  final words =
      text.split(RegExp(r'[\s,.।!?]+')).where((w) => w.isNotEmpty).toSet();

  VoiceIntent? best;
  var bestLength = 0;

  kVoicePhrases.forEach((intent, phrases) {
    for (final phrase in phrases) {
      final candidate = phrase.toLowerCase();
      final matched = candidate.contains(' ')
          ? text.contains(candidate)
          : words.contains(candidate);
      if (matched && candidate.length > bestLength) {
        best = intent;
        bestLength = candidate.length;
      }
    }
  });

  return best;
}
