import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Anyone the user has blocked, with a one-tap way to undo it. Blocking is
/// only trustworthy if it's easy to see and reverse — otherwise it is just
/// another dead-end menu action.
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final ids = app.blockedUserIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenBackHeader(
            title: t['blockedUsers'], onBack: () => context.app.goBack()),
        Expanded(
          child: ids.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(t['noBlockedUsers'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: C.textSecondary)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  itemCount: ids.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final id = ids[i];
                    final name = app.blockedUserNames[id] ?? id;
                    return SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Avatar(initialsOf(name)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: C.text)),
                          ),
                          TextButton(
                            onPressed: () => context.app.unblockUser(id),
                            child: Text(t['unblock'],
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: C.accent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
