# Play Console "Data Safety" Form — Draft Answers

Use these as your answers when filling out the Data Safety section in Play Console. Double-check against the actual current form fields, since Google occasionally restructures this questionnaire.

## Does your app collect or share any required user data types?
**Yes**

## Data types collected

| Data type | Collected? | Shared with third parties? | Purpose |
|---|---|---|---|
| Name | Yes | No | App functionality (profile display) |
| Phone number | Yes | No | Account creation/authentication |
| Precise location | Yes | No | App functionality (job/worker matching) |
| Approximate location | Yes | No | App functionality (job/worker matching) |
| Photos | Yes (optional) | No | App functionality (profile/work photos) |
| In-app messages | Yes | No | App functionality (chat between users) |
| App interactions / crash logs | Yes | No | Analytics, app performance |
| Device or other IDs | Yes (push notification token) | No | App functionality (notifications) |

## Is data encrypted in transit?
**Yes** (Firebase encrypts all data in transit by default)

## Can users request data deletion?
**Yes** — in-app account deletion is available (Settings → Delete Account), which removes the user's profile and related data.

## Is data collection required or optional?
- Phone number: **Required** (needed to create an account)
- Location: **Required** for core matching functionality, though users can choose manual entry (state/city/PIN) instead of precise GPS
- Photos: **Optional**

## Notes for you (Indu)
- If you add AWS S3 for storage later, you'll need to update "shared with third parties" for photos to reflect that a US-based third party (AWS) processes that data — Google requires disclosure of processors, not just data collectors.
- If you keep Firebase Analytics/Crashlytics enabled, those count as "shared with Google" for analytics purposes — the form has a specific toggle for this under each data type ("Is this data shared with Google Analytics/Crashlytics SDK").
- Re-confirm final answers directly against the live app before submission — this draft reflects the app as currently built.
