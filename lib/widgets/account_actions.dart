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
          onPressed: () => context.app.openLegalDocument(terms: true),
          child: Text(t['termsTitle'],
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        TextButton(
          onPressed: () => context.app.openLegalDocument(terms: false),
          child: Text(t['privacyTitle'],
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
    if (app.role == null) return;
    context.app.beginEditProfile();
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
      // Deletion runs server-side (no recent sign-in needed); a failure here is a network/server problem.
      app.showToast(app.t['actionFailed']);
    }
  }
}
