import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../backend/models.dart';
import '../data/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Label keys for the report reasons a notice can carry (report_block_sheet).
const Map<String, String> _reasonKeys = {
  'wage_not_paid': 'reportReasonWageNotPaid',
  'paid_less': 'reportReasonPaidLess',
  'asked_money': 'reportReasonAskedMoney',
  'fake_job': 'reportReasonFakeJob',
  'forced_work': 'reportReasonForcedWork',
  'unsafe': 'reportReasonUnsafeSite',
  'scam': 'reportReasonScam',
  'fake_identity': 'reportReasonFakeIdentity',
  'harassment': 'reportReasonHarassment',
  'inappropriate_messages': 'reportReasonInappropriateMessages',
  'misleading': 'reportReasonMisleading',
  'payment_issue': 'reportReasonPayment',
  'suspicious': 'reportReasonSuspicious',
  'other': 'reportReasonOther',
};

String _date(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}, ${two(l.hour)}:${two(l.minute)}';
}

/// Sits above every screen. A paused or suspended account sees only the pause
/// screen; a new warning shows as a card that must be acknowledged.
class ModerationOverlay extends StatelessWidget {
  const ModerationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    if (app.accountLocked) {
      return const Positioned.fill(child: _PauseScreen());
    }
    if (app.signedIn && app.moderation.warningUnread) {
      return const Positioned.fill(child: _WarningCard());
    }
    return const SizedBox.shrink();
  }
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.t, required this.reasons});
  final Str t;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['reportedForLabel'], style: T.label),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in reasons)
              BadgePill(t[_reasonKeys[r] ?? 'reportReasonOther'],
                  background: C.dangerBg, color: C.danger),
          ],
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final m = app.moderation;
    return Material(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            decoration: BoxDecoration(
                color: C.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 44, color: C.danger),
                const SizedBox(height: 10),
                Text(t['warningTitle'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: C.text)),
                const SizedBox(height: 10),
                Text(t['warningBody'], style: T.body),
                const SizedBox(height: 12),
                _Reasons(t: t, reasons: m.lastReasons),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: C.dangerBg,
                      borderRadius: BorderRadius.circular(12)),
                  // After a pause the next strike is the third: suspension.
                  child: Text(
                      m.activeStrikes().length >= 2
                          ? t['warningNextStepSuspend']
                          : t['warningNextStep'],
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: C.danger)),
                ),
                const SizedBox(height: 16),
                PrimaryButton(t['iUnderstand'],
                    onTap: () => context.app.acknowledgeWarning()),
                const SizedBox(height: 4),
                _AppealButton(app: app),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseScreen extends StatelessWidget {
  const _PauseScreen();

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final m = app.moderation;
    final temporary = m.status == 'banned' && m.bannedUntil != null;
    return Material(
      color: C.appBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const Icon(Icons.lock_clock_outlined, size: 56, color: C.danger),
            const SizedBox(height: 14),
            Text(temporary ? t['pausedTitle'] : t['suspendedTitle'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(height: 8),
            if (temporary)
              Text(t['pausedUntil'].replaceAll('{date}', _date(m.bannedUntil!)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.danger)),
            const SizedBox(height: 14),
            Text(temporary ? t['pausedBody'] : t['suspendedBody'],
                textAlign: TextAlign.center, style: T.body),
            const SizedBox(height: 18),
            _Reasons(t: t, reasons: m.lastReasons),
            const SizedBox(height: 24),
            if (temporary) ...[
              PrimaryButton(t['checkAgain'],
                  onTap: () => context.app.checkStandingAgain()),
              const SizedBox(height: 8),
            ],
            _AppealButton(app: app),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.app.signOut(),
              child: Text(t['signOut'],
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: C.textMid)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "This is wrong — appeal", or a note that the appeal is under review.
class _AppealButton extends StatelessWidget {
  const _AppealButton({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = app.t;
    if (app.moderation.appealPendingAt != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t['appealPending'],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: C.textSecondary)),
      );
    }
    // A manual suspension with no notice has nothing to appeal against here.
    if (app.moderation.status == 'clear') return const SizedBox.shrink();
    return TextButton(
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: C.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (_) => const _AppealSheet(),
      ),
      child: Text(t['appealAction'],
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: C.accent)),
    );
  }
}

class _AppealSheet extends StatefulWidget {
  const _AppealSheet();

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  String _text = '';
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appWatch.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t['appealAction'],
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 12),
          AppTextField(
            initial: _text,
            hint: t['appealHint'],
            fontSize: 14,
            maxLines: 4,
            onChanged: (v) => setState(() => _text = v),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            t['appealSubmit'],
            enabled: !_sending && _text.trim().isNotEmpty,
            onTap: () async {
              setState(() => _sending = true);
              final sent = await context.app.submitAppeal(_text);
              if (!context.mounted) return;
              if (sent) {
                Navigator.of(context).pop();
              } else {
                setState(() => _sending = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// "Account status" on every profile: good standing, or how many warnings
/// still count and when the oldest stops counting.
class AccountStandingTile extends StatelessWidget {
  const AccountStandingTile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    if (!app.signedIn) return const SizedBox.shrink();
    final t = app.t;
    final ModerationDoc m = app.moderation;
    final active = m.activeStrikes().length;
    final expiry = m.nextStrikeExpiry;
    final good = active == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(good ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
              size: 20, color: good ? C.ok : C.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['standingTitle'], style: T.label),
                const SizedBox(height: 2),
                Text(
                    good || expiry == null
                        ? t['standingGood']
                        : t['standingWarnings']
                            .replaceAll('{n}', '$active')
                            .replaceAll('{date}', _date(expiry)),
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: good ? C.ok : C.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
