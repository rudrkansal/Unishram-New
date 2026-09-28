# UniShram — machine setup

Nothing here can be run for you: each step needs your password, your Google or
Apple account, or a payment. Work down the list; I'll note what unblocks what.

## 0. What this Mac is missing right now

| Tool | Needed for | Status |
|---|---|---|
| Xcode (full) + CocoaPods | building the iOS app at all | missing |
| Android SDK (via Android Studio) | building the Android app at all | missing |
| Java JDK 17 | Android Gradle builds | missing |
| Node.js 20+ | Firebase CLI, Cloud Functions, emulators | missing |
| Firebase CLI + FlutterFire CLI | connecting the app to your Firebase project | missing |

Until Xcode and the Android SDK exist, **no store binary can be produced** — not
by me, not by you. Everything else can proceed in parallel.

## 1. Xcode (iOS) — slowest, start it first

Install **Xcode** from the Mac App Store (~10 GB, expect an hour or more), then:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

## 2. Android Studio + JDK

Install **Android Studio** from https://developer.android.com/studio, open it
once and let it install the SDK, then accept the licences:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter doctor --android-licenses
```

Install JDK 17 (Temurin):

```bash
brew install --cask temurin@17
```

## 3. Node.js and the Firebase tooling

```bash
brew install node@20
npm install -g firebase-tools
export PATH="$HOME/development/flutter/bin:$PATH"
dart pub global activate flutterfire_cli
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
```

## 4. Create the Firebase project

1. Go to https://console.firebase.google.com and create a project named
   **UniShram**. Enable Google Analytics only if you want it.
2. In **Build → Authentication → Sign-in method**, enable **Phone**. Add a few
   test numbers under "Phone numbers for testing" so you can sign in without
   burning real SMS quota.
3. In **Build → Firestore Database**, create a database in **asia-south1**
   (Mumbai) in *production mode* — the security rules in this repo will replace
   the defaults.
4. In **Build → Storage**, enable it, same region.
5. Firestore, Storage and Functions all require the **Blaze** (pay-as-you-go)
   plan. Phone Auth SMS also costs per message. Set a budget alert.

Then, from the repo root:

```bash
export PATH="$HOME/development/flutter/bin:$PATH":"$HOME/.pub-cache/bin"
firebase login
flutterfire configure --project=<your-firebase-project-id>
```

That generates `lib/firebase_options.dart` and drops the platform config files
into `android/app` and `ios/Runner`. **Do not commit those to a public repo.**

Deploy the rules, indexes and functions that live in this repo:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
cd functions && npm install && cd ..
firebase deploy --only functions
```

## 5. Store developer accounts

**Google Play Console** — https://play.google.com/console — one-time ₹2,000
(~$25). As an individual you must verify your identity with a government ID, and
your legal name and address become publicly visible on your store listing. Google
now requires new personal accounts to run a **closed test with 12 testers for 14
continuous days** before you may apply for production access. Plan for that: it
is the single longest delay between "app is finished" and "app is live".

**Apple Developer Program** — https://developer.apple.com/programs/ — $99/year,
renewed annually. Individual enrolment uses your own name as the seller.
Enrolling as a company requires a D-U-N-S number, which takes days to obtain.
Approval typically takes 24–48 hours but can run over a week.

Start both enrolments now — they gate the launch and neither depends on the code
being finished.

## 6. Verify

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter doctor          # everything should be a tick
flutter run             # on a connected phone or emulator
```
