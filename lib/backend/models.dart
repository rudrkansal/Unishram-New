import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

/// The `{geopoint, geohash}` shape `GeoCollectionReference.subscribeWithin`
/// range-queries on. Written alongside the plain [GeoPoint] every model also
/// keeps for simple distance display — the two serve different reads.
Map<String, dynamic>? _geoField(GeoPoint? location) =>
    location == null ? null : GeoFirePoint(location).data;

/// Firestore documents. Every model round-trips through [toMap]/[fromDoc] so a
/// schema change is visible in one place.

String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _i(dynamic v) => v is num ? v.toInt() : 0;
DateTime? _t(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _l(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

enum VerificationLevel { none, phone }

/// A person, in whichever role they registered as. One account can hold more
/// than one role over time, so the role lives on the account, not the document
/// type.
class UserDoc {
  final String uid;
  final String role;
  final String fullName;
  final String phone;
  final String gender;
  final List<String> languagesSpoken;
  final String city;
  final String district;
  final String state;
  final String pincode;
  final GeoPoint? location;
  final String geohash;
  final int? age;
  final String? dateOfBirth;
  final String? primarySkillId;
  final List<String> additionalSkillIds;
  final int? experienceYears;
  final int? experienceMonths;
  final String preferredWorkArea;
  final int expectedWage;
  final String availability;
  final String photoUrl;
  final List<String> workPhotoUrls;
  final bool phoneVerified;
  final String businessName;
  final String contractorType;
  final List<String> workTypeIds;
  final List<String> workersRequiredIds;
  final String clientType;
  final String projectAddress;
  final GeoPoint? projectLocation;
  final double ratingAverage;
  final int ratingCount;
  final bool suspended;
  final bool sessionRevoked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserDoc({
    required this.uid,
    required this.role,
    this.fullName = '',
    this.phone = '',
    this.gender = '',
    this.languagesSpoken = const [],
    this.city = '',
    this.district = '',
    this.state = '',
    this.pincode = '',
    this.location,
    this.geohash = '',
    this.age,
    this.dateOfBirth,
    this.primarySkillId,
    this.additionalSkillIds = const [],
    this.experienceYears,
    this.experienceMonths,
    this.preferredWorkArea = '',
    this.expectedWage = 0,
    this.availability = 'available',
    this.photoUrl = '',
    this.workPhotoUrls = const [],
    this.phoneVerified = false,
    this.businessName = '',
    this.contractorType = '',
    this.workTypeIds = const [],
    this.workersRequiredIds = const [],
    this.clientType = '',
    this.projectAddress = '',
    this.projectLocation,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.suspended = false,
    this.sessionRevoked = false,
    this.createdAt,
    this.updatedAt,
  });

  VerificationLevel get verification =>
      phoneVerified ? VerificationLevel.phone : VerificationLevel.none;

  /// Every skill this worker can be matched on.
  List<String> get skillIds =>
      [if (primarySkillId != null) primarySkillId!, ...additionalSkillIds];

  Map<String, dynamic> toMap() => {
        'role': role,
        'fullName': fullName,
        // 'phone' is deliberately NOT here: it is stored in users/{uid}/private/contact
        // (see UserRepository.save) so other users cannot read it from the public profile.
        'gender': gender,
        'languagesSpoken': languagesSpoken,
        'city': city,
        'district': district,
        'state': state,
        'pincode': pincode,
        if (location != null) 'location': location,
        if (_geoField(location) != null) 'geo': _geoField(location),
        'geohash': geohash,
        'age': age,
        'dateOfBirth': dateOfBirth,
        'primarySkillId': primarySkillId,
        'additionalSkillIds': additionalSkillIds,
        'skillIds': skillIds,
        'experienceYears': experienceYears,
        'experienceMonths': experienceMonths,
        'preferredWorkArea': preferredWorkArea,
        'expectedWage': expectedWage,
        'availability': availability,
        'photoUrl': photoUrl,
        'workPhotoUrls': workPhotoUrls,
        'phoneVerified': phoneVerified,
        'businessName': businessName,
        'contractorType': contractorType,
        'workTypeIds': workTypeIds,
        'workersRequiredIds': workersRequiredIds,
        'clientType': clientType,
        'projectAddress': projectAddress,
        if (projectLocation != null) 'projectLocation': projectLocation,
        if (_geoField(projectLocation) != null)
          'projectGeo': _geoField(projectLocation),
        'ratingAverage': ratingAverage,
        'ratingCount': ratingCount,
        'suspended': suspended,
        'sessionRevoked': sessionRevoked,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static UserDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return UserDoc(
      uid: doc.id,
      role: d['role'] ?? 'labourer',
      fullName: d['fullName'] ?? '',
      phone: d['phone'] ?? '',
      gender: d['gender'] ?? '',
      languagesSpoken: _l(d['languagesSpoken']),
      city: d['city'] ?? '',
      district: d['district'] ?? '',
      state: d['state'] ?? '',
      pincode: d['pincode'] ?? '',
      location: d['location'] is GeoPoint ? d['location'] as GeoPoint : null,
      geohash: d['geohash'] ?? '',
      age: d['age'] is num ? (d['age'] as num).toInt() : null,
      dateOfBirth: _s(d['dateOfBirth']),
      primarySkillId: _s(d['primarySkillId']),
      additionalSkillIds: _l(d['additionalSkillIds']),
      experienceYears: d['experienceYears'] is num
          ? (d['experienceYears'] as num).toInt()
          : null,
      experienceMonths: d['experienceMonths'] is num
          ? (d['experienceMonths'] as num).toInt()
          : null,
      preferredWorkArea: d['preferredWorkArea'] ?? '',
      expectedWage: _i(d['expectedWage']),
      availability: d['availability'] ?? 'available',
      photoUrl: d['photoUrl'] ?? '',
      workPhotoUrls: _l(d['workPhotoUrls']),
      phoneVerified: d['phoneVerified'] ?? false,
      businessName: d['businessName'] ?? '',
      contractorType: d['contractorType'] ?? '',
      workTypeIds: _l(d['workTypeIds']),
      workersRequiredIds: _l(d['workersRequiredIds']),
      clientType: d['clientType'] ?? '',
      projectAddress: d['projectAddress'] ?? '',
      projectLocation: d['projectLocation'] is GeoPoint
          ? d['projectLocation'] as GeoPoint
          : null,
      ratingAverage: (d['ratingAverage'] as num?)?.toDouble() ?? 0,
      ratingCount: _i(d['ratingCount']),
      suspended: d['suspended'] ?? false,
      sessionRevoked: d['sessionRevoked'] ?? false,
      createdAt: _t(d['createdAt']),
      updatedAt: _t(d['updatedAt']),
    );
  }

  /// A trust-weighted score for ranking, not just the raw average — a
  /// single 5-star review must not outrank someone with 50 reviews
  /// averaging 4.8. Pulls a low-review-count average toward a neutral
  /// prior (4.0, weighted as 5 phantom reviews) until real reviews
  /// accumulate enough to outweigh it; converges to the plain average as
  /// [ratingCount] grows. Standard Bayesian-average approach (the same
  /// idea behind IMDB's and Reddit's ranking scores).
  double get trustScore {
    const priorMean = 4.0;
    const priorWeight = 5;
    return (priorWeight * priorMean + ratingCount * ratingAverage) /
        (priorWeight + ratingCount);
  }
}

/// A job posted by a contractor or client.
class JobDoc {
  final String id;
  final String postedBy;
  final String contractorName;
  final String contractorPhone;
  final String title;
  final String skill;
  final String description;
  final int wage;
  final int minWageAtPost;
  final int workersNeeded;
  final String address;
  final String area;
  final String pincode;
  final String state;
  final GeoPoint? location;
  final String geohash;
  final DateTime? startDate;
  final DateTime? endDate;
  final int hoursPerDay;
  final String status; // open | filled | closed
  final int applicantCount;
  final DateTime? createdAt;

  const JobDoc({
    required this.id,
    required this.postedBy,
    required this.title,
    required this.skill,
    required this.wage,
    this.contractorName = '',
    this.contractorPhone = '',
    this.description = '',
    this.minWageAtPost = 0,
    this.workersNeeded = 1,
    this.address = '',
    this.area = '',
    this.pincode = '',
    this.state = '',
    this.location,
    this.geohash = '',
    this.startDate,
    this.endDate,
    this.hoursPerDay = 0,
    this.status = 'open',
    this.applicantCount = 0,
    this.createdAt,
  });

  bool get belowMinimumWage => minWageAtPost > 0 && wage < minWageAtPost;

  Map<String, dynamic> toMap() => {
        'postedBy': postedBy,
        'contractorName': contractorName,
        'contractorPhone': contractorPhone,
        'title': title,
        'skill': skill,
        'description': description,
        'wage': wage,
        'minWageAtPost': minWageAtPost,
        'workersNeeded': workersNeeded,
        'address': address,
        'area': area,
        'pincode': pincode,
        'state': state,
        if (location != null) 'location': location,
        if (_geoField(location) != null) 'geo': _geoField(location),
        'geohash': geohash,
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
        'hoursPerDay': hoursPerDay,
        'status': status,
        'applicantCount': applicantCount,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static JobDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return JobDoc(
      id: doc.id,
      postedBy: d['postedBy'] ?? '',
      contractorName: d['contractorName'] ?? '',
      contractorPhone: d['contractorPhone'] ?? '',
      title: d['title'] ?? '',
      skill: d['skill'] ?? '',
      description: d['description'] ?? '',
      wage: _i(d['wage']),
      minWageAtPost: _i(d['minWageAtPost']),
      workersNeeded: _i(d['workersNeeded']),
      address: d['address'] ?? '',
      area: d['area'] ?? '',
      pincode: d['pincode'] ?? '',
      state: d['state'] ?? '',
      location: d['location'] is GeoPoint ? d['location'] as GeoPoint : null,
      geohash: d['geohash'] ?? '',
      startDate: _t(d['startDate']),
      endDate: _t(d['endDate']),
      hoursPerDay: _i(d['hoursPerDay']),
      status: d['status'] ?? 'open',
      applicantCount: _i(d['applicantCount']),
      createdAt: _t(d['createdAt']),
    );
  }
}

/// A worker's application to a job. The id is deterministic (`jobId_workerId`)
/// so applying twice is a no-op rather than a duplicate.
class ApplicationDoc {
  final String id;
  final String jobId;
  final String workerId;
  final String contractorId;
  final String workerName;
  final String workerSkill;
  final String workerPhone;
  final int expectedWage;
  final String status; // pending | shortlisted | rejected | hired
  final DateTime? createdAt;

  const ApplicationDoc({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.contractorId,
    this.workerName = '',
    this.workerSkill = '',
    this.workerPhone = '',
    this.expectedWage = 0,
    this.status = 'pending',
    this.createdAt,
  });

  static String idFor(String jobId, String workerId) => '${jobId}_$workerId';

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'workerId': workerId,
        'contractorId': contractorId,
        'workerName': workerName,
        'workerSkill': workerSkill,
        'workerPhone': workerPhone,
        'expectedWage': expectedWage,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static ApplicationDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ApplicationDoc(
      id: doc.id,
      jobId: d['jobId'] ?? '',
      workerId: d['workerId'] ?? '',
      contractorId: d['contractorId'] ?? '',
      workerName: d['workerName'] ?? '',
      workerSkill: d['workerSkill'] ?? '',
      workerPhone: d['workerPhone'] ?? '',
      expectedWage: _i(d['expectedWage']),
      status: d['status'] ?? 'pending',
      createdAt: _t(d['createdAt']),
    );
  }
}

/// A conversation between two accounts, optionally about one job. The id is
/// derived from the participants so a thread is never duplicated.
class ThreadDoc {
  final String id;
  final List<String> participants;
  final Map<String, String> names;
  final String? jobId;
  final String jobTitle;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unread;

  const ThreadDoc({
    required this.id,
    required this.participants,
    this.names = const {},
    this.jobId,
    this.jobTitle = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unread = const {},
  });

  static String idFor(String a, String b, {String? jobId}) {
    final pair = [a, b]..sort();
    return jobId == null ? pair.join('_') : '${pair.join('_')}_$jobId';
  }

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'names': names,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'lastMessage': lastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unread': unread,
      };

  static ThreadDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ThreadDoc(
      id: doc.id,
      participants: _l(d['participants']),
      names:
          (d['names'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
      jobId: _s(d['jobId']),
      jobTitle: d['jobTitle'] ?? '',
      lastMessage: d['lastMessage'] ?? '',
      lastMessageAt: _t(d['lastMessageAt']),
      unread: (d['unread'] as Map?)
              ?.map((k, v) => MapEntry('$k', v is num ? v.toInt() : 0)) ??
          const {},
    );
  }
}

class MessageDoc {
  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;

  const MessageDoc({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
      };

  static MessageDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return MessageDoc(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      text: d['text'] ?? '',
      sentAt: _t(d['sentAt']),
    );
  }
}

class ListingDoc {
  final String id;
  final String vendorId;
  final String item;
  final int price;
  final String unit;
  final String area;
  final String state;

  const ListingDoc({
    required this.id,
    required this.vendorId,
    required this.item,
    required this.price,
    required this.unit,
    this.area = '',
    this.state = '',
  });

  Map<String, dynamic> toMap() => {
        'vendorId': vendorId,
        'item': item,
        'price': price,
        'unit': unit,
        'area': area,
        'state': state,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ListingDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ListingDoc(
      id: doc.id,
      vendorId: d['vendorId'] ?? '',
      item: d['item'] ?? '',
      price: _i(d['price']),
      unit: d['unit'] ?? 'unit',
      area: d['area'] ?? '',
      state: d['state'] ?? '',
    );
  }
}

class ReviewDoc {
  final String id;
  final String aboutUserId;
  final String byUserId;
  final String byName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const ReviewDoc({
    required this.id,
    required this.aboutUserId,
    required this.byUserId,
    required this.rating,
    this.byName = '',
    this.comment = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'aboutUserId': aboutUserId,
        'byUserId': byUserId,
        'byName': byName,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static ReviewDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ReviewDoc(
      id: doc.id,
      aboutUserId: d['aboutUserId'] ?? '',
      byUserId: d['byUserId'] ?? '',
      byName: d['byName'] ?? '',
      rating: _i(d['rating']),
      comment: d['comment'] ?? '',
      createdAt: _t(d['createdAt']),
    );
  }
}

/// A user flagging a job or another person for review. Write-only from the
/// client — see `onReport` in Cloud Functions and the `reports` rule.
class ReportDoc {
  final String byUserId;
  final String? aboutUserId;
  final String? jobId;
  final List<String> reasons;
  final String note;

  const ReportDoc({
    required this.byUserId,
    this.aboutUserId,
    this.jobId,
    required this.reasons,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'byUserId': byUserId,
        if (aboutUserId != null) 'aboutUserId': aboutUserId,
        if (jobId != null) 'jobId': jobId,
        'reasons': reasons,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Server-maintained minimum-wage figures, read from `config/minWage`. State
/// minimum wages change periodically; keeping the current numbers in a
/// document a moderator can update — rather than compiled into the app —
/// means a revision doesn't need a new app release. Falls back to the
/// bundled `kMinWageTable` when this document doesn't exist or is unreachable.
class MinWageConfigDoc {
  final Map<String, Map<String, int>> table;
  final DateTime? asOf;

  const MinWageConfigDoc({this.table = const {}, this.asOf});

  static MinWageConfigDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final raw = d['table'];
    final table = <String, Map<String, int>>{};
    if (raw is Map) {
      raw.forEach((state, categories) {
        if (categories is Map) {
          table['$state'] = categories
              .map((category, value) => MapEntry('$category', _i(value)));
        }
      });
    }
    return MinWageConfigDoc(table: table, asOf: _t(d['asOf']));
  }
}
