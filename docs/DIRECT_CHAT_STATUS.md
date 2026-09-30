# Direct (Find-screen) chat — current behavior, decision pending

Status: **undecided product question. No rule or behavior change has been made.**

## What happens today
- The Find screens (workers list, contractors list) open a Contact card whose "Send message" button calls
  `AppState.openChatLive(...)` with `jobId: null` (`ContactTarget.chatJobId` is not set there;
  `chatPeerId ?? 'me'` is used as the peer).
- `ChatRepository.openThread` then writes `threads/{a_b}` with `jobId: null`.
- `firestore.rules` (since commit `e8111d5`) only allows a thread create when `jobId` is a string, the caller has a
  live application for it, and the other participant is the job's poster. A `jobId: null` thread is therefore **denied**
  (emulator test S3 in `tests/security/security.test.js`).
- `openChatLive` swallows the error and leaves `_threadId == null`; `sendChatLive` then falls back to the local-only
  `sendChat`, which shows a seeded greeting (`chatSeedGreeting`) and messages that are **never delivered**.

## Consequence
The Find-screen chat looks like it works but delivers nothing. 4 pre-`e8111d5` threads without a `jobId` exist in production.

## Options (not chosen)
- Allow direct chats: keep the Find screens working; adds unsolicited-contact surface (needs blocks, rate limits, reporting).
- Disallow: keep the job-relationship guarantee; remove/change "Send message" on the Find screens and remove the silent
  local-only fallback.
