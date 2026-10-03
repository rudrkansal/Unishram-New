import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../legal/legal_documents.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/legal_text_view.dart';

/// The checkbox line "I agree to the UniShram Terms of Use & Community Guidelines and Privacy Policy."
/// with both document names tappable. It never starts checked; the caller owns [value].
class TermsConsentRow extends StatefulWidget {
  const TermsConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  State<TermsConsentRow> createState() => _TermsConsentRowState();
}

class _TermsConsentRowState extends State<TermsConsentRow> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.app.openLegalDocument(terms: true);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.app.openLegalDocument(terms: false);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appWatch.t;
    const link = TextStyle(
        color: C.accent,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: const ValueKey('termsCheckbox'),
            value: widget.value,
            onChanged:
                widget.enabled ? (v) => widget.onChanged(v ?? false) : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(TextSpan(
                style:
                    const TextStyle(fontSize: 14, height: 1.45, color: C.text),
                children: [
                  TextSpan(text: t['termsAgreePrefix']),
                  TextSpan(
                      text: t['termsLinkTerms'],
                      style: link,
                      recognizer: _termsTap),
                  TextSpan(text: t['termsAgreeAnd']),
                  TextSpan(
                      text: t['termsLinkPrivacy'],
                      style: link,
                      recognizer: _privacyTap),
                  TextSpan(text: t['termsAgreeSuffix']),
                ],
              )),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding step 3: the same consent row, bound to the app state. Ticking it is what allows an OTP to
/// be sent; the acceptance itself (version + server timestamp) is recorded right after sign-in.
class TermsConsentCheck extends StatelessWidget {
  const TermsConsentCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    // Already accepted the current version: nothing to ask again.
    if (app.termsAlreadyAccepted) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(app.t['termsIntro'],
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: C.textSecondary)),
        const SizedBox(height: 10),
        TermsConsentRow(
          value: app.termsChecked,
          enabled: !app.termsSaving,
          onChanged: (v) => context.app.update(() => app.termsChecked = v),
        ),
        if (app.termsError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(app.termsError,
              style: const TextStyle(fontSize: 13, color: C.danger)),
        ],
      ],
    );
  }
}

/// "Before you continue": shown to a signed-in user who has never accepted, or accepted an older version
/// of, the Terms. The checkbox starts unchecked and the button stays disabled until it is ticked.
class TermsGateScreen extends StatefulWidget {
  const TermsGateScreen({super.key});

  @override
  State<TermsGateScreen> createState() => _TermsGateScreenState();
}

class _TermsGateScreenState extends State<TermsGateScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
            children: [
              Text(t['termsBeforeContinue'],
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
              const SizedBox(height: 12),
              Text(
                  app.termsAcceptedVersion == null
                      ? t['termsIntro']
                      : t['termsUpdatedIntro'],
                  style: const TextStyle(
                      fontSize: 14.5, height: 1.45, color: C.textSecondary)),
              const SizedBox(height: 22),
              TermsConsentRow(
                value: _agreed,
                enabled: !app.termsSaving,
                onChanged: (v) => setState(() => _agreed = v),
              ),
              if (app.termsError.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(app.termsError,
                    style: const TextStyle(fontSize: 13, color: C.danger)),
              ],
              const SizedBox(height: 12),
              Text(t['termsEnglishOnly'],
                  style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
          child: Column(
            children: [
              PrimaryButton(
                t['termsAcceptButton'],
                enabled: _agreed && !app.termsSaving,
                onTap: () => context.app.acceptTermsAndContinue(),
              ),
              TextButton(
                onPressed: app.termsSaving ? null : () => context.app.signOut(),
                child: Text(t['signOut'],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.textMid)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Read-only Terms of Use / Privacy Policy, reachable from the consent row and from every profile screen.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.terms});
  final bool terms;

  @override
  Widget build(BuildContext context) {
    final t = context.appWatch.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenBackHeader(
            title: terms ? t['termsTitle'] : t['privacyTitle'],
            onBack: () => context.app.goBack()),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(terms ? 'termsDocument' : 'privacyDocument'),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (terms)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                        '${t['termsVersionWord']} $kTermsVersion · ${t['termsEffectiveWord']} $kTermsEffectiveDate',
                        style: const TextStyle(
                            fontSize: 12.5, color: C.textSecondary)),
                  ),
                LegalTextView(terms ? kTermsText : kPrivacyText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
