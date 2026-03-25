# BIOSYS-HydroGrow

This repo contains a Flutter app in `archive/`.

## Run (Web)

```sh
cd archive
flutter pub get
flutter run -d chrome --no-track-widget-creation
```

## Test / Analyze

```sh
cd archive
flutter test
flutter analyze
```

## Notes

- iOS/macOS builds require a full Xcode install (`xcodebuild`).
- Android builds require Android Studio + the Android SDK.

## Firebase Setup (Login + Tickets)

This app expects Firebase for:
- Auth: Email/Password + Google Sign-In
- Firestore: Support ticket storage
- Remote Config: JSON routing for ticket recipient email(s)

### 1) Configure FlutterFire

From `archive/`:

```sh
# Install CLIs if needed
npm i -g firebase-tools
dart pub global activate flutterfire_cli

# Login + generate firebase_options + native config files
firebase login
flutterfire configure --project=biosense-3bd53
```

This overwrites the placeholder `archive/lib/firebase_options.dart`.

### 2) Enable Auth providers

In Firebase Console → Authentication → Sign-in method:
- Enable **Email/Password**
- Enable **Google**

### 3) Ticket email routing (customizable JSON)

In Firebase Console → Remote Config, set `support_ticket_routing_json` to something like:

```json
{"to":["support@yourcompany.com"],"subjectPrefix":"[HydroSense Ticket]"}
```

### 4) Email sending (optional but recommended)

If you want tickets to email automatically, install Firebase Extension **Trigger Email**
and keep its collection set to `mail` (the app writes docs to `mail/` on submit).






### Mar21Notes
    fix mysystems 
        get rid of werid star and box
        