import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_root.dart';
import 'backend/backend.dart';
import 'firebase_options.dart';
import 'services/firebase_strings_service.dart';
import 'services/places_service.dart';
import 'services/tts_service.dart';
import 'services/voice_config.dart';
import 'services/voice_command_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

/// Background push handler. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The UI is built portrait-first throughout; locking orientation avoids
  // layout overflow rather than redesigning every screen for landscape too.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;

    // Enable Firestore offline persistence for job browsing without network
    if (!kIsWeb) {
      try {
        // Firestore offline persistence is enabled by default on mobile
        await FirebaseFirestore.instance.enableNetwork();
      } catch (e) {
        debugPrint('Offline persistence setup failed: $e');
      }
    }

    // Initialize Firebase Remote Config for translations
    await FirebaseStringsService.initialize();
  } catch (e) {
    // Not configured yet (see SETUP.md). The app still runs so the UI can be
    // worked on; anything needing the server falls back to local data.
    debugPrint('Firebase not configured: $e');
  }

  // Error capture without runZonedGuarded: wrapping runApp in its own zone
  // conflicts with bindings initialised here, which blanks the first frame.
  // Registered whether or not Firebase came up, so an uncaught async error is
  // always visible in the log instead of disappearing.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    if (firebaseReady && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  if (firebaseReady && !kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  }
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  // Building a repository touches FirebaseAuth.instance, which throws when no
  // Firebase app exists — so only construct it once init succeeded.
  final backend = firebaseReady ? Backend() : null;
  final state = AppState(backend: backend);
  await state.load();
  // Public config, needed before sign-in too (onboarding shows minimum wage),
  // so this fires regardless of auth state and never blocks first paint.
  unawaited(state.loadMinWageConfig());

  final voiceConfig = VoiceConfig.fromEnvironment();
  final tts = TtsService(config: voiceConfig);
  final voice = VoiceCommandService(config: voiceConfig);
  final places = PlacesService();
  // Both voice services live outside the state object; mirror their activity
  // into it so the UI only ever watches AppState.
  tts.onStateChanged = () => state.update(() => state.speaking = tts.speaking);
  voice.onStateChanged = () => state.update(() {
        state.voiceListening = voice.listening;
        state.voiceTranscribing = voice.transcribing;
        state.voiceHeard = voice.heard;
      });

  if (backend != null && backend.isSignedIn) {
    await backend.registerForPush();
    await state.syncFromServer();
  }

  runApp(UniShramApp(state: state, tts: tts, voice: voice, places: places));
}

class UniShramApp extends StatelessWidget {
  const UniShramApp({
    super.key,
    required this.state,
    required this.tts,
    required this.voice,
    required this.places,
  });

  final AppState state;
  final TtsService tts;
  final VoiceCommandService voice;
  final PlacesService places;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        Provider.value(value: tts),
        Provider.value(value: voice),
        Provider.value(value: places),
      ],
      child: MaterialApp(
        title: 'UniShram',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        navigatorObservers: [
          if (state.backend != null)
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        home: const AppRoot(),
      ),
    );
  }
}
