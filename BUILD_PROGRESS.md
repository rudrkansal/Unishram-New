# UniShram — build status

Design source: Claude Design project `bf75353e-4d5c-4d74-bf31-cb7f82975866`.
Decision record: Firebase backend · offline Aadhaar QR verification · production
launch intent · no store accounts yet.

Toolchain (not on PATH by default):

    export PATH="$HOME/development/flutter/bin:$PATH"

`flutter analyze` clean · `flutter build web` succeeds.

---

## Done

### App (from the design, complete)
All screens, four roles, 3-step onboarding, pickers, wage protection, chat UI,
calculator, contact sheet, bottom nav. Copy complete in EN/HI/PA, 23 languages
on splash and role select. TTS readout + spoken voice commands. Live GPS.

### Backend (Firebase)
- `lib/backend/models.dart` — Firestore documents: users, jobs, applications,
  threads/messages, listings, reviews
- `lib/backend/repositories.dart` — phone auth, profiles, geo job queries,
  idempotent applications, chat, listings, reviews, photo uploads
- `lib/backend/backend.dart` — single facade; push registration, analytics
- `lib/backend/aadhaar_qr.dart` — real UIDAI secure-QR decode (BigInt → gzip →
  0xFF-delimited fields) and RSA-SHA256 signature check, plus name/DOB/address
  matching that produces the design's five outcomes
- `firestore.rules`, `storage.rules`, `firestore.indexes.json` — clients write
  only their own documents; trust flags are server-owned
- `functions/index.js` — push on application and message, server-side minimum
  wage stamping, rating recomputation, Aadhaar badge recording, full account
  deletion cascade, expired-job sweep

### Wired into the UI
Real SMS OTP (Firebase Phone Auth) with error messages · profile sync up and
down · photo upload to Storage · Aadhaar scanner using the real verifier ·
Crashlytics + Analytics · debug-only demo shortcuts.

---

### Live data (done)
Every list screen now reads a Firestore stream through `FeedBuilder`: job feed
(geo radius from the worker's chosen work area), my posted jobs, applicants,
my applications with real status, worker and contractor search, vendor prices,
my listings, reviews, chat messages. Each falls back to the bundled sample data
when there is no backend, so the app is never a blank screen. Applying, posting,
shortlisting, listing and messaging all write through the repositories.

### Account controls (done)
Sign out and in-app account deletion on all three profile screens, with a
confirmation dialog and a re-authentication message. Deletion runs the Cloud
Function cascade, then removes the auth user.

### Voice (fixed)
Four bugs fixed: recognition locale ids are now matched against the device's
real locale list (a mismatch silently recognised every language as English);
languages with no device voice are re-encoded to Devanagari or read via the
Hindi line instead of going silent; the speaking state can no longer stick on;
and commands exist in 14 languages with whole-word matching. Sarvam AI is integrated for both
directions (Bulbul synthesis, Saarika recognition), off unless a key is passed
via `--dart-define`. What is spoken follows the script actually on
screen rather than the language picked, because app copy exists only in English,
Hindi and Punjabi — so every language now has working voice, reading the text
the user can see. Adding more spoken languages is a translation task, not an
engine one — see VOICE.md. Covered by
`test/voice_test.dart` (18 tests).

## Contact gated on approval (done)

A labourer can message a contractor about a job at any time, but only sees the
contractor's phone number (the "Contact" call option) once that specific
application has been shortlisted or hired — `AppState.isApprovedStatus()`.
Wired into both the job detail screen's contractor card and the My
Applications list, each via `AppState.myApplicationForJob()` /
`ApplicationRepository.watchOne()`. Offline/demo mode has no counterparty to
approve anything, so an applied job stays pending and only Message shows —
the safe default. Covered by `test/contact_gating_test.dart`.

## Remaining

1. **UIDAI certificate** — drop `assets/certs/uidai_prod.pem` in (see that
   folder's README). Verification fails closed until then.
2. **Compliance** — privacy policy URL, Play Data Safety answers, App Privacy
   labels, DPDP consent copy.
3. **Release** — signing keystore, bundle ids, app icons, store screenshots and
   listing copy.
4. **Testing** — voice logic is covered; repository and Aadhaar-parser unit
   tests are the next highest value.
5. **Sarvam live check** — the client is written to the published contract but
   untested against a real key; verify one command and one Listen tap on a
   device, and consider proxying the key through a Cloud Function.

## Verified

`flutter analyze` clean · `flutter build web` succeeds · language, onboarding,
job feed, job detail, calculator, applications and profile screens checked
visually at mobile size.

Note: `flutter run -d web-server` is unreliable here (the entrypoint module
404s). To look at the UI, build and serve the output instead:

    flutter build web --no-tree-shake-icons
    python3 -m http.server 8090 --directory build/web

## Blocked on you (see SETUP.md)
Xcode + CocoaPods · Android Studio SDK + JDK 17 · Node 20 + Firebase CLI ·
Firebase project + `flutterfire configure` · Play Console and Apple Developer
enrolments.
