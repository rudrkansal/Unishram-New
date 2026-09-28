import 'package:flutter/material.dart';

/// UniShram visual system — one accent colour, generous white space, no gradients.
class C {
  static const accent = Color(0xFF0F6B5C);
  static const accentTint = Color(0xFFE5F3F0);
  static const appBg = Color(0xFFFAF9F6);
  static const desk = Color(0xFFF0EEE9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F0EC);
  static const border = Color(0xFFE6E4DE);
  static const borderStrong = Color(0xFFD8D5CD);
  static const borderDashed = Color(0xFFC9C5BB);
  static const text = Color(0xFF1A1C1A);
  static const textMid = Color(0xFF4C4A44);
  static const textSecondary = Color(0xFF6B7268);
  static const muted = Color(0xFF9A968C);
  static const mutedSoft = Color(0xFF8B8F86);
  static const warn = Color(0xFFB3541E);
  static const warnBg = Color(0xFFFDF1E7);
  static const warnBorder = Color(0xFFF0D3BA);
  static const ok = Color(0xFF1F7A4D);
  static const okBg = Color(0xFFE8F5EC);
  static const danger = Color(0xFFB3251E);
  static const dangerBg = Color(0xFFFDECE7);
}

class T {
  static const screenTitle =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: C.text);
  static const sectionTitle =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text);
  static const body = TextStyle(fontSize: 13.5, color: C.text, height: 1.45);
  static const label = TextStyle(fontSize: 12.5, color: C.textSecondary);
  static const caption = TextStyle(fontSize: 12, color: C.mutedSoft);
}

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.appBg,
    colorScheme: base.colorScheme.copyWith(
      primary: C.accent,
      secondary: C.accent,
      surface: C.surface,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: C.text,
      displayColor: C.text,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Indian digit grouping — 12,34,567 rather than 1,234,567.
String inr(num value) {
  final n = value.round().abs().toString();
  String out;
  if (n.length <= 3) {
    out = n;
  } else {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return value < 0 ? '-$out' : out;
}

String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  return words.take(2).map((w) => w[0]).join().toUpperCase();
}

/// First grapheme of a localized label — Latin keeps two letters, Indic scripts
/// keep one base character plus its matras (but never a dangling virama).
String localInitial(String label) {
  final s = label.trim();
  if (s.isEmpty) return '';
  if (RegExp(r'^[A-Za-z]').hasMatch(s)) return initialsOf(s);
  final chars = s.runes.map(String.fromCharCode).toList();
  final virama = RegExp(r'[्্੍્୍்్್്]');
  final mark = RegExp(r'[̀-ͯऀ-ःऺ-ौ॑-ॗॢॣ'
      r'া-ৌਾ-ੌા-ૌା-ୌா-ௌ'
      r'ా-ౌಾ-ೌാ-ൌً-ْٰٓ-ٟ]');
  var out = chars.first;
  for (var i = 1; i < chars.length; i++) {
    if (virama.hasMatch(chars[i]) || !mark.hasMatch(chars[i])) break;
    out += chars[i];
  }
  return out;
}
