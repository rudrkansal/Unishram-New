# Direct (Find-screen) chat — REMOVED; chat is job-scoped only

Status: **direct chat is not a UniShram feature. Entry points removed and the fake-chat fallback eliminated.**
(The product owner should confirm this reading; it is based on the evidence below and the instruction to remove
the entry points if direct chat was not intended.)

## Why it is treated as not intended
- `docs/privacy_policy.md`: chat is "between users involved in a job" and messages are "visible to the other party
  in a given job/application/chat".
- `BUILD_PROGRESS.md`: "A labourer can message a contractor **about a job**"; messaging is wired into the job
  detail screen and My Applications only.
- `firestore.rules` (since `e8111d5`): a thread requires a `jobId`, a live application, and the job's poster as the
  other participant. Direct threads were already denied (emulator test S3).
- There is no inbox / thread list screen (`ChatRepository.watchThreads` is not used anywhere).

## What the problem was
The Find-screen Contact card ("Send message") called `openChatLive` with `jobId: null`. The thread create was denied,
the error was swallowed, `_threadId` stayed null, and `sendChatLive` fell back to the local-only sample chat
(seeded greeting, messages never delivered).

## What changed
- Find worker/contractor detail screens no longer pass `chatPeerId`; their Contact button is shown only when a
  phone is actually available (offline sample data). Public profiles no longer surface other users' phones
  (`toWorker()` / `toContractor()` return an empty phone).
- Contact card: "Send message" is shown only for job-bound cards (`ContactTarget.canChat`); the `'me'` peer
  placeholder fallback is gone.
- `openChatLive`: signed in, the chat screen opens only after the server thread was created. Refused/failed ->
  toast, no navigation. Job-less, self, `'me'` and empty peers are refused (`AppState.canOpenLiveChat`).
- `sendChatLive`: signed in without a server thread -> `ChatSendMode.blocked` (toast), never the local fake chat.
  Only the offline demo (no backend) may use the local sample chat.
- `messageFeed`: signed in with no thread -> empty, not the seeded greeting.

Tests: `test/direct_chat_test.dart` (14), emulator test S3 (`tests/security/security.test.js`).

## Existing production data
4 legacy threads without a `jobId` remain. They are not deleted or migrated (production untouched).
