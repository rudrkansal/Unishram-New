# Firebase Remote Config Setup Guide

## Overview
This guide sets up Firebase Remote Config to manage app translations dynamically without rebuilding.

## Step 1: Set Up Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or select existing one for UniShram
3. Enable **Remote Config** in the Firebase Console

## Step 2: Add Translations to Remote Config

### Via Firebase Console (Manual):
1. Go to **Remote Config** in Firebase Console
2. Click **Add Parameter** for each language:
   - Parameter name: `strings_en`, `strings_hi`, `strings_pa`, etc.
   - Value: Copy the JSON from below for each language

### Via Script (Automated - Recommended):
Run this Node.js script to upload all translations:

```javascript
// upload_to_firebase.js
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./path/to/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const remoteConfig = admin.remoteConfig();

// Translation data (from lib/data/strings.dart)
const translations = {
  strings_en: { /* English strings */ },
  strings_hi: { /* Hindi strings */ },
  strings_pa: { /* Punjabi strings */ },
  strings_bn: { /* Bengali strings */ },
  strings_ta: { /* Tamil strings */ },
  strings_mr: { /* Marathi strings */ },
  strings_gu: { /* Gujarati strings */ },
  strings_te: { /* Telugu strings */ },
  strings_ml: { /* Malayalam strings */ },
  strings_as: { /* Assamese strings */ },
  strings_kn: { /* Kannada strings */ },
  strings_or: { /* Odia strings */ },
  strings_ks: { /* Kashmiri strings */ },
  strings_sd: { /* Sindhi strings */ },
};

async function uploadTranslations() {
  try {
    let template = await remoteConfig.getTemplate();
    
    for (const [key, value] of Object.entries(translations)) {
      template.parameters[key] = {
        defaultValue: {
          value: JSON.stringify(value),
        },
        description: `Translation strings for ${key}`,
      };
    }

    await remoteConfig.publishTemplate(template);
    console.log('✅ All translations uploaded to Firebase Remote Config');
  } catch (error) {
    console.error('❌ Error uploading translations:', error);
  }
}

uploadTranslations();
```

**To run:**
```bash
npm install firebase-admin
node upload_to_firebase.js
```

## Step 3: Initialize in Flutter App

Add to `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_strings_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseStringsService.initialize();
  
  runApp(const MyApp());
}
```

## Step 4: Use in App

Replace the hardcoded string lookup with Firebase version:

```dart
// In your state management (app_state.dart):
Map<String, String> getStringsForLanguage(String langCode) {
  return FirebaseStringsService.getStringsForLanguage(langCode);
}
```

## Step 5: Update Translations Anytime

Now you can update translations in Firebase Console without rebuilding:
1. Go to Remote Config in Firebase Console
2. Edit any parameter (language string map)
3. Click **Publish Changes**
4. Users get the update on next app launch (within cache window)

## Benefits

✅ No APK rebuilds needed for translation updates
✅ A/B test translations with different user groups
✅ Push hotfixes for translation errors instantly
✅ Easy rollback if needed

## Troubleshooting

- **Strings not updating?** Clear app cache or reinstall
- **Size limit exceeded?** Firebase Remote Config has size limits (~100KB per parameter) - split large language maps if needed
- **Firebase not initialized?** Ensure `FirebaseStringsService.initialize()` is called before building the UI

## Production Deployment

1. Build and deploy APK with hardcoded fallbacks (they'll still work)
2. Upload translations to Firebase Remote Config
3. Monitor user feedback
4. Update translations in Firebase as needed
5. No app rebuild required!
