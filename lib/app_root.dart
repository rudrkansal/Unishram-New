import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'screens/blocked_users_screen.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/home/client_vendor_screens.dart';
import 'screens/home/contractor_screens.dart';
import 'screens/home/labourer_screens.dart';
import 'screens/language_screen.dart';
import 'screens/onboarding/contact_step.dart';
import 'screens/onboarding/personal_step.dart';
import 'screens/onboarding/work_step.dart';
import 'screens/role_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/terms_screens.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/rating_prompt_gate.dart';

/// The single surface the whole app renders into: header and bottom nav on the
/// home tier, bare content on the entry tier, with the toast, contact sheet and
/// voice overlay layered on top.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final showChrome = app.showBottomNav;

    return Directionality(
      textDirection: app.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          context.app.goBack();
        },
        child: Scaffold(
          backgroundColor: C.appBg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: !showChrome,
            child: Stack(
              children: [
                Column(
                  children: [
                    if (showChrome) const AppHeader(),
                    Expanded(
                      child: RatingPromptGate(
                        screen: app.screen,
                        child: _content(app.screen),
                      ),
                    ),
                    if (showChrome) const AppBottomNav(),
                  ],
                ),
                const ToastBanner(),
                const ContactSheet(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Screen screen) => switch (screen) {
        Screen.splash => const SplashScreen(),
        Screen.langSelect => const LanguageScreen(),
        Screen.roleSelect => const RoleScreen(),
        Screen.vendorComingSoon => const ComingSoonScreen(),
        Screen.profilePersonal => const PersonalStep(),
        Screen.profileWork => const WorkStep(),
        Screen.profileContact => const ContactStep(),
        Screen.labourerHome => const LabourerHome(),
        Screen.labourerJobDetail => const LabourerJobDetail(),
        Screen.labourerApplications => const LabourerApplications(),
        Screen.labourerProfile => const LabourerProfile(),
        Screen.labourerRatings => const LabourerRatings(),
        Screen.contractorHome => const ContractorHome(),
        Screen.contractorApplicants => const ContractorApplicants(),
        Screen.contractorPost => const ContractorPost(),
        Screen.contractorFind => const ContractorFind(),
        Screen.contractorWorkerDetail => const WorkerDetail(),
        Screen.contractorCalc || Screen.clientCalc => const CostCalculator(),
        Screen.contractorProfile => const ContractorProfile(),
        Screen.clientSearch => const ClientSearch(),
        Screen.clientContractorDetail => const ClientContractorDetail(),
        Screen.clientVendor => const VendorPrices(),
        Screen.clientProfile => const ClientProfile(),
        Screen.vendorListings => const VendorListings(),
        Screen.vendorProfile => const VendorProfile(),
        Screen.chatThread => const ChatThread(),
        Screen.blockedUsers => const BlockedUsersScreen(),
        Screen.terms => const TermsGateScreen(),
        Screen.termsDocument => const LegalDocumentScreen(terms: true),
        Screen.privacyDocument => const LegalDocumentScreen(terms: false),
      };
}
