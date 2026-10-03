import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_scope.dart';
import '../../data/catalog.dart';
import '../../data/strings.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../picker_sheet.dart';
import 'step_scaffold.dart';

/// Step 1 — name, gender, spoken languages, where they live, and age.
class PersonalStep extends StatefulWidget {
  const PersonalStep({super.key});

  @override
  State<PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends State<PersonalStep> {
  final _location = LocationService();
  bool _languagesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;

    return StepScaffold(
      title: t['lpTitle1'],
      stepIndex: 0,
      stepCount: 3,
      speakText:
          '${t['lpTitle1']}. ${t['fullName']}. ${t['whereLabel']} ${t['ageQ']}',
      footer: PrimaryButton(
        t['continueBtn'],
        enabled: app.personalValid,
        onTap: () => context.app.continueFromPersonal(),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(t['fullName']),
            AppTextField(
              initial: lp.fullName,
              hint: t['fullNamePlaceholder'],
              onChanged: (v) => context.app.update(() => lp.fullName = v),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(t['gender']),
            Row(
              children: [
                for (final g in [
                  ('male', t['male']),
                  ('female', t['female']),
                  ('other', t['otherGender'])
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill(
                        g.$2,
                        selected: lp.gender == g.$1,
                        onTap: () => context.app.update(() => lp.gender = g.$1),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(t['languagesSpoken'], sub: t['selectAllApply']),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final lang in (_languagesExpanded
                    ? kLanguages
                    : kLanguages.take(9).toList()))
                  Pill(
                    lang.native,
                    compact: true,
                    selected: lp.languagesSpoken.contains(lang.code),
                    onTap: () => context.app.toggleLanguageSpoken(lang.code),
                  ),
                InkWell(
                  onTap: () =>
                      setState(() => _languagesExpanded = !_languagesExpanded),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      _languagesExpanded ? '−' : '+ ${kLanguages.length - 9}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: C.accent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        _LocationSection(location: _location),
        _AgeSection(),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.location});
  final LocationService location;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;
    final resolved = app.hasResolvedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t['whereLabel'], sub: t['whereSub']),
        const SizedBox(height: 10),
        if (resolved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: C.accentTint,
              border: Border.all(color: C.accent, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: C.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lp.city.isNotEmpty ? lp.city : lp.district,
                          style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: C.text)),
                      const SizedBox(height: 2),
                      Text(
                        [lp.district, lp.state, lp.pincode]
                            .where((e) => e.isNotEmpty && e != lp.city)
                            .join(', '),
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF3D5A52)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.app.clearLocation(),
                  child: Text(t['changeWord'],
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: C.accent)),
                ),
              ],
            ),
          )
        else ...[
          OutlineButton(
            app.gpsLocating ? t['locatingNow'] : t['useMyLocation'],
            icon: app.gpsLocating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: C.accent))
                : const Icon(Icons.my_location, size: 18, color: C.accent),
            onTap: app.gpsLocating ? null : () => _locate(context),
          ),
          if (app.gpsError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(app.gpsError,
                style: const TextStyle(fontSize: 12.5, color: C.warn)),
            if (app.gpsFailure == LocationFailure.off ||
                app.gpsFailure == LocationFailure.denied) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => app.gpsFailure == LocationFailure.off
                    ? Geolocator.openLocationSettings()
                    : Geolocator.openAppSettings(),
                child: Text(
                  app.gpsFailure == LocationFailure.off
                      ? t['openLocationSettings']
                      : t['openAppSettings'],
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Divider(color: C.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(t['orWord'],
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
              ),
              const Expanded(child: Divider(color: C.border)),
            ],
          ),
          const SizedBox(height: 12),
          _StateSelector(),
          const SizedBox(height: 10),
          AppTextField(
            initial: lp.city,
            hint: t['townPlaceholder'],
            onChanged: (v) => context.app.update(() => lp.city = v),
          ),
          const SizedBox(height: 10),
          AppTextField(
            initial: lp.pincode,
            hint: t['pinPlaceholder'],
            digitsOnly: true,
            maxLength: 6,
            letterSpacing: 3,
            fontSize: 17,
            keyboardType: TextInputType.number,
            onChanged: (v) => context.app.applyPin(v),
          ),
          if (app.pinNotFound) ...[
            const SizedBox(height: 8),
            Text(t['pinNotFound'],
                style: const TextStyle(fontSize: 12.5, color: C.warn)),
          ],
          if (app.pinStateMismatch) ...[
            const SizedBox(height: 8),
            Text(t['pinStateMismatch'],
                style: const TextStyle(fontSize: 12.5, color: C.warn)),
          ],
        ],
      ],
    );
  }

  Future<void> _locate(BuildContext context) async {
    final app = context.app;
    app.update(() {
      app.gpsLocating = true;
      app.gpsError = '';
    });
    final result = await location.current();
    if (!context.mounted) return;
    final t = app.t;
    app.update(() {
      app.gpsLocating = false;
      final place = result.place;
      if (place == null) {
        app.locationManual = true;
        app.gpsFailure = result.failure;
        app.gpsError = switch (result.failure) {
          LocationFailure.off => t['gpsOff'],
          LocationFailure.denied => t['gpsDenied'],
          _ => t['gpsUnsupported'],
        };
        return;
      }
      app.gpsFailure = null;
      app.lp.lat = place.lat;
      app.lp.lng = place.lng;
      app.lp.city = place.city;
      app.lp.district = place.district;
      app.lp.state = _matchState(place.state);
      app.lp.pincode = place.pincode;
      app.lp.currentLocation =
          [place.city, place.state].where((e) => e.isNotEmpty).join(', ');
      app.locationManual = false;
      app.pinNotFound = false;
      app.gpsError = '';
      // Without a readable address there is nothing to show — ask for it.
      if (place.state.isEmpty && place.district.isEmpty) {
        app.locationManual = true;
        app.gpsError = t['gpsUnsupported'];
      }
    });
    if (result.failure == LocationFailure.off && context.mounted) {
      _showLocationOffDialog(context);
    }
  }

  Future<void> _showLocationOffDialog(BuildContext context) async {
    final t = context.app.t;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t['locationOffDialogTitle']),
        content: Text(t['locationOffDialogBody']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t['cancel']),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Geolocator.openLocationSettings();
            },
            child: Text(t['openLocationSettings']),
          ),
        ],
      ),
    );
  }

  /// The geocoder's state name has to line up with the minimum-wage table, so
  /// match it against the canonical list rather than storing it verbatim.
  static String _matchState(String raw) {
    if (raw.isEmpty) return '';
    final needle = raw.toLowerCase();
    for (final s in kStates) {
      if (s.toLowerCase() == needle) return s;
    }
    for (final s in kStates) {
      if (needle.contains(s.toLowerCase()) ||
          s.toLowerCase().contains(needle)) {
        return s;
      }
    }
    return raw;
  }
}

class _StateSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final chosen = app.lp.state;
    return InkWell(
      onTap: () async {
        final picked = await PickerSheet.show(
          context,
          title: t['chooseState'],
          subtitle: t['whereSub'],
          searchHint: t['searchState'],
          options: [
            for (final s in kStates) PickerOption(s, stateName(s, app.copyLang))
          ],
          selected: chosen.isEmpty ? const [] : [chosen],
          multi: false,
          emptyText: t['noSkillMatch'],
          doneLabel: t['doneBtn'],
        );
        if (picked != null && picked.isNotEmpty && context.mounted) {
          context.app.pickHomeState(picked.first);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(
              color: chosen.isEmpty ? C.borderStrong : C.accent,
              width: chosen.isEmpty ? 1 : 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chosen.isEmpty
                    ? t['chooseState']
                    : stateName(chosen, app.copyLang),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      chosen.isEmpty ? FontWeight.w400 : FontWeight.w700,
                  color: chosen.isEmpty ? C.muted : C.text,
                ),
              ),
            ),
            Text(chosen.isEmpty ? t['chooseWord'] : t['changeWord'],
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

class _AgeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final lp = app.lp;
    final year = DateTime.now().year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t['ageQ'], sub: t['ageSub']),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in [18, 20, 25, 30, 35, 40, 45, 50, 55, 65])
              Pill('$n',
                  compact: true,
                  selected: lp.age == n,
                  onTap: () => context.app.setAge(n)),
          ],
        ),
        if (lp.age != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              _StepButton(
                  icon: Icons.remove,
                  onTap: () => context.app.setAge((lp.age ?? 25) - 1)),
              Expanded(
                child: Column(
                  children: [
                    Text('${lp.age} ${t['yearsOldWord']}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: C.text)),
                    const SizedBox(height: 2),
                    Text('${t['bornAround']} ${year - lp.age!}',
                        style: const TextStyle(
                            fontSize: 11.5, color: C.mutedSoft)),
                  ],
                ),
              ),
              _StepButton(
                  icon: Icons.add,
                  onTap: () => context.app.setAge((lp.age ?? 25) + 1)),
            ],
          ),
        ],
        TextButton(
          onPressed: () =>
              context.app.update(() => app.showExactDob = !app.showExactDob),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6)),
          child: Text(app.showExactDob ? t['exactDobHide'] : t['exactDobAdd'],
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: C.accent)),
        ),
        if (app.showExactDob)
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final initial = lp.dateOfBirth.isNotEmpty
                  ? DateTime.tryParse(lp.dateOfBirth) ??
                      DateTime(now.year - 25, now.month, now.day)
                  : DateTime(now.year - (lp.age ?? 25), now.month, now.day);
              // Same floor as the age stepper: nobody (of any role) can pick a date implying
              // under kMinAgeYears in the first place, rather than only being told so after
              // they try to continue.
              final latestAllowed =
                  DateTime(now.year - kMinAgeYears, now.month, now.day);
              final picked = await showDatePicker(
                context: context,
                initialDate: initial.isAfter(latestAllowed)
                    ? latestAllowed
                    : initial,
                firstDate: DateTime(now.year - 100),
                lastDate: latestAllowed,
              );
              if (picked != null && context.mounted) {
                context.app.setDob(
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: C.surface,
                border: Border.all(color: C.borderStrong),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lp.dateOfBirth.isEmpty ? t['dob'] : lp.dateOfBirth,
                style: TextStyle(
                    fontSize: 16,
                    color: lp.dateOfBirth.isEmpty ? C.muted : C.text),
              ),
            ),
          ),
        if (app.dobError.isNotEmpty) ...[
          const SizedBox(height: 12),
          WarningNote(app.dobError),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.surface,
            border: Border.all(color: C.borderStrong, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: C.text),
        ),
      );
}
