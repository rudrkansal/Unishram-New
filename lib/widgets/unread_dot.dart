import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// A small red dot + count on a "Messages" entry point, fed by
/// [AppState.threadUnreadCount] so it reflects persistent Firestore state
/// rather than only what this device has seen locally.
class UnreadDot extends StatelessWidget {
  const UnreadDot(
      {super.key, required this.app, required this.otherUid, this.jobId});
  final AppState app;
  final String otherUid;
  final String? jobId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: app.threadUnreadCount(otherUid, jobId: jobId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(left: 5),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
              color: C.danger, borderRadius: BorderRadius.circular(9)),
          constraints: const BoxConstraints(minWidth: 16),
          child: Text('$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        );
      },
    );
  }
}
