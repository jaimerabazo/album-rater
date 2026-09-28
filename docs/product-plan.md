# Build from the listener's experience

## The intended journey

I create an account, start a listening session for an album, and invite my friend. We join the same session, listen to each track, give it a score out of 10, and add a comment. At the end, we see our individual album scores and the group's result. Later, I can reopen that session and remember what we thought.

A listening session is one occasion: reviewing the same album next year should create another history entry.

## Small milestones

1. **Accounts (this starter):** connect a development backend and verify sign-up, login, recovery, and logout on your phone.
2. **Solo review:** manually enter an album and tracks, give each track an integer score from 1–10, add optional comments, and save/reopen the review. These are initial product defaults; change them before building if you prefer zero or decimal ratings. Keep a separately entered overall album score; show the track average with a different label.
3. **A friend joins:** create an invite, join a private session, and see each other's saved ratings. Session access comes from membership verified by the server.
4. **Live updates:** receive new scores/comments without refreshing. First make rating collaboration reliable while each person controls their own music.
5. **Music integration experiment:** verify one provider's authorization, catalog access, playback, and behavior on two physical iPhones before promising synchronized listening.
6. **Public release:** finish account deletion, privacy disclosures, email delivery, abuse controls, accessibility, device testing, and the relevant App Store requirements.

## Backend boundaries

Supabase Auth owns the user records. The profile milestone adds public.profiles with owner-only read/write policies; see database-schema.md and the versioned SQL migration. There is no custom password database, admin endpoint, or music credential storage.

When adding reviews, introduce versioned database migrations and Row Level Security (RLS). RLS means the database itself decides which rows a person can access, even if someone bypasses the app's screens. Do not add tables with broad public access to make development easier.

Proposed tables for the next milestones, not a deployed schema:

| Table | Purpose | Required permission |
| --- | --- | --- |
| profiles | Display name tied to an Auth user ID | Edit your own; expose only deliberate profile fields to peers. |
| listening_sessions | Album snapshot, host, status, creation time | Only members can read; host controls lifecycle. |
| session_members | Which users joined a session | Join via a server-validated invitation; cannot add yourself arbitrarily. |
| session_tracks | Track order and provider IDs for this review | Members can read; controlled writes. |
| track_ratings | One score/comment per user and session track | Members read; only the author writes their own. |
| album_ratings | One overall score per member and session | Same ownership and membership checks. |

Enforce score ranges, comment lengths, foreign keys, and unique ratings in the database. Compute group results from saved ratings; don't trust a client-submitted group total. Invitations need random expiring tokens and server-side verification. Realtime channels need membership authorization too. Test with two members, an unrelated account, and no account, including direct API requests that attempt to read/write another session.

## Music feasibility

Apple's [MusicKit](https://developer.apple.com/musickit/) supports Apple Music catalog access and playback, with user permission and subscription checks. Spotify's [iOS SDK](https://developer.spotify.com/documentation/ios) controls playback in the Spotify app. They are different integrations, each with its own permissions and requirements.

Do not assume matching catalog tracks, synchronized starts, background control, or cross-provider playback will just work. Test latency, pause/seek, disconnects, unavailable tracks, account eligibility, and regional differences on real devices. Store ratings independently of player state, so playback failure does not lose a review.

Before committing to a public Spotify integration, recheck its [developer policy](https://developer.spotify.com/policy) and [quota/approval requirements](https://developer.spotify.com/documentation/web-api/concepts/quota-modes). A personal prototype working does not establish public distribution eligibility. Apple Music is the first integration to investigate for this iPhone project, not a promise of exact synchronization.

## Before App Store submission

This starter is not submission-ready. Add in-app account deletion backed by a trusted server operation, a privacy policy and accurate App Privacy disclosures. Decide how users report/block abusive comments as sharing expands. Confirm music-service requirements and test the completed app against Apple's current [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

Keep privileged account deletion credentials on the server. Define whether deleting an account removes or anonymizes its shared reviews before writing that endpoint. Configure production email, rate limits and appropriate abuse protection before opening registration publicly.
