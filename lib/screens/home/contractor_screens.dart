import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/catalog.dart';
import '../../data/strings.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../backend/models.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';
import '../../widgets/feed_builder.dart';
import '../../widgets/rate_dialog.dart';
import '../../widgets/report_block_sheet.dart';
import '../../widgets/search_tier_bar.dart';
import '../../widgets/unread_dot.dart';

class ContractorHome extends StatelessWidget {
  const ContractorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;

    return FeedBuilder<Job>(
      stream: app.myPostedJobsFeed(),
      emptyText: app.t['noJobsPosted'],
      builder: (context, jobs) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final job = jobs[i];
          final count = app.applicantCountFor(job.id);
          return SurfaceCard(
            onTap: () => context.app.update(() {
              app.setSelectedJob(job);
              app.screen = Screen.contractorApplicants;
            }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(job.title,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: C.text)),
                    ),
                    StreamBuilder<int>(
                      stream: app.jobUnreadCount(job.id),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        if (unread <= 0) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: C.danger,
                              borderRadius: BorderRadius.circular(10)),
                          constraints: const BoxConstraints(minWidth: 18),
                          child: Text('$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                    '${job.location} · ₹${inr(job.wage)}/day · ${job.postedAgo}',
                    style: T.label),
                const SizedBox(height: 4),
                Text(job.duration,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: C.accent)),
                const SizedBox(height: 8),
                Text('$count ${count == 1 ? 'applicant' : 'applicants'} ›',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: C.accent)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ContractorApplicants extends StatelessWidget {
  const ContractorApplicants({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return FeedBuilder<Job>(
      stream: app.myPostedJobsFeed(),
      emptyText: t['noJobsYet'],
      builder: (context, jobs) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, jobIndex) {
          final job = jobs[jobIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(job.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: C.text)),
                  ),
                  _ActionButton(
                    label: t['markFilled'] ?? 'Mark Filled',
                    background: job.status == 'filled' ? C.dangerBg : C.accentTint,
                    color: job.status == 'filled' ? C.danger : C.accent,
                    onTap: job.status == 'filled' ? null : () => context.app.markJobFilled(job.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<ApplicationDoc>>(
                stream: app.applicationsForJob(job.id),
                builder: (context, snapshot) {
                  final applicants = snapshot.data ?? [];
                  if (applicants.isEmpty) {
                    return Text(t['noApplicantsYet'],
                        style: const TextStyle(
                            fontSize: 13, color: C.mutedSoft));
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: applicants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, appIndex) {
                      final w = applicants[appIndex];
                      final status = w.status;
                      final (bg, fg, label) = switch (status) {
                        'hired' => (C.accentTint, C.accent, t['employed']),
                        'shortlisted' => (C.okBg, C.ok, t['shortlisted']),
                        'rejected' => (C.dangerBg, C.danger, t['rejected']),
                        _ => (C.surfaceMuted, C.textSecondary, t['pending']),
                      };
                      return GestureDetector(
                        onTap: () => context.app.viewWorker(
                            w.workerId, Screen.contractorApplicants),
                        child: SurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Avatar(initialsOf(w.workerName)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(w.workerName,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: C.text)),
                                            ),
                                            BadgePill(label,
                                                background: bg, color: fg),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(w.workerSkill,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: C.textSecondary)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(t['wageExpectation'],
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: C.mutedSoft)),
                                            const Spacer(),
                                            Text('₹${inr(w.expectedWage)}/day',
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: C.text)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => showReportBlockSheet(context,
                                        userId: w.workerId,
                                        userName: w.workerName),
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.more_vert,
                                          size: 20, color: C.mutedSoft),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _CallMessageRow(app: app, t: t, w: w),
                              const SizedBox(height: 8),
                              if (status == 'shortlisted')
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _ActionButton(
                                        label: t['markEmployed'],
                                        background: C.accentTint,
                                        color: C.accent,
                                        onTap: () => context.app
                                            .setApplicationStatus(w.jobId,
                                                w.workerId, 'hired'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: _ActionButton(
                                        label: t['reject'],
                                        background: C.dangerBg,
                                        color: C.danger,
                                        onTap: () => context.app
                                            .setApplicationStatus(w.jobId,
                                                w.workerId, 'rejected'),
                                      ),
                                    ),
                                  ],
                                )
                              else if (status == 'hired')
                                _ActionButton(
                                  label: t['employed'],
                                  background: C.accentTint,
                                  color: C.accent,
                                  onTap: null,
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionButton(
                                        label: t['shortlist'],
                                        background: C.accentTint,
                                        color: C.accent,
                                        onTap: () => context.app
                                            .setApplicationStatus(w.jobId,
                                                w.workerId, 'shortlisted'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionButton(
                                        label: t['reject'],
                                        background: C.dangerBg,
                                        color: C.danger,
                                        onTap: () => context.app
                                            .setApplicationStatus(w.jobId,
                                                w.workerId, 'rejected'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color background;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ),
      );
}

/// Direct call + message actions for one applicant, replacing the old single
/// "Contact" button that routed through an extra sheet. The message button
/// carries its own unread badge so a contractor can see, at a glance, which
/// applicant just replied — without opening the thread first.
class _CallMessageRow extends StatelessWidget {
  const _CallMessageRow({required this.app, required this.t, required this.w});
  final AppState app;
  final Str t;
  final ApplicationDoc w;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: t['callNow'],
              background: C.accent,
              color: Colors.white,
              onTap:
                  w.workerPhone.isEmpty ? null : () => dialPhone(w.workerPhone),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _ActionButton(
                  label: t['sendMessage'],
                  background: C.accentTint,
                  color: C.accent,
                  onTap: () => context.app.openChatLive(
                    peerId: w.workerId,
                    peerName: w.workerName,
                    jobId: w.jobId,
                    back: Screen.contractorApplicants,
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child:
                      UnreadDot(app: app, otherUid: w.workerId, jobId: w.jobId),
                ),
              ],
            ),
          ),
        ],
      );
}

/// Post a job. The wage is checked live against the state legal minimum for the
/// chosen skill, and snapped up to it when the field loses focus.
class ContractorPost extends StatelessWidget {
  const ContractorPost({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(t['jobTitle'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.postTitle,
          fontSize: 14,
          onChanged: (v) => context.app.update(() => app.postTitle = v),
        ),
        const SizedBox(height: 14),
        Text(t['skillNeeded'], style: T.label),
        const SizedBox(height: 6),
        _Dropdown(
          value: app.postSkill,
          items: [for (final s in kSkills) (s.jobLabel, s.name(app.copyLang))],
          onChanged: (v) => context.app.update(() => app.postSkill = v),
        ),
        const SizedBox(height: 14),
        Text(t['wagePerDay'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.postWage,
          digitsOnly: true,
          maxLength: 6,
          fontSize: 14,
          keyboardType: TextInputType.number,
          onChanged: (v) => context.app.update(() => app.postWage = v),
          onEditingComplete: () => context.app.clampPostWage(),
        ),
        const SizedBox(height: 6),
        Text('${t['legalMinWage']}: ₹${inr(app.postMinWage)}${t['perDay']}',
            style: T.caption),
        if (app.minWageDisclaimerLine.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(app.minWageDisclaimerLine, style: T.caption),
        ],
        if (app.postWageBelowMin) ...[
          const SizedBox(height: 6),
          Text(
            'Below the ₹${inr(app.postMinWage)}/day legal minimum wage for ${app.postSkill}${app.lp.state.isEmpty ? '' : ' in ${app.lp.state}'}',
            style: const TextStyle(fontSize: 11.5, color: C.warn),
          ),
        ],
        const SizedBox(height: 14),
        Text(t['location'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.postLocation,
          hint: t['locationPlaceholder'],
          fontSize: 14,
          onChanged: (v) => context.app.update(() => app.postLocation = v),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['siteCityDistrict'], style: T.label),
                  const SizedBox(height: 6),
                  AppTextField(
                    initial: app.postCityDistrict,
                    hint: t['siteCityDistrictPlaceholder'],
                    fontSize: 14,
                    onChanged: (v) =>
                        context.app.update(() => app.postCityDistrict = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['sitePincode'], style: T.label),
                  const SizedBox(height: 6),
                  AppTextField(
                    initial: app.postPincode,
                    digitsOnly: true,
                    maxLength: 6,
                    fontSize: 14,
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.app.update(() => app.postPincode = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (app.postPincodeError.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(app.postPincodeError,
              style: const TextStyle(fontSize: 11.5, color: C.warn)),
        ],
        const SizedBox(height: 14),
        Text(t['workersNeeded'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.postWorkers,
          digitsOnly: true,
          maxLength: 4,
          fontSize: 14,
          keyboardType: TextInputType.number,
          onChanged: (v) => context.app.update(() => app.postWorkers = v),
        ),
        const SizedBox(height: 14),
        Text(t['workDates'], style: T.label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _DateField(
                value: app.postStartDate,
                placeholder: t['startDate'],
                onPick: (iso) =>
                    context.app.update(() => app.postStartDate = iso),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DateField(
                value: app.postEndDate,
                placeholder: t['endDate'],
                onPick: (iso) =>
                    context.app.update(() => app.postEndDate = iso),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(t['hoursPerDay'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.postHoursPerDay,
          hint: '8',
          digitsOnly: true,
          maxLength: 2,
          fontSize: 14,
          keyboardType: TextInputType.number,
          onChanged: (v) => context.app.update(() => app.postHoursPerDay = v),
        ),
        if (app.postHoursError.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(app.postHoursError,
              style: const TextStyle(fontSize: 11.5, color: C.warn)),
        ],
        const SizedBox(height: 14),
        Text(t['description'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.postDescription,
          fontSize: 14,
          maxLines: 3,
          onChanged: (v) => context.app.update(() => app.postDescription = v),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          t['postJobBtn'],
          // Everything is required except the description — a job posted
          // without wage, dates, hours, worker count or a precise location
          // is hard for a labourer to trust or act on.
          enabled: app.postTitle.trim().isNotEmpty &&
              app.postWage.isNotEmpty &&
              !app.postWageBelowMin &&
              !app.postJobOnCooldown &&
              app.postLocation.trim().isNotEmpty &&
              app.postCityDistrict.trim().isNotEmpty &&
              app.postPincode.trim().isNotEmpty &&
              app.postPincodeError.isEmpty &&
              app.postWorkers.trim().isNotEmpty &&
              app.postStartDate.isNotEmpty &&
              app.postEndDate.isNotEmpty &&
              app.postHoursPerDay.trim().isNotEmpty &&
              app.postHoursError.isEmpty,
          onTap: () => context.app.postJobLive(),
        ),
        if (app.postJobOnCooldown) ...[
          const SizedBox(height: 10),
          Text(
            '${t['actionFailed']}: ${t['tryAgainIn']} ${app.postJobCooldownSecondsLeft}${t['secondsShort']}',
            style: const TextStyle(fontSize: 12, color: C.warn),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.value, required this.placeholder, required this.onPick});
  final String value;
  final String placeholder;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final picked = DateTime.tryParse(value);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final result = await showDatePicker(
          context: context,
          initialDate: picked ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
        );
        if (result != null) {
          onPick(
              '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}');
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.borderStrong),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          picked == null ? placeholder : formatJobDuration(value, '', ''),
          style: TextStyle(
              fontSize: 13.5, color: picked == null ? C.muted : C.text),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(
      {required this.value, required this.items, required this.onChanged});
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.borderStrong),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.any((e) => e.$1 == value) ? value : items.first.$1,
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: C.text),
            items: [
              for (final item in items)
                DropdownMenuItem(value: item.$1, child: Text(item.$2)),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}

class ContractorFind extends StatelessWidget {
  const ContractorFind({super.key, this.forClient = false});
  final bool forClient;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return Column(
      children: [
        SearchTierBar(
          tier: app.contractorSearchTier,
          onWiden: () => context.app.widenContractorSearch(),
          onReset: () => context.app.resetContractorSearch(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['workerFilterLabel'], style: T.label),
                    const SizedBox(height: 6),
                    _Dropdown(
                      value: app.workerSkillFilter.isEmpty
                          ? '__all'
                          : app.workerSkillFilter,
                      items: [
                        ('__all', t['allWord']),
                        for (final s in kSkills)
                          (s.jobLabel, s.name(app.copyLang)),
                      ],
                      onChanged: (v) => context.app.update(
                          () => app.workerSkillFilter = v == '__all' ? '' : v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: FeedBuilder<Worker>(
                  stream: app.workerFeed(),
                  emptyText: t['noWorkersYet'],
                  builder: (context, workers) => Column(
                    children: [
                      for (final w in workers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SurfaceCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () => context.app.viewWorker(
                                w.id,
                                forClient
                                    ? Screen.clientSearch
                                    : Screen.contractorFind,
                                worker: w),
                            child: Row(
                              children: [
                                Avatar(initialsOf(w.name)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(w.name,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: C.text)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '${w.skill} · ${w.experience} · ${w.location}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: C.textSecondary)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text('★ ${w.rating}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: C.accent)),
                                          const SizedBox(width: 8),
                                          BadgePill(
                                              w.available
                                                  ? t['availableNow']
                                                  : t['onProject'],
                                              background: w.available
                                                  ? C.okBg
                                                  : C.surfaceMuted,
                                              color: w.available
                                                  ? C.ok
                                                  : C.textSecondary),
                                          const Spacer(),
                                          if (!forClient)
                                            Text('₹${inr(w.wage)}/day',
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: C.text)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WorkerDetail extends StatelessWidget {
  const WorkerDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final w = app.selectedWorker;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Column(
          children: [
            Avatar(initialsOf(w.name), size: 76),
            const SizedBox(height: 10),
            Text(w.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(height: 6),
            Text('${w.skill} · ${w.experience} · ${w.location}',
                style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                BadgePill(w.available ? t['availableNow'] : t['onProject'],
                    background: w.available ? C.okBg : C.surfaceMuted,
                    color: w.available ? C.ok : C.textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(value: '★ ${w.rating}', label: t['ratings']),
                const SizedBox(width: 24),
                _Stat(value: '₹${inr(w.wage)}', label: t['wageExpectation']),
                const SizedBox(width: 24),
                FutureBuilder<int>(
                  future: app.hiredJobCountForWorker(w.id),
                  builder: (context, snapshot) => _Stat(
                    value: '${snapshot.data ?? 0}',
                    label: t['employed'],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // No direct chat from the Find screens (chat is job-scoped), and other
        // users' phones are not on public profiles — so Contact only appears
        // where a phone is actually available (offline sample data).
        if (w.phone.isNotEmpty)
          PrimaryButton(t['contact'],
              onTap: () => context.app.openContact(ContactTarget(
                    name: w.name,
                    subtitle: '${w.skill} · ${w.location}',
                    phone: w.phone,
                  ))),
        if (w.id != app.uid) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RateButton(
                app: app,
                t: t,
                aboutUserId: w.id,
                jobId: app.selectedJobId ?? '',
                aboutName: w.name,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: C.textSecondary)),
        ],
      );
}

/// Cost calculator — worker rows, materials, equipment, transport and a
/// contingency buffer, recomputed on every keystroke.
class CostCalculator extends StatelessWidget {
  const CostCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
            app.role == Role.client
                ? t['calcHeaderSubClient']
                : t['calcHeaderSubContractor'],
            style: const TextStyle(
                fontSize: 12.5, height: 1.4, color: C.textSecondary)),
        const SizedBox(height: 14),
        Text(t['workerType'], style: T.label),
        const SizedBox(height: 8),
        for (var i = 0; i < app.calcRows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CalcRowCard(index: i),
          ),
        TextButton(
          onPressed: () => context.app.update(() => app.calcRows.add(
              CalcRow('helper', 1, kDefaultSkillWage['helper'] ?? 450, 30))),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(t['addWorkerType'],
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.accent)),
          ),
        ),
        const SizedBox(height: 8),
        _NumberField(
          label: t['materialCost'],
          value: app.calcMaterial,
          onChanged: (v) => context.app.update(() => app.calcMaterial = v),
        ),
        _NumberField(
          label: t['equipmentCost'],
          value: app.calcEquipment,
          onChanged: (v) => context.app.update(() => app.calcEquipment = v),
        ),
        _NumberField(
          label: t['transportCost'],
          value: app.calcTransport,
          onChanged: (v) => context.app.update(() => app.calcTransport = v),
        ),
        _NumberField(
          label: t['contingency'],
          value: app.calcContingencyPct,
          hint: t['contingencyExplain'],
          onChanged: (v) =>
              context.app.update(() => app.calcContingencyPct = v.clamp(0, 50)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: C.accentTint, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              _TotalRow(t['labourCost'], app.labourCost),
              const SizedBox(height: 6),
              _TotalRow(t['materialCost'], app.calcMaterial),
              const SizedBox(height: 6),
              _TotalRow(t['equipmentCost'], app.calcEquipment),
              const SizedBox(height: 6),
              _TotalRow(t['transportCost'], app.calcTransport),
              const _CalcDivider(),
              _TotalRow(t['subtotal'], app.subtotalCost),
              const SizedBox(height: 6),
              _TotalRow(t['contingency'], app.contingencyAmount),
              const _CalcDivider(),
              Row(
                children: [
                  Expanded(
                    child: Text(t['totalEstimate'],
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: C.accent)),
                  ),
                  Text('₹${inr(app.totalCost)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: C.accent)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(t['costPerDay'],
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B8079))),
                  ),
                  Text('₹${inr(app.costPerDay)}/day',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B8079))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalcDivider extends StatelessWidget {
  const _CalcDivider();
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 10),
        color: const Color(0xFFC7DED8),
      );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF3D5A52))),
          ),
          Text('₹${inr(value)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF3D5A52))),
        ],
      );
}

class _CalcRowCard extends StatelessWidget {
  const _CalcRowCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final row = app.calcRows[index];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: C.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: row.skillId,
                  items: [
                    for (final s in kSkills) (s.id, s.name(app.copyLang))
                  ],
                  onChanged: (v) => context.app.update(() {
                    row.skillId = v;
                    row.wage = kDefaultSkillWage[v] ?? row.wage;
                  }),
                ),
              ),
              if (app.calcRows.length > 1)
                IconButton(
                  onPressed: () =>
                      context.app.update(() => app.calcRows.removeAt(index)),
                  icon: const Icon(Icons.close, size: 18, color: C.muted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SmallNumber(
                  label: t['workerCount'],
                  value: row.count,
                  onChanged: (v) => context.app.update(() => row.count = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallNumber(
                  label: t['wagePerDay'],
                  value: row.wage,
                  onChanged: (v) => context.app.update(() => row.wage = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallNumber(
                  label: t['workerDaysShort'],
                  value: row.days,
                  onChanged: (v) => context.app.update(() => row.days = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('₹${inr(row.cost)}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: C.accent)),
          ),
        ],
      ),
    );
  }
}

class _SmallNumber extends StatelessWidget {
  const _SmallNumber(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: C.mutedSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          AppTextField(
            initial: '$value',
            digitsOnly: true,
            fontSize: 13,
            maxLength: 7,
            keyboardType: TextInputType.number,
            onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
          ),
        ],
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.label),
            const SizedBox(height: 6),
            AppTextField(
              initial: '$value',
              digitsOnly: true,
              fontSize: 14,
              maxLength: 9,
              keyboardType: TextInputType.number,
              onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.4, color: C.mutedSoft)),
            ],
          ],
        ),
      );
}

/// Contractor's own profile: identity, business details, a couple of stats,
/// phone number, and the account actions every profile screen carries.
class ContractorProfile extends StatelessWidget {
  const ContractorProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;
    final totalApplicants =
        app.myPostedJobs.fold(0, (sum, j) => sum + app.applicantCountFor(j.id));
    final typeMatches =
        kContractorTypes.where((ct) => ct.id == lp.contractorType);
    final typeLabel =
        typeMatches.isEmpty ? null : typeMatches.first.label(app.copyLang);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Column(
          children: [
            Avatar(app.roleInitial, size: 76, imagePath: lp.profilePicture),
            const SizedBox(height: 8),
            Text(app.displayName,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
            if (lp.businessName.isNotEmpty || typeLabel != null) ...[
              const SizedBox(height: 3),
              Text(
                [lp.businessName, typeLabel]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(fontSize: 12.5, color: C.textSecondary),
              ),
            ],
            if (lp.phoneVerified) ...[
              const SizedBox(height: 8),
              BadgePill(t['verifiedMobileBadge'],
                  background: C.okBg, color: C.ok),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: C.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                  value: '${app.myPostedJobs.length}', label: t['myJobs']),
              _MiniStat(value: '$totalApplicants', label: t['applicants']),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(t['phoneNumber'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: lp.mobileNumber,
          digitsOnly: true,
          maxLength: 10,
          fontSize: 14,
          keyboardType: TextInputType.phone,
          onChanged: (v) => context.app.update(() => lp.mobileNumber = v),
        ),
        const SizedBox(height: 24),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.app.go(Screen.langSelect),
          child: Text(app.t['changeLanguage'],
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        const SizedBox(height: 8),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        const AccountActions(),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: C.textSecondary)),
        ],
      );
}
