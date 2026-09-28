import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Every scheduled language, shown in its own script. Tapping a tile selects
/// it; nothing is spoken here.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    // Force LTR here regardless of the picked language's own direction, so
    // the grid of tiles never mirrors mid-pick — an RTL choice (Urdu,
    // Kashmiri) should only flip layout once inside the app, not this list.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Image.asset(
                  'assets/branding/unishram_mark_transparent.png',
                  width: 56,
                  height: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['chooseLanguage'],
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: C.text)),
                      const SizedBox(height: 2),
                      Text(t['chooseLanguageSub'], style: T.label),
                    ],
                  ),
                ),
                // Wipes onboarding, profile and session data back to a fresh
                // install. Only for testers walking through the first-run flow
                // repeatedly — a real user never needs this and has proper
                // sign-out / delete-account controls instead.
                if (kDebugMode)
                  TextButton(
                    onPressed: () => context.app.resetDemo(),
                    child: Text(t['resetDemoLabel'],
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.mutedSoft)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 74,
              ),
              itemCount: kLanguages.length,
              itemBuilder: (context, i) {
                final lang = kLanguages[i];
                final selected = app.langCode == lang.code;
                return InkWell(
                  onTap: () => context.app.setLanguage(lang.code),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? C.accentTint : C.surface,
                      border: Border.all(
                          color: selected ? C.accent : C.border,
                          width: selected ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(lang.native,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? C.accent : C.text)),
                        const SizedBox(height: 3),
                        Text(lang.roman,
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: C.mutedSoft,
                                letterSpacing: 0.3)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: C.appBg,
              border: Border(top: BorderSide(color: Color(0xFFEAE7E0))),
            ),
            child: PrimaryButton(t['continueBtn'],
                onTap: () => context.app.go(Screen.splash)),
          ),
        ],
      ),
    );
  }
}
