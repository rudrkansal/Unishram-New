import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/catalog.dart';
import '../../data/strings.dart';
import '../../services/places_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../picker_sheet.dart';
import 'step_scaffold.dart';

/// Step 2 — what the person does. Labourers answer skills, experience, wage and
/// travel radius; contractors and clients answer their own version instead.
class WorkStep extends StatelessWidget {
  const WorkStep({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return StepScaffold(
      title: t['lpTitle2'],
      stepIndex: 1,
      stepCount: 3,
      speakText: '${t['lpTitle2']}. ${t['primarySkillQ']}',
      footer: PrimaryButton(
        t['continueBtn'],
        enabled: app.workValid,
        onTap: () => context.app.continueFromWork(),
      ),
      children: switch (app.role) {
        Role.contractor => _contractorFields(context),
        Role.client => _clientFields(context),
        _ => _labourerFields(context),
      },
    );
  }

  // ------------------------------------------------------------- labourer

  List<Widget> _labourerFields(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;
    final primary = skillById(lp.primarySkillId);

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['primarySkillQ'], sub: t['primarySkillSub']),
          const SizedBox(height: 10),
          _SelectRow(
            value: primary?.name(app.copyLang),
            placeholder: t['choosePrimarySkill'],
            action: primary == null ? t['chooseWord'] : t['changeWord'],
            onTap: () async {
              final picked = await PickerSheet.show(
                context,
                title: t['primarySkillQ'],
                subtitle: t['primarySkillSub'],
                searchHint: t['searchSkill'],
                options: [
                  for (final s in kSkills)
                    PickerOption(s.id, s.name(app.copyLang),
                        tag: categoryLabel(s.wageCategory, app.copyLang))
                ],
                selected:
                    lp.primarySkillId == null ? const [] : [lp.primarySkillId!],
                multi: false,
                emptyText: t['noSkillMatch'],
                doneLabel: t['doneBtn'],
              );
              if (picked != null && picked.isNotEmpty && context.mounted) {
                context.app.update(() {
                  lp.primarySkillId = picked.first;
                  lp.additionalSkillIds.remove(picked.first);
                });
              }
            },
          ),
          if (primary != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(t['skillLevelLabel'],
                    style: const TextStyle(fontSize: 11.5, color: C.mutedSoft)),
                const SizedBox(width: 8),
                _CategoryTag(primary.wageCategory, app.copyLang),
              ],
            ),
          ],
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['additionalSkillQ'],
              sub:
                  '${t['additionalSkillSub']} · ${lp.additionalSkillIds.length}/$kMaxAdditionalSkills ${t['selectedOf']}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in lp.additionalSkillIds)
                _RemovableChip(
                  label: app.skillNameOf(id),
                  tag: categoryLabel(
                      skillById(id)?.wageCategory ?? 'skilled', app.copyLang),
                  category: skillById(id)?.wageCategory ?? 'skilled',
                  onRemove: () => context.app
                      .update(() => lp.additionalSkillIds.remove(id)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _DashedAddButton(
            label: lp.additionalSkillIds.isEmpty
                ? t['addOtherWork']
                : t['addMoreWork'],
            onTap: () async {
              final picked = await PickerSheet.show(
                context,
                title: t['additionalSkillQ'],
                subtitle: t['additionalSkillSub'],
                searchHint: t['searchSkill'],
                options: [
                  for (final s in kSkills)
                    if (s.id != lp.primarySkillId)
                      PickerOption(s.id, s.name(app.copyLang),
                          tag: categoryLabel(s.wageCategory, app.copyLang))
                ],
                selected: lp.additionalSkillIds,
                multi: true,
                emptyText: t['noSkillMatch'],
                doneLabel: t['doneBtn'],
                skipLabel: t['skipForNow'],
                maxSelection: kMaxAdditionalSkills,
                maxSelectionMessage: t['maxSkillsToast'],
              );
              if (picked != null && context.mounted) {
                context.app.update(() => lp.additionalSkillIds = picked);
              }
            },
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['experienceQ']),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 0; n <= 10; n++)
                Pill(
                  n == 10 ? t['tenPlus'] : '$n',
                  compact: true,
                  selected: lp.experienceYears == n,
                  onTap: () => context.app.update(() {
                    lp.experienceYears = n;
                    lp.experienceIs10Plus = n == 10;
                    if (n != 0) lp.experienceMonths = null;
                  }),
                ),
            ],
          ),
          if (lp.experienceYears == 0) ...[
            const SizedBox(height: 14),
            Text(t['experienceMonthsQ'],
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.textMid)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var m = 0; m < 12; m++)
                  Pill('$m ${t['monthsShort']}',
                      compact: true,
                      selected: lp.experienceMonths == m,
                      onTap: () => context.app.update(() {
                            lp.experienceMonths = m;
                            if (m != 0) lp.isFirstJob = null;
                          })),
              ],
            ),
            if (lp.experienceMonths == 0) ...[
              const SizedBox(height: 14),
              Text(t['firstJobQ'],
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.textMid)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Pill(t['yesWord'],
                        selected: lp.isFirstJob == true,
                        onTap: () =>
                            context.app.update(() => lp.isFirstJob = true)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Pill(t['noWord'],
                        selected: lp.isFirstJob == false,
                        onTap: () =>
                            context.app.update(() => lp.isFirstJob = false)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['expectedWageQ'], required: true),
          const SizedBox(height: 10),
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
                  initial: lp.expectedWage,
                  hint: t['expectedWagePlaceholder'],
                  digitsOnly: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => context.app.update(() {
                    lp.expectedWage = v;
                    app.wageExpectation = v;
                  }),
                  onEditingComplete: () => context.app.clampExpectedWage(),
                ),
              ),
              const SizedBox(width: 8),
              Text(t['perDay'],
                  style: const TextStyle(fontSize: 13, color: C.mutedSoft)),
            ],
          ),
          if (app.wageErrorText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(app.wageErrorText,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: C.warn)),
          ],
          if (app.wageMin != null && app.wageErrorText.isEmpty) ...[
            const SizedBox(height: 8),
            Text('${t['legalMinWage']}: ₹${inr(app.wageMin!)}${t['perDay']}',
                style: T.caption),
            if (app.minWageDisclaimerLine.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(app.minWageDisclaimerLine, style: T.caption),
            ],
          ],
        ],
      ),
    ];
  }

  // ----------------------------------------------------------- contractor

  List<Widget> _contractorFields(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['businessNameQ'], sub: t['businessNameHint']),
          const SizedBox(height: 10),
          AppTextField(
            initial: lp.businessName,
            hint: t['businessNamePlaceholder'],
            onChanged: (v) => context.app.update(() => lp.businessName = v),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['contractorTypeQ']),
          const SizedBox(height: 10),
          for (final ct in kContractorTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RadioRow(
                label: ct.label(app.copyLang),
                selected: lp.contractorType == ct.id,
                onTap: () =>
                    context.app.update(() => lp.contractorType = ct.id),
              ),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['workTypeQ'],
              sub: lp.workTypeIds
                  .map((id) => kWorkTypes
                      .firstWhere((w) => w.id == id)
                      .label(app.copyLang))
                  .join(', ')),
          const SizedBox(height: 10),
          _SelectRow(
            value: lp.workTypeIds.isEmpty
                ? null
                : '${lp.workTypeIds.length} ${t['selectedOf']}',
            placeholder: t['workTypeQ'],
            action: lp.workTypeIds.isEmpty ? t['chooseWord'] : t['changeWord'],
            onTap: () async {
              final picked = await PickerSheet.show(
                context,
                title: t['workTypeQ'],
                subtitle: t['selectAllApply'],
                searchHint: t['searchSkill'],
                options: [
                  for (final w in kWorkTypes)
                    PickerOption(w.id, w.label(app.copyLang))
                ],
                selected: lp.workTypeIds,
                multi: true,
                emptyText: t['noSkillMatch'],
                doneLabel: t['doneBtn'],
              );
              if (picked != null && context.mounted) {
                context.app.update(() => lp.workTypeIds = picked);
              }
            },
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['workersRequiredQ'],
              sub: lp.workersRequiredIds
                  .map((id) => app.skillNameOf(id))
                  .join(', ')),
          const SizedBox(height: 10),
          _SelectRow(
            value: lp.workersRequiredIds.isEmpty
                ? null
                : '${lp.workersRequiredIds.length} ${t['selectedOf']}',
            placeholder: t['workersRequiredQ'],
            action: lp.workersRequiredIds.isEmpty
                ? t['chooseWord']
                : t['changeWord'],
            onTap: () async {
              final picked = await PickerSheet.show(
                context,
                title: t['workersRequiredQ'],
                subtitle: t['selectAllApply'],
                searchHint: t['searchSkill'],
                options: [
                  for (final s in kSkills)
                    PickerOption(s.id, s.name(app.copyLang),
                        tag: categoryLabel(s.wageCategory, app.copyLang))
                ],
                selected: lp.workersRequiredIds,
                multi: true,
                emptyText: t['noSkillMatch'],
                doneLabel: t['doneBtn'],
              );
              if (picked != null && context.mounted) {
                context.app.update(() => lp.workersRequiredIds = picked);
              }
            },
          ),
        ],
      ),
    ];
  }

  // --------------------------------------------------------------- client

  List<Widget> _clientFields(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['clientTypeQ']),
          const SizedBox(height: 10),
          for (final ct in kClientTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RadioRow(
                label: ct.label(app.copyLang),
                selected: lp.clientType == ct.id,
                onTap: () => context.app.update(() => lp.clientType = ct.id),
              ),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(t['workLocationQ']),
          const SizedBox(height: 10),
          _RadioRow(
            label: t['workLocCurrent'],
            selected: lp.workLocationChoice == 'current',
            onTap: () => context.app.update(() {
              lp.workLocationChoice = 'current';
              lp.projectPincode = '';
            }),
          ),
          const SizedBox(height: 8),
          _RadioRow(
            label: t['workLocDifferent'],
            selected: lp.workLocationChoice == 'different',
            onTap: () =>
                context.app.update(() => lp.workLocationChoice = 'different'),
          ),
          if (lp.workLocationChoice == 'different') ...[
            const SizedBox(height: 10),
            if (context.places.available) ...[
              _AddressAutocomplete(
                initial: lp.projectAddress,
                onSelected: (address) =>
                    context.app.applyProjectAddress(address),
              ),
              if (lp.projectAddress.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(t['orEnterPin'], style: T.caption),
                const SizedBox(height: 6),
              ] else
                const SizedBox(height: 10),
            ],
            AppTextField(
              initial: lp.projectPincode,
              hint: t['pinPlaceholder'],
              digitsOnly: true,
              maxLength: 6,
              letterSpacing: 3,
              fontSize: 17,
              keyboardType: TextInputType.number,
              onChanged: (v) => context.app.update(() => lp.projectPincode = v),
            ),
          ],
        ],
      ),
      const PhoneVerificationBlock(),
    ];
  }
}

/// Mobile number plus the OTP exchange. Clients verify here; labourers and
/// contractors verify on step 3.
class PhoneVerificationBlock extends StatelessWidget {
  const PhoneVerificationBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t['phoneNumber']),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                initial: lp.mobileNumber,
                hint: t['mobilePlaceholder'],
                digitsOnly: true,
                maxLength: 10,
                keyboardType: TextInputType.phone,
                onChanged: (v) => context.app.update(() {
                  lp.mobileNumber = v;
                  // Editing the number after an OTP went out means that OTP
                  // belongs to a different (likely wrong) number — drop it
                  // so the button reads "Send OTP" again, not a "Resend"
                  // that would reuse a token for the old number.
                  if (app.otpSent) {
                    app.otpSent = false;
                    app.otpCode = '';
                    app.authError = '';
                    app.otpSentAt = null;
                    app.otpResendCount = 0; // Reset resend counter for new number
                  }
                }),
              ),
            ),
            if (!lp.phoneVerified) ...[
              const SizedBox(width: 8),
              _ResendOtpButton(app: app, t: t, lp: lp),
            ],
          ],
        ),
        if (app.otpSent && !lp.phoneVerified) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  initial: app.otpCode,
                  hint: t['enterOtp'],
                  digitsOnly: true,
                  maxLength: 6,
                  letterSpacing: 5,
                  fontSize: 17,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => context.app.update(() => app.otpCode = v),
                ),
              ),
              const SizedBox(width: 8),
              _SideButton(
                label: t['verify'],
                enabled: app.otpCode.length == 6 && !app.otpSending,
                onTap: () => context.app.verifyOtp(),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            app.online ? t['otpSentHint'] : t['otpHintDemo'],
            style: const TextStyle(fontSize: 11.5, color: C.mutedSoft),
          ),
        ],
        if (lp.phoneVerified) ...[
          const SizedBox(height: 10),
          CheckRow(t['phoneVerifiedLabel']),
        ],
        if (app.authError.isNotEmpty) ...[
          const SizedBox(height: 10),
          WarningNote(app.authError),
        ],
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: enabled ? C.accent : C.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : C.textSecondary)),
        ),
      );
}

/// The "Send OTP" / "Resend OTP" button. Once an OTP has gone out, resend is
/// disabled for a short countdown — without this, rapidly re-tapping resend
/// is exactly what trips Firebase's "too-many-requests" abuse block, which
/// then locks out that number for hours with no way to retry sooner.
class _ResendOtpButton extends StatefulWidget {
  const _ResendOtpButton({required this.app, required this.t, required this.lp});
  final AppState app;
  final Str t;
  final Profile lp;

  @override
  State<_ResendOtpButton> createState() => _ResendOtpButtonState();
}

class _ResendOtpButtonState extends State<_ResendOtpButton> {
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _ResendOtpButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  void _syncTimer() {
    final active = widget.app.otpResendSecondsLeft > 0;
    if (active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (widget.app.otpResendSecondsLeft <= 0) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    } else if (!active && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = widget.t;
    final lp = widget.lp;
    final cooldown = app.otpResendSecondsLeft;
    final onCooldown = app.otpSent && cooldown > 0;
    final label = app.otpSending
        ? '…'
        : onCooldown
            ? '${t['resendOtp']} (${cooldown}s)'
            : app.otpSent
                ? t['resendOtp']
                : t['sendOtp'];
    return _SideButton(
      label: label,
      enabled: lp.mobileNumber.length == 10 && !app.otpSending && !onCooldown,
      onTap: () => context.app.sendOtp(resend: app.otpSent),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.value,
    required this.placeholder,
    required this.action,
    required this.onTap,
  });
  final String? value;
  final String placeholder;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(
              color: empty ? C.borderStrong : C.accent, width: empty ? 1 : 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(empty ? placeholder : value!,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
                      color: empty ? C.muted : C.text)),
            ),
            Text(action,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: C.accent)),
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? C.accentTint : C.surface,
            border: Border.all(
                color: selected ? C.accent : C.border,
                width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? C.accent : C.borderStrong, width: 2),
                  color: selected ? C.accent : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: C.text)),
              ),
            ],
          ),
        ),
      );
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.category, this.lang);
  final String category;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = categoryColors(category);
    return BadgePill(categoryLabel(category, lang), background: bg, color: fg);
  }
}

(Color, Color) categoryColors(String category) => switch (category) {
      'skilled' => (C.accentTint, C.accent),
      'semi_skilled' => (C.warnBg, C.warn),
      _ => (const Color(0xFFECEAE4), C.textSecondary),
    };

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({
    required this.label,
    required this.tag,
    required this.category,
    required this.onRemove,
  });
  final String label;
  final String tag;
  final String category;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = categoryColors(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
          color: C.accentTint, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: C.accent)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(100)),
            child: Text(tag,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: C.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 54),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.surface,
            border: Border.all(color: C.borderDashed, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.accent)),
        ),
      );
}

/// A client's project-address field: type-ahead suggestions from Google
/// Places, only shown when a key is configured. Debounced so a full second
/// of typing is one request, not one per keystroke, and billed as a single
/// session (see [PlacesService.newSessionToken]) from first keystroke to pick.
class _AddressAutocomplete extends StatefulWidget {
  const _AddressAutocomplete({required this.initial, required this.onSelected});
  final String initial;
  final ValueChanged<ResolvedAddress> onSelected;

  @override
  State<_AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<_AddressAutocomplete> {
  late String _sessionToken = context.places.newSessionToken();
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _resolving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results =
          await context.places.autocomplete(text, sessionToken: _sessionToken);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {
    setState(() {
      _suggestions = [];
      _resolving = true;
    });
    final address = await context.places
        .details(suggestion.placeId, sessionToken: _sessionToken);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _sessionToken = context.places.newSessionToken();
    });
    if (address != null) widget.onSelected(address);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appWatch.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          initial: widget.initial,
          hint: t['projectAddressHint'],
          fontSize: 14,
          onChanged: _onChanged,
        ),
        if (_resolving)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        for (final s in _suggestions)
          InkWell(
            onTap: () => _pick(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: C.mutedSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.description,
                        style: const TextStyle(fontSize: 13, color: C.text)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
