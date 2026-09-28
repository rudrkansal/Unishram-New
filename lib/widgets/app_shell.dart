import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../services/voice_command_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'unread_dot.dart';

class NavItem {
  final Screen target;
  final String label;
  final List<Screen> activeOn;
  final IconData icon;
  const NavItem(this.target, this.label, this.activeOn, this.icon);
}

List<NavItem> navItemsFor(AppState app) {
  final t = app.t;
  return switch (app.role) {
    Role.labourer => [
        NavItem(Screen.labourerHome, t['navJobs'],
            const [Screen.labourerHome, Screen.labourerJobDetail],
            Icons.work_outline),
        NavItem(Screen.labourerApplications, t['navApplications'],
            const [Screen.labourerApplications, Screen.chatThread],
            Icons.assignment_outlined),
        NavItem(Screen.labourerRatings, t['navRatings'],
            const [Screen.labourerRatings], Icons.star_outline),
        NavItem(Screen.labourerProfile, t['navProfile'],
            const [Screen.labourerProfile], Icons.person_outline),
      ],
    Role.contractor => [
        NavItem(Screen.contractorHome, t['navMyJobs'], const [
          Screen.contractorHome,
          Screen.contractorApplicants,
          Screen.chatThread
        ], Icons.work_outline),
        NavItem(Screen.contractorPost, t['navPost'],
            const [Screen.contractorPost], Icons.add_box_outlined),
        NavItem(Screen.contractorFind, t['navFind'],
            const [Screen.contractorFind, Screen.contractorWorkerDetail],
            Icons.search),
        NavItem(Screen.contractorCalc, t['navCalc'],
            const [Screen.contractorCalc], Icons.calculate_outlined),
        NavItem(Screen.contractorProfile, t['navProfile'],
            const [Screen.contractorProfile], Icons.person_outline),
      ],
    Role.client => [
        NavItem(Screen.clientSearch, t['navSearch'], const [
          Screen.clientSearch,
          Screen.clientContractorDetail,
          Screen.contractorWorkerDetail
        ], Icons.search),
        NavItem(Screen.clientVendor, t['navPrices'],
            const [Screen.clientVendor], Icons.storefront_outlined),
        NavItem(Screen.clientCalc, t['navCalc'], const [Screen.clientCalc],
            Icons.calculate_outlined),
        NavItem(Screen.clientProfile, t['navProfile'],
            const [Screen.clientProfile], Icons.person_outline),
      ],
    Role.vendor => [
        NavItem(Screen.vendorListings, t['navListings'],
            const [Screen.vendorListings], Icons.list_alt_outlined),
        NavItem(Screen.vendorProfile, t['navProfile'],
            const [Screen.vendorProfile], Icons.person_outline),
      ],
    null => const [],
  };
}

String headerTitleFor(AppState app) {
  final t = app.t;
  return switch (app.screen) {
    Screen.labourerHome => t['jobsNearYou'],
    Screen.labourerJobDetail => t['jobTitle'],
    Screen.labourerApplications => t['myApplications'],
    Screen.labourerProfile => t['myProfile'],
    Screen.labourerRatings => t['ratings'],
    Screen.contractorHome => t['myJobs'],
    Screen.contractorApplicants => t['applicants'],
    Screen.contractorPost => t['postJob'],
    Screen.contractorFind => t['findWorkers'],
    Screen.contractorWorkerDetail => t['profile'],
    Screen.contractorCalc || Screen.clientCalc => t['calculator'],
    Screen.contractorProfile => t['profile'],
    Screen.clientSearch => t['search'],
    Screen.clientContractorDetail => t['profile'],
    Screen.clientVendor => t['vendorPrices'],
    Screen.clientProfile => t['profile'],
    Screen.vendorListings => t['myListings'],
    Screen.vendorProfile => t['profile'],
    Screen.chatThread => t['messages'],
    _ => '',
  };
}

const Set<Screen> _screensWithBack = {
  Screen.labourerJobDetail,
  Screen.contractorWorkerDetail,
  Screen.clientContractorDetail,
  Screen.contractorApplicants,
  Screen.chatThread,
};

/// The white header bar: role switcher (or back arrow), title, and the
/// Listen button that reads the screen aloud.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final showBack = _screensWithBack.contains(app.screen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
          if (showBack)
            RoundIconButton(
              onTap: () => context.app.goBack(),
              child: const Icon(Icons.chevron_left, color: C.text),
            )
          else
            RoundIconButton(
              tooltip: app.t['switchRole'],
              background: C.accent,
              onTap: () => context.app.switchRole(),
              child: Text(app.roleInitial,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          Expanded(
            child: Text(
              headerTitleFor(app),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: C.text),
            ),
          ),
          if (app.voiceAvailable)
            RoundIconButton(
              tooltip: app.t['listen'],
              onTap: () => context.speakAloud(_screenSpeech(app)),
              child: SpeakerIcon(active: app.speaking, size: 18),
            ),
        ],
      ),
    );
  }

  /// What the Listen button reads on each screen — the title plus the single
  /// most useful fact, rather than the whole page.
  static String _screenSpeech(AppState app) {
    final t = app.t;
    final title = headerTitleFor(app);
    return switch (app.screen) {
      Screen.labourerHome => () {
          final jobs = app.filteredJobs;
          if (jobs.isEmpty) return title;
          final j = jobs.first;
          final distancePart = j.distance.isEmpty ? '' : ' ${j.distance}.';
          return '$title. ${j.title}. ${j.contractor}.$distancePart ₹${inr(j.wage)} ${t['perDay']}.';
        }(),
      Screen.labourerJobDetail => () {
          final j = app.selectedJob;
          return '${j.title}. ${j.contractor}. ${j.area}. ${t['offeredWage']} ₹${inr(j.wage)}. ${t['legalMinWage']} ₹${inr(app.jobMinWage(j))}.';
        }(),
      Screen.contractorCalc ||
      Screen.clientCalc =>
        '$title. ${t['totalEstimate']} ₹${inr(app.totalCost)}.',
      _ => title,
    };
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final items = navItemsFor(app);
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: () => context.app.go(item.target),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 26,
                          color: item.activeOn.contains(app.screen)
                              ? C.accent
                              : C.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: item.activeOn.contains(app.screen)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: item.activeOn.contains(app.screen)
                                  ? C.text
                                  : C.muted,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ToastBanner extends StatelessWidget {
  const ToastBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final message = context.appWatch.toast;
    if (message.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 84,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: C.text,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.white)),
        ),
      ),
    );
  }
}

/// The contact sheet: the verified number, a real dial action, and a way into
/// the message thread.
class ContactSheet extends StatelessWidget {
  const ContactSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final card = app.contactCard;
    if (card == null) return const SizedBox.shrink();
    final t = app.t;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: GestureDetector(
          onTap: () => context.app.closeContact(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  decoration: const BoxDecoration(
                    color: C.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Avatar(initialsOf(card.name), size: 50),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(card.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: C.text)),
                                  const SizedBox(height: 2),
                                  Text(card.subtitle,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: C.textSecondary)),
                                ],
                              ),
                            ),
                            RoundIconButton(
                              onTap: () => context.app.closeContact(),
                              child: const Icon(Icons.close,
                                  size: 18, color: C.textMid),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F4EF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['contactCardHint'].toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 10.5,
                                            letterSpacing: 0.4,
                                            color: C.mutedSoft)),
                                    const SizedBox(height: 3),
                                    Text(card.phone.isEmpty ? '—' : card.phone,
                                        style: const TextStyle(
                                            fontSize: 17,
                                            letterSpacing: 0.4,
                                            fontWeight: FontWeight.w700,
                                            color: C.text)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                    color: C.ok, shape: BoxShape.circle),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                t['callNow'],
                                enabled: card.phone.isNotEmpty,
                                icon: const Icon(Icons.call,
                                    size: 16, color: Colors.white),
                                onTap: () => _dial(card.phone),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final target = card;
                                      final back = app.screen;
                                      context.app.closeContact();
                                      context.app.openChatLive(
                                        peerId: target.chatPeerId ?? 'me',
                                        peerName: target.name,
                                        jobId: target.chatJobId,
                                        back: back,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 52),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: C.surfaceMuted,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(t['sendMessage'],
                                          style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: C.text)),
                                    ),
                                  ),
                                  if (card.chatPeerId != null)
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: UnreadDot(
                                          app: app,
                                          otherUid: card.chatPeerId!,
                                          jobId: card.chatJobId),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dial(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:+91$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

/// Shown while the microphone is open, so the user can see they were heard.
class VoiceListeningOverlay extends StatelessWidget {
  const VoiceListeningOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    if (!app.voiceListening && !app.voiceTranscribing) {
      return const SizedBox.shrink();
    }
    final t = app.t;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 84,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: C.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (app.voiceTranscribing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.mic, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        app.voiceTranscribing
                            ? t['voiceUnderstanding']
                            : t['voiceListening'],
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                app.voiceHeard.isEmpty
                    ? (app.voiceTranscribing ? '' : t['voiceStopHint'])
                    : app.voiceHeard,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice control: listen for one command, then act on it.
Future<void> startVoiceCommand(BuildContext context) async {
  final app = context.app;
  final voice = context.voice;
  if (voice.listening) {
    await voice.stop();
    return;
  }
  final result = await voice.listen(
    languageTag: app.voiceLocale,
    appLanguage: app.spokenLanguage,
    onCommand: (transcript) => _handleCommand(app, transcript),
  );

  if (!result.started) {
    app.showToast(result.failure == VoiceFailure.languageUnsupported
        ? app.t['voiceLanguageUnsupported']
        : app.t['voiceUnavailable']);
    return;
  }
}

void _handleCommand(AppState app, String transcript) {
  final intent = matchIntent(transcript);
  if (intent == null) {
    app.showToast('${app.t['voiceNoMatch']}: "$transcript"');
    return;
  }
  switch (intent) {
    case VoiceIntent.back:
      app.goBack();
    case VoiceIntent.switchRole:
      app.switchRole();
    case VoiceIntent.apply:
      if (app.screen == Screen.labourerJobDetail) {
        app.applyToSelectedJob();
      } else {
        app.go(Screen.labourerHome);
      }
    case VoiceIntent.read:
      app.showToast('${app.t['voiceHeard']}: "$transcript"');
    default:
      final target = _targetFor(app, intent);
      if (target != null) {
        app.go(target);
      } else {
        app.showToast(app.t['voiceNoMatch']);
      }
  }
}

/// A command means different screens per role, and must never land a user on
/// a screen their role has no navigation back from.
Screen? _targetFor(AppState app, VoiceIntent intent) {
  return switch ((app.role, intent)) {
    (Role.labourer, VoiceIntent.jobs) => Screen.labourerHome,
    (Role.labourer, VoiceIntent.applications) => Screen.labourerApplications,
    (Role.labourer, VoiceIntent.profile) => Screen.labourerProfile,
    (Role.labourer, VoiceIntent.ratings) => Screen.labourerRatings,
    (Role.contractor, VoiceIntent.jobs) => Screen.contractorHome,
    (Role.contractor, VoiceIntent.postJob) => Screen.contractorPost,
    (Role.contractor, VoiceIntent.findWorkers) => Screen.contractorFind,
    (Role.contractor, VoiceIntent.calculator) => Screen.contractorCalc,
    (Role.client, VoiceIntent.search) => Screen.clientSearch,
    (Role.client, VoiceIntent.findWorkers) => Screen.clientSearch,
    (Role.client, VoiceIntent.prices) => Screen.clientVendor,
    (Role.client, VoiceIntent.calculator) => Screen.clientCalc,
    (Role.client, VoiceIntent.profile) => Screen.clientProfile,
    (Role.vendor, VoiceIntent.listings) => Screen.vendorListings,
    (Role.vendor, VoiceIntent.profile) => Screen.vendorProfile,
    _ => null,
  };
}

/// The microphone that opens voice control. Lives in the header wherever the
/// screen has one, so it never covers the primary action.
class VoiceCommandButton extends StatelessWidget {
  const VoiceCommandButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    if (!app.voiceAvailable) return const SizedBox.shrink();
    return RoundIconButton(
      tooltip: app.t['voiceControl'],
      background: app.voiceListening ? C.accentTint : C.surfaceMuted,
      onTap: () => startVoiceCommand(context),
      child: Icon(app.voiceListening ? Icons.mic : Icons.mic_none,
          size: 20, color: app.voiceListening ? C.accent : C.text),
    );
  }
}
