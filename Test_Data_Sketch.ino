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
  Firebase.signUp(&config, &auth, "", "");
  Serial.println("Firebase initialized!");
}

void loop() {
  Serial.println("Checking Firebase...");
  if (Firebase.ready()) {
    Serial.println("Firebase ready!");
    if (Firebase.RTDB.setInt(&fbdo, "/test/value", 42)) {
      Serial.println("Data written successfully!");
    } else {
      Serial.println(fbdo.errorReason());
    }
  } else {
    Serial.println("Firebase not ready...");
  }
  delay(5000);
}