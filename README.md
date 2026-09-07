# Whistly

A Flutter app for keeping score at Colour Whist (Kleurenwiezen). It tracks
players, deals and running totals for a full session, including the special
contracts:

- Ask & Join (bidding whist)
- Trull
- Solo
- Abondance
- Miserie
- Open Miserie
- Solo Slim
- Rondpas multipliers

## Running the app

```bash
flutter pub get
flutter run
```

## Running tests

```bash
flutter test
```

## Project layout

```
lib/
  models/     Game, Player and Round data models (Hive-backed)
  providers/  ChangeNotifier state: game, players, theme, localization
  screens/    Full-page routes (active game, history, player stats, ...)
  widgets/    Reusable widgets (e.g. round setup dialog)
  theme/      App theming (AppTheme, colours)
```

## Building a release

Android:

```bash
flutter build appbundle --release
```

iOS:

```bash
flutter build ipa --release
```

Release signing for Android is configured via `android/key.properties`
(copy `android/key.properties.example` and fill in your keystore details —
see that file for the exact `keytool` command). Without it, release builds
fall back to debug signing so the project still builds out of the box.

## Before first store release

This checklist must be completed before the first App Store / Play Store
upload — none of it is done yet:

- [ ] **Choose the final package ID / bundle ID.** The project still uses
      the placeholder `com.example.whistfull`. Play rejects `com.example.*`
      uploads outright, and the applicationId can never be changed once
      published. Update `android/app/build.gradle.kts` (`namespace` and
      `applicationId`) and the iOS bundle identifier in Xcode.
- [ ] **Generate the Android upload keystore** and create
      `android/key.properties` from `android/key.properties.example`. Keep
      both the `.jks` file and `key.properties` out of version control.
- [ ] **Regenerate launcher icons and splash screen** for the final app
      identity:
      ```bash
      dart run flutter_launcher_icons
      dart run flutter_native_splash:create
      ```
- [ ] **Add a privacy policy URL** (required by both stores) and link it
      from the app's store listings.
- [ ] **Complete Play Data Safety** and **Apple App Privacy** ("privacy
      nutrition label") questionnaires in their respective consoles.
