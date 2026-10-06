import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../services/app_update_service.dart';
import '../theme.dart';

/// Checks the store for a newer UniShram once per app session, the first time
/// a signed-in user reaches the home tier — never during onboarding or OTP.
class UpdatePromptGate extends StatefulWidget {
  const UpdatePromptGate({super.key, required this.homeTier, required this.child});
  final bool homeTier;
  final Widget child;

  @override
  State<UpdatePromptGate> createState() => _UpdatePromptGateState();
}

class _UpdatePromptGateState extends State<UpdatePromptGate> {
  @override
  void initState() {
    super.initState();
    _maybeCheck();
  }

  @override
  void didUpdateWidget(covariant UpdatePromptGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.homeTier && !oldWidget.homeTier) _maybeCheck();
  }

  void _maybeCheck() {
    if (!widget.homeTier) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = AppUpdateService.instance;
      final result = await service.checkOnce();
      if (!mounted || result == StoreUpdate.none) return;
      if (result == StoreUpdate.resumeImmediate) {
        await service.startUpdate();
        return;
      }
      service.promptOpen = true;
      final updateNow = await _showUpdateDialog(context);
      service.promptOpen = false;
      if (updateNow == true) {
        await service.startUpdate();
      } else {
        await service.remindLater();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<bool?> _showUpdateDialog(BuildContext context) {
  final t = context.app.t;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t['updateTitle']),
      content: Text(t['updateBody'],
          style: const TextStyle(fontSize: 14, height: 1.4, color: C.text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(t['updateLater'],
              style: const TextStyle(color: C.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.accent),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(t['updateNow']),
        ),
      ],
    ),
  );
}
