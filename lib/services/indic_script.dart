library;

/// Script helpers for speech.
///
/// Most Indian phones ship two or three Indic voices at most. Rather than let a
/// Bengali or Tamil user hear silence, text can be re-encoded into Devanagari
/// and read by a Hindi voice: the Brahmic blocks are laid out in parallel in
/// Unicode, so a fixed offset maps a character to its Devanagari counterpart.
/// Pronunciation is approximate but understandable, which beats nothing.

/// Unicode blocks that map onto Devanagari by a fixed offset.
const List<List<int>> _brahmicBlocks = [
  [0x0980, 0x09FF, 0x080], // Bengali / Assamese
  [0x0A00, 0x0A7F, 0x100], // Gurmukhi
  [0x0A80, 0x0AFF, 0x180], // Gujarati
  [0x0B00, 0x0B7F, 0x200], // Odia
  [0x0B80, 0x0BFF, 0x280], // Tamil
  [0x0C00, 0x0C7F, 0x300], // Telugu
  [0x0C80, 0x0CFF, 0x380], // Kannada
  [0x0D00, 0x0D7F, 0x400], // Malayalam
];

/// Characters with no positional equivalent, mapped by hand.
const Map<String, String> _special = {
  'ੜ': 'ड़',
  'ਖ਼': 'ख़',
  'ਗ਼': 'ग़',
  'ਜ਼': 'ज़',
  'ਫ਼': 'फ़',
  'ੰ': 'ं',
  'ੱ': '',
  'ੴ': '',
  'ড়': 'ड़',
  'ঢ়': 'ढ़',
  'য়': 'य़',
  'ৰ': 'र',
  'ৱ': 'व',
  'ଡ଼': 'ड़',
  'ଢ଼': 'ढ़',
};

/// Assamese shares Bengali's block but not its phonology: শ/ষ/স are a velar
/// fricative, চ is /s/, জ is /z/. Without this pass Assamese and Bengali read
/// aloud identically through a Hindi voice.
const Map<String, String> _assamese = {
  'श': 'ख़',
  'ष': 'ख़',
  'स': 'ख़',
  'च': 'स',
  'छ': 'स',
  'ज': 'ज़',
  'झ': 'ज़',
  'ड': 'र',
  'ढ': 'र',
};

final RegExp _brahmicPattern = RegExp(r'[ऀ-෿]');

bool isBrahmic(String text) => _brahmicPattern.hasMatch(text);

/// Re-encodes Brahmic text as Devanagari so a Hindi voice can read it.
String toDevanagari(String text, {String? languageCode}) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final replacement = _special[char];
    if (replacement != null) {
      buffer.write(replacement);
      continue;
    }
    final block = _brahmicBlocks
        .cast<List<int>?>()
        .firstWhere((b) => rune >= b![0] && rune <= b[1], orElse: () => null);
    buffer.write(block == null ? char : String.fromCharCode(rune - block[2]));
  }

  final devanagari = buffer.toString();
  if (languageCode != 'as') return devanagari;

  final assamese = StringBuffer();
  for (final char in devanagari.split('')) {
    assamese.write(_assamese[char] ?? char);
  }
  return assamese.toString();
}

/// Which language a piece of text is actually written in, judged by script.
///
/// The app's own copy is complete only in English, Hindi and Punjabi; a user who
/// picks Tamil sees mostly English text. Speaking that English with a Tamil
/// voice produces nonsense, so what gets spoken must follow the script in front
/// of the user rather than the language they selected.
///
/// Returns null when there is nothing recognisable to go on.
String? scriptLanguage(String text) {
  final counts = <String, int>{};
  for (final rune in text.runes) {
    final code = _languageOfRune(rune);
    if (code != null) counts[code] = (counts[code] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  // Mixed strings are common ("₹750/day" beside Devanagari), so the dominant
  // script wins rather than the first one seen.
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String? _languageOfRune(int rune) {
  if (rune >= 0x0900 && rune <= 0x097F) return 'hi'; // Devanagari
  if (rune >= 0x0980 && rune <= 0x09FF) return 'bn'; // Bengali / Assamese
  if (rune >= 0x0A00 && rune <= 0x0A7F) return 'pa'; // Gurmukhi
  if (rune >= 0x0A80 && rune <= 0x0AFF) return 'gu'; // Gujarati
  if (rune >= 0x0B00 && rune <= 0x0B7F) return 'or'; // Odia
  if (rune >= 0x0B80 && rune <= 0x0BFF) return 'ta'; // Tamil
  if (rune >= 0x0C00 && rune <= 0x0C7F) return 'te'; // Telugu
  if (rune >= 0x0C80 && rune <= 0x0CFF) return 'kn'; // Kannada
  if (rune >= 0x0D00 && rune <= 0x0D7F) return 'ml'; // Malayalam
  if (rune >= 0x0600 && rune <= 0x06FF) return 'ur'; // Perso-Arabic
  if ((rune >= 0x0041 && rune <= 0x005A) ||
      (rune >= 0x0061 && rune <= 0x007A)) {
    return 'en';
  }
  return null;
}
