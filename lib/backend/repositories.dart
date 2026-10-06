import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import 'models.dart';
import 'post_job_api.dart';

typedef Snap = DocumentSnapshot<Map<String, dynamic>>;

/// Phone-number sign-in. Firebase sends the real SMS; on Android it may resolve
/// the code automatically, in which case [onVerified] fires without the user
/// typing anything.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  String? _verificationId;
  int? _resendToken;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// [phone] is the 10-digit Indian number without the country code.
  Future<void> sendOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function(UserCredential credential) onVerified,
    required void Function(String message) onError,
    bool resend = false,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[AuthRepository.sendOtp] Starting OTP verification for: +91$phone');
      }
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        forceResendingToken: resend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          if (kDebugMode) {
            debugPrint('[AuthRepository] verificationCompleted callback fired');
          }
          try {
            onVerified(await _auth.signInWithCredential(credential));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[AuthRepository] Error in verificationCompleted: $e');
            }
            onError(_message(e));
          }
        },
        verificationFailed: (e) {
          if (kDebugMode) {
            debugPrint('[AuthRepository] verificationFailed callback fired with: $e');
          }
          onError(_message(e));
        },
        codeSent: (verificationId, resendToken) {
          if (kDebugMode) {
            debugPrint('[AuthRepository] codeSent callback fired');
          }
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (kDebugMode) {
            debugPrint('[AuthRepository] codeAutoRetrievalTimeout callback fired');
          }
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      // verifyPhoneNumber's own Future can reject directly (seen on web)
      // without ever calling verificationFailed — route it through the same
      // onError channel so callers only ever need to handle one failure path,
      // including a throttled ("too-many-requests") send/resend.
      if (kDebugMode) {
        debugPrint('[AuthRepository.sendOtp] Caught exception in verifyPhoneNumber: $e');
      }
      onError(_message(e));
    }
  }

  /// Throws the translation-key string (see [_message]) rather than a raw
  /// [FirebaseAuthException], so the caller can show it without needing to
  /// know Firebase's error codes.
  Future<UserCredential> verifyOtp(String smsCode) async {
    final id = _verificationId;
    if (id == null) {
      throw 'authErrorSessionExpired';
    }
    try {
      return await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode),
      );
    } catch (e) {
      throw _message(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Play and the App Store both require in-app account deletion. Recent
  /// sign-in is required, so the caller may need to re-verify first.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  /// Returns a [Str] lookup key, not the message itself — this layer has no
  /// access to the current language, so translation happens where the
  /// caller has a `t`. `authErrorGeneric` is the fallback for a Firebase
  /// code with no specific copy of its own (rare, but the raw
  /// [FirebaseAuthException.message] is always English and never shown).
  /// Firebase's own error code for the most recent failure the app has no specific wording for, so the
  /// generic "Sign-in failed" message can say what actually went wrong.
  static String? lastUnrecognisedCode;

  static String _generic(String code) {
    lastUnrecognisedCode = code;
    return 'authErrorGeneric';
  }

  static String _message(Object error) {
    lastUnrecognisedCode = null;
    if (error is FirebaseAuthException) {
      if (kDebugMode) {
        debugPrint(
          '[FirebaseAuth] Exception caught\n'
          '  Code: ${error.code}\n'
          '  Message: ${error.message}\n'
          '  Plugin Code: ${error.plugin}\n'
          '  Full exception: $error',
        );
      }
      return switch (error.code) {
        'invalid-phone-number' => 'authErrorInvalidPhone',
        'too-many-requests' => 'authErrorTooManyAttempts',
        'invalid-verification-code' => 'authErrorInvalidCode',
        'session-expired' => 'authErrorSessionExpired',
        'quota-exceeded' => 'authErrorQuotaExceeded',
        'requires-recent-login' => 'authErrorReauthRequired',
        'network-request-failed' => 'authErrorNetwork',
        _ => _generic(error.code),
      };
    }
    if (kDebugMode) {
      debugPrint('[FirebaseAuth] Non-Firebase exception: $error\nType: ${error.runtimeType}');
    }
    lastUnrecognisedCode = 'unknown';
    return 'authErrorGeneric';
  }

  /// The user only ever sees the translated copy, which hides what actually
  /// went wrong (a missing SHA fingerprint, Play Integrity, billing...). Log
  /// the real code to the console and to Crashlytics so Play builds can be
  /// diagnosed without a cable.
  static void _logAuthError(Object error) {
    final detail = error is FirebaseAuthException
        ? 'FirebaseAuthException(${error.code}): ${error.message}'
        : '$error';
    debugPrint('Phone auth failed: $detail');
    unawaited(FirebaseCrashlytics.instance
        .recordError(error, StackTrace.current, reason: 'phone auth: $detail')
        .catchError((_) {}));
  }
}

class UserRepository {
  UserRepository({FirebaseFirestore? db})
      : _users = (db ?? FirebaseFirestore.instance).collection('users');
  final CollectionReference<Map<String, dynamic>> _users;

  Future<UserDoc?> fetch(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? UserDoc.fromDoc(doc) : null;
  }

  Stream<UserDoc?> watch(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserDoc.fromDoc(doc) : null);

  /// Creates on first write, merges afterwards, so an interrupted onboarding
  /// resumes instead of starting over.
  Future<void> save(UserDoc user) async {
    final batch = _users.firestore.batch();
    batch.set(_users.doc(user.uid), {
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (user.phone.isNotEmpty) {
      batch.set(_privateContact(user.uid), {
        'phone': user.phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _privateTerms(String uid) =>
      _users.doc(uid).collection('private').doc('terms');

  /// The Terms version this user has accepted (owner-only document), or null if none.
  Future<String?> fetchTermsVersion(String uid) async {
    final snap = await _privateTerms(uid).get();
    final v = snap.data()?['termsVersion'];
    return v is String ? v : null;
  }

  /// Records acceptance. The timestamp is generated by the server (the rules require it to equal the
  /// request time), never taken from the client.
  Future<void> acceptTerms(String uid, String version) =>
      _privateTerms(uid).set({
        'termsVersion': version,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      });

  DocumentReference<Map<String, dynamic>> _privateContact(String uid) =>
      _users.doc(uid).collection('private').doc('contact');

  /// The signed-in user's own phone number (owner-only document). Falls back
  /// to a legacy profile field until that has been migrated. Only ever call
  /// this for the current user — rules deny it for anyone else.
  Future<String> fetchOwnPhone(String uid, {String legacy = ''}) async {
    try {
      final snap = await _privateContact(uid).get();
      final phone = snap.data()?['phone'];
      if (phone is String && phone.isNotEmpty) return phone;
    } on FirebaseException catch (_) {}
    return legacy;
  }

  /// Another user's phone for Call now. firestore.rules decide who may read
  /// it (role pair + not blocked); refused or missing returns ''. Profiles not
  /// yet migrated still carry it on the profile itself.
  Future<String> fetchContactPhone(String uid) async {
    try {
      final phone = (await _privateContact(uid).get()).data()?['phone'];
      if (phone is String && phone.isNotEmpty) return phone;
    } on FirebaseException catch (_) {}
    try {
      final legacy = (await _users.doc(uid).get()).data()?['phone'];
      if (legacy is String) return legacy;
    } on FirebaseException catch (_) {}
    return '';
  }

  Future<void> patch(String uid, Map<String, dynamic> fields) =>
      _users.doc(uid).set({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Workers for the contractor's Find screen, closest first when the
  /// contractor has a coverage point, best-rated first otherwise.
  Stream<List<UserDoc>> watchWorkers({
    String? skillId,
    List<String>? cityIn,
    String? state,
    GeoPoint? centre,
    double? radiusKm,
  }) {
    Query<Map<String, dynamic>> filter(Query<Map<String, dynamic>> q) {
      if (skillId != null && skillId.isNotEmpty) {
        q = q.where('skillIds', arrayContains: skillId);
      }
      return q;
    }

    if (centre != null && radiusKm != null) {
      return GeoCollectionReference<Map<String, dynamic>>(_users)
          .subscribeWithin(
            center: GeoFirePoint(centre),
            radiusInKm: radiusKm,
            field: 'geo',
            geopointFrom: (data) =>
                (data['geo'] as Map<String, dynamic>?)?['geopoint']
                    as GeoPoint? ??
                const GeoPoint(0, 0),
            queryBuilder: (q) => filter(q
                .where('role', isEqualTo: 'labourer')
                .where('suspended', isEqualTo: false)),
            strictMode: true,
          )
          // The geo query itself is a geohash proximity scan with no server-
          // side rating sort available — best-rated-first has to be applied
          // client-side once the nearby candidates are in hand, so a highly
          // rated worker isn't buried under closer but lower-rated ones.
          // Sorted by trustScore, not raw ratingAverage — see its doc.
          .map((docs) => docs.map(UserDoc.fromDoc).toList()
            ..sort((a, b) => b.trustScore.compareTo(a.trustScore)));
    }

    Query<Map<String, dynamic>> q = filter(_users
        .where('role', isEqualTo: 'labourer')
        .where('suspended', isEqualTo: false));
    if (cityIn != null && cityIn.isNotEmpty) {
      q = q.where('city', whereIn: cityIn);
    } else if (state != null && state.isNotEmpty) {
      q = q.where('state', isEqualTo: state);
    }
    // Firestore can only orderBy a stored field, so ratingAverage picks the
    // top-50 cut server-side; trustScore then re-sorts that batch so the
    // final order a user sees rewards a consistently good track record over
    // a raw average from just one or two reviews.
    return q
        .orderBy('ratingAverage', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(UserDoc.fromDoc).toList()
          ..sort((a, b) => b.trustScore.compareTo(a.trustScore)));
  }

  Stream<List<UserDoc>> watchContractors({
    List<String>? cityIn,
    String? state,
    GeoPoint? centre,
    double? radiusKm,
  }) {
    if (centre != null && radiusKm != null) {
      return GeoCollectionReference<Map<String, dynamic>>(_users)
          .subscribeWithin(
            center: GeoFirePoint(centre),
            radiusInKm: radiusKm,
            field: 'geo',
            geopointFrom: (data) =>
                (data['geo'] as Map<String, dynamic>?)?['geopoint']
                    as GeoPoint? ??
                const GeoPoint(0, 0),
            queryBuilder: (q) => q
                .where('role', isEqualTo: 'contractor')
                .where('suspended', isEqualTo: false),
            strictMode: true,
          )
          .map((docs) => docs.map(UserDoc.fromDoc).toList()
            ..sort((a, b) => b.trustScore.compareTo(a.trustScore)));
    }

    Query<Map<String, dynamic>> q = _users
        .where('role', isEqualTo: 'contractor')
        .where('suspended', isEqualTo: false);
    if (cityIn != null && cityIn.isNotEmpty) {
      q = q.where('city', whereIn: cityIn);
    } else if (state != null && state.isNotEmpty) {
      q = q.where('state', isEqualTo: state);
    }
    return q
        .orderBy('ratingAverage', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(UserDoc.fromDoc).toList()
          ..sort((a, b) => b.trustScore.compareTo(a.trustScore)));
  }

  Future<void> saveDeviceToken(String uid, String token) =>
      _users.doc(uid).collection('tokens').doc(token).set({
        'token': token,
        'platform': Platform.operatingSystem,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeDeviceToken(String uid, String token) =>
      _users.doc(uid).collection('tokens').doc(token).delete();
}

class JobRepository {
  JobRepository({FirebaseFirestore? db, PostJobApi? postJobApi})
      : _jobs = (db ?? FirebaseFirestore.instance).collection('jobs'),
        _postJobApi = postJobApi ?? PostJobApi();
  final CollectionReference<Map<String, dynamic>> _jobs;
  final PostJobApi _postJobApi;

  /// Jobs are created only through the `postJob` Cloud Function (firestore.rules deny
  /// client creates); it validates the payload and enforces the post cooldown.
  Future<String> post(JobDoc job) => _postJobApi.post(job);

  Future<void> close(String jobId) =>
      _jobs.doc(jobId).update({'status': 'closed'});

  Future<void> markFilled(String jobId) =>
      _jobs.doc(jobId).update({'status': 'filled'});

  Stream<JobDoc?> watch(String jobId) => _jobs
      .doc(jobId)
      .snapshots()
      .map((d) => d.exists ? JobDoc.fromDoc(d) : null);

  Stream<List<JobDoc>> watchPostedBy(String uid) => _jobs
      .where('postedBy', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(JobDoc.fromDoc).toList());

  /// Jobs within [radiusKm] of [centre], nearest first, when both are given
  /// (the Nearby tier). Otherwise a flat query: filtered to [state] (the
  /// State tier), or completely unfiltered (the All India tier) — also the
  /// fallback when the worker has no coordinates yet, since a job list is
  /// more useful than an empty screen.
  Stream<List<JobDoc>> watchNearby({
    required GeoPoint? centre,
    required double? radiusKm,
    String? skill,
    String? state,
  }) {
    if (centre == null || radiusKm == null) {
      Query<Map<String, dynamic>> q = _jobs.where('status', isEqualTo: 'open');
      if (skill != null && skill.isNotEmpty) {
        q = q.where('skill', isEqualTo: skill);
      }
      if (state != null && state.isNotEmpty) {
        q = q.where('state', isEqualTo: state);
      }
      return q
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map(JobDoc.fromDoc).toList());
    }

    final collection = GeoCollectionReference<Map<String, dynamic>>(_jobs);
    return collection
        .subscribeWithin(
          center: GeoFirePoint(GeoPoint(centre.latitude, centre.longitude)),
          radiusInKm: radiusKm,
          field: 'geo',
          geopointFrom: (data) =>
              (data['geo'] as Map<String, dynamic>?)?['geopoint']
                  as GeoPoint? ??
              const GeoPoint(0, 0),
          queryBuilder: (query) {
            var q = query.where('status', isEqualTo: 'open');
            if (skill != null && skill.isNotEmpty) {
              q = q.where('skill', isEqualTo: skill);
            }
            return q;
          },
          strictMode: true,
        )
        .map((docs) => docs.map(JobDoc.fromDoc).toList());
  }

  /// Distance in km between the worker and a job, for the "2.3 km" line.
  static double? distanceKm(GeoPoint? from, GeoPoint? to) {
    if (from == null || to == null) return null;
    return GeoFirePoint(from)
        .distanceBetweenInKm(geopoint: GeoPoint(to.latitude, to.longitude));
  }
}

class ApplicationRepository {
  ApplicationRepository({FirebaseFirestore? db})
      : _applications =
            (db ?? FirebaseFirestore.instance).collection('applications');
  final CollectionReference<Map<String, dynamic>> _applications;

  /// Applying is idempotent: the document id is derived from the job and the
  /// worker, so a double tap cannot create two applications. No pre-read
  /// check is needed (or possible — firestore.rules denies reads on a
  /// not-yet-existing doc, since `resource` is null): a repeat `set()` on an
  /// existing application is simply rejected by the rules' `allow update`
  /// clause, which doesn't permit this shape of write. The job's applicant
  /// tally is bumped server-side by the `onApplication` Cloud Function —
  /// firestore.rules blocks clients from touching it directly.
  Future<void> apply(ApplicationDoc application) async {
    final ref = _applications
        .doc(ApplicationDoc.idFor(application.jobId, application.workerId));
    try {
      await ref.set(application.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

  Stream<List<ApplicationDoc>> watchForWorker(String workerId) => _applications
      .where('workerId', isEqualTo: workerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ApplicationDoc.fromDoc).toList());

  /// Firestore rules are not filters: the `allow read` rule for applications
  /// is an OR (workerId == me || contractorId == me), and a query must
  /// structurally prove which branch it satisfies via a matching `where` —
  /// a bare `jobId` filter alone gets the whole query denied. The
  /// contractorId filter here is that proof.
  Stream<List<ApplicationDoc>> watchForJob(String jobId, String contractorId) =>
      _applications
          .where('jobId', isEqualTo: jobId)
          .where('contractorId', isEqualTo: contractorId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(ApplicationDoc.fromDoc).toList());

  Future<void> setStatus(String applicationId, String status) =>
      _applications.doc(applicationId).update({'status': status});

  /// A worker's own application for one job, if it exists. Used to decide
  /// whether they may see the contractor's phone number yet.
  Stream<ApplicationDoc?> watchOne(String jobId, String workerId) =>
      _applications
          .doc(ApplicationDoc.idFor(jobId, workerId))
          .snapshots()
          .map((d) => d.exists ? ApplicationDoc.fromDoc(d) : null);
}

class ChatRepository {
  ChatRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance,
        _threads = (db ?? FirebaseFirestore.instance).collection('threads');
  final FirebaseFirestore _db;
  final CollectionReference<Map<String, dynamic>> _threads;

  Future<String> openThread({
    required String me,
    required String myName,
    required String other,
    required String otherName,
    String? jobId,
    String jobTitle = '',
  }) async {
    final id = ThreadDoc.idFor(me, other, jobId: jobId);
    await _threads.doc(id).set({
      'participants': [me, other],
      'names': {me: myName, other: otherName},
      'jobId': jobId,
      'jobTitle': jobTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  /// Opens, or reuses, the single direct thread between a contractor and a
  /// labourer. The id and participant order are canonical, so reopening hits
  /// the same document and the update rule (participants/kind kept) passes.
  Future<String> openDirectThread({
    required String me,
    required String myName,
    required String other,
    required String otherName,
  }) async {
    final id = ThreadDoc.directIdFor(me, other);
    await _threads.doc(id).set({
      'participants': ThreadDoc.sortedPair(me, other),
      'names': {me: myName, other: otherName},
      'jobId': null,
      'kind': ThreadDoc.kindDirect,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  Stream<List<ThreadDoc>> watchThreads(String uid) => _threads
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ThreadDoc.fromDoc).toList());

  Stream<List<MessageDoc>> watchMessages(String threadId) => _threads
      .doc(threadId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(MessageDoc.fromDoc).toList());

  Future<void> send({
    required String threadId,
    required String senderId,
    required String recipientId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final thread = _threads.doc(threadId);
    final batch = _db.batch();
    batch.set(thread.collection('messages').doc(), {
      'senderId': senderId,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        thread,
        {
          'lastMessage': trimmed,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unread': {recipientId: FieldValue.increment(1)},
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> markRead(String threadId, String uid) =>
      _threads.doc(threadId).set({
        'unread': {uid: 0}
      }, SetOptions(merge: true));
}

class ListingRepository {
  ListingRepository({FirebaseFirestore? db})
      : _listings = (db ?? FirebaseFirestore.instance).collection('listings');
  final CollectionReference<Map<String, dynamic>> _listings;

  Stream<List<ListingDoc>> watchAll({bool ascending = true}) => _listings
      .orderBy('price', descending: !ascending)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(ListingDoc.fromDoc).toList());

  Stream<List<ListingDoc>> watchForVendor(String vendorId) => _listings
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map((s) => s.docs.map(ListingDoc.fromDoc).toList());

  Future<void> add(ListingDoc listing) => _listings.add(listing.toMap());
  Future<void> remove(String id) => _listings.doc(id).delete();
}

class ReviewRepository {
  ReviewRepository({FirebaseFirestore? db})
      : _reviews = (db ?? FirebaseFirestore.instance).collection('reviews');
  final CollectionReference<Map<String, dynamic>> _reviews;

  Stream<List<ReviewDoc>> watchFor(String userId) => _reviews
      .where('aboutUserId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(ReviewDoc.fromDoc).toList());

  /// Writes under a deterministic [id] (job + rater) so a second submission
  /// for the same job hits Firestore's `allow update: if false` rule instead
  /// of silently creating a duplicate review.
  Future<void> submit(String id, ReviewDoc review) =>
      _reviews.doc(id).set(review.toMap());
}

/// Photo uploads. Paths are namespaced by uid so the storage rules can grant a
/// user write access to their own folder and nobody else's.
class PhotoRepository {
  PhotoRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;

  Future<String> uploadProfilePhoto(String uid, File file) =>
      _upload('users/$uid/profile.jpg', file);

  Future<String> uploadWorkPhoto(String uid, File file) => _upload(
      'users/$uid/work/${DateTime.now().millisecondsSinceEpoch}.jpg', file);

  Future<void> delete(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Already gone, or never uploaded — nothing to clean up.
    }
  }

  Future<String> _upload(String path, File file) async {
    final ref = _storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}

/// Abuse/fake-listing reports. Write-only — see the `reports` rule.
class ReportRepository {
  ReportRepository({FirebaseFirestore? db})
      : _reports = (db ?? FirebaseFirestore.instance).collection('reports');
  final CollectionReference<Map<String, dynamic>> _reports;

  Future<void> file(ReportDoc report) => _reports.add(report.toMap());
}

/// Persistent, server-side blocking: a block is a doc at
/// `users/{me}/blocks/{blockedUid}`. Its existence is what firestore.rules
/// checks before letting a message be created, so blocking holds even if the
/// blocker is signed in on a different device than the one that set it.
class BlockRepository {
  BlockRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _blocks(String uid) =>
      _db.collection('users').doc(uid).collection('blocks');

  Future<void> block(String me, String blockedUid, String blockedName) =>
      _blocks(me).doc(blockedUid).set({
        'name': blockedName,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> unblock(String me, String blockedUid) =>
      _blocks(me).doc(blockedUid).delete();

  Stream<Map<String, String>> watch(String me) => _blocks(me).snapshots().map(
      (s) => {for (final d in s.docs) d.id: (d.data()['name'] ?? '') as String});
}

/// Minimum-wage figures a moderator can update from the console without a new
/// app release. See `MinWageConfigDoc`.
class MinWageRepository {
  MinWageRepository({FirebaseFirestore? db})
      : _doc = (db ?? FirebaseFirestore.instance)
            .collection('config')
            .doc('minWage');
  final DocumentReference<Map<String, dynamic>> _doc;

  Stream<MinWageConfigDoc?> watch() => _doc
      .snapshots()
      .map((doc) => doc.exists ? MinWageConfigDoc.fromDoc(doc) : null);
}
