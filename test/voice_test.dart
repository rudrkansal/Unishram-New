import 'package:flutter_test/flutter_test.dart';
import 'package:labour_marketplace/services/indic_script.dart';
import 'package:labour_marketplace/services/sarvam.dart';
import 'package:labour_marketplace/services/voice_command_service.dart';
import 'package:labour_marketplace/services/voice_config.dart';

void main() {
  group('command matching', () {
    test('matches whole words, not fragments inside other words', () {
      // "posted" used to trigger the Post-a-job screen.
      expect(matchIntent('I posted nothing'), isNot(VoiceIntent.postJob));
      expect(matchIntent('post'), VoiceIntent.postJob);
    });

    test('a longer phrase wins over a word it contains', () {
      expect(matchIntent('post a job'), VoiceIntent.postJob);
      expect(matchIntent('find workers'), VoiceIntent.findWorkers);
    });

    test('understands Indian languages beyond English and Hindi', () {
      expect(matchIntent('কাজ'), VoiceIntent.jobs); // Bengali
      expect(matchIntent('வேலை'), VoiceIntent.jobs); // Tamil
      expect(matchIntent('ಕೆಲಸ'), VoiceIntent.jobs); // Kannada
      expect(matchIntent('کام'), VoiceIntent.jobs); // Urdu
      expect(matchIntent('ପ୍ରୋଫାଇଲ'), VoiceIntent.profile); // Odia
      expect(matchIntent('వెనుకకు'), VoiceIntent.back); // Telugu
    });

    test('still works with Hindi and Punjabi', () {
      expect(matchIntent('काम'), VoiceIntent.jobs);
      expect(matchIntent('ਪ੍ਰੋਫ਼ਾਈਲ'), VoiceIntent.profile);
    });

    test('ignores punctuation the recogniser adds', () {
      expect(matchIntent('काम।'), VoiceIntent.jobs);
      expect(matchIntent('Profile.'), VoiceIntent.profile);
    });

    test('returns nothing for speech that is not a command', () {
      expect(matchIntent('what is the weather'), isNull);
      expect(matchIntent(''), isNull);
    });
  });

  group('script fallback for languages with no device voice', () {
    test('detects Brahmic scripts', () {
      expect(isBrahmic('বাংলা'), isTrue);
      expect(isBrahmic('தமிழ்'), isTrue);
      expect(isBrahmic('English'), isFalse);
      expect(isBrahmic('اردو'), isFalse); // Perso-Arabic has no mapping
    });

    test('re-encodes Bengali into Devanagari a Hindi voice can read', () {
      // ক (U+0995) sits 0x080 above क (U+0915).
      expect(toDevanagari('ক'), 'क');
      expect(toDevanagari('বাংলা').codeUnits.first, 0x092C); // ब
    });

    test('re-encodes Gurmukhi, Gujarati, Tamil and Telugu', () {
      expect(toDevanagari('ਕ'), 'क');
      expect(toDevanagari('ક'), 'क');
      expect(toDevanagari('க'), 'क');
      expect(toDevanagari('క'), 'क');
    });

    test('applies Assamese phonetics so it does not read as Bengali', () {
      // Assamese স is a velar fricative, not /s/.
      expect(toDevanagari('স', languageCode: 'as'), 'ख़');
      expect(toDevanagari('স', languageCode: 'bn'), 'स');
    });

    test('leaves Latin text alone', () {
      expect(toDevanagari('UniShram'), 'UniShram');
    });
  });

  sarvamTests();
  scriptDetectionTests();
}

/// Sarvam language mapping. Getting this wrong is silent and expensive: a bad
/// code means every request fails and every user falls back to a device voice
/// that may not exist.
void sarvamTests() {
  group('Sarvam language mapping', () {
    test('maps the languages Sarvam supports natively', () {
      expect(SarvamClient.languageCodeFor('hi'), 'hi-IN');
      expect(SarvamClient.languageCodeFor('ta'), 'ta-IN');
      expect(SarvamClient.languageCodeFor('bn'), 'bn-IN');
      expect(SarvamClient.supports('hi'), isTrue);
    });

    test('uses od-IN for Odia, not or-IN', () {
      expect(SarvamClient.languageCodeFor('or'), 'od-IN');
    });

    test('offers no voice at all for languages it cannot speak', () {
      // Speaking Bengali to an Assamese user, or Marathi to a Konkani one,
      // reads as careless. These languages get a text-only app instead.
      for (final code in [
        'as', 'brx', 'doi', 'kok', 'mai', 'mni', 'ne', 'sa', 'sat', 'sd',
        'ks', 'ur',
      ]) {
        expect(SarvamClient.supports(code), isFalse,
            reason: '$code should not be offered voice');
        expect(SarvamClient.languageCodeFor(code), isNull);
      }
    });

    test('covers exactly the eleven languages Sarvam speaks', () {
      expect(
        SarvamClient.supportedLanguages,
        {'en', 'hi', 'bn', 'gu', 'kn', 'ml', 'mr', 'or', 'pa', 'ta', 'te'},
      );
    });
  });

  group('voice configuration', () {
    test('stays on device voices when no key is set', () {
      const config = VoiceConfig();
      expect(config.usesCloudTts, isFalse);
      expect(config.usesCloudAsr, isFalse);
    });

    test('enables both directions once a key is present', () {
      const config = VoiceConfig(apiKey: 'test-key');
      expect(config.usesCloudTts, isTrue);
      expect(config.usesCloudAsr, isTrue);
    });

    test('recognition can be disabled without disabling synthesis', () {
      const config = VoiceConfig(apiKey: 'test-key', cloudSpeechIn: false);
      expect(config.usesCloudTts, isTrue);
      expect(config.usesCloudAsr, isFalse);
    });
  });
}

/// The app is only fully translated into English, Hindi and Punjabi. What gets
/// spoken has to follow the script actually on screen, or a Tamil voice ends up
/// reading English words.
void scriptDetectionTests() {
  group('language of a line, judged by script', () {
    test('detects the Indian scripts the app displays', () {
      expect(scriptLanguage('आपके पास काम'), 'hi');
      expect(scriptLanguage('বাংলা'), 'bn');
      expect(scriptLanguage('ਪੰਜਾਬੀ'), 'pa');
      expect(scriptLanguage('தமிழ்'), 'ta');
      expect(scriptLanguage('ಕನ್ನಡ'), 'kn');
      expect(scriptLanguage('اردو'), 'ur');
    });

    test('English body text is spoken in English, whatever was selected', () {
      expect(scriptLanguage('Jobs near you'), 'en');
      expect(scriptLanguage('Post a Job'), 'en');
    });

    test('mixed lines follow the dominant script, not the first character', () {
      expect(scriptLanguage('₹750/day आपके पास काम मिलेगा'), 'hi');
      expect(scriptLanguage('Site Mason needed ₹750'), 'en');
    });

    test('gives up on text with no letters', () {
      expect(scriptLanguage('₹750'), isNull);
      expect(scriptLanguage(''), isNull);
    });
  });
}
