/// Example: How to use FirebaseStringsService in your app

// Option 1: Use in app_state.dart (CURRENT IMPLEMENTATION)
// Instead of:
//   Str get t => stringsFor(langCode);
// Use:
//   Str get t => Str(FirebaseStringsService.getStringsForLanguage(langCode));

// Option 2: Wrap the stringsFor function in strings.dart
// Modify stringsFor():
//   Str stringsFor(String langCode) {
//     try {
//       return Str(FirebaseStringsService.getStringsForLanguage(langCode));
//     } catch (e) {
//       debugPrint('Firebase error: $e');
//     }
//     return Str(_getHardcodedStrings(langCode));
//   }

// How to test Firebase strings locally:
// 1. firebase emulators:start --only remoteconfig
// 2. Add test parameters via Firebase Emulator UI
// 3. Verify app loads them correctly

// Deployment checklist:
// ✅ firebase_remote_config in pubspec.yaml
// ✅ FirebaseStringsService created
// ✅ Initialize in main.dart
// ✅ app_state.dart updated to use Firebase
// ✅ Hardcoded fallback present
// Ready to build: flutter build apk --release

// See FIREBASE_SETUP.md for complete setup instructions
