import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'rate_dialog.dart';

/// Sign out and account deletion. Both stores reject apps that let a user
/// create an account but not delete it, so this belongs on every profile
/// screen, not buried in a settings page.
class AccountActions extends StatelessWidget {
  const AccountActions({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Divider(color: C.border),
        const RateAppTile(),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _editProfile(context, app),
          child: Text(t['editProfile'],
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        const SizedBox(height: 8),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.app.openBlockedUsers(),
          child: Text(t['blockedUsers'],
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        const SizedBox(height: 8),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.app.signOut(),
          child: Text(t['signOut'],
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        TextButton(
          onPressed: () => _confirmDelete(context),
          child: Text(t['deleteAccount'],
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.danger)),
        ),
      ],
    );
  }

  void _editProfile(BuildContext context, AppState app) {
    final role = app.role;
    if (role == null) return;
    final targetScreen = switch (role) {
      Role.labourer => Screen.profilePersonal,
      Role.contractor => Screen.profilePersonal,
      Role.client => Screen.profilePersonal,
      Role.vendor => Screen.profilePersonal,
    };
    context.app.update(() => app.screen = targetScreen);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final app = context.app;
    final t = app.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(t['deleteAccount'],
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
        content: Text(t['deleteAccountWarning'],
            style:
                const TextStyle(fontSize: 14, height: 1.45, color: C.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t['keepAccount'],
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t['deleteAccountConfirm'],
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: C.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await app.deleteAccount();
    } catch (_) {
      // Firebase requires a recent sign-in before deletion; say so plainly
      // rather than leaving the user staring at an unchanged screen.
      app.showToast(app.t['deleteNeedsReauth']);
    }
  }
}
