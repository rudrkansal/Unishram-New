import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Reasons that put someone in danger right now: the sheet then offers a
/// one-tap call to 112 next to the report, which only reaches a moderator.
const Set<String> _dangerReasons = {'forced_work', 'unsafe'};

/// Whether a report is about the person who hires (a contractor or client)
/// rather than a worker. A labourer only ever deals with hirers, so that is
/// the default whenever the reporter is a labourer.
bool _defaultAboutEmployer(AppState app) => app.role == Role.labourer;

/// The "⋮ more" menu next to a Contact/Message action: Report and, when the
/// other person has a stable id, Block. Two taps, no typing required unless
/// the user wants to add detail — this is the safety net for an audience that
/// mostly can't read a long form.
void showReportBlockSheet(
  BuildContext context, {
  String? userId,
  required String userName,
  String? jobId,
  bool? aboutEmployer,
}) {
  final app = context.app;
  final t = app.t;
  final employer = aboutEmployer ?? _defaultAboutEmployer(app);
  showModalBottomSheet(
    context: context,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: C.textMid),
              title: Text(t['reportAction'],
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: C.text)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showReportSheet(context,
                    userId: userId, jobId: jobId, aboutEmployer: employer);
              },
            ),
            if (userId != null)
              ListTile(
                leading: const Icon(Icons.block, color: C.danger),
                title: Text(t['blockAction'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: C.danger)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmBlock(context, userId: userId, userName: userName);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmBlock(
  BuildContext context, {
  required String userId,
  required String userName,
}) async {
  final app = context.app;
  final t = app.t;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: C.surface,
      title: Text(t['blockConfirmTitle'],
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
      content: Text(t['blockConfirmBody'],
          style:
              const TextStyle(fontSize: 13.5, height: 1.4, color: C.textMid)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t['cancelWord'],
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: C.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t['blockAction'],
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: C.danger)),
        ),
      ],
    ),
  );
  if (confirmed == true) app.blockUser(userId, userName);
}

/// Opens the reasons sheet straight away — what the visible "Report" buttons
/// use, so reporting a hirer is one tap rather than hidden behind "⋮".
void showReportSheet(
  BuildContext context, {
  String? userId,
  String? jobId,
  bool? aboutEmployer,
}) {
  final employer = aboutEmployer ?? _defaultAboutEmployer(context.app);
  showModalBottomSheet(
    context: context,
    backgroundColor: C.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetContext) => _ReportReasonSheet(
        userId: userId, jobId: jobId, aboutEmployer: employer),
  );
}

/// A labelled, always-visible report action. Workers are the people most
/// likely to be cheated and least likely to find an unlabelled "⋮", so the
/// screens where they meet a hirer show this instead of relying on the menu.
class ReportUserButton extends StatelessWidget {
  const ReportUserButton({
    super.key,
    required this.userId,
    this.jobId,
    this.aboutEmployer,
    this.label,
    this.compact = false,
  });
  final String? userId;
  final String? jobId;
  final bool? aboutEmployer;

  /// Defaults to "Report fraud / unpaid wages" about a hirer, else "Report".
  final String? label;

  /// A small inline text button (for cards) instead of a full-width one.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final employer = aboutEmployer ?? _defaultAboutEmployer(app);
    final text =
        label ?? (employer ? t['reportEmployerAction'] : t['reportAction']);
    void open() => showReportSheet(context,
        userId: userId, jobId: jobId, aboutEmployer: employer);
    if (compact) {
      return TextButton.icon(
        onPressed: open,
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        icon: const Icon(Icons.flag_outlined, size: 17, color: C.danger),
        label: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: C.danger)),
      );
    }
    return OutlinedButton.icon(
      onPressed: open,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: C.danger),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.flag_outlined, size: 19, color: C.danger),
      label: Text(text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: C.danger)),
    );
  }
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet(
      {this.userId, this.jobId, required this.aboutEmployer});
  final String? userId;
  final String? jobId;
  final bool aboutEmployer;

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  final Set<String> _reasons = {};
  String _note = '';

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    // About a hirer, the list leads with the ways workers actually get
    // cheated — unpaid or cut wages, "registration fees", jobs that don't
    // exist, bonded/forced work — in the worker's own words.
    final reasons = widget.aboutEmployer
        ? [
            ('wage_not_paid', t['reportReasonWageNotPaid']),
            ('paid_less', t['reportReasonPaidLess']),
            ('asked_money', t['reportReasonAskedMoney']),
            ('fake_job', t['reportReasonFakeJob']),
            ('forced_work', t['reportReasonForcedWork']),
            ('unsafe', t['reportReasonUnsafeSite']),
            ('harassment', t['reportReasonHarassment']),
            ('scam', t['reportReasonScam']),
            ('other', t['reportReasonOther']),
          ]
        : [
      ('scam', t['reportReasonScam']),
      ('fake_identity', t['reportReasonFakeIdentity']),
      ('harassment', t['reportReasonHarassment']),
      ('inappropriate_messages', t['reportReasonInappropriateMessages']),
      ('misleading', t['reportReasonMisleading']),
      ('payment_issue', t['reportReasonPayment']),
      ('suspicious', t['reportReasonSuspicious']),
      ('unsafe', t['reportReasonUnsafe']),
      ('other', t['reportReasonOther']),
          ];
    final inDanger = _reasons.any(_dangerReasons.contains);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['reportReasonQ'],
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (id, label) in reasons)
                    CheckboxListTile(
                      value: _reasons.contains(id),
                      onChanged: (v) => setState(
                          () => v == true ? _reasons.add(id) : _reasons.remove(id)),
                      activeColor: C.accent,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(label,
                          style: const TextStyle(fontSize: 14, color: C.text)),
                    ),
                ],
              ),
            ),
          ),
          if (inDanger) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                  color: C.dangerBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t['reportDangerHint'],
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: C.danger)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:112')),
                    style: FilledButton.styleFrom(backgroundColor: C.danger),
                    icon: const Icon(Icons.call, size: 17),
                    label: Text(t['callEmergency'],
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          AppTextField(
            initial: _note,
            hint: t['reportNoteHint'],
            fontSize: 13.5,
            maxLines: 2,
            onChanged: (v) => _note = v,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            t['reportSubmit'],
            enabled: _reasons.isNotEmpty,
            onTap: () {
              context.app.submitReport(
                aboutUserId: widget.userId,
                jobId: widget.jobId,
                reasons: _reasons.toList(),
                note: _note.trim(),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
