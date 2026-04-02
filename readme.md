# BIOSYS-HydroGrow

This repo contains a Flutter app in `archive/`.

## Run (Web)

```sh
cd archive
flutter pub get
flutter run -d chrome --no-track-widget-creation
```

## Docker

Requires Docker Desktop (or another Docker daemon) running.

### Setup (auto)

```sh
bash scripts/docker_setup.sh
```

### Run (Web, hot reload)

```sh
docker compose up flutter-web
```

Then open `http://localhost:8080`.

### Export APK

```sh
docker compose run --rm flutter-apk
```

APK output: `dist/HydroGrow.apk` (debug-signed; not Play Store-ready).

## Export APK (Local)

```sh
# macOS helper (installs Android SDK cmdline tools + required packages)
bash scripts/setup_android_sdk_macos.sh

# build + copy to dist/
bash scripts/export_apk.sh --local
```

## Demo
Login via email and password: 
```
email: 
admin@admin.com
pass:
adminadmin

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


### 5) Send sample data to Firebase

From `archive/`:

```bash
node tools/rtdb_device_sim.js --interval 5 --min 20 --max 80
```
