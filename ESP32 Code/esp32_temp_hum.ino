
#include <Wire.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>
#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

// ---------------- OLED SETTINGS ----------------

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define OLED_ADDRESS 0x3C

#define OLED_SDA 21
#define OLED_SCL 22

Adafruit_SSD1306 display(
  SCREEN_WIDTH,
  SCREEN_HEIGHT,
  &Wire,
  OLED_RESET
);

// ---------------- SERVO GATE BARRIER SETTINGS ----------------

// GPIO32 was previously used by the DHT11 data pin.
#define SERVO_PIN 32

// Adjust these angles to match your physical barrier mechanism.
const int GATE_CLOSED_ANGLE = 0;
const int GATE_OPEN_ANGLE = 90;

Servo gateServo;

// ---------------- BUZZER ----------------

#define BUZZER_PIN 27

// ---------------- RFID RC522 SETTINGS ----------------

#define RFID_SS_PIN   5
#define RFID_RST_PIN  2

#define RFID_SCK_PIN  26
#define RFID_MISO_PIN 33
#define RFID_MOSI_PIN 4

MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);

// ---------------- KEYPAD SETTINGS ----------------

const byte ROWS = 4;
const byte COLS = 4;

char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

byte rowPins[ROWS] = {13, 14, 16, 17};
byte colPins[COLS] = {18, 19, 23, 25};

Keypad keypad = Keypad(
  makeKeymap(keys),
  rowPins,
  colPins,
  ROWS,
  COLS
);

// ---------------- ESP32 HOTSPOT AND HTTP API ----------------

const char* AP_SSID = "ESP32_DOOR_LOCK";
// Change this to a strong Wi-Fi password (8 characters minimum).
const char* AP_PASSWORD = "12345678";

WebServer server(80);

// One active admin session. The token expires after 30 minutes.
String adminSessionToken = "";
unsigned long adminSessionExpiry = 0;
const unsigned long ADMIN_SESSION_DURATION = 30UL * 60UL * 1000UL;

const char* requestHeaders[] = {"Authorization"};

// Event history: a small persistent ring buffer in Preferences.
const byte MAX_STORED_EVENTS = 20;
uint32_t eventSequence = 0;

// The phone synchronizes Unix time when it connects.
// Until then, events contain uptime but no fabricated calendar timestamp.
bool deviceTimeSynced = false;
uint64_t syncedUnixTime = 0;
unsigned long syncedMillis = 0;

// ---------------- PASSWORD SETTINGS ----------------

Preferences preferences;

String correctPassword = "1234";
String adminPassword = "987654";
String enteredPassword = "";

const byte MIN_PASSWORD_LENGTH = 4;
const byte MAX_PASSWORD_LENGTH = 8;

bool unlocked = false;

// Automatically close the gate 5 seconds after it opens.
const unsigned long GATE_AUTO_CLOSE_MS = 5000UL;
unsigned long gateOpenedAt = 0;

// Password operation modes
enum PasswordMode {
  NORMAL_LOGIN,
  VERIFY_CURRENT,
  SET_NEW,
  VERIFY_RFID_ADMIN,
  SET_NEW_ADMIN
};

enum RFIDAdminMode {
  RFID_ADMIN_OFF,
  RFID_ADMIN_MENU,
  RFID_WAIT_ADD,
  RFID_WAIT_REMOVE
};

RFIDAdminMode rfidAdminMode = RFID_ADMIN_OFF;

// Registered RFID card UIDs
String registeredUIDs = "|";

PasswordMode passwordMode = NORMAL_LOGIN;

unsigned long lastGateDisplayUpdate = 0;

// ---------------- BUZZER FUNCTION ----------------

void beep(int duration) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(duration);
  digitalWrite(BUZZER_PIN, LOW);
}

// ---------------- MESSAGE SCREEN ----------------

void showMessage(const char* line1, const char* line2) {

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(2);
  display.setCursor(5, 12);
  display.println(line1);

  display.setTextSize(1);
  display.setCursor(5, 42);
  display.println(line2);

  display.display();
}

// ---------------- PASSWORD SCREEN ----------------

void showPasswordScreen() {

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);

  if (passwordMode == NORMAL_LOGIN) {

    display.setTextSize(2);
    display.setCursor(15, 5);
    display.println("WELCOME");

    display.setTextSize(1);
    display.setCursor(10, 32);
    display.println("Enter Password:");

  }

  else if (passwordMode == VERIFY_CURRENT) {

    display.setCursor(5, 5);
    display.println("CHANGE PASSWORD");

    display.setCursor(5, 27);
    display.println("Current Password:");

  }

  else if (passwordMode == SET_NEW) {

    display.setCursor(5, 5);
    display.println("CHANGE PASSWORD");

    display.setCursor(5, 27);
    display.println("Enter New Password:");

  }

  else if (passwordMode == VERIFY_RFID_ADMIN) {

  display.setCursor(5, 5);
  display.println("RFID MANAGEMENT");

  display.setCursor(5, 27);
  display.println("Enter Admin Pass:");

}
else if (passwordMode == SET_NEW_ADMIN) {

  display.setCursor(5, 5);
  display.println("ADMIN PASSWORD");

  display.setCursor(5, 27);
  display.println("Enter New Password:");

}

  display.setTextSize(2);
  display.setCursor(15, 45);

  for (int i = 0; i < enteredPassword.length(); i++) {
    display.print("*");
  }

  display.display();
}

// ---------------- WRONG PASSWORD ----------------

void wrongPassword() {

  showMessage("WRONG!", "Incorrect Password");

  recordEvent("password_attempt", "", "denied");
  beep(1000);

  enteredPassword = "";
  passwordMode = NORMAL_LOGIN;

  delay(1000);
  rfidAdminMode = RFID_ADMIN_OFF;
  showPasswordScreen();
}

// ---------------- START PASSWORD CHANGE ----------------

void startPasswordChange() {

  passwordMode = VERIFY_CURRENT;
  enteredPassword = "";

  showPasswordScreen();

  Serial.println("Password change requested.");
  Serial.println("Enter current password.");
}

// ---------------- CANCEL PASSWORD CHANGE ----------------

void cancelPasswordChange() {

  enteredPassword = "";
  passwordMode = NORMAL_LOGIN;

  showMessage("CANCELLED", "Password unchanged");

  beep(150);

  delay(1000);

  showPasswordScreen();

  Serial.println("Password change cancelled.");
}

// ---------------- VERIFY CURRENT PASSWORD ----------------

void verifyCurrentPassword() {

  if (enteredPassword == correctPassword) {

    enteredPassword = "";
    passwordMode = SET_NEW;

    showPasswordScreen();

    beep(150);

    Serial.println("Current password verified.");
    Serial.println("Enter your new password.");

  }

  else {

    Serial.println("Incorrect current password.");

    wrongPassword();
  }
}

// ---------------- SAVE NEW PASSWORD ----------------

void saveNewPassword() {

  if (enteredPassword.length() < MIN_PASSWORD_LENGTH ||
      enteredPassword.length() > MAX_PASSWORD_LENGTH) {

    showMessage("INVALID!", "Use 4-8 digits");

    beep(500);

    delay(1200);

    enteredPassword = "";
    showPasswordScreen();

    return;
  }

  // Save password permanently in ESP32 NVS memory
  size_t saved = preferences.putString(
    "password",
    enteredPassword
  );

  if (saved > 0) {

    correctPassword = enteredPassword;

    enteredPassword = "";

    passwordMode = NORMAL_LOGIN;

    showMessage("PASSWORD", "UPDATED!");

    beep(150);

    Serial.println("New password saved successfully.");

    delay(1500);

    showPasswordScreen();

  }

  else {

    enteredPassword = "";

    showMessage("SAVE ERROR", "Try again");

    beep(1000);

    delay(1500);

    passwordMode = NORMAL_LOGIN;
    showPasswordScreen();

    Serial.println("ERROR: Could not save password.");
  }
}

// ---------------- START ADMIN PASSWORD CHANGE ----------------

void startAdminPasswordChange() {

  passwordMode = SET_NEW_ADMIN;
  enteredPassword = "";

  showPasswordScreen();

  Serial.println("Admin password change requested.");
  Serial.println("Enter new admin password (4-8 digits).");
}


// ---------------- SAVE NEW ADMIN PASSWORD ----------------

void saveNewAdminPassword() {

  if (enteredPassword.length() < MIN_PASSWORD_LENGTH ||
      enteredPassword.length() > MAX_PASSWORD_LENGTH) {

    showMessage("INVALID!", "Use 4-8 digits");

    beep(500);
    delay(1200);

    enteredPassword = "";
    showPasswordScreen();

    return;
  }

  size_t saved = preferences.putString(
    "adminPass",
    enteredPassword
  );

  if (saved > 0) {

    adminPassword = enteredPassword;
    enteredPassword = "";

    passwordMode = NORMAL_LOGIN;
    rfidAdminMode = RFID_ADMIN_MENU;

    showMessage("ADMIN PASS", "UPDATED!");

    beep(150);

    Serial.println("Admin password updated successfully.");

    delay(1500);

    showRFIDAdminMenu();

  } else {

    enteredPassword = "";

    passwordMode = NORMAL_LOGIN;
    rfidAdminMode = RFID_ADMIN_MENU;

    showMessage("SAVE ERROR", "Try again");

    beep(1000);
    delay(1500);

    showRFIDAdminMenu();

    Serial.println("ERROR: Could not save admin password.");
  }
}

// ---------------- CORRECT LOGIN ----------------

void correctPasswordEntered() {

  unlocked = true;
  gateServo.write(GATE_OPEN_ANGLE);

  enteredPassword = "";

  display.clearDisplay();

  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(2);
  display.setCursor(10, 10);
  display.println("ACCESS");

  display.setCursor(10, 35);
  display.println("GRANTED!");

  display.display();

  beep(150);

  delay(1000);

  gateOpenedAt = millis();
  lastGateDisplayUpdate = 0;
}

// ---------------- GATE DISPLAY ----------------

void showGateStatus() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(18, 5);
  display.println("SMART GATE BARRIER");

  display.drawLine(0, 18, 128, 18, SSD1306_WHITE);

  display.setTextSize(2);
  if (unlocked) {
    display.setCursor(32, 29);
    display.println("OPEN");
    display.setTextSize(1);
    display.setCursor(12, 54);
    display.println("Press * to close");
  } else {
    display.setCursor(20, 29);
    display.println("CLOSED");
    display.setTextSize(1);
    display.setCursor(20, 54);
    display.println("System secured");
  }

  display.display();
}

// ---------------- RFID ACCESS FUNCTION ----------------

void checkRFID() {

  if (!rfid.PICC_IsNewCardPresent()) {
    return;
  }

  if (!rfid.PICC_ReadCardSerial()) {
    return;
  }

  String scannedUID = "";

  for (byte i = 0; i < rfid.uid.size; i++) {

    if (i > 0) {
      scannedUID += " ";
    }

    if (rfid.uid.uidByte[i] < 0x10) {
      scannedUID += "0";
    }

    scannedUID += String(rfid.uid.uidByte[i], HEX);
  }

  scannedUID.toUpperCase();

  Serial.print("RFID Card UID: ");
  Serial.println(scannedUID);

  // Registration mode
  if (rfidAdminMode == RFID_WAIT_ADD) {

    registerRFIDCard(scannedUID);
  }

  // Removal mode
  else if (rfidAdminMode == RFID_WAIT_REMOVE) {

    removeRFIDCard(scannedUID);
  }

  // Normal login mode
  else if (
    rfidAdminMode == RFID_ADMIN_OFF &&
    passwordMode == NORMAL_LOGIN
  ) {

    if (isRFIDRegistered(scannedUID)) {

      recordEvent("rfid_access", scannedUID, "granted");
      Serial.println("Authorized RFID Card!");

      showMessage("RFID ACCESS", "GRANTED!");

      beep(150);

      delay(1000);

      correctPasswordEntered();

    } else {

      recordEvent("rfid_access", scannedUID, "denied");
      Serial.println("Unauthorized RFID Card!");

      showMessage("ACCESS DENIED", "Invalid RFID Card");

      beep(1000);

      delay(1200);

      showPasswordScreen();
    }
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}


// ---------------- RFID MANAGEMENT MENU ----------------

// ---------------- RFID MANAGEMENT MENU ----------------

void showRFIDAdminMenu() {

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);

  display.setCursor(5, 3);
  display.println("RFID MANAGEMENT");

  display.drawLine(0, 15, 128, 15, SSD1306_WHITE);

  display.setCursor(5, 21);
  display.println("A: Register Card");

  display.setCursor(5, 32);
  display.println("B: Remove Card");

  display.setCursor(5, 43);
  display.println("C: Change Admin Pass");

  display.setCursor(5, 54);
  display.println("D: Exit");

  display.display();
}

// ---------------- RFID SCAN SCREEN ----------------

void showRFIDScanScreen(bool adding) {

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);

  display.setCursor(5, 5);
  display.println(adding ? "REGISTER NEW CARD" : "REMOVE RFID CARD");

  display.drawLine(0, 17, 128, 17, SSD1306_WHITE);

  display.setCursor(5, 28);
  display.println("Place your card");

  display.setCursor(5, 42);
  display.println("near RFID reader");

  display.setCursor(5, 55);
  display.println("Press B to cancel");

  display.display();
}

// ---------------- RFID SAVE FUNCTION ----------------

bool saveRFIDList() {

  size_t saved = preferences.putString(
    "rfids",
    registeredUIDs
  );

  return saved > 0;
}

// ---------------- CHECK REGISTERED CARD ----------------

bool isRFIDRegistered(String uid) {

  return registeredUIDs.indexOf("|" + uid + "|") >= 0;
}

// ---------------- REGISTER NEW CARD ----------------

void registerRFIDCard(String uid) {

  if (isRFIDRegistered(uid)) {

    showMessage("ALREADY", "Card Registered");

    Serial.println("This RFID card is already registered.");
    recordEvent("rfid_card_registered", uid, "already_registered");

    beep(500);

    delay(1500);

    rfidAdminMode = RFID_ADMIN_OFF;
    passwordMode = NORMAL_LOGIN;
    showPasswordScreen();

    return;
  }

  String oldList = registeredUIDs;

  registeredUIDs += uid + "|";

  if (saveRFIDList()) {

    showMessage("CARD", "REGISTERED!");

    Serial.println("New RFID card registered:");
    Serial.println(uid);
    recordEvent("rfid_card_registered", uid, "success");

    beep(150);

  } else {

    registeredUIDs = oldList;

    showMessage("SAVE ERROR", "Registration failed");

    beep(1000);

    Serial.println("Failed to save RFID card.");
  }

  delay(1500);

  rfidAdminMode = RFID_ADMIN_OFF;
  passwordMode = NORMAL_LOGIN;
  showPasswordScreen();
}

// ---------------- REMOVE REGISTERED CARD ----------------

void removeRFIDCard(String uid) {

  String token = "|" + uid + "|";

  int position = registeredUIDs.indexOf(token);

  if (position < 0) {

    showMessage("NOT FOUND", "Card Not Registered");

    Serial.println("RFID card is not registered.");

    beep(500);

    delay(1500);

    rfidAdminMode = RFID_ADMIN_MENU;

    showRFIDAdminMenu();

    return;
  }

  // Keep the separators intact.
  // Remove only the matching UID and preserve the remaining cards.
  String oldList = registeredUIDs;

  registeredUIDs =
    registeredUIDs.substring(0, position) +
    registeredUIDs.substring(position + token.length() - 1);

  Serial.println("Updated RFID List:");
  Serial.println(registeredUIDs);

  if (saveRFIDList()) {

    showMessage("CARD", "REMOVED!");

    Serial.println("RFID card removed successfully:");
    Serial.println(uid);
    recordEvent("rfid_card_removed", uid, "success");

    beep(150);

  } else {

    // Restore previous list if saving fails
    registeredUIDs = oldList;

    showMessage("SAVE ERROR", "Removal failed");

    beep(1000);

    Serial.println("Failed to save RFID list.");
  }

  delay(1500);

  rfidAdminMode = RFID_ADMIN_OFF;
  passwordMode = NORMAL_LOGIN;
  showPasswordScreen();
}



// ---------------- EVENT LOGGING ----------------

uint64_t currentUnixTime() {
  if (!deviceTimeSynced) return 0;
  return syncedUnixTime + ((millis() - syncedMillis) / 1000ULL);
}

void recordEvent(const char* type, const String& uid, const char* result) {
  DynamicJsonDocument doc(384);
  doc["id"] = eventSequence + 1;
  doc["type"] = type;
  doc["uid"] = uid;
  doc["result"] = result;
  doc["uptime_ms"] = millis();
  uint64_t epoch = currentUnixTime();
  doc["timestamp"] = epoch; // 0 means phone time has not yet been synchronized
  doc["timestamp_source"] = epoch > 0 ? "phone_sync" : "uptime_only";

  String payload;
  serializeJson(doc, payload);

  String key = "ev" + String(eventSequence % MAX_STORED_EVENTS);
  preferences.putString(key.c_str(), payload);

  eventSequence++;
  preferences.putUInt("eventSeq", eventSequence);
}

bool isAdminAuthorized() {
  if (adminSessionToken.length() == 0) return false;
  if ((long)(millis() - adminSessionExpiry) >= 0) {
    adminSessionToken = "";
    return false;
  }

  String header = server.header("Authorization");
  if (!header.startsWith("Bearer ")) return false;
  return header.substring(7) == adminSessionToken;
}

void sendJson(int statusCode, JsonDocument& doc) {
  String body;
  serializeJson(doc, body);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
  server.sendHeader("Cache-Control", "no-store");
  server.send(statusCode, "application/json", body);
}

void handleOptions() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
  server.send(204);
}

void sendError(int statusCode, const char* message) {
  DynamicJsonDocument doc(192);
  doc["ok"] = false;
  doc["error"] = message;
  sendJson(statusCode, doc);
}

void requireAdminOrReject() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
  }
}

void handleApiStatus() {
  DynamicJsonDocument doc(512);
  doc["ok"] = true;
  doc["device"] = "ESP32_DOOR_LOCK";
  doc["locked"] = !unlocked;
  doc["unlocked"] = unlocked;
  doc["wifi_mode"] = "access_point";
  doc["ssid"] = AP_SSID;
  doc["ip"] = WiFi.softAPIP().toString();
  doc["connected_clients"] = WiFi.softAPgetStationNum();
  doc["uptime_ms"] = millis();
  doc["time_synced"] = deviceTimeSynced;
  doc["registration_waiting"] = (rfidAdminMode == RFID_WAIT_ADD);
  sendJson(200, doc);
}

// Kept at /api/sensors so the existing API route remains available.
// DHT11 data has been removed; this endpoint now reports gate status.
void handleApiSensors() {
  DynamicJsonDocument doc(256);
  doc["ok"] = true;
  doc["gate_open"] = unlocked;
  doc["gate_closed"] = !unlocked;
  doc["servo_angle"] = unlocked ? GATE_OPEN_ANGLE : GATE_CLOSED_ANGLE;
  doc["timestamp"] = currentUnixTime();
  doc["uptime_ms"] = millis();
  sendJson(200, doc);
}

// ---------------- GATE CONTROL API ----------------

void handleApiGateOpen() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  unlocked = true;
  gateServo.write(GATE_OPEN_ANGLE);
  gateOpenedAt = millis();
  showGateStatus();
  recordEvent("gate_control", "", "opened_by_app");

  DynamicJsonDocument doc(192);
  doc["ok"] = true;
  doc["gate_open"] = true;
  doc["servo_angle"] = GATE_OPEN_ANGLE;
  doc["message"] = "Gate opened";
  sendJson(200, doc);
}

void handleApiGateClose() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  unlocked = false;
  gateServo.write(GATE_CLOSED_ANGLE);
  enteredPassword = "";
  passwordMode = NORMAL_LOGIN;
  rfidAdminMode = RFID_ADMIN_OFF;
  showGateStatus();
  recordEvent("gate_control", "", "closed_by_app");

  DynamicJsonDocument doc(192);
  doc["ok"] = true;
  doc["gate_open"] = false;
  doc["servo_angle"] = GATE_CLOSED_ANGLE;
  doc["message"] = "Gate closed";
  sendJson(200, doc);
}

void handleApiCards() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  DynamicJsonDocument doc(1536);
  doc["ok"] = true;
  JsonArray cards = doc.createNestedArray("cards");

  int start = 0;
  while (start < registeredUIDs.length()) {
    int first = registeredUIDs.indexOf('|', start);
    if (first < 0) break;
    int next = registeredUIDs.indexOf('|', first + 1);
    if (next < 0) break;
    if (next > first + 1) {
      String uid = registeredUIDs.substring(first + 1, next);
      cards.add(uid);
    }
    start = next;
  }

  sendJson(200, doc);
}

void handleApiEvents() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  DynamicJsonDocument doc(4096);
  doc["ok"] = true;
  JsonArray events = doc.createNestedArray("events");

  uint32_t available = eventSequence < MAX_STORED_EVENTS
                         ? eventSequence
                         : MAX_STORED_EVENTS;

  for (uint32_t i = 0; i < available; i++) {
    uint32_t sequence = eventSequence - 1 - i;
    String key = "ev" + String(sequence % MAX_STORED_EVENTS);
    String stored = preferences.getString(key.c_str(), "");
    if (stored.length() > 0) {
      DynamicJsonDocument item(384);
      DeserializationError error = deserializeJson(item, stored);
      if (!error) {
        events.add(item.as<JsonObject>());
      }
    }
  }

  doc["count"] = events.size();
  doc["total_events_recorded"] = eventSequence;
  sendJson(200, doc);
}

void handleApiAdminLogin() {
  DynamicJsonDocument request(256);
  DeserializationError error = deserializeJson(request, server.arg("plain"));
  if (error || !request["password"].is<const char*>()) {
    sendError(400, "JSON body must contain password");
    return;
  }

  String suppliedPassword = request["password"].as<String>();
  if (suppliedPassword != adminPassword) {
    recordEvent("admin_login", "", "failed");
    sendError(401, "Invalid admin password");
    return;
  }

  char tokenBuffer[33];
  snprintf(tokenBuffer, sizeof(tokenBuffer), "%08lx%08lx%08lx%08lx",
           (unsigned long)esp_random(), (unsigned long)esp_random(),
           (unsigned long)esp_random(), (unsigned long)esp_random());
  adminSessionToken = String(tokenBuffer);
  adminSessionExpiry = millis() + ADMIN_SESSION_DURATION;

  recordEvent("admin_login", "", "success");

  DynamicJsonDocument response(256);
  response["ok"] = true;
  response["token"] = adminSessionToken;
  response["expires_in_seconds"] = ADMIN_SESSION_DURATION / 1000UL;
  sendJson(200, response);
}

void handleApiAdminLogout() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }
  adminSessionToken = "";
  recordEvent("admin_logout", "", "success");
  DynamicJsonDocument doc(128);
  doc["ok"] = true;
  doc["message"] = "Logged out";
  sendJson(200, doc);
}

void handleApiTimeSync() {
  DynamicJsonDocument request(256);
  DeserializationError error = deserializeJson(request, server.arg("plain"));
  if (error || !request["epoch"].is<uint64_t>()) {
    sendError(400, "JSON body must contain epoch as Unix seconds");
    return;
  }

  syncedUnixTime = request["epoch"].as<uint64_t>();
  syncedMillis = millis();
  deviceTimeSynced = syncedUnixTime > 1700000000ULL;

  DynamicJsonDocument doc(192);
  doc["ok"] = deviceTimeSynced;
  doc["timestamp"] = currentUnixTime();
  sendJson(deviceTimeSynced ? 200 : 400, doc);
}

void handleApiStartRegistration() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  // Ensure gate barrier is lowered/secured before registration
  if (unlocked) {
    unlocked = false;
    gateServo.write(GATE_CLOSED_ANGLE);
  }

  passwordMode = NORMAL_LOGIN;
  rfidAdminMode = RFID_WAIT_ADD;
  showRFIDScanScreen(true);

  DynamicJsonDocument doc(192);
  doc["ok"] = true;
  doc["status"] = "waiting_for_card";
  doc["message"] = "Present a card to the RC522 reader";
  sendJson(200, doc);
}

void handleApiCancelRegistration() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  rfidAdminMode = RFID_ADMIN_OFF;
  passwordMode = NORMAL_LOGIN;
  showPasswordScreen();

  DynamicJsonDocument doc(128);
  doc["ok"] = true;
  doc["message"] = "Registration mode cancelled";
  sendJson(200, doc);
}

void handleApiRemoveCard() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }
  if (unlocked) {
    sendError(409, "Lock the device before managing cards");
    return;
  }

  DynamicJsonDocument request(256);
  DeserializationError error = deserializeJson(request, server.arg("plain"));
  if (error || !request["uid"].is<const char*>()) {
    sendError(400, "JSON body must contain uid");
    return;
  }

  String uid = request["uid"].as<String>();
  uid.trim();
  uid.toUpperCase();

  if (!isRFIDRegistered(uid)) {
    sendError(404, "RFID card not registered");
    return;
  }

  removeRFIDCard(uid);

  DynamicJsonDocument doc(192);
  doc["ok"] = true;
  doc["uid"] = uid;
  doc["message"] = "Card removal processed";
  sendJson(200, doc);
}

void handleApiChangeAdminPassword() {
  if (!isAdminAuthorized()) {
    sendError(401, "Admin login required or session expired");
    return;
  }

  DynamicJsonDocument request(256);
  DeserializationError error = deserializeJson(request, server.arg("plain"));
  if (error || !request["newPassword"].is<const char*>()) {
    sendError(400, "JSON body must contain newPassword");
    return;
  }

  String newPassword = request["newPassword"].as<String>();
  if (newPassword.length() < MIN_PASSWORD_LENGTH ||
      newPassword.length() > MAX_PASSWORD_LENGTH) {
    sendError(400, "Password must contain 4 to 8 digits");
    return;
  }

  for (size_t i = 0; i < newPassword.length(); i++) {
    if (!isDigit(newPassword[i])) {
      sendError(400, "Password must contain digits only");
      return;
    }
  }

  if (preferences.putString("adminPass", newPassword) == 0) {
    sendError(500, "Could not save admin password");
    return;
  }

  adminPassword = newPassword;
  recordEvent("admin_password_changed", "", "success");

  DynamicJsonDocument doc(128);
  doc["ok"] = true;
  doc["message"] = "Admin password updated";
  sendJson(200, doc);
}

void handleApiNotFound() {
  sendError(404, "API endpoint not found");
}

void startWiFiHotspotAndApi() {
  WiFi.mode(WIFI_AP);
  bool started = WiFi.softAP(AP_SSID, AP_PASSWORD);

  if (!started) {
    Serial.println("ERROR: Could not start ESP32 hotspot");
    return;
  }

  Serial.println("ESP32 hotspot started");
  Serial.print("SSID: ");
  Serial.println(AP_SSID);
  Serial.print("IP address: ");
  Serial.println(WiFi.softAPIP());

  server.collectHeaders(requestHeaders, 1);

  server.on("/api/status", HTTP_GET, handleApiStatus);
  server.on("/api/sensors", HTTP_GET, handleApiSensors);
  server.on("/api/gate/open", HTTP_POST, handleApiGateOpen);
  server.on("/api/gate/close", HTTP_POST, handleApiGateClose);
  server.on("/api/rfid/cards", HTTP_GET, handleApiCards);
  server.on("/api/events", HTTP_GET, handleApiEvents);
  server.on("/api/admin/login", HTTP_POST, handleApiAdminLogin);
  server.on("/api/admin/logout", HTTP_POST, handleApiAdminLogout);
  server.on("/api/admin/change-password", HTTP_POST, handleApiChangeAdminPassword);
  server.on("/api/time-sync", HTTP_POST, handleApiTimeSync);
  server.on("/api/rfid/register", HTTP_POST, handleApiStartRegistration);
  server.on("/api/rfid/cancel", HTTP_POST, handleApiCancelRegistration);
  server.on("/api/rfid/remove", HTTP_POST, handleApiRemoveCard);
  server.onNotFound([]() {
    if (server.method() == HTTP_OPTIONS) {
      handleOptions();
    } else {
      handleApiNotFound();
    }
  });

  server.begin();
  Serial.println("HTTP API server started on port 80");
}


// ---------------- SETUP ----------------

void setup() {

  Serial.begin(115200);

  // Buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // OLED initialization
  Wire.begin(OLED_SDA, OLED_SCL);

  if (!display.begin(
        SSD1306_SWITCHCAPVCC,
        OLED_ADDRESS
      )) {

    Serial.println("OLED initialization failed!");

    while (true) {
      delay(100);
    }
  }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // Servo initialization. The servo must use a separate suitable 5V supply.
  gateServo.setPeriodHertz(50);
  gateServo.attach(SERVO_PIN, 500, 2400);
  gateServo.write(GATE_CLOSED_ANGLE);
  unlocked = false;

  // RFID initialization
  SPI.begin(
    RFID_SCK_PIN,
    RFID_MISO_PIN,
    RFID_MOSI_PIN,
    RFID_SS_PIN
  );

  rfid.PCD_Init();

  Serial.println("RFID Reader Initialized");

  // Load saved password from ESP32 memory
  if (!preferences.begin("doorlock", false)) {

    Serial.println("Preferences initialization failed!");

    showMessage("MEMORY ERROR", "Restart device");

    while (true) {
      delay(100);
    }
  }
  // preferences.remove("rfids");

  // Load registered RFID cards
registeredUIDs = preferences.getString("rfids", "|");

if (registeredUIDs.length() == 0) {
  registeredUIDs = "|";
}

Serial.println("Registered RFID cards loaded.");

  correctPassword = preferences.getString(
    "password",
    "1234"
  );
  adminPassword = preferences.getString(
  "adminPass",
  "987654"
);

  Serial.println("Saved password loaded.");

  eventSequence = preferences.getUInt("eventSeq", 0);

  // Start local Wi-Fi hotspot and REST API after Preferences is ready.
  startWiFiHotspotAndApi();

  // Startup screen
  display.setTextSize(2);
  display.setCursor(10, 15);
  display.println("ESP32");

  display.setTextSize(1);
  display.setCursor(10, 42);
  display.println("Password Security");

  display.display();

  delay(2000);

  showPasswordScreen();

  Serial.println("System Started Successfully");
}

// ---------------- MAIN LOOP ----------------

void loop() {

  // Keep the local HTTP API responsive.
  server.handleClient();

  // Automatically close the gate 5 seconds after it was opened.
  // This applies to keypad, RFID, and Flutter-app opening commands.
  if (unlocked && (millis() - gateOpenedAt >= GATE_AUTO_CLOSE_MS)) {
    unlocked = false;
    gateServo.write(GATE_CLOSED_ANGLE);
    enteredPassword = "";
    passwordMode = NORMAL_LOGIN;
    rfidAdminMode = RFID_ADMIN_OFF;
    showGateStatus();
    recordEvent("gate_control", "", "auto_closed_after_5_seconds");
    Serial.println("Gate automatically closed after 5 seconds.");
  }

  char key = keypad.getKey();

  // RFID scanning during normal login or card management
if (
  !unlocked &&
  (
    (passwordMode == NORMAL_LOGIN &&
     rfidAdminMode == RFID_ADMIN_OFF) ||
    rfidAdminMode == RFID_WAIT_ADD ||
    rfidAdminMode == RFID_WAIT_REMOVE
  )
) {
  checkRFID();
}

  // ---------------- LOCKED MODE ----------------

  if (!unlocked) {
    // ---------------- ADMIN PASSWORD CHANGE MODE ----------------

if (passwordMode == SET_NEW_ADMIN) {

  if (key == 'B') {

    enteredPassword = "";

    passwordMode = NORMAL_LOGIN;
    rfidAdminMode = RFID_ADMIN_MENU;

    showMessage("CANCELLED", "Admin pass unchanged");

    beep(150);
    delay(1200);

    showRFIDAdminMenu();

    Serial.println("Admin password change cancelled.");

    return;
  }

  if (key == '*' || key == 'C') {

    enteredPassword = "";

    showPasswordScreen();

    return;
  }

  if (key == '#') {

    saveNewAdminPassword();

    return;
  }

  if (key >= '0' && key <= '9') {

    if (enteredPassword.length() < MAX_PASSWORD_LENGTH) {

      enteredPassword += key;

      showPasswordScreen();
    }

    return;
  }

  return;
}

// ---------------- RFID MANAGEMENT MENU ----------------

if (rfidAdminMode == RFID_ADMIN_MENU) {

  if (key == 'A') {

    rfidAdminMode = RFID_WAIT_ADD;

    showRFIDScanScreen(true);

    Serial.println("Scan a new RFID card to register.");
  }

  else if (key == 'B') {

    rfidAdminMode = RFID_WAIT_REMOVE;

    showRFIDScanScreen(false);

    Serial.println("Scan an RFID card to remove.");
  }

  else if (key == 'C') {

    rfidAdminMode = RFID_ADMIN_OFF;

    startAdminPasswordChange();
  }

  else if (key == 'D') {

    rfidAdminMode = RFID_ADMIN_OFF;

    passwordMode = NORMAL_LOGIN;
    enteredPassword = "";

    showPasswordScreen();

    Serial.println("RFID management closed.");
  }

  return;
}

// Cancel card registration or removal
if (
  (rfidAdminMode == RFID_WAIT_ADD ||
   rfidAdminMode == RFID_WAIT_REMOVE) &&
  key == 'B'
) {

  rfidAdminMode = RFID_ADMIN_MENU;

  showRFIDAdminMenu();

  Serial.println("RFID operation cancelled.");

  return;
}

    if (key) {

      Serial.print("Key Pressed: ");
      Serial.println(key);

      // Cancel password change
      if (key == 'B' &&
          passwordMode != NORMAL_LOGIN) {

        cancelPasswordChange();
        return;
      }

      // Start password change
      if (key == 'A' &&
          passwordMode == NORMAL_LOGIN) {

        startPasswordChange();
        return;
      }

      // Clear entered password
      if (key == '*' || key == 'C') {

        enteredPassword = "";

        showPasswordScreen();
        return;
      }

      // Open RFID management after pressing D
if (key == 'D' &&
    passwordMode == NORMAL_LOGIN &&
    rfidAdminMode == RFID_ADMIN_OFF) {

  enteredPassword = "";

  passwordMode = VERIFY_RFID_ADMIN;

  showPasswordScreen();

  Serial.println("Enter current password for RFID management.");

  return;
}

      // Submit entered password
      if (key == '#') {

        if (passwordMode == NORMAL_LOGIN) {

          if (enteredPassword == correctPassword) {

            correctPasswordEntered();

          } else {

            wrongPassword();
          }

        }

        else if (passwordMode == VERIFY_CURRENT) {

          verifyCurrentPassword();

        }

        else if (passwordMode == SET_NEW) {

          saveNewPassword();

        }

        else if (passwordMode == VERIFY_RFID_ADMIN) {

  if (enteredPassword == adminPassword) {

    enteredPassword = "";

    passwordMode = NORMAL_LOGIN;

    rfidAdminMode = RFID_ADMIN_MENU;

    showRFIDAdminMenu();

    beep(150);

    Serial.println("RFID management authorized.");
    recordEvent("admin_login_keypad", "", "success");

  } else {

    wrongPassword();

    rfidAdminMode = RFID_ADMIN_OFF;
  }
}

        return;
      }

      // Accept numeric keys only
      if (key >= '0' && key <= '9') {

        if (enteredPassword.length() < MAX_PASSWORD_LENGTH) {

          enteredPassword += key;

          showPasswordScreen();
        }
      }
    }
  }

  // ---------------- UNLOCKED MODE ----------------

  else {

    // Press * to lock again
    if (key == '*') {

      unlocked = false;
      gateServo.write(GATE_CLOSED_ANGLE);

      enteredPassword = "";
      passwordMode = NORMAL_LOGIN;

      showPasswordScreen();

      Serial.println("System Locked. Gate closed.");

      return;
    }

    // Refresh gate status on the OLED every 2 seconds.
    if (millis() - lastGateDisplayUpdate >= 2000) {
      lastGateDisplayUpdate = millis();
      showGateStatus();
    }
  }
}
