import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// The person's phone number with Call now and Message now, for a profile
/// opened from Find/discovery. No job or application is needed: the number
/// comes from AppState.contactPhoneFor (firestore.rules decide who may read
/// it) and the chat is the pair's single direct thread.
class ProfileContactActions extends StatefulWidget {
  const ProfileContactActions({
    super.key,
    required this.app,
    required this.peerId,
    required this.peerName,
    required this.back,
    this.fallbackPhone = '',
  });
  final AppState app;
  final String peerId;
  final String peerName;
  final Screen back;

  /// Offline sample profiles carry their number directly.
  final String fallbackPhone;

  @override
  State<ProfileContactActions> createState() => _ProfileContactActionsState();
}

class _ProfileContactActionsState extends State<ProfileContactActions> {
  late Future<String> _phone = _load();

  Future<String> _load() async {
    final phone = await widget.app.contactPhoneFor(widget.peerId);
    return phone.isNotEmpty ? phone : widget.fallbackPhone;
  }

  @override
  void didUpdateWidget(covariant ProfileContactActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerId != widget.peerId) _phone = _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final canMessage = app.backend == null ||
        AppState.canStartDirectChat(
            myRole: app.role,
            myUid: app.uid,
            peerId: widget.peerId,
            peerBlocked: app.isBlocked(widget.peerId));

    return FutureBuilder<String>(
      future: _phone,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final phone = snapshot.data ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (phone.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, size: 17, color: C.accent),
                  const SizedBox(width: 6),
                  SelectableText(_display(phone),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: C.text)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.call,
                    label: t['callNow'],
                    filled: true,
                    onTap: phone.isEmpty ? null : () => dialPhone(phone),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: t['messageNow'],
                    filled: false,
                    onTap: canMessage
                        ? () => context.app.openDirectChat(
                              peerId: widget.peerId,
                              peerName: widget.peerName,
                              back: widget.back,
                            )
                        : null,
                  ),
                ),
              ],
            ),
            if (!loading && phone.isEmpty) ...[
              const SizedBox(height: 8),
              Text(t['noPhoneOnProfile'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            ],
          ],
        );
      },
    );
  }

  static String _display(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return local.length == 10
        ? '+91 ${local.substring(0, 5)} ${local.substring(5)}'
        : phone;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final fg = !on
        ? C.mutedSoft
        : filled
            ? Colors.white
            : C.accent;
    return Semantics(
      button: true,
      enabled: on,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: !on
                ? C.surfaceMuted
                : filled
                    ? C.accent
                    : C.accentTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
