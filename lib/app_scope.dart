import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/places_service.dart';
import 'services/tts_service.dart';
import 'services/voice_command_service.dart';
import 'state/app_state.dart';

/// Convenience accessors shared by every screen.
extension AppScope on BuildContext {
  AppState get app => read<AppState>();
  AppState get appWatch => watch<AppState>();
  TtsService get tts => read<TtsService>();
  VoiceCommandService get voice => read<VoiceCommandService>();
  PlacesService get places => read<PlacesService>();

  /// Speaks [text] in the user's language. Voice is only offered for languages
  /// the app can speak properly, so the only thing left to report is a device
  /// with no usable voice at all.
  Future<void> speakAloud(String text) async {
    final state = app;
    final route = await tts.toggle(
      text,
      state.voiceLocaleFor(text),
      languageCode: state.voiceLanguageFor(text),
    );
    // Toggling speech off returns the same value; only complain if a request to
    // speak produced nothing.
    if (route == SpeechRoute.unavailable && tts.speaking) {
      state.showToast(state.t['speechUnavailable']);
    }
  }
}
