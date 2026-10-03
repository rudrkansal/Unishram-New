import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/catalog.dart';
import '../../data/strings.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../backend/experience.dart';
import '../../backend/models.dart';
import '../../widgets/common.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/feed_builder.dart';
import '../../widgets/unread_dot.dart';
import '../../widgets/report_block_sheet.dart';
import '../../widgets/search_tier_bar.dart';

/// Jobs near you — availability toggle, own skills, skill filter, job cards.
class LabourerHome extends StatelessWidget {
  const LabourerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final mySkills = app.mySkillIds;

    return Column(
      children: [
        SearchTierBar(
          tier: app.labourerSearchTier,
          onWiden: () => context.app.widenLabourerSearch(),
          onReset: () => context.app.resetLabourerSearch(),
          baseTier: SearchTier.nearby,
        ),
        Expanded(
          child: ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: C.surfaceMuted,
                  borderRadius: BorderRadius.circular(100)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Segment(
                    label: t['availableNow'],
                    active: app.lp.availability == 'available',
                    onTap: () => context.app
                        .update(() => app.lp.availability = 'available'),
                  ),
                  _Segment(
                    label: t['onProject'],
                    active: app.lp.availability != 'available',
                    onTap: () => context.app
                        .update(() => app.lp.availability = 'onProject'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (mySkills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['yourSkillsLabel'],
                    style: const TextStyle(fontSize: 12, color: C.mutedSoft)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in mySkills)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: id == app.lp.primarySkillId
                              ? C.accent
                              : C.accentTint,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(app.skillNameOf(id),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: id == app.lp.primarySkillId
                                    ? Colors.white
                                    : C.accent)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            children: [
              FilterChipPill(t['allWord'],
                  active: app.jobSkillFilter.isEmpty,
                  onTap: () =>
                      context.app.update(() => app.jobSkillFilter = '')),
              for (final id in mySkills) ...[
                const SizedBox(width: 8),
                FilterChipPill(
                  app.skillNameOf(id),
                  active: app.jobSkillFilter == skillById(id)?.jobLabel,
                  onTap: () => context.app.update(
                      () => app.jobSkillFilter = skillById(id)?.jobLabel ?? ''),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: FeedBuilder<Job>(
            stream: app.jobFeed(),
            emptyText: t['noJobsNearby'],
            builder: (context, jobs) => Column(
              children: [
                for (final job in jobs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      onTap: () => context.app.viewJob(job.id, job: job),
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
                              const SizedBox(width: 8),
                              Text(job.postedAgo, style: T.label),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                              [job.contractor, job.area, job.distance]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: T.label),
                          const SizedBox(height: 5),
                          Text(job.duration,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: C.accent)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text('₹${inr(job.wage)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: C.text)),
                              const Text('/day',
                                  style: TextStyle(
                                      fontSize: 12, color: C.textSecondary)),
                              const Spacer(),
                              _WageBadge(job: job),
                            ],
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

class _WageBadge extends StatelessWidget {
  const _WageBadge({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final below = job.wage < app.jobMinWage(job);
    return BadgePill(
      below ? app.t['minWageBadgeLow'] : app.t['minWageBadgeOk'],
      background: below ? C.warnBg : C.okBg,
      color: below ? C.warn : C.ok,
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: active ? C.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? C.text : C.textSecondary)),
        ),
      );
}

/// Job detail — location, wage versus the legal minimum, description, the
/// contractor, an expected-wage field, and a sticky Apply button.
class LabourerJobDetail extends StatelessWidget {
  const LabourerJobDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final job = app.selectedJob;
    final minWage = app.jobMinWage(job);
    final applied = app.selectedJobApplied;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(job.title,
                  style: const TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: C.text)),
              const SizedBox(height: 4),
              Text(
                  [job.contractor, job.area, job.distance]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(fontSize: 13, color: C.textSecondary)),
              const SizedBox(height: 4),
              Text(job.duration,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: C.accent)),
              const SizedBox(height: 18),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['locationDetails'], style: T.label),
                    const SizedBox(height: 10),
                    Text(t['siteAddress'],
                        style: const TextStyle(
                            fontSize: 11.5, color: C.mutedSoft)),
                    const SizedBox(height: 4),
                    Text(job.location,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                            color: C.text)),
                    const SizedBox(height: 14),
                    const Divider(color: C.surfaceMuted, height: 1),
                    const SizedBox(height: 12),
                    if (job.distance.isNotEmpty) ...[
                      _DetailRow(t['distanceFromYou'], job.distance),
                      const SizedBox(height: 10),
                    ],
                    _DetailRow(t['contractorLabel'], job.contractor),
                    if (job.startDateLabel.isEmpty &&
                        job.endDateLabel.isEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(t['jobDuration'], job.duration),
                    ] else ...[
                      if (job.startDateLabel.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(t['startDate'], job.startDateLabel),
                      ],
                      if (job.endDateLabel.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(t['endDate'], job.endDateLabel),
                      ],
                      const SizedBox(height: 10),
                      _DetailRow(t['jobDuration'], job.durationSpan),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(t['wageComparison'], style: T.label)),
                        BadgePill(
                          job.wage < minWage
                              ? t['minWageBadgeLow']
                              : t['minWageBadgeOk'],
                          background: job.wage < minWage ? C.warnBg : C.okBg,
                          color: job.wage < minWage ? C.warn : C.ok,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _WageRow(
                      label: t['offeredWage'],
                      value: '₹${inr(job.wage)}',
                      fraction: job.wage / 1000,
                      color: C.accent,
                    ),
                    const SizedBox(height: 12),
                    _WageRow(
                      label: t['legalMinWage'],
                      value: '₹${inr(minWage)}',
                      fraction: minWage / 1000,
                      color: C.textSecondary,
                    ),
                    if (app.minWageDisclaimerLine.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(app.minWageDisclaimerLine, style: T.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(t['description'], style: T.label),
              const SizedBox(height: 6),
              Text(job.desc, style: T.body),
              const SizedBox(height: 18),
              SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Avatar(initialsOf(job.contractor)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.contractor,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: C.text)),
                          const SizedBox(height: 2),
                          Text(t['contractorLabel'],
                              style: const TextStyle(
                                  fontSize: 11.5, color: C.textSecondary)),
                        ],
                      ),
                    ),
                    // A worker can always message a contractor about a job;
                    // the phone number only appears once the contractor has
                    // shortlisted or hired them for it.
                    // No Message / Contact on a job you posted yourself.
                    if (job.contractorUid != app.uid)
                    StreamBuilder<ApplicationDoc?>(
                      stream: app.myApplicationForJob(job.id),
                      builder: (context, snapshot) {
                        final approved = snapshot.data != null &&
                            AppState.isApprovedStatus(snapshot.data!.status);
                        if (approved) {
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: app.getContractorContact(job.id),
                            builder: (context, phoneSnapshot) {
                              final phone = phoneSnapshot.data?['contractorPhone'] as String? ?? '';
                              return _SmallAccentButton(
                                label: t['contact'],
                                onTap: phone.isNotEmpty
                                    ? () => context.app.openContact(ContactTarget(
                                      name: job.contractor,
                                      subtitle: '${t['contractorLabel']} · ${job.area}',
                                      phone: phone,
                                      chatJobId: job.id,
                                      chatPeerId: job.contractorUid,
                                    ))
                                    : () => context.app.openChatLive(
                                      peerId: job.contractorUid,
                                      peerName: job.contractor,
                                      jobId: job.id,
                                      jobTitle: job.title,
                                      back: Screen.labourerJobDetail,
                                    ),
                              );
                            },
                          );
                        }
                        return _SmallAccentButton(
                          label: t['messages'],
                          onTap: () => context.app.openChatLive(
                            peerId: job.contractorUid,
                            peerName: job.contractor,
                            jobId: job.id,
                            jobTitle: job.title,
                            back: Screen.labourerJobDetail,
                          ),
                        );
                      },
                    ),
                    InkWell(
                      onTap: () => showReportBlockSheet(context,
                          userId: job.contractorUid,
                          userName: job.contractor,
                          jobId: job.id),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child:
                            Icon(Icons.more_vert, size: 20, color: C.mutedSoft),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(t['yourExpectedWageQ'], style: T.label),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('₹',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: C.textMid)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      initial: app.jobApplyWage,
                      hint: inr(job.wage),
                      digitsOnly: true,
                      maxLength: 6,
                      fontSize: 14,
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          context.app.update(() => app.jobApplyWage = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(t['perDay'],
                      style: const TextStyle(fontSize: 13, color: C.mutedSoft)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  '${t['contractorOfferedNote']} ₹${inr(job.wage)}${t['perDay']}',
                  style: const TextStyle(fontSize: 11.5, color: C.mutedSoft)),
            ],
          ),
        ),
        Container(
          color: C.appBg,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: PrimaryButton(
            applied ? t['applied'] : t['apply'],
            enabled: !applied,
            onTap: () => context.app.applyToJobLive(job),
          ),
        ),
      ],
    );
  }
}

class _WageRow extends StatelessWidget {
  const _WageRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });
  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12.5, color: C.textSecondary))),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: C.text)),
            ],
          ),
          const SizedBox(height: 6),
          WageBar(fraction: fraction, color: color),
        ],
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: C.text))),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
          ),
        ],
      );
}

class _SmallAccentButton extends StatelessWidget {
  const _SmallAccentButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: C.accent, borderRadius: BorderRadius.circular(10)),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      );
}

class LabourerApplications extends StatelessWidget {
  const LabourerApplications({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return FeedBuilder<ApplicationDoc>(
      stream: app.myApplications(),
      emptyText: t['noApplicationsYet'],
      builder: (context, applications) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: applications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final application = applications[i];
          return StreamBuilder<Job?>(
            stream: app.jobStream(application.jobId),
            builder: (context, snapshot) {
              final job = snapshot.data;
              if (job == null) return const SizedBox.shrink();
              return _ApplicationCard(app: app, t: t, job: job, application: application);
            },
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.app,
    required this.t,
    required this.job,
    required this.application,
  });
  final AppState app;
  final Str t;
  final Job job;
  final ApplicationDoc application;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: C.text)),
                const SizedBox(height: 5),
                Text('${job.contractor} · ${job.area}', style: T.label),
                const SizedBox(height: 4),
                Text(job.duration,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: C.accent)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatusBadge(status: application.status),
                    const Spacer(),
                    // The phone number only appears once the contractor has
                    // shortlisted or hired for this job; messaging is always
                    // open regardless of status.
                    if (AppState.isApprovedStatus(application.status)) ...[
                      FutureBuilder<Map<String, dynamic>?>(
                        future: app.getContractorContact(job.id),
                        builder: (context, phoneSnapshot) {
                          final phone = phoneSnapshot.data?['contractorPhone'] as String? ?? '';
                          return TextButton(
                            onPressed: phone.isNotEmpty
                                ? () => context.app.openContact(ContactTarget(
                                  name: job.contractor,
                                  subtitle: '${t['contractorLabel']} · ${job.area}',
                                  phone: phone,
                                  chatJobId: job.id,
                                  chatPeerId: application.contractorId,
                                ))
                                : null,
                            child: Text('${t['contact']} ›',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                color: C.accent)),
                          );
                        },
                      ),
                    ],
                    if (application.contractorId != app.uid)
                    TextButton(
                      onPressed: () => context.app.openChatLive(
                        peerId: application.contractorId,
                        peerName: job.contractor,
                        jobId: job.id,
                        jobTitle: job.title,
                        back: Screen.labourerApplications,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${t['messages']} ›',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: C.accent)),
                          UnreadDot(
                              app: app,
                              otherUid: application.contractorId,
                              jobId: job.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
  }
}

/// Pending, shortlisted, rejected or hired — the worker sees where they stand.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.appWatch.t;
    final (bg, fg, label) = switch (status) {
      'shortlisted' => (C.okBg, C.ok, t['shortlisted']),
      'hired' => (C.okBg, C.ok, t['hired']),
      'rejected' => (C.dangerBg, C.danger, t['rejected']),
      _ => (C.surfaceMuted, C.textSecondary, t['pending']),
    };
    return BadgePill(label, background: bg, color: fg);
  }
}

class LabourerProfile extends StatelessWidget {
  const LabourerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            children: [
              Avatar(initialsOf(app.displayName),
                  size: 76, imagePath: lp.profilePicture),
              const SizedBox(height: 10),
              Text(app.displayName,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: C.text)),
              const SizedBox(height: 8),
              BadgePill(
                lp.phoneVerified ? t['verifiedMobileBadge'] : t['notVerifiedBadge'],
                background: lp.phoneVerified ? C.okBg : C.surfaceMuted,
                color: lp.phoneVerified ? C.ok : C.textSecondary,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['skills'], style: T.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (lp.primarySkillId != null)
                    _SkillTag(
                        label: app.skillNameOf(lp.primarySkillId),
                        primary: true),
                  for (final id in lp.additionalSkillIds)
                    _SkillTag(
                      label: app.skillNameOf(id),
                      onRemove: () => context.app
                          .update(() => lp.additionalSkillIds.remove(id)),
                    ),
                  if (lp.primarySkillId == null)
                    for (final s in app.extraSkills)
                      _SkillTag(
                        label: s,
                        onRemove: () =>
                            context.app.update(() => app.extraSkills.remove(s)),
                      ),
                ],
              ),
              const SizedBox(height: 18),
              _StatBox(
                label: t['experience'],
                value: _experienceLabel(app),
              ),
              const SizedBox(height: 18),
              Text(t['wageExpectation'], style: T.label),
              const SizedBox(height: 6),
              AppTextField(
                initial: app.wageExpectation,
                digitsOnly: true,
                maxLength: 6,
                fontSize: 14,
                keyboardType: TextInputType.number,
                onChanged: (v) => context.app.update(() {
                  app.wageExpectation = v;
                  lp.expectedWage = v;
                }),
                onEditingComplete: () => context.app.clampExpectedWage(),
              ),
              const SizedBox(height: 24),
              const Divider(color: C.border),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.app.go(Screen.langSelect),
                child: Text(t['changeLanguage'],
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
          ),
        ),
      ],
    );
  }

  static String _experienceLabel(AppState app) {
    final lp = app.lp;
    final t = app.t;
    final total = effectiveExperienceMonths(
        years: lp.experienceYears,
        months: lp.experienceMonths,
        asOf: lp.experienceAsOf);
    if (total == null) return '—';
    return experienceLabel(total,
        tenPlus: lp.experienceIs10Plus,
        monthsWord: t['monthsShort'],
        yearsWord: t['yearsShort'],
        tenPlusWord: t['tenPlus']);
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, this.action});
  final String label;
  final String value;
  final String? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: C.text)),
                ),
                if (action != null) ...[
                  const SizedBox(width: 6),
                  Text(action!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: C.accent)),
                ],
              ],
            ),
          ],
        ),
      );
}

class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.label, this.primary = false, this.onRemove});
  final String label;
  final bool primary;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? C.accentTint : C.surfaceMuted,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w400,
                    color: primary ? C.accent : C.text)),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 13, color: C.muted),
                ),
              ),
            ],
          ],
        ),
      );
}

class LabourerRatings extends StatelessWidget {
  const LabourerRatings({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return FeedBuilder<Review>(
      stream: app.reviewFeed(),
      emptyText: t['noReviewsYet'],
      builder: (context, reviews) {
        final average =
            reviews.fold<int>(0, (a, r) => a + r.rating) / reviews.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            Row(
              children: [
                Text(average.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: C.text)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_stars(average),
                        style: const TextStyle(fontSize: 13, color: C.text)),
                    const SizedBox(height: 2),
                    Text('${reviews.length} ${t['ratings']}',
                        style: const TextStyle(
                            fontSize: 12, color: C.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final r in reviews)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: C.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: C.text)),
                        ),
                        Text(_stars(r.rating.toDouble()),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: C.accent)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(r.comment,
                        style: const TextStyle(
                            fontSize: 13, height: 1.4, color: C.textMid)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _stars(double n) {
    final filled = n.round();
    return '★' * filled + '☆' * (5 - filled);
  }
}
