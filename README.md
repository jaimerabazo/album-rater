# Album Rater

A small iPhone app for keeping the first-listen reviews you make with friends. Built with SwiftUI, starting with accounts.

## What works in this starter

- Email and password sign-up, with an email confirmation code.
- Login, saved login sessions in Keychain, and sign-out on this device.
- Password recovery using an email code.
- Loading states, basic form validation, and readable errors.
- Profile creation after login, with a unique username and display name.
- Saved profile retrieval on subsequent logins, then an empty listening-history screen.

This is an authentication foundation, not the finished listening app. Friends, ratings, stored album history, playback, and synchronization are not implemented. No hosted backend has been created or configured by this repository.

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
6. Duplicate `AlbumRater/BackendConfig.example.plist` as `AlbumRater/BackendConfig.plist` in the same folder. Replace the placeholders with your **project URL** and **publishable key** from the project's Connect/API settings. Xcode automatically includes this folder's files.
7. Run the app, create an account, retrieve the email code, and enter it in the app.

The local configuration file is ignored by Git. A publishable key is intentionally included in a shipped app and is not a server secret. **Never use a secret key or a service_role key in the iPhone app.** Database access must be restricted by backend permissions, not by hiding this key.

Official references: [Swift setup](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui), [email templates](https://supabase.com/docs/guides/auth/auth-email-templates), [password settings](https://supabase.com/docs/guides/auth/password-security).

## Understand the Swift files

| File | Responsibility |
| --- | --- |
| `AlbumRaterApp.swift` | Starts the app and chooses the setup, login, or home screen. |
| `Backend.swift` | Reads configuration and creates one Supabase client with Keychain storage. |
| `AuthStore.swift` | Performs account requests and holds the current user and loading state. |
| `AuthView.swift` | Displays forms and sends the user's input to the account store. |
| `Profile.swift` | Profile fields, input validation, and readable errors. |
| `ProfileStore.swift` | Profile loading/saving state, independent of the database client. |
| `SupabaseProfileRepository.swift` | Reads and inserts the current user's profile. |
| `ProfileView.swift` | Requests a missing profile or displays the saved one. |

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

## Verification of this starter

On September 7, 2026, Xcode 26.6 successfully compiled the app and its pinned dependencies for both arm64 and x86_64 iPhone simulator architectures using an SDK-only target build. The project and configuration property lists also passed validation. A simulator launch and real-account tests were not performed: this Mac needs its iOS platform/runtime component installed, and no Supabase project configuration has been supplied.

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
Consulta [las pruebas](Tests/README.md) y [el esquema actualizado](docs/database-schema.md).
