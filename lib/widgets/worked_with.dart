import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../backend/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'rate_dialog.dart';
import 'report_block_sheet.dart';
import 'user_avatar.dart';

/// "Working with now" and "Worked with before": everyone the user has an
/// application with, each with Rate and Report — so reporting starts from
/// the person, which is how people remember it, not from a job post. Then
/// "People you've messaged" from direct chats: for a client (who can't post
/// jobs) that is the whole list.
class WorkedWithSection extends StatefulWidget {
  const WorkedWithSection({super.key});

  @override
  State<WorkedWithSection> createState() => _WorkedWithSectionState();
}

class _WorkedWithSectionState extends State<WorkedWithSection> {
  late Future<List<WorkedWith>> _people = context.app.workedWith();
  late Future<List<ThreadDoc>> _messaged = context.app.messagedPeople();

  void _retry() => setState(() {
        _people = context.app.workedWith();
        _messaged = context.app.messagedPeople();
      });

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final worker = app.role == Role.labourer;
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        _people.catchError((_) => <WorkedWith>[]),
        _messaged,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: C.accent)),
            ),
          );
        }
        final results = snapshot.data;
        final people = (results?[0] as List<WorkedWith>?) ?? const [];
        final onJobs = {for (final p in people) p.uid};
        final me = app.uid ?? '';
        // Someone already listed through a job isn't repeated here.
        final messaged = ((results?[1] as List<ThreadDoc>?) ?? const [])
            .where((th) => !onJobs.contains(th.otherParticipant(me)))
            .toList();
        final now = people.where((p) => p.current).toList();
        final before = people.where((p) => !p.current).toList();
        // Clients have no jobs of their own, only the people they messaged.
        final jobs = app.role != Role.client;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (jobs) ...[
              _Header(t['workingWithNow'], now.length),
              if (now.isEmpty)
                _Empty(t[worker
                    ? 'workingWithNowEmpty'
                    : 'workingWithNowEmptyHirer'])
              else
                for (final p in now) _PersonCard(person: p),
              const SizedBox(height: 18),
              _Header(t['workedWithBefore'], before.length),
              if (before.isEmpty)
                _Empty(t['workedWithBeforeEmpty'])
              else
                for (final p in before) _PersonCard(person: p),
            ],
            if (!jobs || messaged.isNotEmpty) ...[
              if (jobs) const SizedBox(height: 18),
              _Header(t['messagedPeople'], messaged.length),
              if (messaged.isEmpty)
                _Empty(t['messagedPeopleEmpty'])
              else
                for (final th in messaged) _MessagedCard(thread: th, me: me),
            ],
            if (snapshot.hasError)
              TextButton(
                onPressed: _retry,
                child: Text(t['retryWord'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: C.accent)),
              ),
          ],
        );
      },
    );
  }
}

/// A direct-chat contact: no job, so no Rate (a review belongs to a job) —
/// open the chat, or report them.
class _MessagedCard extends StatelessWidget {
  const _MessagedCard({required this.thread, required this.me});
  final ThreadDoc thread;
  final String me;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final peer = thread.otherParticipant(me);
    final name = thread.names[peer] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(uid: peer, name: name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.text)),
                      if (thread.lastMessage.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(thread.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: C.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      context.app.resumeDirectThread(thread, app.screen),
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: 17, color: C.accent),
                  label: Text(t['messages'],
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: C.accent)),
                ),
                ReportUserButton(
                  userId: peer,
                  aboutEmployer: app.role == Role.labourer,
                  label: t['reportAction'],
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label, this.count);
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(count == 0 ? label : '$label ($count)',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 12.5, color: C.mutedSoft)),
      );
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});
  final WorkedWith person;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final p = person;
    final dates = p.job.durationSpan.isNotEmpty
        ? p.job.durationSpan
        : p.job.duration;
    final hired = p.status == 'hired';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(uid: p.uid, name: p.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.text)),
                      const SizedBox(height: 2),
                      Text(p.job.title,
                          style: const TextStyle(
                              fontSize: 12.5, color: C.textSecondary)),
                      if (dates.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(dates,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: C.accent)),
                      ],
                    ],
                  ),
                ),
                BadgePill(hired ? t['employed'] : t['shortlisted'],
                    background: hired ? C.accentTint : C.okBg,
                    color: hired ? C.accent : C.ok),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FutureBuilder<bool>(
                  future: app.hasReviewed(p.uid, p.job.id),
                  builder: (context, snapshot) {
                    final rated = snapshot.data ?? false;
                    return TextButton.icon(
                      onPressed: rated
                          ? null
                          : () => showRateDialog(context,
                              aboutUserId: p.uid,
                              jobId: p.job.id,
                              aboutName: p.name),
                      icon: Icon(rated ? Icons.check : Icons.star_outline,
                          size: 17, color: rated ? C.mutedSoft : C.accent),
                      label: Text(rated ? t['rated'] : t['rateThem'],
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: rated ? C.mutedSoft : C.accent)),
                    );
                  },
                ),
                ReportUserButton(
                  userId: p.uid,
                  jobId: p.job.id,
                  aboutEmployer: app.role == Role.labourer,
                  label: t['reportAction'],
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
