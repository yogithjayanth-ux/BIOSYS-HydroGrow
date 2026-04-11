#include <WiFi.h>
#include <Preferences.h>

#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

/**
 * ESP32 "device" uploader for Firebase Realtime Database (matches archive/tools/rtdb_device_sim.js).
 *
 * Writes:
 *   /devices/<deviceUid>                      { moisture, updatedAt }
 *   /devices/<deviceUid>/readings/<pushId>    { moisture, ts }
 *
 * Notes:
 * - Uses Anonymous Auth and persists the refresh token in NVS (Preferences) so the
 *   same System ID (UID) is reused across reboots (like device_identity.json in the JS sim).
 * - In Firebase Console → Authentication → Sign-in method: enable Anonymous provider.
 */

// ----------------------------
// Config (edit these)
// ----------------------------
static const char* WIFI_SSID = "YOUR_WIFI_SSID";
static const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

static const char* FIREBASE_API_KEY = "AIzaSyCOkkpK-cggYsfc9xm3orWoCv44JQGDgM0";
static const char* FIREBASE_DATABASE_URL = "https://biosense-3bd53-default-rtdb.firebaseio.com";

static const uint32_t UPLOAD_INTERVAL_MS = 5000;

// Moisture sensor (analog)
static const int MOISTURE_ADC_PIN = 34;  // ESP32 ADC1 pin (adjust for your wiring)
static const int ADC_WET = 1400;         // TODO: calibrate for "fully wet"
static const int ADC_DRY = 3200;         // TODO: calibrate for "fully dry"

// Set true to force a brand-new anonymous UID next boot (clears saved refresh token).
static const bool FORGET_SAVED_IDENTITY_ON_BOOT = false;

// NVS keys (where we persist identity)
static const char* PREF_NAMESPACE = "hydrogrow";
static const char* PREF_REFRESH_TOKEN_KEY = "refresh_token";

// ----------------------------
// Firebase globals
// ----------------------------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

Preferences prefs;
String deviceUid;
String savedRefreshToken;

static uint32_t lastUploadMs = 0;

static void connectWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("WiFi connected. IP: ");
  Serial.println(WiFi.localIP());
}

static String loadRefreshToken() {
  prefs.begin(PREF_NAMESPACE, false);
  if (FORGET_SAVED_IDENTITY_ON_BOOT) {
    prefs.remove(PREF_REFRESH_TOKEN_KEY);
  }
  const String token = prefs.getString(PREF_REFRESH_TOKEN_KEY, "");
  prefs.end();
  return token;
}

static void saveRefreshTokenIfChanged(const char* token) {
  if (token == nullptr || token[0] == '\0') return;

  const String next(token);
  if (next == savedRefreshToken) return;

  prefs.begin(PREF_NAMESPACE, false);
  prefs.putString(PREF_REFRESH_TOKEN_KEY, next);
  prefs.end();

  savedRefreshToken = next;
  Serial.println("Saved refresh token (stable System ID across reboots).");
}

static bool waitForFirebaseReady(uint32_t timeoutMs) {
  const uint32_t start = millis();
  while (millis() - start < timeoutMs) {
    if (Firebase.ready()) return true;
    delay(100);
  }
  return Firebase.ready();
}

static void printSystemIdHint() {
  Serial.println();
  Serial.println("Add this in the app:");
  Serial.println("  Systems → + → System ID = the UID printed above");
  Serial.println();
}

static void ensureFirebaseIdentity() {
  savedRefreshToken = loadRefreshToken();

  config.api_key = FIREBASE_API_KEY;
  config.database_url = FIREBASE_DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;

  if (savedRefreshToken.length() > 0) {
    Serial.println("Restoring identity from saved refresh token...");
    Firebase.setCustomToken(&config, savedRefreshToken.c_str());
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);

    if (waitForFirebaseReady(15000)) {
      deviceUid = auth.token.uid.c_str();
      Serial.println("Firebase ready (restored identity).");
      Serial.print("System ID (device UID): ");
      Serial.println(deviceUid);
      saveRefreshTokenIfChanged(Firebase.getRefreshToken());
      printSystemIdHint();
      return;
    }

    Serial.println("Restore failed; creating a new anonymous identity...");
  }

  if (!Firebase.signUp(&config, &auth, "", "")) {
    Serial.print("Anonymous signUp failed: ");
    Serial.println(config.signer.signupError.message.c_str());
    return;
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (!waitForFirebaseReady(15000)) {
    Serial.println("Firebase not ready after signUp.");
    return;
  }

  deviceUid = auth.token.uid.c_str();
  Serial.println("Firebase ready (new identity created).");
  Serial.print("System ID (device UID): ");
  Serial.println(deviceUid);
  saveRefreshTokenIfChanged(Firebase.getRefreshToken());
  printSystemIdHint();
}

static int clampInt(int v, int lo, int hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static int adcToPercent(int adc) {
  // TODO: Calibrate ADC_WET and ADC_DRY for your sensor + wiring.
  // Many sensors read lower ADC when wetter (reverse if yours is opposite).
  const int wet = ADC_WET;
  const int dry = ADC_DRY;
  if (wet == dry) return 0;

  const long percent = (long)(adc - dry) * 100L / (long)(wet - dry);
  return clampInt((int)percent, 0, 100);
}

static int readMoisturePercent() {
  // TODO: Replace/adjust this logic for your exact moisture sensor.
  const int adc = analogRead(MOISTURE_ADC_PIN);
  return adcToPercent(adc);
}

static void uploadMoisture(int moisture) {
  if (!Firebase.ready()) {
    Serial.println("Firebase not ready; skipping upload.");
    return;
  }

  if (deviceUid.length() == 0) {
    deviceUid = auth.token.uid.c_str();
    if (deviceUid.length() == 0) {
      Serial.println("Device UID not available yet; skipping upload.");
      return;
    }
  }

  const String devicePath = "/devices/" + deviceUid;

  // History:
  //   /devices/<uid>/readings/<pushId> { moisture, ts }
  FirebaseJson reading;
  reading.set("moisture", moisture);
  reading.set("ts/.sv", "timestamp");
  if (Firebase.RTDB.pushJSON(&fbdo, devicePath + "/readings", &reading)) {
    Serial.print("Pushed reading: ");
    Serial.println(fbdo.pushName());
  } else {
    Serial.print("Failed to push reading: ");
    Serial.println(fbdo.errorReason());
  }

  // Current state (JS sim does a PATCH with { moisture, updatedAt }):
  //   /devices/<uid> { moisture, updatedAt }
  FirebaseJson patch;
  patch.set("moisture", moisture);
  patch.set("updatedAt/.sv", "timestamp");
  if (Firebase.RTDB.updateNode(&fbdo, devicePath, &patch)) {
    Serial.println("Updated device state.");
  } else {
    Serial.print("Failed to update device state: ");
    Serial.println(fbdo.errorReason());
  }

  // Persist the refresh token (it may rotate).
  saveRefreshTokenIfChanged(Firebase.getRefreshToken());
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println();
  Serial.println("ESP32 RTDB device uploader starting...");

  connectWiFi();
  ensureFirebaseIdentity();
}

void loop() {
  const uint32_t now = millis();
  if (now - lastUploadMs < UPLOAD_INTERVAL_MS) {
    delay(50);
    return;
  }
  lastUploadMs = now;

  const int moisture = readMoisturePercent();
  Serial.print("Moisture%: ");
  Serial.println(moisture);

  uploadMoisture(moisture);
}

