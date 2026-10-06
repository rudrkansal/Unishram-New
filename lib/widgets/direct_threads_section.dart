import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../backend/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// "Messages": the user's direct (Find-started) conversations, so either side
/// can get back into one and reply. Renders nothing until there is at least
/// one conversation with a message in it.
class DirectThreadsSection extends StatefulWidget {
  const DirectThreadsSection({super.key, required this.back});
  final Screen back;

  @override
  State<DirectThreadsSection> createState() => _DirectThreadsSectionState();
}

class _DirectThreadsSectionState extends State<DirectThreadsSection> {
  // Kept across rebuilds so appWatch rebuilds don't restart the subscription.
  Stream<List<ThreadDoc>>? _stream;
  String? _streamUid;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final me = app.uid;
    if (_streamUid != me) {
      _streamUid = me;
      _stream = app.directThreadsFeed();
    }

    return StreamBuilder<List<ThreadDoc>>(
      stream: _stream,
      builder: (context, snapshot) {
        final threads = (snapshot.data ?? const <ThreadDoc>[])
            .where((th) => !app.isBlocked(th.otherParticipant(me ?? '')))
            .toList();
        if (me == null || threads.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['messagesTitle'], style: T.label),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _ThreadTile(thread: threads[i], me: me, back: widget.back),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile(
      {required this.thread, required this.me, required this.back});
  final ThreadDoc thread;
  final String me;
  final Screen back;

  @override
  Widget build(BuildContext context) {
    final peer = thread.otherParticipant(me);
    final name = thread.names[peer] ?? '';
    final unread = thread.unread[me] ?? 0;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.app.resumeDirectThread(thread, back),
      child: Row(
        children: [
          Avatar(initialsOf(name), size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.text)),
                const SizedBox(height: 2),
                Text(thread.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: C.textSecondary)),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                  color: C.danger, borderRadius: BorderRadius.circular(10)),
              child: Text('$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
