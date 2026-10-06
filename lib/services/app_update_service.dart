import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

/// What the store reported. [none] covers "no update", "not installed from
/// the store", offline, store errors and unsupported platforms alike — the
/// app carries on normally in every one of those cases.
enum StoreUpdate { none, available, resumeImmediate }

/// Optional app updates through each platform's official store mechanism:
/// Google Play In-App Updates on Android, the App Store listing on iOS
/// (Apple offers no in-app update API, so `upgrader` reads the store version
/// and opens the listing).
class AppUpdateService {
  AppUpdateService._();
  static final instance = AppUpdateService._();

  static const _laterKey = 'updatePromptLaterAt';
  static const laterCooldown = Duration(days: 3);
  static const _timeout = Duration(seconds: 10);

  bool _checkedThisSession = false;
  AppUpdateInfo? _playInfo;
  Upgrader? _upgrader;

  /// True while the update dialog is on screen, so other startup prompts can
  /// stay out of its way.
  bool promptOpen = false;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// At most one real check per app session, and none within [laterCooldown]
  /// of the user choosing "Later".
  Future<StoreUpdate> checkOnce() async {
    if (_checkedThisSession || !_supported) return StoreUpdate.none;
    _checkedThisSession = true;
    try {
      if (await _inLaterCooldown()) return StoreUpdate.none;
      return Platform.isAndroid ? await _checkPlay() : await _checkAppStore();
    } catch (e) {
      debugPrint('Update check failed (non-fatal): $e');
      return StoreUpdate.none;
    }
  }

  Future<StoreUpdate> _checkPlay() async {
    // Throws when the app was not installed from Google Play (sideloaded or
    // debug builds) or Play services are unavailable — treated as no update.
    final info = await InAppUpdate.checkForUpdate().timeout(_timeout);
    _playInfo = info;
    // The user already accepted an immediate update that was interrupted;
    // Play's guidance is to resume it rather than ask again.
    if (info.updateAvailability ==
        UpdateAvailability.developerTriggeredUpdateInProgress) {
      return StoreUpdate.resumeImmediate;
    }
    if (info.updateAvailability == UpdateAvailability.updateAvailable &&
        (info.immediateUpdateAllowed || info.flexibleUpdateAllowed)) {
      return StoreUpdate.available;
    }
    return StoreUpdate.none;
  }

  Future<StoreUpdate> _checkAppStore() async {
    final upgrader = Upgrader(checkOnResume: false);
    _upgrader = upgrader;
    try {
      await upgrader.initialize().timeout(_timeout);
      if (upgrader.isUpdateAvailable()) return StoreUpdate.available;
    } catch (_) {
      _disposeUpgrader();
      rethrow;
    }
    _disposeUpgrader();
    return StoreUpdate.none;
  }

  /// Runs the platform's update flow. Returns normally whether the user
  /// finished, cancelled or the store failed.
  Future<void> startUpdate() async {
    try {
      if (Platform.isAndroid) {
        await _startPlayUpdate();
      } else if (Platform.isIOS) {
        await _upgrader?.sendUserToAppStore();
      }
    } catch (e) {
      debugPrint('Update flow failed (non-fatal): $e');
    } finally {
      _disposeUpgrader();
    }
  }

  Future<void> _startPlayUpdate() async {
    final info = _playInfo;
    if (info == null) return;
    // Immediate is Play's full-screen download-and-install flow (the user can
    // still cancel it); flexible downloads in the background and installs on
    // completion. Both are Google's own UI.
    if (info.immediateUpdateAllowed ||
        info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress) {
      await InAppUpdate.performImmediateUpdate();
      return;
    }
    if (info.flexibleUpdateAllowed) {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        await InAppUpdate.completeFlexibleUpdate();
      }
    }
  }

  Future<void> remindLater() async {
    _disposeUpgrader();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_laterKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<bool> _inLaterCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_laterKey);
    if (at == null) return false;
    final since =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    return since >= Duration.zero && since < laterCooldown;
  }

  void _disposeUpgrader() {
    _upgrader?.dispose();
    _upgrader = null;
  }
}
