# DUO AI

Personal AI operating system app. Flutter + Firebase, MVVM / clean
architecture, Riverpod, go_router.

## Status

- ✅ Auth (email/password, auto-login)
- ✅ Home Screen (dynamic agent cards: Web Developer, Marketing, Manager)
- ✅ Chat Screen (Firestore-backed per-agent history, fake canned replies)
- ⏳ Real Claude API integration (swap `agentResponseServiceProvider`)

## Before this app actually works

Two things in this repo are placeholders and need your real Firebase
project's values:

1. **`lib/firebase_options.dart`** — currently a stub that throws at
   runtime. Generate the real file with:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

2. **`android/app/google-services.json`** — currently a dummy file
   (valid shape, fake keys) so the Gradle build succeeds without a
   Firebase project connected. `flutterfire configure` above will also
   regenerate this with real values, or grab it manually from the
   Firebase console (Project settings → your Android app).

Until both are replaced, the app **builds and installs**, but will
throw on launch when it tries to initialize Firebase — that's expected.

## Building the APK locally

```
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Building the APK via GitHub Actions

Every push to `main` (or a manual run from the Actions tab) builds a
release APK and attaches it as a workflow artifact — see
`.github/workflows/build-apk.yml`.

The workflow builds fine with the placeholder `google-services.json`.
To have CI use your **real** Firebase config without committing it to
the repo:

1. `base64 -i android/app/google-services.json | pbcopy` (or
   equivalent on your OS) — copy the base64 of your *real* file.
2. In the repo: Settings → Secrets and variables → Actions → New
   repository secret, name it `GOOGLE_SERVICES_JSON_BASE64`, paste
   the value.
3. Re-run the workflow — it decodes the secret over the placeholder
   before building.

## Signing

Release builds currently use the Android debug signing key, so the
APK installs fine on your own devices but isn't suitable for the Play
Store. Add a real signing config (`android/key.properties` + a
keystore) before distributing this more widely.

## Platforms

Only Android is set up right now, since the goal here was an
installable APK. iOS/web can be added later with `flutter create --platforms=ios,web .`
once there's a Mac in the loop for iOS.
