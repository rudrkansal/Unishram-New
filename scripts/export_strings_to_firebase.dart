#!/usr/bin/env dart
/// Export strings from lib/data/strings.dart to Firebase Remote Config JSON format
/// Run: dart scripts/export_strings_to_firebase.dart

import 'dart:io';
import 'dart:convert';

void main() {
  // Import the strings (you'll need to run this from the Flutter project)
  print('📋 Generating Firebase Remote Config payload...\n');

  // Language maps (copied from lib/data/strings.dart)
  // For brevity, showing structure - actual data comes from strings.dart
  final languages = {
    'en': 'English',
    'hi': 'Hindi',
    'pa': 'Punjabi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'as': 'Assamese',
    'kn': 'Kannada',
    'or': 'Odia',
    'ks': 'Kashmiri',
    'sd': 'Sindhi',
  };

  final firebaseConfig = <String, Map<String, dynamic>>{};

  for (final lang in languages.keys) {
    // This will be populated with actual strings from strings.dart
    firebaseConfig['strings_$lang'] = {
      'defaultValue': {
        'value': '{}', // Placeholder - replace with actual string map JSON
      },
      'description': 'Translation strings for ${languages[lang]}',
    };
  }

  // Generate Firebase Remote Config template JSON
  final template = {
    'parameters': firebaseConfig,
    'version': {
      'description': 'UniShram App Translations',
      'versionNumber': '1',
    },
  };

  // Save to file
  final output = File('firebase_remote_config_template.json');
  output.writeAsStringSync(jsonEncode(template));

  print('✅ Generated: firebase_remote_config_template.json');
  print('\n📤 Next step:');
  print('1. Replace placeholder {} with actual string maps from strings.dart');
  print('2. Upload to Firebase Console');
  print('3. Or use: firebase remoteconfig:publish firebase_remote_config_template.json');
}
