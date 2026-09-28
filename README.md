# Album Rater

A small iPhone app for keeping the first-listen reviews you make with friends. Built with SwiftUI, starting with accounts.

## What works in this starter

- Email and password sign-up, with an email confirmation code.
- Login, saved login sessions in Keychain, and sign-out on this device.
- Password recovery using an email code.
- Loading states, basic form validation, and readable errors.
- Profile creation after login, with a unique username and display name.
- Saved profile retrieval on subsequent logins.
- Solo reviews: add an album with its track list, score each track from 1 to 10 (one decimal at most) with an optional comment, and reopen it from your history. The album average is calculated from the tracks you have scored so far and updates with every new score.

Friends, shared sessions, live updates, playback, and synchronization are not implemented. No hosted backend has been created or configured by this repository.

## Run it in Xcode

1. Open `AlbumRater.xcodeproj` in **Xcode**, Apple's app development tool. This project targets iPhone with iOS 17 or later. Use Xcode 26 or later for the pinned package's Swift tools requirements.
2. Let Xcode download the Supabase Swift package. The package version is pinned so the starting point stays reproducible.
3. In **Xcode > Settings > Components**, install the iOS platform/runtime if Xcode asks for it (if it is missing). Choose an iPhone simulator and press **Run** (Command-R). Without backend configuration, you'll see a setup message.
4. Complete the Supabase setup below, then run again.

For a physical iPhone, choose your own unique Bundle Identifier and your Apple development team under the app target's **Signing & Capabilities**. The starter uses `com.example.albumrater` as a placeholder.

## Connect Supabase

Supabase provides account management and the PostgreSQL database for profiles. The iPhone talks to its API over HTTPS. We do not implement password storage ourselves.

1. Create a development project at [Supabase](https://supabase.com/dashboard). Choose a suitable region for your users.
2. In Authentication, enable email/password sign-up and **keep email confirmation enabled**. Set the minimum password length to **12** on the server as well as in the app. Leave anonymous sign-ins disabled.
3. In Authentication's email templates, replace **Confirm sign up** with:

   ```html
   <h2>Confirm your Album Rater account</h2>
   <p>Enter this code in Album Rater:</p>
   <p>{{ .Token }}</p>
   <p>If you didn't request this, ignore this email.</p>
   ```

4. Replace the **Reset password** email template with:

   ```html
   <h2>Reset your Album Rater password</h2>
   <p>Enter this recovery code in Album Rater:</p>
   <p>{{ .Token }}</p>
   <p>If you didn't request this, ignore this email.</p>
   ```

   This starter uses codes entered in the app, so it does not need a website or email deep links. Use the newest code. If it expires, return to login and start the sign-up/recovery flow again. Supabase can rate-limit repeated requests.

5. Configure a mail provider under **Custom SMTP** to send to your friend's email too. Supabase's built-in test mail service restricts recipients and delivery volume; it is not suitable for public use. See [SMTP setup](https://supabase.com/docs/guides/auth/auth-smtp).
6. Copy `Config/BackendConfig.example.plist` to `AlbumRater/BackendConfig.plist`. Replace the placeholders with your **project URL** and **publishable key** from the project's Connect/API settings. Xcode automatically includes every file in the `AlbumRater` folder, which is why the template lives outside it.

   ```sh
   cp Config/BackendConfig.example.plist AlbumRater/BackendConfig.plist
   ```
7. Run the app, create an account, retrieve the email code, and enter it in the app.

The local configuration file is ignored by Git. A publishable key is intentionally included in a shipped app and is not a server secret. **Never use a secret key or a service_role key in the iPhone app.** Database access must be restricted by backend permissions, not by hiding this key.

Official references: [Swift setup](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui), [email templates](https://supabase.com/docs/guides/auth/auth-email-templates), [password settings](https://supabase.com/docs/guides/auth/password-security).

## Understand the Swift files

The code is split into layers. The local package `Packages/AlbumRaterKit` holds the logic, which the app target imports.

**`AlbumRaterCore`** — no dependencies, unit tested with a 95% coverage gate:

| File | Responsibility |
| --- | --- |
| `Profile.swift` | Profile fields, input validation, and readable errors. |
| `ProfileStore.swift` | Profile loading/saving state, independent of the database client. |
| `TextValidation.swift` | Single-line text rules shared with the PostgreSQL checks. |
| `Review.swift` | Albums, tracks, scores, the album average, input validation, and readable errors. |
| `ReviewsStore.swift` | Album history state shared by the list and detail screens. |

**`AlbumRaterData`** — Supabase access, integration tested against a local Supabase:

| File | Responsibility |
| --- | --- |
| `SupabaseProfileRepository.swift` | Reads and inserts the current user's profile. |
| `SupabaseReviewRepository.swift` | Loads, creates, and deletes albums; saves and clears track scores. |

**`AlbumRater/`** (app target) — SwiftUI screens, covered by UI tests:

| File | Responsibility |
| --- | --- |
| `AlbumRaterApp.swift` | Starts the app and chooses the setup, login, or home screen. |
| `Backend.swift` | Reads configuration and creates one Supabase client with Keychain storage. |
| `AuthStore.swift` | Performs account requests and holds the current user and loading state. |
| `AuthView.swift` | Displays forms and sends the user's input to the account store. |
| `ProfileView.swift` | Requests a missing profile, then shows the album history. |
| `ReviewListView.swift` | Album history, profile menu, and deletion. |
| `NewReviewView.swift` | Form for a new album with one track per line. |
| `ReviewDetailView.swift` | Album tracks and the live average. |
| `TrackRatingView.swift` | Score and comment for one track. |

`@State` remembers a screen's values. `@Observable` lets SwiftUI notice changes to the account store. `async` / `await` lets a request finish without freezing the screen. `@MainActor` keeps screen state updates on the main thread.

Start reading `AlbumRaterApp.swift`, then follow the login button in `AuthView.swift` to `AuthStore.submit`. You can change text and layout without changing account logic.

## Check the connected flow

These checks require a real Supabase development project. Compilation alone does not verify email delivery or server configuration.

- With no configuration, the setup screen appears without a crash.
- A new account must confirm its email; an incorrect code does not grant access.
- Correct login loads your profile or asks you to create it; an incorrect password shows a useful error.
- Closing and reopening the app restores a saved account. Backend requests must still validate the access token: cached screen state is not authorization.
- Sign-out returns to login and stays signed out after relaunch.
- Password recovery accepts a valid email code, requires matching new passwords, and allows login with the new password after sign-out.
- Invalid/expired recovery codes, duplicate sign-up, and temporary network failure leave a recoverable screen.
- Try a large accessibility text size and VoiceOver; confirm the form remains usable.

See [the product plan](docs/product-plan.md) for the next small milestones and the backend permissions we will need.

## Tests

Each layer has its own tests: unit tests with a 95% coverage gate for the core logic, integration tests against a local Supabase for the data layer, pgTAP for the database permissions, and UI tests for the critical flow. See [docs/testing.md](docs/testing.md).

```sh
supabase start          # local Supabase in Docker (once per session)
scripts/test-core.sh    # unit tests + coverage gate
scripts/test-data.sh    # data layer integration tests
supabase test db        # database permission tests
scripts/test-ui.sh      # UI tests in the simulator
```

For a repeatable compile without launching a simulator:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project AlbumRater.xcodeproj -target AlbumRater \
  -sdk iphonesimulator -configuration Debug \
  SYMROOT=/private/tmp/album-rater-target-build \
  OBJROOT=/private/tmp/album-rater-target-objects \
  CODE_SIGNING_ALLOWED=NO build
```

## Perfiles y migración

La tabla `public.profiles` se creó en el proyecto album-rater el 11 de septiembre
de 2026. El SQL exacto está en
[`supabase/migrations/20260911000100_create_profiles.sql`](supabase/migrations/20260911000100_create_profiles.sql).
No vuelvas a ejecutarlo en ese proyecto. Para otro entorno, sigue
[la guía de la migración](supabase/README.md).

La app ya pide nombre visible y username después del login cuando no existe perfil.
Al guardarlo espera la respuesta del servidor; en el siguiente acceso lo recupera.
Todavía no incluye edición de perfil ni cambio de username en la interfaz.

La nueva integración compila con Xcode. Las pruebas de Swift, PostgreSQL aislado y permisos en el proyecto Supabase
pasan; el recorrido completo en iPhone debe comprobarse con tu cuenta.
Consulta [las pruebas](docs/testing.md) y [el esquema actualizado](docs/database-schema.md).

## Reviews individuales (milestone 2)

La migración
[`supabase/migrations/20260928000100_create_solo_reviews.sql`](supabase/migrations/20260928000100_create_solo_reviews.sql)
crea `listening_sessions`, `session_tracks` y `track_ratings`. **Hay que aplicarla en
Supabase antes de usar esta parte de la app**; hasta entonces el historial muestra un
aviso para aplicar la migración. Sigue [la guía](supabase/README.md).

Las notas van de 1 a 10 con un decimal como máximo. La media del álbum no se guarda:
se calcula con las canciones ya puntuadas y cambia con cada nota nueva.
