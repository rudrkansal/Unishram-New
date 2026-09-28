import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme.dart';
import 'common.dart';

/// The "⋮ more" menu next to a Contact/Message action: Report and, when the
/// other person has a stable id, Block. Two taps, no typing required unless
/// the user wants to add detail — this is the safety net for an audience that
/// mostly can't read a long form.
void showReportBlockSheet(
  BuildContext context, {
  String? userId,
  required String userName,
  String? jobId,
}) {
  final app = context.app;
  final t = app.t;
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
                _showReportReasons(context, userId: userId, jobId: jobId);
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

void _showReportReasons(BuildContext context, {String? userId, String? jobId}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: C.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetContext) => _ReportReasonSheet(userId: userId, jobId: jobId),
  );
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet({this.userId, this.jobId});
  final String? userId;
  final String? jobId;

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
    final reasons = [
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
