
#include <Wire.h>
#include <Keypad.h>
#include <DHT.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>

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

// ---------------- DHT11 SETTINGS ----------------

#define DHTPIN 32
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// ---------------- BUZZER ----------------

#define BUZZER_PIN 27

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

// ---------------- PASSWORD SETTINGS ----------------

Preferences preferences;

String correctPassword = "1234";
String enteredPassword = "";

const byte MIN_PASSWORD_LENGTH = 4;
const byte MAX_PASSWORD_LENGTH = 8;

bool unlocked = false;

// Password operation modes
enum PasswordMode {
  NORMAL_LOGIN,
  VERIFY_CURRENT,
  SET_NEW
};

PasswordMode passwordMode = NORMAL_LOGIN;

unsigned long lastSensorRead = 0;

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

  beep(1000);

  enteredPassword = "";
  passwordMode = NORMAL_LOGIN;

  delay(1000);

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

// ---------------- CORRECT LOGIN ----------------

void correctPasswordEntered() {

  unlocked = true;

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

  lastSensorRead = 0;
}

// ---------------- SENSOR DISPLAY ----------------

void showSensorData() {

  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  display.clearDisplay();

  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(15, 2);
  display.println("ACCESS GRANTED");

  display.drawLine(0, 15, 128, 15, SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(5, 23);
  display.println("Temperature:");

  display.setTextSize(2);
  display.setCursor(5, 34);

  if (isnan(temperature)) {
    display.println("Sensor Error");
  } else {
    display.print(temperature, 1);
    display.print(" C");
  }

  display.setTextSize(1);
  display.setCursor(5, 52);
  display.print("Humidity: ");

  if (isnan(humidity)) {
    display.print("Error");
  } else {
    display.print(humidity, 1);
    display.print("%");
  }

  display.display();
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

  // DHT11 initialization
  dht.begin();

  // Load saved password from ESP32 memory
  if (!preferences.begin("doorlock", false)) {

    Serial.println("Preferences initialization failed!");

    showMessage("MEMORY ERROR", "Restart device");

    while (true) {
      delay(100);
    }
  }

  correctPassword = preferences.getString(
    "password",
    "1234"
  );

  Serial.println("Saved password loaded.");

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

  char key = keypad.getKey();

  // ---------------- LOCKED MODE ----------------

  if (!unlocked) {

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

      enteredPassword = "";
      passwordMode = NORMAL_LOGIN;

      showPasswordScreen();

      Serial.println("System Locked.");

      return;
    }

    // Update sensor readings every 2 seconds
    if (millis() - lastSensorRead >= 2000) {

      lastSensorRead = millis();

      showSensorData();
    }
  }
}
