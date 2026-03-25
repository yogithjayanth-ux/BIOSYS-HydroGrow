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
- If you see `CONFIGURATION_NOT_FOUND`, first go to Authentication and click **Get started**.
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

## Realtime Database Setup (Systems + Moisture)

This app uses **Firebase Realtime Database** for:
- Per-user system lists (metadata)
- Per-system sensor readings (currently `moisture`)

### Data Model

- User systems: `users/{userUid}/systems/{systemId}` → `{ "name": "Lettuce" }`
- System ownership: `systemOwners/{systemId}` → `{userUid}`
- Device sensor data: `devices/{systemId}/moisture` → number

`systemId` should be the **ESP32’s Firebase anonymous-auth UID** (printed over Serial).

### Deploy RTDB Rules

From `archive/`:

```sh
firebase deploy --only database
```

### Simulate an ESP32 (send moisture)

From `archive/`:

```sh
node tools/rtdb_device_sim.js --interval 5 --min 20 --max 80
```

It prints a **System ID** (device UID). Add that ID in the app (Systems → `+`).

Optional env vars:
- `FIREBASE_API_KEY`
- `FIREBASE_DATABASE_URL`
