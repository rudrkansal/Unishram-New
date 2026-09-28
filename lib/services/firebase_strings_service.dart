import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Manages translation strings from Firebase Remote Config with fallback to hardcoded strings
class FirebaseStringsService {
  static final FirebaseStringsService _instance =
      FirebaseStringsService._internal();
  static late FirebaseRemoteConfig _remoteConfig;
  static final Map<String, Map<String, String>> _cache = {};

  FirebaseStringsService._internal();

  factory FirebaseStringsService() {
    return _instance;
  }

  /// Initialize Firebase Remote Config
  static Future<void> initialize() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      // Fetch from Firebase (cache for 1 hour)
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Firebase Remote Config init error: $e');
      // Continue with hardcoded fallbacks
    }
  }

  /// Get strings for a specific language
  static Map<String, String> getStringsForLanguage(String langCode) {
    // Try cache first
    if (_cache.containsKey(langCode)) {
      return _cache[langCode]!;
    }

    try {
      final key = 'strings_$langCode';
      final jsonString = _remoteConfig.getString(key);

      if (jsonString.isNotEmpty) {
        final decoded = _decodeStringsMap(jsonString);
        _cache[langCode] = decoded;
        return decoded;
      }
    } catch (e) {
      debugPrint('Error fetching $langCode from Firebase: $e');
    }

    // Fallback to hardcoded strings via stringsFor()
    return _getHardcodedStrings(langCode);
  }

  /// Get hardcoded strings (fallback) by using stringsFor()
  static Map<String, String> _getHardcodedStrings(String langCode) {
    // stringsFor() returns a Str object with the hardcoded map
    // We return empty map here since the Str wrapper in app_state will handle fallback via [] operator
    return {};
  }

  /// Decode JSON string from Firebase back to map
  static Map<String, String> _decodeStringsMap(String jsonString) {
    try {
      final result = <String, String>{};
      jsonString = jsonString.substring(1, jsonString.length - 1);

      // Split by comma, careful with escaped values
      final pairs = <String>[];
      String current = '';
      bool inValue = false;

      for (int i = 0; i < jsonString.length; i++) {
        final char = jsonString[i];
        if (char == '"' && (i == 0 || jsonString[i - 1] != '\\')) {
          inValue = !inValue;
        }
        if (char == ',' && !inValue) {
          pairs.add(current);
          current = '';
        } else {
          current += char;
        }
      }
      if (current.isNotEmpty) pairs.add(current);

      for (final pair in pairs) {
        final colonIndex = pair.indexOf(':');
        if (colonIndex > 0) {
          final key = pair.substring(0, colonIndex).replaceAll('"', '').trim();
          var value = pair.substring(colonIndex + 1).trim();
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }
          value = value.replaceAll('\\"', '"');
          result[key] = value;
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error decoding strings: $e');
      return {};
    }
  }
}
