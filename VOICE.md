# Voice in UniShram

Two separate things with very different coverage:

- **Speech out** — the Listen button reading screens aloud.
- **Speech in** — the microphone taking spoken commands.

## Default: device engines

Free, offline, instant, and narrow. In practice you can rely on Hindi and
English; Bengali, Tamil, Telugu, Kannada, Malayalam, Gujarati, Marathi and Urdu
are common but not guaranteed; Bodo, Dogri, Konkani, Maithili, Manipuri,
Santali, Sanskrit, Sindhi and Kashmiri are effectively absent from every phone.

Within the languages the app offers voice for, speech out degrades like this:

1. A real device voice for their language.
2. No voice but a Brahmic script → re-encoded into Devanagari and read by a
   Hindi voice. The words stay the user's own; only the accent is approximate.
   (Assamese gets a phonetic pass first, or it reads identically to Bengali.)
3. Neither → silence, and the app says a voice is missing.

There is no step where one language is read in another.

Speech in matches the locale against the device's real locale list, because
Android reports `hi_IN` and iOS `hi-IN`; passing an unknown tag does not error,
it silently recognises everything as the phone's default language. If the phone
cannot listen in the user's language, the app says so instead of listening in
a different one.

## Which language actually gets spoken

The app's own copy is complete in **English, Hindi and Punjabi only**. Every
other language falls back to one of those for body text — a user who picks Tamil
sees "Jobs near you", not Tamil.

Voice availability is a separate, simpler rule: **the Listen button and the
microphone only appear for the eleven languages Sarvam speaks** — English,
Hindi, Bengali, Gujarati, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil,
Telugu. Pick any of the other twelve — Assamese, Bodo, Dogri, Kashmiri,
Konkani, Maithili, Manipuri, Nepali, Sanskrit, Santali, Sindhi, Urdu — and
voice is absent, full stop, not a control that quietly fails or answers in the
wrong language.

`AppState.voiceAvailable` is a plain synchronous getter over
`SarvamClient.supports(langCode)`. It is deliberately not an async, engine-polled
flag: an earlier version re-asked the TTS and speech-recognition engines what
they supported and only updated after that finished, which meant the buttons
briefly showed the *previous* language's availability for a moment after
switching. Being synchronous means the buttons are correct in the very same
frame the language changes in.

Within a supported language, what is actually spoken still follows **the script
on screen**, not blindly the picked language, so mixed text (₹ amounts beside
Devanagari, for instance) is read sensibly:

| User picks | Body text they see | Voice used |
|---|---|---|
| English | English | English |
| Hindi, Maithili, Dogri, Konkani, Sanskrit, Bodo, Marathi, Nepali | Hindi | Hindi |
| Punjabi | Punjabi | Punjabi |
| the remaining fourteen | English | English |
| *splash and role screens, any language* | that language | that language |

The splash screen and role cards **are** translated into all twenty-three, so
those lines are spoken in the user's own language; the detection is by Unicode
block, so it follows the text automatically.

This is why adding a second speech vendor would not help today. There is no
Assamese or Maithili *text* for an Assamese or Maithili voice to read. The
constraint is translation, not engines — and Sarvam already covers eleven
languages, so voice follows for free as translations land.

### To add a language properly

1. Translate the copy table in `lib/data/strings.dart` (304 keys; Punjabi is at
   186 and shows the pattern for a partial one).
2. Add the language to `copyLangFor()` so it stops falling back.
3. If Sarvam covers it, voice starts working with no further change.
4. If it does not — Bodo, Santali, Dogri, Kashmiri, Sindhi, Manipuri, Maithili,
   Konkani, Sanskrit, Nepali, Assamese, Urdu — you then need a second engine.
   Azure Speech is the practical hosted option (broadest Indic coverage among
   the big clouds, notably Urdu and Nepali); self-hosted AI4Bharat is the only
   realistic route for the genuinely low-resource ones, and costs you a GPU.
   Verify the current language list with the vendor before committing: these
   lists change, and I would not trust a remembered one.

## If a supported language plays nothing

The Listen button showing up means the app has decided the language is one it
should be able to speak — Punjabi, Gujarati, Malayalam and Odia are all in that
set. Whether a tap actually produces sound is a separate question, and without
a Sarvam key there are two ways it can go quiet:

**No Sarvam key configured.** This is the default state of every build so far
in this project. With no key, every language depends entirely on whatever
text-to-speech voices the specific phone happens to have installed. Hindi and
English are close to universal; Bengali, Tamil, Telugu, Kannada are common;
Gujarati, Malayalam, Punjabi and especially Odia are frequently *not*
pre-installed — a phone has to have that language pack downloaded, and most
never are unless the owner went looking for it. This is not a bug in the app;
it is what "no voice configured" actually means, and it is exactly why Sarvam
exists in the first place. A key removes this entirely for these four
languages, since Sarvam speaks all of them natively.

**A startup race, now fixed.** On the first Listen tap of a session, the app
used to ask the platform once for its list of installed voices and cache the
answer forever. That list is not always ready the instant the app starts — this
was measured directly: a fresh page load reported zero voices, and the same
query a few seconds later reported the full list. Whichever language got
tapped during that gap was treated as having no device voice for the rest of
the session, regardless of what was actually installed — so which languages
"worked" came down to timing, not to the language itself. The app now retries
that query a few times over about a second before giving up, which closes the
gap without adding a noticeable delay on a normal device.

## Sarvam AI (recommended, off by default)

[Sarvam](https://www.sarvam.ai) is chosen over self-hosting AI4Bharat because it
is a hosted API — no GPU to run — with one vendor for both directions and Indian
data residency, which matters under DPDP. AI4Bharat wins only if you need
Santali or Bodo, which no commercial provider covers.

Eleven languages have a real voice: English, Hindi, Bengali, Gujarati, Kannada,
Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu.

**The other twelve get no voice at all** — Assamese, Bodo, Dogri, Kashmiri,
Konkani, Maithili, Manipuri, Nepali, Sanskrit, Santali, Sindhi, Urdu. The Listen
button and the microphone are hidden for them, and the language screen does not
speak the app name back when one is chosen.

This is deliberate. Answering an Assamese speaker in Bengali, or a Konkani one
in Marathi, reads as careless rather than helpful, and a half-working
microphone that mis-hears every command is worse than a clearly text-only
screen. The app either speaks a user's own language properly or stays quiet.
`SarvamClient.supportedLanguages` is the single list that decides this; add a
language there and the buttons appear on their own.

Enable at build time; the key is never committed:

```bash
flutter run --dart-define=SARVAM_API_KEY=your_key_here
```

Optional switches:

```bash
--dart-define=CLOUD_SPEECH_IN=false    # cloud voices, device recognition
--dart-define=CLOUD_SPEECH_OUT=false   # device voices, cloud recognition
--dart-define=SARVAM_BASE_URL=...      # staging or a proxy
```

With no key the app runs entirely on device engines.

### How it behaves

- **Speech out** — synthesised audio is cached per phrase, so tapping Listen
  twice on a screen costs one request. Any failure falls back to the device
  voice rather than going quiet.
- **Speech in** — records a short clip, stops after 7 seconds or when the user
  taps the mic again, sends it for transcription, then **deletes the file**.
  If recording cannot start, it falls back to the on-device recogniser.

### Before you ship

1. **Verify the API contract.** `lib/services/sarvam.dart` is written to
   Sarvam's published contract (`/text-to-speech`, `/speech-to-text`,
   `api-subscription-key`, models `bulbul:v2` and `saarika:v2`) but has **not
   been tested against a live key** — I had none. Check the current docs, then
   run one command and one Listen tap on a real device.
2. **Budget.** Both directions bill per request. Speech out is cached; speech in
   is not, and every command is a request. `CLOUD_SPEECH_IN=false` halves the
   spend if commands prove expensive.
3. **Privacy policy.** Cloud voice sends text and short audio clips to a third
   party. Say so explicitly, name Sarvam, and say the clip is deleted after
   transcription. This is required for Play Data Safety and Apple's privacy
   labels, and it is the honest thing to tell a worker.
4. **Keys.** `--dart-define` keeps the key out of git, but it is still embedded
   in the shipped binary and can be extracted. For real volume, proxy Sarvam
   through a Cloud Function so the key stays server-side and you can rate-limit
   per user.
