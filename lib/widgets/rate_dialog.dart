import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// A "Rate" action that swaps to a disabled "Rated" once the current user has
/// already reviewed [aboutUserId] for [jobId] — the same duplicate check the
/// Firestore rules enforce, surfaced in the UI.
class RateButton extends StatelessWidget {
  const RateButton({
    super.key,
    required this.app,
    required this.t,
    required this.aboutUserId,
    required this.jobId,
    required this.aboutName,
  });
  final AppState app;
  final Str t;
  final String aboutUserId;
  final String jobId;
  final String aboutName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: app.hasReviewed(aboutUserId, jobId),
      builder: (context, snapshot) {
        final rated = snapshot.data ?? false;
        final color = rated ? C.mutedSoft : C.accent;
        return Semantics(
          button: true,
          enabled: !rated,
          child: InkWell(
            onTap: rated
                ? null
                : () => showRateDialog(context,
                    aboutUserId: aboutUserId,
                    jobId: jobId,
                    aboutName: aboutName),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: rated ? C.surfaceMuted : C.surface,
                border: Border.all(
                    color: rated ? C.border : C.accent, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(rated ? Icons.star : Icons.star_border,
                      size: 20, color: color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(rated ? t['rated'] : t['rateWorker'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A 1–5 star rating dialog with an optional comment, shown after a worker
/// or contractor has actually engaged on a job (shortlisted/hired). Wired to
/// [AppState.submitReview], which enforces one rating per job per rater at
/// the Firestore rules level.
Future<void> showRateDialog(
  BuildContext context, {
  required String aboutUserId,
  required String jobId,
  required String aboutName,
}) =>
    _showRateDialog(
      context,
      aboutUserId: aboutUserId,
      jobId: jobId,
      aboutName: aboutName,
      forced: false,
    );

/// Same rating dialog, but non-dismissible: no cancel button, no tap-outside
/// or back-button escape. Used by the periodic pending-rating prompt so a
/// user with an un-rated engagement can't skip past it — they can only leave
/// by submitting a rating. Reachable at most a handful of times per install
/// (see [AppState.maybeGetForcedRatingCandidate]).
Future<void> showForcedRateDialog(
  BuildContext context, {
  required String aboutUserId,
  required String jobId,
  required String aboutName,
}) =>
    _showRateDialog(
      context,
      aboutUserId: aboutUserId,
      jobId: jobId,
      aboutName: aboutName,
      forced: true,
    );

Future<void> _showRateDialog(
  BuildContext context, {
  required String aboutUserId,
  required String jobId,
  required String aboutName,
  required bool forced,
}) {
  final app = context.app;
  final t = app.t;
  int stars = 0;
  final commentCtrl = TextEditingController();

  return showDialog<void>(
    context: context,
    barrierDismissible: !forced,
    builder: (dialogContext) => PopScope(
      canPop: !forced,
      child: StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(forced ? t['rateDialogForcedTitle'] : t['rateDialogTitle']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(aboutName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: C.text)),
              if (forced) ...[
                const SizedBox(height: 6),
                Text(t['rateDialogForcedHint'],
                    style: const TextStyle(fontSize: 12, color: C.mutedSoft)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setState(() => stars = i),
                      icon: Icon(
                        i <= stars ? Icons.star : Icons.star_border,
                        color: C.accent,
                        size: 30,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLength: 300,
                maxLines: 3,
                decoration: InputDecoration(hintText: t['rateDialogComment']),
              ),
            ],
          ),
          actions: [
            if (!forced)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t['cancel']),
              ),
            TextButton(
              onPressed: () async {
                if (stars == 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(t['rateDialogSelectStars'])));
                  return;
                }
                final error = await app.submitReview(
                  aboutUserId: aboutUserId,
                  jobId: jobId,
                  rating: stars,
                  comment: commentCtrl.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t['rateDialogAlready'])));
                }
              },
              child: Text(t['rateDialogSubmit']),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A profile-screen tile that opens a 1–5 star dialog for rating the app
/// itself (not another user) — distinct from [RateButton], which rates a
/// specific person after a job. Wired to [AppState.submitAppRating].
class RateAppTile extends StatelessWidget {
  const RateAppTile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    return InkWell(
      onTap: () => showRateAppDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.star_rate_rounded, color: C.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t['rateAppMenuLabel'],
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
            ),
            const Icon(Icons.chevron_right, color: C.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Always dismissible (Cancel button, tap-outside, back button all work) —
/// unlike [showForcedRateDialog] for post-job ratings. Play Store policy
/// prohibits pressuring or blocking users into rating an app, so this one
/// never forces the issue regardless of how it was triggered.
Future<void> showRateAppDialog(BuildContext context) {
  final app = context.app;
  final t = app.t;
  int stars = 0;
  final commentCtrl = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(t['rateAppTitle']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => stars = i),
                    icon: Icon(
                      i <= stars ? Icons.star : Icons.star_border,
                      color: C.accent,
                      size: 30,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentCtrl,
              maxLength: 300,
              maxLines: 3,
              decoration: InputDecoration(hintText: t['rateDialogComment']),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Dismissing counts as "shown" for the auto-prompt too — it
              // must never come back on its own after the user has already
              // seen and dismissed it once, forced or not.
              app.markAppRatePromptShown();
              Navigator.pop(dialogContext);
            },
            child: Text(t['cancel']),
          ),
          TextButton(
            onPressed: () async {
              if (stars == 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(t['rateDialogSelectStars'])));
                return;
              }
              await app.submitAppRating(
                rating: stars,
                comment: commentCtrl.text.trim(),
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t['rateAppThanks'])));
              }
            },
            child: Text(t['rateDialogSubmit']),
          ),
        ],
      ),
    ),
  );
}
