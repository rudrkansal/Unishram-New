import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/adapters.dart';
import '../backend/backend.dart';
import '../backend/models.dart';
import '../data/catalog.dart';
import '../data/strings.dart';
import '../services/firebase_strings_service.dart';
import '../services/indic_script.dart';
import '../services/location_service.dart';
import '../services/pincode_lookup.dart';
import '../services/places_service.dart';
import '../services/sarvam.dart';

enum Role { labourer, contractor, client, vendor }

/// The four-step "widen search" ladder shared by every people/job search
/// screen (contractor finding workers, client finding contractors,
/// labourer finding jobs). Each step is strictly broader than the last.
enum SearchTier {
  city,
  nearby,
  state,
  allIndia;

  SearchTier get next => switch (this) {
        SearchTier.city => SearchTier.nearby,
        SearchTier.nearby => SearchTier.state,
        SearchTier.state => SearchTier.allIndia,
        SearchTier.allIndia => SearchTier.allIndia,
      };

  bool get isWidest => this == SearchTier.allIndia;
}

/// A pending, unrated engagement surfaced by [AppState.findPendingRatingCandidate].
class RatingCandidate {
  const RatingCandidate({
    required this.aboutUserId,
    required this.jobId,
    required this.aboutName,
  });
  final String aboutUserId;
  final String jobId;
  final String aboutName;
}

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String roleKey(Role r) => r.name;
Role? roleFromKey(String? k) {
  for (final r in Role.values) {
    if (r.name == k) return r;
  }
  return null;
}

/// Every screen in the app. The entry tier has no bottom nav; the home tier does.
enum Screen {
  splash,
  langSelect,
  roleSelect,
  vendorComingSoon,
  profilePersonal,
  profileWork,
  profileContact,
  labourerHome,
  labourerJobDetail,
  labourerApplications,
  labourerProfile,
  labourerRatings,
  contractorHome,
  contractorApplicants,
  contractorPost,
  contractorFind,
  contractorWorkerDetail,
  contractorCalc,
  contractorProfile,
  clientSearch,
  clientContractorDetail,
  clientVendor,
  clientCalc,
  clientProfile,
  vendorListings,
  vendorProfile,
  chatThread,
  blockedUsers,
}

const Set<Screen> kHomeTierScreens = {
  Screen.labourerHome,
  Screen.labourerJobDetail,
  Screen.labourerApplications,
  Screen.labourerProfile,
  Screen.labourerRatings,
  Screen.contractorHome,
  Screen.contractorApplicants,
  Screen.contractorPost,
  Screen.contractorFind,
  Screen.contractorWorkerDetail,
  Screen.contractorCalc,
  Screen.contractorProfile,
  Screen.clientSearch,
  Screen.clientContractorDetail,
  Screen.clientVendor,
  Screen.clientCalc,
  Screen.clientProfile,
  Screen.vendorListings,
  Screen.vendorProfile,
  Screen.chatThread,
};

/// The one profile model, filled across the three onboarding steps and kept
/// intact when the user navigates back. Skills are stored as stable ids.
class Profile {
  String fullName = '';
  String gender = '';
  List<String> languagesSpoken = [];
  String city = '';
  String district = '';
  String state = '';
  String pincode = '';
  String currentLocation = '';
  double? lat;
  double? lng;
  String dateOfBirth = '';
  int? age;
  String? primarySkillId;
  List<String> additionalSkillIds = [];
  int? experienceYears;
  bool experienceIs10Plus = false;
  int? experienceMonths;
  bool? isFirstJob;
  String preferredWorkArea = '';
  String mobileNumber = '';
  bool phoneVerified = false;
  String profilePicture = '';
  List<String> workPhotos = [];
  String businessName = '';
  String contractorType = '';
  List<String> workTypeIds = [];
  List<String> workersRequiredIds = [];
  String clientType = '';
  String workLocationChoice = '';
  String projectPincode = '';
  String projectAddress = '';
  double? projectLat;
  double? projectLng;
  String expectedWage = '';
  String availability = 'available';

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'gender': gender,
        'languagesSpoken': languagesSpoken,
        'city': city,
        'district': district,
        'state': state,
        'pincode': pincode,
        'currentLocation': currentLocation,
        'lat': lat,
        'lng': lng,
        'dateOfBirth': dateOfBirth,
        'age': age,
        'primarySkillId': primarySkillId,
        'additionalSkillIds': additionalSkillIds,
        'experienceYears': experienceYears,
        'experienceIs10Plus': experienceIs10Plus,
        'experienceMonths': experienceMonths,
        'isFirstJob': isFirstJob,
        'preferredWorkArea': preferredWorkArea,
        'mobileNumber': mobileNumber,
        'phoneVerified': phoneVerified,
        // Photo paths are device-local and can be revoked; they are re-picked
        // rather than restored.
        'businessName': businessName,
        'contractorType': contractorType,
        'workTypeIds': workTypeIds,
        'workersRequiredIds': workersRequiredIds,
        'clientType': clientType,
        'workLocationChoice': workLocationChoice,
        'projectPincode': projectPincode,
        'projectAddress': projectAddress,
        'projectLat': projectLat,
        'projectLng': projectLng,
        'expectedWage': expectedWage,
        'availability': availability,
      };

  static Profile fromJson(Map<String, dynamic> j) {
    final p = Profile();
    p.fullName = j['fullName'] ?? '';
    p.gender = j['gender'] ?? '';
    p.languagesSpoken = List<String>.from(j['languagesSpoken'] ?? const []);
    p.city = j['city'] ?? '';
    p.district = j['district'] ?? '';
    p.state = j['state'] ?? '';
    p.pincode = j['pincode'] ?? '';
    p.currentLocation = j['currentLocation'] ?? '';
    p.lat = (j['lat'] as num?)?.toDouble();
    p.lng = (j['lng'] as num?)?.toDouble();
    p.dateOfBirth = j['dateOfBirth'] ?? '';
    p.age = j['age'];
    p.primarySkillId = j['primarySkillId'];
    p.additionalSkillIds =
        List<String>.from(j['additionalSkillIds'] ?? const []);
    p.experienceYears = j['experienceYears'];
    p.experienceIs10Plus = j['experienceIs10Plus'] ?? false;
    p.experienceMonths = j['experienceMonths'];
    p.isFirstJob = j['isFirstJob'];
    p.preferredWorkArea = j['preferredWorkArea'] ?? '';
    p.mobileNumber = j['mobileNumber'] ?? '';
    p.phoneVerified = j['phoneVerified'] ?? false;
    p.businessName = j['businessName'] ?? '';
    p.contractorType = j['contractorType'] ?? '';
    p.workTypeIds = List<String>.from(j['workTypeIds'] ?? const []);
    p.workersRequiredIds =
        List<String>.from(j['workersRequiredIds'] ?? const []);
    p.clientType = j['clientType'] ?? '';
    p.workLocationChoice = j['workLocationChoice'] ?? '';
    p.projectPincode = j['projectPincode'] ?? '';
    p.projectAddress = j['projectAddress'] ?? '';
    p.projectLat = (j['projectLat'] as num?)?.toDouble();
    p.projectLng = (j['projectLng'] as num?)?.toDouble();
    p.expectedWage = j['expectedWage'] ?? '';
    p.availability = j['availability'] ?? 'available';
    return p;
  }
}

class PostedJob {
  final String id;
  final String title;
  final String skill;
  final String location;
  final int wage;
  final String workersNeeded;
  final String description;
  final String contractor;
  final String startDate;
  final String endDate;
  final String hoursPerDay;
  const PostedJob({
    required this.id,
    required this.title,
    required this.skill,
    required this.location,
    required this.wage,
    required this.workersNeeded,
    required this.description,
    required this.contractor,
    this.startDate = '',
    this.endDate = '',
    this.hoursPerDay = '',
  });

  Job toJob() => Job(
        id: id,
        title: title,
        skill: skill,
        area: location.isEmpty ? 'Your area' : location,
        location: location.isEmpty ? 'Your area' : location,
        distance: '0.0 km',
        wage: wage,
        contractor: contractor,
        contractorPhone: '',
        postedAgo: 'Just now',
        duration: formatJobDuration(startDate, endDate, hoursPerDay),
        desc: description,
        startDateLabel: formatJobDateLabel(startDate),
        endDateLabel: formatJobDateLabel(endDate),
        durationSpan: formatJobDurationSpan(startDate, endDate, hoursPerDay),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'skill': skill,
        'location': location,
        'wage': wage,
        'workersNeeded': workersNeeded,
        'description': description,
        'contractor': contractor,
        'startDate': startDate,
        'endDate': endDate,
        'hoursPerDay': hoursPerDay,
      };

  static PostedJob fromJson(Map<String, dynamic> j) => PostedJob(
        id: j['id'],
        title: j['title'] ?? '',
        skill: j['skill'] ?? 'Mason',
        location: j['location'] ?? '',
        wage: j['wage'] ?? 0,
        workersNeeded: j['workersNeeded'] ?? '',
        description: j['description'] ?? '',
        contractor: j['contractor'] ?? 'You',
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'] ?? '',
        hoursPerDay: j['hoursPerDay'] ?? '',
      );
}

class ChatMessage {
  final bool mine;
  final String text;
  final String time;
  const ChatMessage(this.mine, this.text, this.time);
  Map<String, dynamic> toJson() => {'mine': mine, 'text': text, 'time': time};
  static ChatMessage fromJson(Map<String, dynamic> j) =>
      ChatMessage(j['mine'] ?? false, j['text'] ?? '', j['time'] ?? '');
}

class Listing {
  final String id;
  final String item;
  final int price;
  final String unit;
  const Listing(this.id, this.item, this.price, this.unit);
  Map<String, dynamic> toJson() =>
      {'id': id, 'item': item, 'price': price, 'unit': unit};
  static Listing fromJson(Map<String, dynamic> j) =>
      Listing(j['id'], j['item'], j['price'], j['unit']);
}

class CalcRow {
  String skillId;
  int count;
  int wage;
  int days;
  CalcRow(this.skillId, this.count, this.wage, this.days);
  int get cost => count * wage * days;
  Map<String, dynamic> toJson() =>
      {'skillId': skillId, 'count': count, 'wage': wage, 'days': days};
  static CalcRow fromJson(Map<String, dynamic> j) =>
      CalcRow(j['skillId'], j['count'], j['wage'], j['days']);
}

class ContactTarget {
  final String name;
  final String subtitle;
  final String phone;
  final String? chatJobId;
  final String? chatPeerId;
  const ContactTarget({
    required this.name,
    required this.subtitle,
    required this.phone,
    this.chatJobId,
    this.chatPeerId,
  });
}

/// The jobs a contractor is shown as already having posted.
const List<Job> kSeedContractorJobs = [
  Job(
      id: 'sj1',
      title: 'Site Mason needed',
      skill: 'Mason',
      area: 'Rohini, Delhi',
      location: 'Rohini, Delhi',
      distance: '0.0 km',
      wage: 750,
      contractor: 'You',
      contractorPhone: '',
      postedAgo: '2h ago',
      duration: '18 Aug – 20 Sep 2026',
      desc: ''),
  Job(
      id: 'sj2',
      title: 'Helper for loading work',
      skill: 'Helper',
      area: 'Saket, Delhi',
      location: 'Saket, Delhi',
      distance: '0.0 km',
      wage: 480,
      contractor: 'You',
      contractorPhone: '',
      postedAgo: '8h ago',
      duration: '17 Aug – 24 Aug 2026',
      desc: ''),
];

const Map<String, int> kSeedApplicantCount = {'sj1': 5, 'sj2': 2};

/// Everything the app knows, in one notifier. Progress survives a closed app.
class AppState extends ChangeNotifier {
  AppState({this.backend});

  static const _sessionKey = 'unishram.session.v2';

  /// Null until Firebase is configured (see SETUP.md). Every server call goes
  /// through here, so the app degrades to local-only rather than crashing.
  final Backend? backend;

  SharedPreferences? _prefs;
  final PincodeLookup _pincodeLookup = const LocalPincodeLookup();
  final IndiaPostPincodeLookup _indiaPost = const IndiaPostPincodeLookup();

  bool get online => backend != null;
  bool get signedIn => backend?.isSignedIn ?? false;
  String? get uid => backend?.uid;

  /// Set when a server call fails, so the screen can say so plainly.
  String authError = '';
  bool otpSending = false;

  // Navigation
  Screen screen = Screen.langSelect;
  Role? role;

  // Language
  String langCode = 'en';
  String get copyLang => copyLangFor(langCode);
  Str get t {
    final firebaseStrings = FirebaseStringsService.getStringsForLanguage(langCode);
    // If Firebase returns empty, fall back to hardcoded stringsFor()
    if (firebaseStrings.isEmpty) {
      return stringsFor(langCode);
    }
    return Str(firebaseStrings);
  }

  /// The language the app's own text is actually written in. Copy is complete
  /// only in English, Hindi and Punjabi, so a user who picked Tamil is reading
  /// English — and must therefore be read to in English.
  String get spokenLanguage => copyLang;

  String get voiceLocale => kBcp47[spokenLanguage] ?? 'en-IN';

  /// The language of one specific line, which is not always the copy language:
  /// the splash screen and role cards are translated into every language even
  /// though the rest of the app is not.
  String voiceLanguageFor(String text) =>
      scriptLanguage(text) ?? spokenLanguage;

  String voiceLocaleFor(String text) =>
      kBcp47[voiceLanguageFor(text)] ?? voiceLocale;

  /// Whether the Listen button and the microphone should appear.
  ///
  /// Sarvam is the only voice this app offers, and it speaks eleven languages
  /// properly. For everything else, offering a control that reads the wrong
  /// language back is worse than no control at all — so voice is gated on the
  /// language the user actually picked, not on a fallback.
  ///
  /// This is a plain getter, not a stored, asynchronously-refreshed flag: it
  /// has to be correct in the very same frame the language changes in, or the
  /// buttons flash the previous language's availability for a moment before
  /// catching up.
  bool get voiceAvailable => SarvamClient.supports(langCode);

  bool get rtl => isRtl(langCode);

  // Onboarding / profile
  Profile lp = Profile();
  bool locationManual = false;
  bool pinNotFound = false;
  bool pinStateMismatch = false;
  bool gpsLocating = false;
  String gpsError = '';
  LocationFailure? gpsFailure;
  bool showExactDob = false;
  String dobError = '';
  bool otpSent = false;
  String otpCode = '';
  /// The number the current OTP session actually belongs to. Used to catch
  /// the case where a user sends an OTP, realises the number was wrong,
  /// edits it, and taps what is now labelled "Resend" — that must start a
  /// fresh verification, not reuse the old number's resend token (which
  /// Firebase silently rejects, leaving the button stuck forever).
  String? _otpSentForNumber;

  /// When the last OTP actually went out — drives the resend cooldown, so a
  /// user can't hammer "Resend" and trip Firebase's abuse rate-limit
  /// ("too-many-requests") within seconds of the first send.
  DateTime? otpSentAt;
  static const Duration otpResendCooldown = Duration(seconds: 30);

  /// Seconds left before "Resend OTP" is tappable again; 0 once it's clear.
  int get otpResendSecondsLeft {
    final sentAt = otpSentAt;
    if (sentAt == null) return 0;
    final elapsed = DateTime.now().difference(sentAt);
    final left = otpResendCooldown - elapsed;
    return left.isNegative ? 0 : left.inSeconds + 1;
  }

  // Marketplace
  String jobSkillFilter = '';
  String workerSkillFilter = '';
  String searchMode = 'contractors';
  List<String> appliedJobIds = [];
  List<PostedJob> postedJobs = [];
  String jobApplyWage = '';
  Map<String, String> applicantStatuses = {};
  Map<String, List<ChatMessage>> chatMessages = {};
  String? chatJobId;
  String? chatPeerId;
  String? chatPeerName;
  Screen chatBackScreen = Screen.contractorHome;
  String? selectedJobId;
  Job? _selectedFeedJob;
  String? selectedWorkerId;
  String? selectedContractorId;
  Screen workerDetailBack = Screen.contractorFind;

  // Forms
  String postTitle = '';
  String postSkill = 'Mason';
  String postWage = '';
  String postLocation = ''; // site address (distinct from the user's own lp.* location)
  String postCityDistrict = '';
  String postPincode = '';
  String get postPincodeError =>
      postPincode.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(postPincode)
          ? t['pincodeInvalid']
          : '';
  String postWorkers = '';
  String postDescription = '';
  String postStartDate = '';
  String postEndDate = '';
  String postHoursPerDay = '';

  List<CalcRow> calcRows = [
    CalcRow('mason', 5, 750, 30),
    CalcRow('excavator', 1, 650, 10),
    CalcRow('helper', 5, 450, 30),
  ];
  int calcMaterial = 50000;
  int calcEquipment = 10000;
  int calcTransport = 5000;
  int calcContingencyPct = 10;

  List<String> extraSkills = ['Mason', 'Helper'];
  String wageExpectation = '750';
  bool workAreaEditOpen = false;

  bool vendorSortAsc = true;
  List<Listing> ownListings = const [
    Listing('ol1', 'Cement (OPC 53)', 370, 'bag'),
    Listing('ol2', 'Sand (River)', 1400, 'ton'),
  ];
  String shopName = '';
  String shopLocation = '';

  // Transient UI
  String toast = '';
  ContactTarget? contactCard;
  bool speaking = false;
  bool voiceListening = false;
  bool voiceTranscribing = false;
  String voiceHeard = '';

  // ---------------------------------------------------------------- session

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_sessionKey);
    if (raw == null) return;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      langCode = d['langCode'] ?? 'en';
      role = roleFromKey(d['role']);
      lp = Profile.fromJson(Map<String, dynamic>.from(d['lp'] ?? {}));
      locationManual = d['locationManual'] ?? false;
      showExactDob = d['showExactDob'] ?? false;
      otpSent = d['otpSent'] ?? false;
      appliedJobIds = List<String>.from(d['appliedJobIds'] ?? const []);
      postedJobs = (d['postedJobs'] as List? ?? [])
          .map((e) => PostedJob.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      applicantStatuses =
          Map<String, String>.from(d['applicantStatuses'] ?? {});
      chatMessages = (d['chatMessages'] as Map? ?? {}).map((k, v) => MapEntry(
          k as String,
          (v as List)
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList()));
      extraSkills = List<String>.from(d['extraSkills'] ?? extraSkills);
      wageExpectation = d['wageExpectation'] ?? wageExpectation;
      ownListings = (d['ownListings'] as List? ?? [])
              .map((e) => Listing.fromJson(Map<String, dynamic>.from(e)))
              .toList()
              .cast<Listing>()
              .isEmpty
          ? ownListings
          : (d['ownListings'] as List)
              .map((e) => Listing.fromJson(Map<String, dynamic>.from(e)))
              .toList();
      shopName = d['shopName'] ?? '';
      shopLocation = d['shopLocation'] ?? '';
      calcRows = (d['calcRows'] as List? ?? [])
          .map((e) => CalcRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (calcRows.isEmpty) calcRows = [CalcRow('mason', 5, 750, 30)];
      calcMaterial = d['calcMaterial'] ?? calcMaterial;
      calcEquipment = d['calcEquipment'] ?? calcEquipment;
      calcTransport = d['calcTransport'] ?? calcTransport;
      calcContingencyPct = d['calcContingencyPct'] ?? calcContingencyPct;
      blockedUserIds = List<String>.from(d['blockedUserIds'] ?? const []);
      blockedUserNames =
          Map<String, String>.from(d['blockedUserNames'] ?? const {});

      // A chat thread or applicant list is never the screen you come back to,
      // and splash is only ever reached by backing out of language select —
      // relaunching the app should land on language select, not the logo.
      final saved = Screen.values.asNameMap()[d['screen'] as String? ?? ''];
      if (saved != null &&
          saved != Screen.chatThread &&
          saved != Screen.contractorApplicants &&
          saved != Screen.blockedUsers &&
          saved != Screen.splash) {
        screen = saved;
      }

      // For first-time users (not signed in), always show language selection
      // For returning users (signed in), skip language select and go to home screen
      if (signedIn && role != null) {
        // Only skip language selection for users who are already logged in
        screen = switch (role) {
          Role.labourer => Screen.labourerProfile,
          Role.contractor => Screen.contractorHome,
          Role.client => Screen.clientSearch,
          Role.vendor => Screen.vendorListings,
          null => Screen.langSelect,
        };
      } else if (!signedIn) {
        // First-time users always go to language selection
        screen = Screen.langSelect;
      }
    } catch (_) {
      // A corrupt session should never trap the user — start clean instead.
      await _prefs!.remove(_sessionKey);
    }
    notifyListeners();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString(
      _sessionKey,
      jsonEncode({
        'screen': screen.name,
        'langCode': langCode,
        'role': role == null ? null : roleKey(role!),
        'lp': lp.toJson(),
        'locationManual': locationManual,
        'showExactDob': showExactDob,
        'otpSent': otpSent,
        'appliedJobIds': appliedJobIds,
        'postedJobs': postedJobs.map((e) => e.toJson()).toList(),
        'applicantStatuses': applicantStatuses,
        'chatMessages': chatMessages
            .map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'extraSkills': extraSkills,
        'wageExpectation': wageExpectation,
        'ownListings': ownListings.map((e) => e.toJson()).toList(),
        'shopName': shopName,
        'shopLocation': shopLocation,
        'calcRows': calcRows.map((e) => e.toJson()).toList(),
        'calcMaterial': calcMaterial,
        'calcEquipment': calcEquipment,
        'calcTransport': calcTransport,
        'calcContingencyPct': calcContingencyPct,
        'blockedUserIds': blockedUserIds,
        'blockedUserNames': blockedUserNames,
      }),
    );
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  Future<void> resetDemo() async {
    await _prefs?.remove(_sessionKey);
    screen = Screen.langSelect;
    role = null;
    langCode = 'en';
    lp = Profile();
    locationManual = false;
    pinNotFound = false;
    gpsError = '';
    showExactDob = false;
    dobError = '';
    otpSent = false;
    otpCode = '';
    jobSkillFilter = '';
    workerSkillFilter = '';
    searchMode = 'contractors';
    appliedJobIds = [];
    postedJobs = [];
    applicantStatuses = {};
    chatMessages = {};
    extraSkills = ['Mason', 'Helper'];
    wageExpectation = '750';
    calcRows = [
      CalcRow('mason', 5, 750, 30),
      CalcRow('excavator', 1, 650, 10),
      CalcRow('helper', 5, 450, 30),
    ];
    calcMaterial = 50000;
    calcEquipment = 10000;
    calcTransport = 5000;
    calcContingencyPct = 10;
    ownListings = const [
      Listing('ol1', 'Cement (OPC 53)', 370, 'bag'),
      Listing('ol2', 'Sand (River)', 1400, 'ton'),
    ];
    shopName = '';
    shopLocation = '';
    _changed();
  }

  // ------------------------------------------------------------ navigation

  Screen defaultScreenFor(Role r) => switch (r) {
        Role.labourer => Screen.labourerHome,
        Role.contractor => Screen.contractorHome,
        Role.client => Screen.clientSearch,
        Role.vendor => Screen.vendorListings,
      };

  void go(Screen s) {
    screen = s;
    _changed();
  }

  void setLanguage(String code) {
    langCode = code;
    _changed();
  }

  void selectRole(Role r) {
    role = r;
    if (r == Role.vendor) {
      screen = Screen.vendorComingSoon;
    } else if (lp.phoneVerified) {
      screen = defaultScreenFor(r);
    } else {
      if (lp.languagesSpoken.isEmpty) lp.languagesSpoken = [langCode];
      screen = Screen.profilePersonal;
    }
    _changed();
  }

  void switchRole() {
    role = null;
    screen = Screen.roleSelect;
    _changed();
  }

  static const Map<Screen, Screen> _backMap = {
    Screen.langSelect: Screen.splash,
    Screen.roleSelect: Screen.splash,
    Screen.vendorComingSoon: Screen.roleSelect,
    Screen.profilePersonal: Screen.roleSelect,
    Screen.profileWork: Screen.profilePersonal,
    Screen.profileContact: Screen.profileWork,
    Screen.labourerJobDetail: Screen.labourerHome,
    Screen.clientContractorDetail: Screen.clientSearch,
    Screen.contractorApplicants: Screen.contractorHome,
  };

  void goBack() {
    if (screen == Screen.chatThread) return go(chatBackScreen);
    if (screen == Screen.contractorWorkerDetail) return go(workerDetailBack);
    if (screen == Screen.blockedUsers) {
      return go(accountBackScreen);
    }
    go(_backMap[screen] ?? Screen.roleSelect);
  }

  /// Where Blocked users returns to — whichever profile screen (labourer,
  /// client or vendor) the person opened it from.
  Screen accountBackScreen = Screen.labourerProfile;

  void openBlockedUsers() => update(() {
        accountBackScreen = screen;
        screen = Screen.blockedUsers;
      });

  bool get showBottomNav => kHomeTierScreens.contains(screen);

  // ------------------------------------------------------------- profile

  void update(void Function() mutate) {
    mutate();
    _changed();
  }

  int get stepIndex => switch (screen) {
        Screen.profilePersonal => 0,
        Screen.profileWork => 1,
        Screen.profileContact => 2,
        _ => 0,
      };

  void toggleLanguageSpoken(String code) => update(() {
        if (lp.languagesSpoken.contains(code)) {
          lp.languagesSpoken.remove(code);
        } else {
          lp.languagesSpoken.add(code);
        }
      });

  /// Labourers and contractors can't be under [kMinAgeYears] — the stepper
  /// itself must not let them dial down to an under-age value in the first
  /// place, rather than relying on the "Continue" button's check to catch
  /// it afterwards. A client isn't working the job themselves, so they keep
  /// the wider floor.
  void setAge(int n) => update(() {
        final floor = role == Role.client ? 13 : kMinAgeYears;
        lp.age = n.clamp(floor, 100);
        dobError = '';
      });

  void applyPin(String value) => update(() {
        final v = value.replaceAll(RegExp(r'\D'), '');
        lp.pincode = v.length > 6 ? v.substring(0, 6) : v;
        final hit =
            lp.pincode.length == 6 ? _pincodeLookup.lookup(lp.pincode) : null;
        if (hit != null) {
          lp.city = hit.city;
          lp.district = hit.district;
          lp.state = hit.state;
        }
        // Our detailed directory only covers a small sample of PINs — a real
        // one outside it is still a real PIN, so only flag "not found" when
        // even the postal-circle prefix is unrecognised.
        pinNotFound = lp.pincode.length == 6 &&
            hit == null &&
            !isKnownPincodePrefix(lp.pincode);
        pinStateMismatch = hit == null &&
            lp.pincode.length == 6 &&
            lp.state.isNotEmpty &&
            !pincodeMatchesState(lp.pincode, lp.state);
        // Bundled sample missed it — ask India Post's own free directory,
        // which covers every real PIN. Fire-and-forget: applies only if the
        // field still holds this exact PIN when the reply lands.
        if (hit == null && lp.pincode.length == 6) {
          unawaited(_refinePincodeOnline(lp.pincode));
        }
      });

  Future<void> _refinePincodeOnline(String pincode) async {
    final online = await _indiaPost.lookup(pincode);
    if (online == null || lp.pincode != pincode) return;
    update(() {
      lp.city = online.city;
      lp.district = online.district;
      lp.state = online.state;
      pinNotFound = false;
      pinStateMismatch = false;
    });
  }

  /// Re-checks the PIN against the newly chosen state, in case the person
  /// filled in the PIN first and only then picked a state.
  void pickHomeState(String state) => update(() {
        lp.state = state;
        pinStateMismatch = lp.pincode.length == 6 &&
            lp.state.isNotEmpty &&
            !pincodeMatchesState(lp.pincode, lp.state);
      });

  /// A client picked a suggestion from Places Autocomplete for their project
  /// address — fills the structured fields the rest of the app already reads
  /// (pincode, state) alongside the free-text formatted address and point.
  void applyProjectAddress(ResolvedAddress address) => update(() {
        lp.projectAddress = address.formattedAddress;
        lp.projectLat = address.lat;
        lp.projectLng = address.lng;
        if (address.pincode.isNotEmpty) lp.projectPincode = address.pincode;
      });

  void clearLocation() => update(() {
        lp.city = '';
        lp.district = '';
        lp.state = '';
        lp.pincode = '';
        lp.currentLocation = '';
        lp.lat = null;
        lp.lng = null;
        locationManual = false;
        pinNotFound = false;
        pinStateMismatch = false;
      });

  bool get hasResolvedLocation =>
      lp.currentLocation.isNotEmpty ||
      (lp.state.isNotEmpty &&
          lp.district.isNotEmpty &&
          !locationManual &&
          lp.pincode.isNotEmpty);

  /// True age from an exact date of birth — the birthday must already have
  /// passed this year. Null for an empty, unparseable or future date.
  static int? ageFromDob(String iso) {
    if (iso.isEmpty) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]),
        m = int.tryParse(parts[1]),
        d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final dob = DateTime(y, m, d);
    if (dob.month != m || dob.day != d) return null;
    final now = DateTime.now();
    if (dob.isAfter(now)) return null;
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age -= 1;
    }
    return age;
  }

  void setDob(String iso) => update(() {
        lp.dateOfBirth = iso;
        final age = ageFromDob(iso);
        if (age != null) lp.age = age;
        dobError = iso.isEmpty
            ? ''
            : age == null
                ? t['dobInvalid']
                : (role != Role.client && age < kMinAgeYears)
                    ? t['minAgeError']
                    : '';
      });

  bool get personalValid =>
      lp.fullName.trim().isNotEmpty &&
      lp.gender.isNotEmpty &&
      (lp.city.trim().isNotEmpty || lp.district.trim().isNotEmpty) &&
      lp.state.isNotEmpty &&
      (role == Role.client || lp.age != null || lp.dateOfBirth.isNotEmpty);

  String? get primaryCategory => lp.primarySkillId == null
      ? null
      : skillById(lp.primarySkillId)?.wageCategory;

  /// Minimum wage figures published today go stale by design — most states
  /// revise them a couple of times a year. `config/minWage` lets a moderator
  /// push a correction without a new app release; this cache is what every
  /// wage screen actually reads, falling back to the bundled table (whose
  /// numbers are only ever as current as the last app update) when the
  /// document hasn't loaded or there is no backend at all.
  Map<String, Map<String, int>>? _minWageOverride;
  DateTime? _minWageAsOf;

  DateTime? get minWageAsOf => _minWageAsOf;

  /// One line to sit under any minimum-wage figure: the freshness date, when
  /// known.
  String get minWageDisclaimerLine {
    final asOf = _minWageAsOf;
    if (asOf == null) return '';
    final date = '${asOf.day} ${_shortMonths[asOf.month - 1]} ${asOf.year}';
    return '${t['minWageAsOf']} $date';
  }

  Future<void> loadMinWageConfig() async {
    final api = backend;
    if (api == null) return;
    try {
      final cfg =
          await api.minWage.watch().first.timeout(const Duration(seconds: 6));
      if (cfg != null && cfg.table.isNotEmpty) {
        _minWageOverride = cfg.table;
        _minWageAsOf = cfg.asOf;
        notifyListeners();
      }
    } catch (_) {
      // No document yet, or unreachable — the bundled table still applies.
    }
  }

  int resolvedMinWageFor(String? state, String category) {
    final override = _minWageOverride?[state]?[category];
    if (override != null) return override;
    return minWageFor(state, category);
  }

  int? get wageMin => (lp.state.isNotEmpty && primaryCategory != null)
      ? resolvedMinWageFor(lp.state, primaryCategory!)
      : null;

  String get wageErrorText {
    final min = wageMin;
    if (lp.expectedWage.isEmpty || min == null) return '';
    final entered = int.tryParse(lp.expectedWage) ?? 0;
    if (entered < min) return '${t['wageTooLowError']} ₹$min/day';
    if (entered > min * 4) return t['wageTooHighError'];
    return '';
  }

  void clampExpectedWage() => update(() {
        final min = wageMin;
        if (min == null || lp.expectedWage.isEmpty) return;
        var n = int.tryParse(lp.expectedWage) ?? 0;
        if (n == 0) return;
        if (n < min) n = min;
        if (n > min * 4) n = min * 4;
        lp.expectedWage = '$n';
        wageExpectation = '$n';
      });

  bool get workValid {
    if (role == Role.contractor) {
      return lp.workTypeIds.isNotEmpty && lp.workersRequiredIds.isNotEmpty;
    }
    if (role == Role.client) {
      final pinOk = lp.workLocationChoice == 'current' ||
          (lp.workLocationChoice == 'different' &&
              lp.projectPincode.length == 6);
      return lp.clientType.isNotEmpty &&
          lp.workLocationChoice.isNotEmpty &&
          pinOk &&
          lp.phoneVerified;
    }
    return lp.primarySkillId != null &&
        lp.experienceYears != null &&
        lp.expectedWage.isNotEmpty &&
        wageErrorText.isEmpty;
  }

  bool get contactValid => lp.phoneVerified;

  /// Continue from step 1. A hand-typed date can never bypass the minimum age.
  void continueFromPersonal() {
    if (lp.dateOfBirth.isNotEmpty) {
      final age = ageFromDob(lp.dateOfBirth);
      if (age == null) return update(() => dobError = t['dobInvalid']);
      if (role != Role.client && age < kMinAgeYears) {
        return update(() => dobError = t['minAgeError']);
      }
    }
    if (role != Role.client && lp.age != null && lp.age! < kMinAgeYears) {
      return update(() => dobError = t['minAgeError']);
    }
    if (!personalValid) return;
    update(() {
      dobError = '';
      screen = Screen.profileWork;
    });
  }

  void continueFromWork() {
    if (!workValid) return;
    if (role == Role.client) return completeProfile();
    go(Screen.profileContact);
  }

  void completeProfile() {
    if (role != Role.client && !contactValid) return;
    if (role == Role.client && !lp.phoneVerified) return;
    update(() {
      screen = defaultScreenFor(role ?? Role.labourer);
      toast = t['profileCompleteToast'];
    });
    clearToastLater();
    unawaited(pushProfile());
  }

  // ------------------------------------------------------------------ OTP

  /// Sends a real SMS through Firebase Phone Auth. Without a backend the demo
  /// path is used instead, so the UI can still be exercised.
  Future<void> sendOtp({bool resend = false}) async {
    if (lp.mobileNumber.length != 10) return;
    // A "resend" only means something for the number the last OTP actually
    // went to. If the number has changed since then (the user spotted a
    // typo and fixed it), this must be a fresh send — reusing the old
    // resend token against a different number makes Firebase silently
    // drop the request, so none of the callbacks below ever fire and the
    // button looks stuck forever.
    final isResend = resend && _otpSentForNumber == lp.mobileNumber;
    // Belt-and-braces alongside the UI disabling the button during the
    // cooldown — never let a resend through early even if something else
    // triggers this call.
    if (isResend && otpResendSecondsLeft > 0) return;
    final api = backend;
    if (api == null) {
      update(() {
        otpSent = true;
        otpCode = '';
        otpSentAt = DateTime.now();
      });
      return;
    }
    update(() {
      otpSending = true;
      authError = '';
    });
    await api.auth.sendOtp(
      phone: lp.mobileNumber,
      resend: isResend,
      onCodeSent: () => update(() {
        otpSending = false;
        otpSent = true;
        otpCode = '';
        _otpSentForNumber = lp.mobileNumber;
        otpSentAt = DateTime.now();
      }),
      // Android can read the SMS itself, which signs the user in with no typing.
      onVerified: (_) async {
        update(() {
          otpSending = false;
          lp.phoneVerified = true;
        });
        await _afterSignIn();
      },
      onError: (errorKey) => update(() {
        otpSending = false;
        authError = t[errorKey];
      }),
    );
  }

  Future<void> verifyOtp() async {
    if (otpCode.length < 6) return;
    final api = backend;
    if (api == null) {
      update(() => lp.phoneVerified = true);
      return;
    }
    update(() {
      otpSending = true;
      authError = '';
    });
    try {
      await api.auth.verifyOtp(otpCode);
      update(() {
        otpSending = false;
        lp.phoneVerified = true;
      });
      await _afterSignIn();
    } catch (e) {
      update(() {
        otpSending = false;
        authError = t[e is String ? e : 'authErrorGeneric'];
      });
    }
  }

  /// Pulls an existing profile down after sign-in, so a returning user lands
  /// straight in the app instead of re-doing onboarding on a new phone.
  Future<void> _afterSignIn() async {
    final api = backend;
    if (api == null) return;
    await api.registerForPush();
    await syncFromServer();
    await pushProfile();
  }

  /// Overwrites local state with the server's copy when one exists.
  Future<void> syncFromServer() async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return;
    final doc = await api.users.fetch(id);
    if (doc == null) return;
    update(() {
      role = roleFromKey(doc.role) ?? role;
      lp.fullName = doc.fullName;
      lp.gender = doc.gender;
      lp.languagesSpoken = [...doc.languagesSpoken];
      lp.city = doc.city;
      lp.district = doc.district;
      lp.state = doc.state;
      lp.pincode = doc.pincode;
      lp.lat = doc.location?.latitude;
      lp.lng = doc.location?.longitude;
      lp.age = doc.age;
      lp.dateOfBirth = doc.dateOfBirth ?? '';
      lp.primarySkillId = doc.primarySkillId;
      lp.additionalSkillIds = [...doc.additionalSkillIds];
      lp.experienceYears = doc.experienceYears;
      lp.experienceMonths = doc.experienceMonths;
      lp.preferredWorkArea = doc.preferredWorkArea;
      lp.expectedWage = doc.expectedWage == 0 ? '' : '${doc.expectedWage}';
      lp.availability = doc.availability;
      lp.mobileNumber = doc.phone.isEmpty ? lp.mobileNumber : doc.phone;
      lp.phoneVerified = doc.phoneVerified || lp.phoneVerified;
      lp.profilePicture =
          doc.photoUrl.isEmpty ? lp.profilePicture : doc.photoUrl;
      lp.workPhotos =
          doc.workPhotoUrls.isEmpty ? lp.workPhotos : [...doc.workPhotoUrls];
      lp.businessName = doc.businessName;
      lp.contractorType = doc.contractorType;
      lp.workTypeIds = [...doc.workTypeIds];
      lp.workersRequiredIds = [...doc.workersRequiredIds];
      lp.clientType = doc.clientType;
      lp.projectAddress = doc.projectAddress;
      lp.projectLat = doc.projectLocation?.latitude;
      lp.projectLng = doc.projectLocation?.longitude;
      wageExpectation = lp.expectedWage;
    });
    await _syncBlockedUsers();
  }

  /// Pulls the server's record of who this user has blocked, so blocking
  /// persists across reinstalls and devices instead of living only in this
  /// device's local session.
  Future<void> _syncBlockedUsers() async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return;
    try {
      final blocked = await api.blocks.watch(id).first;
      update(() {
        blockedUserIds = blocked.keys.toList();
        blockedUserNames = blocked;
      });
    } catch (_) {
      // Keep whatever was in the local session; blocking still degrades to
      // client-side filtering rather than failing outright.
    }
  }

  /// Writes the local profile up. Called at each onboarding step so a dropped
  /// connection never loses what the worker already typed.
  /// Saves the profile, retrying once after a short delay on failure before
  /// showing an error. Firebase's ID token isn't always immediately ready
  /// for a Firestore write in the instant right after sign-in resolves —
  /// this is the very first write a brand-new account ever makes, right on
  /// the heels of verifyOtp, so it's exactly where that race condition
  /// bites hardest. A silent retry fixes the common case instead of
  /// scaring a new user with "could not save" on their first ever save.
  Future<void> pushProfile() async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null || role == null) return;
    try {
      await _savePushedProfile(api, id);
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 900));
      try {
        await _savePushedProfile(api, id);
      } catch (e) {
        authError = t['authErrorSaveProfile'];
        notifyListeners();
      }
    }
  }

  Future<void> _savePushedProfile(Backend api, String id) async {
    {
      await api.users.save(UserDoc(
        uid: id,
        role: roleKey(role!),
        fullName: lp.fullName,
        phone: lp.mobileNumber,
        gender: lp.gender,
        languagesSpoken: lp.languagesSpoken,
        city: lp.city,
        district: lp.district,
        state: lp.state,
        pincode: lp.pincode,
        location: (lp.lat != null && lp.lng != null)
            ? GeoPoint(lp.lat!, lp.lng!)
            : null,
        age: lp.age,
        dateOfBirth: lp.dateOfBirth.isEmpty ? null : lp.dateOfBirth,
        primarySkillId: lp.primarySkillId,
        additionalSkillIds: lp.additionalSkillIds,
        experienceYears: lp.experienceYears,
        experienceMonths: lp.experienceMonths,
        preferredWorkArea: lp.preferredWorkArea,
        expectedWage: int.tryParse(lp.expectedWage) ?? 0,
        availability: lp.availability,
        photoUrl: lp.profilePicture.startsWith('http') ? lp.profilePicture : '',
        workPhotoUrls:
            lp.workPhotos.where((p) => p.startsWith('http')).toList(),
        phoneVerified: lp.phoneVerified,
        businessName: lp.businessName,
        contractorType: lp.contractorType,
        workTypeIds: lp.workTypeIds,
        workersRequiredIds: lp.workersRequiredIds,
        clientType: lp.clientType,
        projectAddress: lp.projectAddress,
        projectLocation: (lp.projectLat != null && lp.projectLng != null)
            ? GeoPoint(lp.projectLat!, lp.projectLng!)
            : null,
      ));
    }
  }

  /// Uploads a picked photo and swaps the local path for its download URL.
  Future<void> setProfilePhoto(String localPath) async {
    update(() => lp.profilePicture = localPath);
    final api = backend;
    if (api == null || !api.isSignedIn) return;
    try {
      final url = await api.uploadProfilePhoto(File(localPath));
      update(() => lp.profilePicture = url);
      await pushProfile();
    } catch (_) {
      // The local file still shows; the next save retries the upload.
    }
  }

  Future<void> addWorkPhotos(List<String> localPaths) async {
    update(() =>
        lp.workPhotos = [...lp.workPhotos, ...localPaths].take(6).toList());
    final api = backend;
    if (api == null || !api.isSignedIn) return;
    for (final path in localPaths) {
      try {
        final url = await api.uploadWorkPhoto(File(path));
        update(() {
          final i = lp.workPhotos.indexOf(path);
          if (i >= 0) lp.workPhotos[i] = url;
        });
      } catch (_) {
        // Keep the local copy; it uploads on the next attempt.
      }
    }
    await pushProfile();
  }

  Future<void> signOut() async {
    final api = backend;
    if (api != null) {
      await api.unregisterPush();
      await api.auth.signOut();
    }
    await resetDemo();
  }

  /// Both stores require deletion to be available inside the app.
  Future<void> deleteAccount() async {
    final api = backend;
    if (api == null) return resetDemo();
    await api.deleteAccount();
    await resetDemo();
  }

  // ------------------------------------------------------------ job feed

  List<String> get mySkillIds => [lp.primarySkillId, ...lp.additionalSkillIds]
      .whereType<String>()
      .toList();

  List<Job> get allJobs => [...postedJobs.map((e) => e.toJob()), ...kJobs];

  List<Job> get filteredJobs {
    final ids = mySkillIds;
    return allJobs
        // Offline jobs carry no contractor id, only a display name — the
        // same stand-in blocking uses from the job detail screen.
        .where((j) => !isBlocked(j.contractor))
        .where((j) {
      if (jobSkillFilter.isNotEmpty) return j.skill == jobSkillFilter;
      if (ids.isNotEmpty) {
        return ids.any((id) => skillById(id)?.jobLabel == j.skill);
      }
      return true;
    }).toList();
  }

  Job? jobById(String? id) {
    if (id == null) return null;
    for (final j in [...allJobs, ...kSeedContractorJobs]) {
      if (j.id == id) return j;
    }
    return null;
  }

  Job get selectedJob =>
      _selectedFeedJob ??
      jobById(selectedJobId) ??
      (allJobs.isNotEmpty ? allJobs.first : kJobs.first);

  /// The legal minimum wage to compare a job's offered wage against.
  /// Prefers [Job.minWageAtPost] — captured once, using the job's own
  /// location, when it was posted — over recomputing against whoever
  /// happens to be viewing it right now. Using the *viewer's* state here
  /// was the bug: the same job would show as "below minimum" to a labourer
  /// from a high-minimum-wage state and "fine" to one from a low-wage
  /// state, regardless of where the job itself actually is. The viewer's
  /// state is now only a last-resort estimate, for demo/sample jobs that
  /// never had a real minWageAtPost captured.
  int jobMinWage(Job j) {
    if (j.minWageAtPost > 0) return j.minWageAtPost;
    if (lp.state.isNotEmpty) {
      return resolvedMinWageFor(lp.state, skillCategoryByDisplayName(j.skill));
    }
    return kJobMinWage[j.skill] ?? 500;
  }

  bool get selectedJobApplied => appliedJobIds.contains(selectedJob.id);

  /// The feed streams real jobs straight from Firestore; jobById only
  /// searches locally-posted + demo jobs, so it misses feed jobs from other
  /// users entirely. Caching the tapped object sidesteps that.
  void setSelectedJob(Job job) {
    selectedJobId = job.id;
    _selectedFeedJob = job;
  }

  void viewJob(String id, {Job? job}) => update(() {
        if (job != null) {
          setSelectedJob(job);
        } else {
          selectedJobId = id;
          _selectedFeedJob = null;
        }
        jobApplyWage = '';
        screen = Screen.labourerJobDetail;
      });

  void applyToSelectedJob() {
    final id = selectedJob.id;
    if (appliedJobIds.contains(id)) return;
    update(() {
      appliedJobIds = [...appliedJobIds, id];
      toast = t['applyConfirm'];
    });
    clearToastLater();
  }

  List<Job> get myPostedJobs =>
      postedJobs.map((e) => e.toJob()).toList();

  int applicantCountFor(String jobId) =>
      kApplicantsByJob[jobId]?.length ?? 0;

  List<Worker> applicantsFor(String? jobId) =>
      (kApplicantsByJob[jobId] ?? const [])
          .map((id) => kWorkers.firstWhere((w) => w.id == id))
          .where((w) => !isBlocked(w.id))
          .toList();

  String applicantStatus(String jobId, String workerId) =>
      applicantStatuses['$jobId:$workerId'] ?? 'pending';

  void setApplicantStatus(String jobId, String workerId, String status) =>
      update(() => applicantStatuses['$jobId:$workerId'] = status);

  /// A short pause between job posts, enforced here and (once a real backend
  /// exists) again by `firestore.rules` — the client-side copy just keeps the
  /// button itself honest so a double-tap can't slip through before the
  /// network round-trip even starts.
  static const kJobPostCooldown = Duration(seconds: 20);
  DateTime? _lastJobPostAt;

  bool get postJobOnCooldown =>
      _lastJobPostAt != null &&
      DateTime.now().difference(_lastJobPostAt!) < kJobPostCooldown;

  void postJob() {
    if (postTitle.trim().isEmpty ||
        postWage.isEmpty ||
        postWageBelowMin ||
        postPincodeError.isNotEmpty ||
        postHoursError.isNotEmpty ||
        postJobOnCooldown) {
      return;
    }
    _lastJobPostAt = DateTime.now();
    update(() {
      postedJobs = [
        PostedJob(
          id: 'p${DateTime.now().millisecondsSinceEpoch}',
          title: postTitle,
          skill: postSkill,
          location: postLocation,
          wage: int.tryParse(postWage) ?? 0,
          workersNeeded: postWorkers,
          description: postDescription,
          contractor: lp.fullName.isEmpty ? 'You' : lp.fullName,
          startDate: postStartDate,
          endDate: postEndDate,
          hoursPerDay: postHoursPerDay,
        ),
        ...postedJobs,
      ];
      postTitle = '';
      postSkill = 'Mason';
      postWage = '';
      postLocation = '';
      postCityDistrict = '';
      postPincode = '';
      postWorkers = '';
      postDescription = '';
      postStartDate = '';
      postEndDate = '';
      postHoursPerDay = '';
      screen = Screen.contractorHome;
      toast = t['jobPostedConfirm'];
    });
    clearToastLater();
  }

  /// The job site's own state, derived from its pincode where possible —
  /// not just assumed to match the contractor's own profile state. A
  /// contractor can post a job across a state line from where they live
  /// (this app now actively encourages exactly that for cross-border metro
  /// clusters like Chandigarh/Mohali/Zirakpur/Panchkula), so falling back
  /// to the contractor's home state would silently compute the wrong
  /// state's minimum wage for that job.
  String get _postJobState {
    if (postPincode.length == 6) {
      final hit = _pincodeLookup.lookup(postPincode);
      if (hit != null && hit.state.isNotEmpty) return hit.state;
    }
    return lp.state;
  }

  int get postMinWage =>
      resolvedMinWageFor(_postJobState, skillCategoryByDisplayName(postSkill));

  bool get postWageBelowMin {
    final n = int.tryParse(postWage) ?? 0;
    return n > 0 && n < postMinWage;
  }

  void clampPostWage() {
    final n = int.tryParse(postWage) ?? 0;
    if (n > 0 && n < postMinWage) update(() => postWage = '$postMinWage');
  }

  /// A working day tops out at [kMaxHoursPerDay] hours. The contractor must
  /// correct an over-limit value themselves — it is never silently clamped.
  String get postHoursError =>
      (int.tryParse(postHoursPerDay) ?? 0) > kMaxHoursPerDay
          ? t['hoursPerDayMax']
          : '';

  // -------------------------------------------------------------- workers

  List<Worker> get filteredWorkers => kWorkers
      .where((w) => workerSkillFilter.isEmpty || w.skill == workerSkillFilter)
      .where((w) => !isBlocked(w.id))
      .toList();

  // The feed streams real workers/contractors straight from Firestore;
  // kWorkers/kContractors are only the offline demo list, so falling back to
  // them for a real feed tap shows a random unrelated demo profile. Caching
  // the tapped object (like selectedJob does) sidesteps that.
  Worker? _selectedFeedWorker;
  Contractor? _selectedFeedContractor;

  Worker get selectedWorker =>
      _selectedFeedWorker ??
      kWorkers.firstWhere((w) => w.id == selectedWorkerId,
          orElse: () => kWorkers.first);

  Contractor get selectedContractor =>
      _selectedFeedContractor ??
      kContractors.firstWhere((c) => c.id == selectedContractorId,
          orElse: () => kContractors.first);

  void viewWorker(String id, Screen back, {Worker? worker}) => update(() {
        selectedWorkerId = id;
        _selectedFeedWorker = worker;
        workerDetailBack = back;
        screen = Screen.contractorWorkerDetail;
      });

  void viewContractor(String id, {Contractor? contractor}) => update(() {
        selectedContractorId = id;
        _selectedFeedContractor = contractor;
        screen = Screen.clientContractorDetail;
      });

  // ---------------------------------------------------------------- safety
  //
  // Blocking is always local-first — it has to work the instant someone taps
  // it, with or without a backend, so a simple settings-style list is enough.
  // Reports are the opposite: they only mean something once a moderator can
  // see them, so they require a live backend and fail quietly offline.

  List<String> blockedUserIds = [];
  Map<String, String> blockedUserNames = {};
  DateTime? _lastReportAt;

  bool isBlocked(String userId) => blockedUserIds.contains(userId);

  /// Blocks [userId], persisted to Firestore so it holds across devices and
  /// is what firestore.rules checks before letting them message this user —
  /// not just a local filter. Updates the local cache immediately so the UI
  /// reflects it without waiting on the round-trip.
  Future<void> blockUser(String userId, String name) async {
    if (blockedUserIds.contains(userId)) return;
    update(() {
      blockedUserIds = [...blockedUserIds, userId];
      blockedUserNames = {...blockedUserNames, userId: name};
      toast = t['blockedConfirm'];
    });
    clearToastLater();
    final api = backend;
    final id = api?.uid;
    if (api != null && id != null) {
      try {
        await api.blocks.block(id, userId, name);
      } catch (_) {
        // The local block still applies to this session even if the write
        // failed; syncFromServer will reconcile on the next launch.
      }
    }
  }

  Future<void> unblockUser(String userId) async {
    update(() {
      blockedUserIds = blockedUserIds.where((id) => id != userId).toList();
      toast = t['unblockedConfirm'];
    });
    clearToastLater();
    final api = backend;
    final id = api?.uid;
    if (api != null && id != null) {
      try {
        await api.blocks.unblock(id, userId);
      } catch (_) {}
    }
  }

  /// Files a report and always confirms to the user, even offline — the
  /// alternative (silently doing nothing) is worse for someone reporting
  /// abuse than a mild overstatement of what just happened.
  Future<void> submitReport({
    String? aboutUserId,
    String? jobId,
    required List<String> reasons,
    String note = '',
  }) async {
    final now = DateTime.now();
    if (_lastReportAt != null &&
        now.difference(_lastReportAt!) < const Duration(seconds: 10)) {
      showToast(t['reportTooSoon']);
      return;
    }
    _lastReportAt = now;
    final api = backend;
    final id = api?.uid;
    if (api != null && id != null) {
      try {
        await api.reports.file(ReportDoc(
          byUserId: id,
          aboutUserId: aboutUserId,
          jobId: jobId,
          reasons: reasons,
          note: note,
        ));
      } catch (_) {
        // Still tell the user it was received — see method doc.
      }
    }
    showToast(t['reportConfirm']);
  }

  // ----------------------------------------------------------------- chat

  String get chatKey => '$chatJobId:$chatPeerId';

  void openChat(String? jobId, String? peerId, Screen back,
          {String? peerName}) =>
      update(() {
        chatJobId = jobId;
        chatPeerId = peerId;
        chatPeerName = peerName;
        chatBackScreen = back;
        screen = Screen.chatThread;
      });

  List<ChatMessage> get chatThread {
    final stored = chatMessages[chatKey] ?? const [];
    if (chatPeerId != 'me' && stored.isEmpty) {
      return [ChatMessage(false, t['chatSeedGreeting'], '2h ago')];
    }
    return stored;
  }

  void sendChat(String text) {
    if (text.trim().isEmpty) return;
    update(() {
      final list = [...(chatMessages[chatKey] ?? const <ChatMessage>[])];
      if (chatPeerId != 'me' && list.isEmpty) {
        list.add(ChatMessage(false, t['chatSeedGreeting'], '2h ago'));
      }
      list.add(ChatMessage(true, text.trim(), 'Now'));
      chatMessages[chatKey] = list;
    });
  }

  String get chatWithName {
    if (chatPeerName != null && chatPeerName!.isNotEmpty) return chatPeerName!;
    if (chatPeerId == 'me') return jobById(chatJobId)?.contractor ?? '';
    for (final w in kWorkers) {
      if (w.id == chatPeerId) return w.name;
    }
    for (final c in kContractors) {
      if (c.id == chatPeerId) return c.name;
    }
    return '';
  }

  // -------------------------------------------------------------- vendors

  List<VendorItem> get sortedVendorItems {
    final list = [...kVendorItems];
    list.sort((a, b) => vendorSortAsc
        ? a.price.compareTo(b.price)
        : b.price.compareTo(a.price));
    return list;
  }

  void addListing(String name, String price, String unit) {
    if (name.trim().isEmpty || price.isEmpty) return;
    update(() => ownListings = [
          Listing('ol${DateTime.now().millisecondsSinceEpoch}', name.trim(),
              int.tryParse(price) ?? 0, unit.isEmpty ? 'unit' : unit),
          ...ownListings,
        ]);
  }

  // ----------------------------------------------------------- calculator

  int get labourCost => calcRows.fold(0, (total, r) => total + r.cost);
  int get subtotalCost =>
      labourCost + calcMaterial + calcEquipment + calcTransport;
  int get contingencyAmount =>
      (subtotalCost * calcContingencyPct / 100).round();
  int get totalCost => subtotalCost + contingencyAmount;
  int get projectDays => calcRows.fold(0, (m, r) => r.days > m ? r.days : m);
  int get costPerDay =>
      projectDays == 0 ? 0 : (totalCost / projectDays).round();

  // ------------------------------------------------------------------ feeds
  //
  // Every feed falls back to the bundled sample data when there is no backend,
  // so the app is never a blank screen — a worker with no signal still sees
  // something, and the UI can be worked on without Firebase configured.

  GeoPoint? get _myLocation =>
      (lp.lat != null && lp.lng != null) ? GeoPoint(lp.lat!, lp.lng!) : null;

  /// The distance used by the "Nearby" tier — wide enough to cover a whole
  /// metro area (including cross-state clusters like Chandigarh/Mohali/
  /// Zirakpur/Panchkula) without pulling in an entire state.
  static const double kNearbyRadiusKm = 50;

  /// A labourer defaults to casting a slightly wider net (jobs are scarcer
  /// than workers), so their ladder skips straight to Nearby; a contractor
  /// defaults to the tightest tier and widens deliberately.
  SearchTier contractorSearchTier = SearchTier.city;
  SearchTier labourerSearchTier = SearchTier.nearby;

  void widenContractorSearch() =>
      update(() => contractorSearchTier = contractorSearchTier.next);
  void resetContractorSearch() =>
      update(() => contractorSearchTier = SearchTier.city);

  void widenLabourerSearch() =>
      update(() => labourerSearchTier = labourerSearchTier.next);
  void resetLabourerSearch() =>
      update(() => labourerSearchTier = SearchTier.nearby);

  /// Resolves one tier into the actual query filters to apply. City and
  /// Nearby are mutually exclusive with State — only one of
  /// {cityIn, (centre+radius), state} is ever non-null at a time.
  ({List<String>? cityIn, String? state, GeoPoint? centre, double? radiusKm})
      _searchParamsFor(SearchTier tier) => switch (tier) {
            SearchTier.city => (
                cityIn: citiesInClusterOf(lp.city),
                state: null,
                centre: null,
                radiusKm: null,
              ),
            SearchTier.nearby => (
                cityIn: null,
                state: null,
                centre: _myLocation,
                radiusKm: kNearbyRadiusKm,
              ),
            SearchTier.state => (
                cityIn: null,
                state: lp.state.isEmpty ? null : lp.state,
                centre: null,
                radiusKm: null,
              ),
            SearchTier.allIndia => (
                cityIn: null,
                state: null,
                centre: null,
                radiusKm: null,
              ),
          };

  /// Jobs near the worker, filtered by their current search tier.
  Stream<List<Job>> jobFeed() {
    final api = backend;
    if (api == null) return Stream.value(filteredJobs);
    final p = _searchParamsFor(labourerSearchTier);
    return api.jobs
        .watchNearby(
      centre: p.centre,
      radiusKm: p.radiusKm,
      skill: jobSkillFilter.isEmpty ? null : jobSkillFilter,
      state: p.state,
    )
        .map((docs) {
      final jobs = docs
          .map((d) => d.toJob(viewerLocation: _myLocation))
          .where((j) => !isBlocked(j.contractorUid))
          .toList();
      if (jobSkillFilter.isNotEmpty) return jobs;
      final mine = mySkillIds
          .map((id) => skillById(id)?.jobLabel)
          .whereType<String>()
          .toSet();
      if (mine.isEmpty) return jobs;
      // Their own trades first, everything else after.
      final matching = jobs.where((j) => mine.contains(j.skill)).toList();
      return matching.isEmpty ? jobs : matching;
    });
  }

  Stream<List<Job>> myPostedJobsFeed() {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return Stream.value(myPostedJobs);
    return api.jobs
        .watchPostedBy(id)
        .map((docs) => docs.map((d) => d.toJob()).toList());
  }

  /// Applicant counts come from the job document, which only the server writes.
  Stream<Map<String, int>> applicantCounts() {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) {
      return Stream.value(
          {for (final j in myPostedJobs) j.id: applicantCountFor(j.id)});
    }
    return api.jobs
        .watchPostedBy(id)
        .map((docs) => {for (final d in docs) d.id: d.applicantCount});
  }

  Stream<List<ApplicationDoc>> applicationsForJob(String jobId) {
    final api = backend;
    if (api == null) {
      return Stream.value([
        for (final w in applicantsFor(jobId))
          ApplicationDoc(
            id: ApplicationDoc.idFor(jobId, w.id),
            jobId: jobId,
            workerId: w.id,
            contractorId: uid ?? 'me',
            workerName: w.name,
            workerSkill: w.skill,
            workerPhone: w.phone,
            expectedWage: w.wage,
            status: applicantStatus(jobId, w.id),
          )
      ]);
    }
    final myUid = api.uid;
    if (myUid == null) return const Stream.empty();
    return api.applications
        .watchForJob(jobId, myUid)
        .map((docs) => docs.where((d) => !isBlocked(d.workerId)).toList());
  }

  Stream<List<ApplicationDoc>> myApplications() {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) {
      return Stream.value([
        for (final jobId in appliedJobIds)
          if (jobById(jobId) != null)
            ApplicationDoc(
              id: ApplicationDoc.idFor(jobId, 'me'),
              jobId: jobId,
              workerId: 'me',
              contractorId: '',
              workerName: displayName,
            )
      ]);
    }
    return api.applications.watchForWorker(id);
  }

  /// Shortlisted or hired counts as approved — the point at which a
  /// contractor has actually agreed to consider or take on this worker for
  /// this job, as opposed to merely having received the application.
  static bool isApprovedStatus(String status) =>
      status == 'shortlisted' || status == 'hired';

  /// My own application for one specific job, if any — used to decide
  /// whether I may see the contractor's phone number for it yet. A worker can
  /// always message a contractor about a job; calling them is gated on this.
  Stream<ApplicationDoc?> myApplicationForJob(String jobId) {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) {
      // Offline/demo mode has no contractor on the other end to approve
      // anything, so an applied job just sits pending — contact stays
      // unavailable, which is the safe default rather than a false positive.
      return Stream.value(appliedJobIds.contains(jobId)
          ? ApplicationDoc(
              id: ApplicationDoc.idFor(jobId, 'me'),
              jobId: jobId,
              workerId: 'me',
              contractorId: '',
            )
          : null);
    }
    return api.applications.watchOne(jobId, id);
  }

  Stream<Job?> jobStream(String jobId) {
    final api = backend;
    if (api == null) return Stream.value(jobById(jobId));
    return api.jobs
        .watch(jobId)
        .map((d) => d?.toJob(viewerLocation: _myLocation));
  }

  Stream<List<Worker>> workerFeed() {
    final api = backend;
    if (api == null) return Stream.value(filteredWorkers);
    final p = _searchParamsFor(contractorSearchTier);
    return api.users
        .watchWorkers(
          skillId: _skillIdForFilter(workerSkillFilter),
          cityIn: p.cityIn,
          state: p.state,
          centre: p.centre,
          radiusKm: p.radiusKm,
        )
        .map((docs) => docs
            .map((d) => d.toWorker())
            .where((w) => !isBlocked(w.id))
            .toList());
  }

  Stream<List<Contractor>> contractorFeed() {
    final api = backend;
    if (api == null) {
      return Stream.value(kContractors.where((c) => !isBlocked(c.id)).toList());
    }
    final p = _searchParamsFor(contractorSearchTier);
    return api.users
        .watchContractors(
          cityIn: p.cityIn,
          state: p.state,
          centre: p.centre,
          radiusKm: p.radiusKm,
        )
        .map((docs) => docs
            .map((d) => d.toContractor())
            .where((c) => !isBlocked(c.id))
            .toList());
  }

  static String? _skillIdForFilter(String jobLabel) {
    if (jobLabel.isEmpty) return null;
    for (final s in kSkills) {
      if (s.jobLabel == jobLabel || s.displayName == jobLabel) return s.id;
    }
    return null;
  }

  Stream<List<VendorItem>> vendorPriceFeed() {
    final api = backend;
    if (api == null) return Stream.value(sortedVendorItems);
    return api.listings.watchAll(ascending: vendorSortAsc).map((docs) => docs
        .map((d) => d.toVendorItem(d.vendorId == uid ? shopName : 'Vendor'))
        .toList());
  }

  Stream<List<Listing>> myListingsFeed() {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return Stream.value(ownListings);
    return api.listings.watchForVendor(id).map((docs) =>
        docs.map((d) => Listing(d.id, d.item, d.price, d.unit)).toList());
  }

  /// Submits a 1–5 star rating (with optional comment) for [aboutUserId]
  /// arising from [jobId]. Returns null on success, or an error code
  /// (`'duplicate'`) the UI can show a message for. Enforced server-side too:
  /// the deterministic review id means a second submission hits Firestore's
  /// `allow update: if false` rule rather than creating a duplicate.
  Future<String?> submitReview({
    required String aboutUserId,
    required String jobId,
    required int rating,
    String comment = '',
  }) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return 'offline';
    // Keyed by job + rater + the person being rated, so a contractor rating
    // several workers hired on the same job gets one doc each, not one
    // shared doc that only the first rating can ever occupy.
    final reviewId = '${jobId}_${id}_$aboutUserId';
    try {
      await api.reviews.submit(
        reviewId,
        ReviewDoc(
          id: reviewId,
          aboutUserId: aboutUserId,
          byUserId: id,
          byName: displayName,
          rating: rating,
          comment: comment,
        ),
      );
      notifyListeners();
      return null;
    } catch (_) {
      return 'duplicate';
    }
  }

  /// Whether the signed-in user has already reviewed [aboutUserId] for
  /// [jobId] — used to swap the "Rate" button for a disabled "Rated" state.
  Future<bool> hasReviewed(String aboutUserId, String jobId) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('reviews')
        .doc('${jobId}_${id}_$aboutUserId')
        .get();
    return doc.exists;
  }

  /// A job counts as ripe for the forced rating prompt once its end date has
  /// arrived — not before, and not indefinitely after (14 days, so an old
  /// unrated job doesn't nag forever).
  static bool _ratingWindowOpen(DateTime? endDate) {
    if (endDate == null) return false;
    final today = DateTime.now();
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    if (todayDay.isBefore(endDay)) return false;
    return todayDay.difference(endDay).inDays <= 14;
  }

  /// Finds one completed engagement (project end date reached) the
  /// signed-in user hasn't rated the other party for yet, so the forced
  /// pop-up has someone to show. Contractors are matched against workers on
  /// their own posted jobs; workers are matched against the contractor on
  /// jobs they were approved for. Returns null when there's nothing left to
  /// rate, nothing has ended yet, or the review system needs a signed-in
  /// backend user (offline/demo mode never prompts).
  Future<RatingCandidate?> findPendingRatingCandidate() async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return null;

    if (role == Role.contractor) {
      for (final job in myPostedJobs.take(15)) {
        if (!_ratingWindowOpen(job.endDate)) continue;
        List<ApplicationDoc> apps;
        try {
          apps = await applicationsForJob(job.id).first
              .timeout(const Duration(seconds: 4));
        } catch (_) {
          continue;
        }
        for (final a in apps) {
          if (!isApprovedStatus(a.status)) continue;
          if (await hasReviewed(a.workerId, job.id)) continue;
          return RatingCandidate(
            aboutUserId: a.workerId,
            jobId: job.id,
            aboutName: a.workerName,
          );
        }
      }
      return null;
    }

    if (role == Role.labourer) {
      List<ApplicationDoc> apps;
      try {
        apps = await myApplications().first.timeout(const Duration(seconds: 4));
      } catch (_) {
        return null;
      }
      for (final a in apps) {
        if (!isApprovedStatus(a.status)) continue;
        if (a.contractorId.isEmpty) continue;
        final job = jobById(a.jobId);
        if (!_ratingWindowOpen(job?.endDate)) continue;
        if (await hasReviewed(a.contractorId, a.jobId)) continue;
        return RatingCandidate(
          aboutUserId: a.contractorId,
          jobId: a.jobId,
          aboutName: job?.contractor ?? '',
        );
      }
      return null;
    }

    return null;
  }

  /// Looks up a pending, post-project rating candidate for the forced
  /// pop-up. The caller is responsible for actually showing the dialog.
  Future<RatingCandidate?> maybeGetForcedRatingCandidate() =>
      findPendingRatingCandidate();

  /// Rates the app itself (not another user) — one doc per signed-in user,
  /// upserted on every submission, feeding into overall product feedback.
  /// Returns false when there's no signed-in backend user to attribute it to.
  Future<bool> submitAppRating({required int rating, String comment = ''}) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return false;
    await FirebaseFirestore.instance.collection('appRatings').doc(id).set({
      'rating': rating,
      'comment': comment,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _prefs?.setBool(_kAppRatePromptedKey, true);
    return true;
  }

  static const _kAppRatePromptedKey = 'appRatePromptShown';

  /// Whether the signed-in user has already rated the app — read once to
  /// decide whether the auto-prompt should ever fire again.
  Future<bool> hasRatedApp() async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('appRatings')
        .doc(id)
        .get();
    return doc.exists;
  }

  /// The auto "Rate this app" prompt is offered at most once ever, per
  /// Play Store's policy against pressuring/repeating rating prompts — it
  /// is always dismissible (never forced, unlike the post-job rating), and
  /// once shown — rated or dismissed — it never appears again on its own.
  /// The profile's "Rate this app" tile stays available any time regardless.
  Future<bool> shouldShowAppRatePrompt() async {
    if (_prefs?.getBool(_kAppRatePromptedKey) ?? false) return false;
    if (await hasRatedApp()) {
      await _prefs?.setBool(_kAppRatePromptedKey, true);
      return false;
    }
    return true;
  }

  /// Marks the auto-prompt as shown so it never fires again, whether the
  /// user rated or dismissed it.
  Future<void> markAppRatePromptShown() =>
      _prefs?.setBool(_kAppRatePromptedKey, true) ?? Future.value();

  /// How many of my own posted jobs this worker has been marked "employed"
  /// (hired) for — the employment-history data point surfaced on their
  /// profile. Scoped to jobs *I* posted, since Firestore rules only let a
  /// contractor read applications they're a party to, not a worker's whole
  /// history with other contractors.
  Future<int> hiredJobCountForWorker(String workerId) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return 0;
    var count = 0;
    for (final job in myPostedJobs) {
      try {
        final apps = await applicationsForJob(job.id)
            .first
            .timeout(const Duration(seconds: 3));
        if (apps.any((a) => a.workerId == workerId && a.status == 'hired')) {
          count++;
        }
      } catch (_) {
        // Skip a job whose applications can't be read right now.
      }
    }
    return count;
  }

  Stream<List<Review>> reviewFeed() {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return Stream.value(kReviews);
    return api.reviews
        .watchFor(id)
        .map((docs) => docs.map((d) => d.toReview()).toList());
  }

  /// Live unread-message count for the thread with [otherUid] over [jobId],
  /// read straight from Firestore so the badge survives app restarts and
  /// updates the moment the other person sends something — not just while
  /// this device happens to have that chat open.
  Stream<int> threadUnreadCount(String otherUid, {String? jobId}) {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return Stream.value(0);
    final threadId = ThreadDoc.idFor(id, otherUid, jobId: jobId);
    return FirebaseFirestore.instance
        .collection('threads')
        .doc(threadId)
        .snapshots()
        .map((doc) {
          final v = (doc.data()?['unread'] as Map?)?[id];
          return v is num ? v.toInt() : 0;
        });
  }

  /// Total unread messages across every applicant thread on one of my
  /// posted jobs — the badge shown on a "My Jobs" card, since a job can have
  /// several applicants each with their own thread.
  Stream<int> jobUnreadCount(String jobId) {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('threads')
        .where('jobId', isEqualTo: jobId)
        .where('participants', arrayContains: id)
        .snapshots()
        .map((snap) => snap.docs.fold<int>(0, (sum, doc) {
              final v = (doc.data()['unread'] as Map?)?[id];
              return sum + (v is num ? v.toInt() : 0);
            }));
  }

  /// Whether the application behind the current chat (if any) was rejected —
  /// chat history stays visible, but the input is disabled until the
  /// contractor reopens it. Mirrors the same check firestore.rules makes
  /// before allowing a new message to be created.
  Stream<bool> chatApplicationRejected() {
    final api = backend;
    final id = api?.uid;
    final jobId = chatJobId;
    final peerId = chatPeerId;
    if (api == null || id == null || jobId == null || peerId == null) {
      return Stream.value(false);
    }
    final workerId = role == Role.labourer ? id : peerId;
    return api.applications
        .watchOne(jobId, workerId)
        .map((a) => a?.status == 'rejected');
  }

  Stream<List<ChatMessage>> messageFeed() {
    final api = backend;
    if (api == null || _threadId == null) return Stream.value(chatThread);
    return api.chat.watchMessages(_threadId!).map((docs) => docs.map((m) {
          final sent = m.sentAt;
          return ChatMessage(
            m.senderId == uid,
            m.text,
            sent == null ? 'Now' : _ago(sent),
          );
        }).toList());
  }

  static String _ago(DateTime then) {
    final d = DateTime.now().difference(then);
    if (d.inMinutes < 1) return 'Now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  String? _threadId;
  String? get currentThreadId => _threadId;

  // ------------------------------------------------------------ server writes

  /// Applying writes through the repository, which makes it idempotent and
  /// bumps the applicant count in the same transaction.
  Future<void> applyToJobLive(Job job) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return applyToSelectedJob();
    if (appliedJobIds.contains(job.id)) return;
    try {
      await api.applications.apply(ApplicationDoc(
        id: ApplicationDoc.idFor(job.id, id),
        jobId: job.id,
        workerId: id,
        contractorId: job.contractorUid,
        workerName: displayName,
        workerSkill: skillNameOf(lp.primarySkillId),
        workerPhone: lp.mobileNumber,
        expectedWage: int.tryParse(
                jobApplyWage.isEmpty ? lp.expectedWage : jobApplyWage) ??
            0,
      ));
      update(() {
        appliedJobIds = [...appliedJobIds, job.id];
        toast = t['applyConfirm'];
      });
      clearToastLater();
      await api.logEvent('job_applied');
    } catch (_) {
      showToast(t['actionFailed']);
    }
  }

  Future<void> postJobLive() async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return postJob();
    if (postTitle.trim().isEmpty ||
        postWage.isEmpty ||
        postWageBelowMin ||
        postPincodeError.isNotEmpty ||
        postHoursError.isNotEmpty ||
        postJobOnCooldown) {
      return;
    }
    _lastJobPostAt = DateTime.now();
    try {
      await api.jobs.post(JobDoc(
        id: '',
        postedBy: id,
        contractorName:
            lp.businessName.isNotEmpty ? lp.businessName : displayName,
        contractorPhone: lp.mobileNumber,
        title: postTitle.trim(),
        skill: postSkill,
        description: postDescription.trim(),
        wage: int.tryParse(postWage) ?? 0,
        minWageAtPost: postMinWage,
        workersNeeded: int.tryParse(postWorkers) ?? 1,
        address: postLocation.trim(),
        area: postCityDistrict.trim(),
        pincode: postPincode.trim(),
        state: lp.state,
        location: _myLocation,
        startDate: DateTime.tryParse(postStartDate),
        endDate: DateTime.tryParse(postEndDate),
        hoursPerDay: int.tryParse(postHoursPerDay) ?? 0,
      ));
      update(() {
        postTitle = '';
        postSkill = 'Mason';
        postWage = '';
        postLocation = '';
        postCityDistrict = '';
        postPincode = '';
        postWorkers = '';
        postDescription = '';
        postStartDate = '';
        postEndDate = '';
        postHoursPerDay = '';
        screen = Screen.contractorHome;
        toast = t['jobPostedConfirm'];
      });
      clearToastLater();
      await api.logEvent('job_posted');
    } catch (_) {
      showToast(t['actionFailed']);
    }
  }

  Future<void> setApplicationStatus(
      String jobId, String workerId, String status) async {
    final api = backend;
    if (api == null) return setApplicantStatus(jobId, workerId, status);
    try {
      await api.applications
          .setStatus(ApplicationDoc.idFor(jobId, workerId), status);
    } catch (_) {
      showToast(t['actionFailed']);
    }
  }

  Future<void> addListingLive(String name, String price, String unit) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null) return addListing(name, price, unit);
    if (name.trim().isEmpty || price.isEmpty) return;
    try {
      await api.listings.add(ListingDoc(
        id: '',
        vendorId: id,
        item: name.trim(),
        price: int.tryParse(price) ?? 0,
        unit: unit.isEmpty ? 'unit' : unit,
        area: lp.city,
        state: lp.state,
      ));
    } catch (_) {
      showToast(t['actionFailed']);
    }
  }

  /// Opens (or reuses) the thread between this user and [peerId].
  Future<void> openChatLive({
    required String peerId,
    required String peerName,
    String? jobId,
    String jobTitle = '',
    required Screen back,
  }) async {
    final api = backend;
    final id = api?.uid;
    openChat(jobId, peerId, back, peerName: peerName);
    if (api == null || id == null) return;
    try {
      _threadId = await api.chat.openThread(
        me: id,
        myName: displayName,
        other: peerId,
        otherName: peerName,
        jobId: jobId,
        jobTitle: jobTitle,
      );
      await api.chat.markRead(_threadId!, id);
      notifyListeners();
    } catch (_) {
      _threadId = null;
    }
  }

  Future<void> sendChatLive(String text) async {
    final api = backend;
    final id = api?.uid;
    if (api == null || id == null || _threadId == null) return sendChat(text);
    if (text.trim().isEmpty) return;
    try {
      await api.chat.send(
        threadId: _threadId!,
        senderId: id,
        recipientId: chatPeerId ?? '',
        text: text,
      );
    } catch (_) {
      showToast(t['actionFailed']);
    }
  }

  // ------------------------------------------------------------- feedback

  void showToast(String message) {
    update(() => toast = message);
    clearToastLater();
  }

  void clearToastLater() {
    final shown = toast;
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (toast == shown) update(() => toast = '');
    });
  }

  void openContact(ContactTarget target) => update(() => contactCard = target);
  void closeContact() => update(() => contactCard = null);

  /// English TTS engines read "UniShram" as "uh-ni-shram" rather than
  /// "you-ni-shram" — this respelling nudges them onto the right first
  /// syllable. Only used for speech; the displayed app name is untouched.
  String get _spokenAppName =>
      langCode == 'en' ? 'Yoo-nishram' : t['appName'];

  String get splashLine => '$_spokenAppName. ${t['tagline']}.';

  String get displayName {
    if (lp.fullName.isNotEmpty) return lp.fullName;
    return switch (role) {
      Role.labourer => 'Suresh Kumar',
      Role.vendor => 'Vendor',
      _ => 'You',
    };
  }

  String get roleInitial => role == null ? '' : roleKey(role!)[0].toUpperCase();

  String skillNameOf(String? id) => skillById(id)?.name(copyLang) ?? '';
}
