import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../state/app_state.dart';
import 'rate_dialog.dart';

/// Wraps the home-tier content and, whenever the user lands on their home
/// screen, checks for two independent prompts:
///  1. A forced (non-skippable) rating for one pending post-job engagement
///     whose project end date has passed — see [AppState.findPendingRatingCandidate].
///  2. A dismissible "Rate this app" prompt, offered at most once ever per
///     [AppState.shouldShowAppRatePrompt] — never forced, per Play Store
///     policy against pressuring users into rating an app. The forced
///     per-job prompt takes priority; the app-rating prompt is only
///     offered when there's nothing pending there.
class RatingPromptGate extends StatefulWidget {
  const RatingPromptGate({super.key, required this.screen, required this.child});
  final Screen screen;
  final Widget child;

  @override
  State<RatingPromptGate> createState() => _RatingPromptGateState();
}

class _RatingPromptGateState extends State<RatingPromptGate> {
  static const _triggerScreens = {Screen.labourerHome, Screen.contractorHome};
  Screen? _lastChecked;

  @override
  void initState() {
    super.initState();
    _maybeCheck();
  }

  @override
  void didUpdateWidget(covariant RatingPromptGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screen != widget.screen) _maybeCheck();
  }

  void _maybeCheck() {
    if (!_triggerScreens.contains(widget.screen)) return;
    if (_lastChecked == widget.screen) return;
    _lastChecked = widget.screen;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.app;
      final candidate = await app.maybeGetForcedRatingCandidate();
      if (candidate != null && mounted) {
        await showForcedRateDialog(
          context,
          aboutUserId: candidate.aboutUserId,
          jobId: candidate.jobId,
          aboutName: candidate.aboutName,
        );
        return;
      }
      if (!mounted || !(await app.shouldShowAppRatePrompt())) return;
      if (!mounted) return;
      await showRateAppDialog(context);
      // Covers every dismissal path (Cancel, tap-outside, back button) —
      // submitting also sets this itself, so this is a harmless no-op then.
      await app.markAppRatePromptShown();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
