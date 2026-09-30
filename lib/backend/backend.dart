import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import 'account_api.dart';
import 'repositories.dart';

/// One place the app talks to the server through. Screens never touch Firebase
/// directly, so the data layer can be swapped or stubbed in tests.
class Backend {
  final AccountApi accounts;
  Backend({
    AuthRepository? auth,
    UserRepository? users,
    JobRepository? jobs,
    ApplicationRepository? applications,
    ChatRepository? chat,
    ListingRepository? listings,
    ReviewRepository? reviews,
    PhotoRepository? photos,
    ReportRepository? reports,
    MinWageRepository? minWage,
    BlockRepository? blocks,
    AccountApi? accounts,
  })  : accounts = accounts ?? AccountApi(),
        auth = auth ?? AuthRepository(),
        users = users ?? UserRepository(),
        jobs = jobs ?? JobRepository(),
        applications = applications ?? ApplicationRepository(),
        chat = chat ?? ChatRepository(),
        listings = listings ?? ListingRepository(),
        reviews = reviews ?? ReviewRepository(),
        photos = photos ?? PhotoRepository(),
        reports = reports ?? ReportRepository(),
        minWage = minWage ?? MinWageRepository(),
        blocks = blocks ?? BlockRepository();

  final AuthRepository auth;
  final UserRepository users;
  final JobRepository jobs;
  final ApplicationRepository applications;
  final ChatRepository chat;
  final ListingRepository listings;
  final ReviewRepository reviews;
  final PhotoRepository photos;
  final ReportRepository reports;
  final MinWageRepository minWage;
  final BlockRepository blocks;

  String? get uid => auth.uid;
  bool get isSignedIn => auth.isSignedIn;

  /// Attaches a geohash alongside the point so radius queries work.
  static Map<String, dynamic> geoField(double lat, double lng) =>
      GeoFirePoint(GeoPoint(lat, lng)).data;

  /// Registers this device for push and keeps the token fresh.
  Future<void> registerForPush() async {
    if (kIsWeb) return;
    final uid = auth.uid;
    if (uid == null) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await users.saveDeviceToken(uid, token);
      messaging.onTokenRefresh.listen((t) => users.saveDeviceToken(uid, t));
    } catch (e, s) {
      await FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'push registration');
    }
  }

  Future<void> unregisterPush() async {
    if (kIsWeb) return;
    final uid = auth.uid;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await users.removeDeviceToken(uid, token);
    } catch (_) {
      // Signing out matters more than tidying the token list.
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {
      // Analytics must never break a user flow.
    }
  }


  Future<String> uploadProfilePhoto(File file) async {
    final uid = auth.uid;
    if (uid == null) throw StateError('Not signed in');
    return photos.uploadProfilePhoto(uid, file);
  }

  Future<String> uploadWorkPhoto(File file) async {
    final uid = auth.uid;
    if (uid == null) throw StateError('Not signed in');
    return photos.uploadWorkPhoto(uid, file);
  }

  Future<void> deleteAccount() async {
    await unregisterPush();
    // The deleteAccount Cloud Function removes every document and file and then the Auth user itself;
    // FirebaseAuth.delete() alone would leave the user's data behind.
    await accounts.deleteAccount();
    try {
      await auth.signOut();
    } catch (_) {
      // The Auth user is already gone server-side; clearing the local session is best-effort.
    }
  }
}
