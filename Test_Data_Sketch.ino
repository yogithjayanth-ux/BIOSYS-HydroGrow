#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

#define WIFI_SSID "Site1649-2.4"
#define WIFI_PASSWORD "MSUSpartans49!"
#define API_KEY "AIzaSyCOkkpK-cggYsfc9xm3orWoCv44JQGDgM0"
#define DATABASE_URL "https://biosense-3bd53-default-rtdb.firebaseio.com"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
String deviceUid;

void setup() {
  Serial.begin(115200);
  delay(5000);
  Serial.println("Starting...");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("WiFi connected!");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  // Enable anonymous sign in
  auth.user.email = "";
  auth.user.password = "";
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  if (Firebase.signUp(&config, &auth, "", "")) {
    deviceUid = auth.token.uid.c_str();
    Serial.println("Firebase initialized!");
    Serial.print("Device UID (use this as System ID in the app): ");
    Serial.println(deviceUid);
  } else {
    Serial.print("Firebase signUp failed: ");
    Serial.println(config.signer.signupError.message.c_str());
  }
}

void loop() {
  Serial.println("Checking Firebase...");
  if (Firebase.ready()) {
    Serial.println("Firebase ready!");
    if (deviceUid.length() == 0) {
      Serial.println("Device UID not ready yet...");
      delay(2000);
      return;
    }

    String uidPath = "/devices/" + deviceUid;

    // TODO: Set `moisture` from a real sensor reading (left intentionally open; do not randomize).
    const int moisture = 42;

    // Append a history point:
    //   /devices/<deviceUid>/readings/<pushId> { moisture, ts }
    // This matches `archive/tools/rtdb_device_sim.js` and the Flutter app's expected shape.
    FirebaseJson reading;
    reading.set("moisture", moisture);
    reading.set("ts/.sv", "timestamp");
    if (Firebase.RTDB.pushJSON(&fbdo, uidPath + "/readings", &reading)) {
      Serial.print("Pushed reading: ");
      Serial.println(fbdo.pushName());
    } else {
      Serial.print("Failed to push reading: ");
      Serial.println(fbdo.errorReason());
    }

    // Update the current value (same shape as the JS simulator's PATCH call).
    FirebaseJson devicePatch;
    devicePatch.set("moisture", moisture);
    devicePatch.set("updatedAt/.sv", "timestamp");
    if (Firebase.RTDB.updateNode(&fbdo, uidPath, &devicePatch)) {
      Serial.println("Device state updated!");
    } else {
      Serial.print("Failed to update device state: ");
      Serial.println(fbdo.errorReason());
    }
  } else {
    Serial.println("Firebase not ready...");
  }
  delay(5000);
}
