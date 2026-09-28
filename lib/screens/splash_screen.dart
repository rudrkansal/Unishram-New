import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Logo, tagline, Listen button, language switch, Get Started.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final speaking = app.speaking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox.shrink(),
          Column(
            children: [
              Image.asset(
                'assets/branding/unishram_mark_transparent.png',
                width: 128,
                height: 128,
              ),
              const SizedBox(height: 18),
              Text(t['appName'],
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: C.text)),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(t['tagline'],
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 14, color: C.textSecondary)),
              ),
              if (app.voiceAvailable) ...[
                const SizedBox(height: 18),
                _ListenButton(
                  label: speaking ? t['listening'] : t['listen'],
                  active: speaking,
                  onTap: () => _speak(context),
                ),
              ],
            ],
          ),
          Column(
            children: [
              InkWell(
                onTap: () => context.app.go(Screen.langSelect),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: C.surface,
                    border: Border.all(color: C.borderStrong),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['language'],
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: C.textSecondary,
                                    letterSpacing: 0.3)),
                            const SizedBox(height: 2),
                            Text(_currentLanguageName(app.langCode),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: C.text)),
                          ],
                        ),
                      ),
                      Text(t['changeWord'],
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.accent)),
                      const Icon(Icons.chevron_right,
                          size: 18, color: C.accent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(t['getStarted'],
                  onTap: () => context.app.go(Screen.roleSelect)),
            ],
          ),
        ],
      ),
    );
  }

  void _speak(BuildContext context) =>
      context.speakAloud(context.app.splashLine);

  static String _currentLanguageName(String code) {
    for (final l in _languages) {
      if (l.$1 == code) return l.$2;
    }
    return 'English';
  }
}

const List<(String, String)> _languages = [
  ('en', 'English'),
  ('hi', 'हिन्दी'),
  ('as', 'অসমীয়া'),
  ('bn', 'বাংলা'),
  ('brx', 'बड़ो'),
  ('doi', 'डोगरी'),
  ('gu', 'ગુજરાતી'),
  ('kn', 'ಕನ್ನಡ'),
  ('ks', 'کٲشُر'),
  ('kok', 'कोंकणी'),
  ('mai', 'मैथिली'),
  ('ml', 'മലയാളം'),
  ('mni', 'ꯃꯤꯇꯩꯂꯣꯟ'),
  ('mr', 'मराठी'),
  ('ne', 'नेपाली'),
  ('or', 'ଓଡ଼ିଆ'),
  ('pa', 'ਪੰਜਾਬੀ'),
  ('sa', 'संस्कृतम्'),
  ('sat', 'ᱥᱟᱱᱛᱟᱲᱤ'),
  ('sd', 'سنڌي'),
  ('ta', 'தமிழ்'),
  ('te', 'తెలుగు'),
  ('ur', 'اردو'),
];

class _ListenButton extends StatelessWidget {
  const _ListenButton(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active ? C.accentTint : C.surface,
            border: Border.all(color: active ? C.accent : C.borderStrong),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpeakerIcon(active: active),
              const SizedBox(width: 9),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
