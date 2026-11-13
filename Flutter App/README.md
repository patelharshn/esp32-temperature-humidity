# ESP32 Smart Door Lock – Mobile Flutter Application

A modern IoT mobile application for Android and iOS engineered to communicate directly with the **ESP32 Smart Door Lock** through its own standalone Wi-Fi hotspot (`ESP32_DOOR_LOCK`) without requiring an external router or internet connection.

---

## 1. System Architecture & Overview

The application is built using Flutter 3 (Dart 3) following Clean Architecture principles:

```
lib/
├── core/
│   ├── config/
│   │   └── api_config.dart          # Centralized API URLs, endpoints, timeouts, and hotspot credentials
│   ├── network/
│   │   ├── api_client.dart          # Dio-based HTTP client, auth interceptor, session expiration handler
│   │   └── api_exceptions.dart      # Strongly-typed exceptions for timeouts, 401, 404, 409 errors
│   ├── theme/
│   │   ├── app_colors.dart          # OLED Dark & Light palette, lock status colors, sensor accents
│   │   └── app_theme.dart           # Material 3 typography, cards, buttons, input fields
│   └── utils/
│       ├── date_formatter.dart      # Unix epoch calendar formatting & ESP32 uptime breakdown
│       └── helpers.dart             # Card UID formatting, heat index computation, SnackBar helpers
├── models/
│   ├── device_status.dart           # GET /api/status model
│   ├── sensor_data.dart             # GET /api/sensors model
│   ├── door_event.dart              # GET /api/events model (distinguishes phone_sync vs uptime_only)
│   ├── rfid_card.dart               # RFID Card model with local nickname support
│   └── admin_session.dart           # Bearer token and 30-minute expiry session tracker
├── services/
│   ├── api_service.dart             # Direct ESP32 REST API service
│   ├── storage_service.dart         # SharedPreferences for tokens, cached events, nicknames, settings
│   └── location_service.dart        # Geolocation service for phone GPS tagging
├── repositories/
│   ├── device_repository.dart       # Device status, latency, sensor polling & time synchronization
│   ├── auth_repository.dart         # Admin login, logout, password change & session persistence
│   └── rfid_repository.dart         # RFID cards, card removal, registration polling & event caching
├── providers/
│   ├── connection_provider.dart     # Hotspot connection state, latency, IP updates, time sync
│   ├── auth_provider.dart           # Admin login state, session timeout, password alteration
│   ├── dashboard_provider.dart      # Auto-refresh loop (2.5s), lock state, sensors, activity
│   ├── rfid_provider.dart           # 7-step RFID card enrollment, deletion & label management
│   ├── sensor_provider.dart         # Real-time DHT11 polling, °C/°F toggle, real statistics
│   ├── activity_provider.dart       # Search, filter (type/result), sort, and audit log exploration
│   └── settings_provider.dart       # Theme mode, door installation location & phone GPS capture
├── features/
│   ├── splash/                      # Splash Screen with silent probe
│   ├── connection/                  # ESP32 Hotspot setup guide, IP config, diagnostics
│   ├── authentication/              # Admin Login screen (POST /api/admin/login)
│   ├── dashboard/                   # Live IoT Dashboard with door lock badge, sensors, quick actions
│   ├── activity/                    # RFID Activity screen, filters, search & detail sheet
│   ├── rfid/                        # Registered cards list & interactive registration sheet
│   ├── sensors/                     # Sensor Monitor with fl_chart historical trend (actual samples only)
│   └── settings/                    # Settings & Admin Security Profile screen
└── widgets/                         # Reusable UI widgets (LivePulseIndicator, CustomButton, etc.)
```

---

## 2. ESP32 Firmware REST API Endpoints

All endpoints are centralized in [`lib/core/config/api_config.dart`](file:///d:/ESP32%20DHT11%20APP/lib/core/config/api_config.dart):

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| `GET` | `/api/status` | No | Retrieves lock state (`locked`/`unlocked`), Wi-Fi AP clients, uptime, time sync status, registration mode |
| `GET` | `/api/sensors` | No | Retrieves DHT11 temperature in °C, humidity %, validity flag, and timestamp |
| `POST` | `/api/time-sync` | No | Synchronizes ESP32 clock with current Unix epoch (`{"epoch": 1794300000}`) |
| `POST` | `/api/admin/login` | No | Validates admin password (`{"password": "..."}`) and issues 30-min Bearer token |
| `POST` | `/api/admin/logout` | `Bearer <token>` | Invalidates active admin session on ESP32 |
| `POST` | `/api/admin/change-password` | `Bearer <token>` | Updates master admin password (4-8 digits) in ESP32 Preferences |
| `GET` | `/api/rfid/cards` | `Bearer <token>` | Returns array of all registered RFID card UIDs |
| `GET` | `/api/events` | `Bearer <token>` | Returns ring buffer of recent access and admin events |
| `POST` | `/api/rfid/register` | `Bearer <token>` | Puts ESP32 RC522 reader into card enrollment mode |
| `POST` | `/api/rfid/remove` | `Bearer <token>` | Revokes an RFID card UID (`{"uid": "..."}`) |

---

## 3. Firmware Capabilities Audit

Based on inspection of `esp32_temp_hum.ino`:

### Supported Features:
- **Direct Hotspot Communication**: ESP32 runs `WiFi.softAP("ESP32_DOOR_LOCK", "12345678")` at default IP `192.168.4.1`.
- **Live DHT11 Monitoring**: Returns raw temperature and humidity every request.
- **Hardware-Managed RFID Enrollment & Deletion**: ESP32 performs actual RC522 card scanning, storage in `Preferences` ("rfids" key), and UID validation.
- **Clock Calibration**: Syncs Unix epoch via `/api/time-sync` and calculates relative calendar timestamps.
- **Security Audit Ring Buffer**: Stores up to 20 events in NVS memory; the Flutter app caches historical events locally so older events are not lost.
- **Admin Session Token**: Issues a 32-character hexadecimal token with 30-minute validity.

### Firmware Limitations (Not Supported by Firmware):
- **Remote Unlock via REST API**: The firmware does not have a `POST /api/unlock` endpoint. Unlocking is strictly performed on physical hardware (keypad password entry or physical RFID card scan) for physical safety. The app displays real-time door lock status (`LOCKED` or `UNLOCKED`).
- **On-board GPS**: The ESP32 dev board does not have a satellite GPS receiver. The app provides a dedicated feature to record the **smartphone's GPS position** at the moment of installation, clearly identified as the phone's location.

---

## 4. Mobile Platform Permissions & Cleartext Configuration

### Android:
- Configured in [`android/app/src/main/AndroidManifest.xml`](file:///d:/ESP32%20DHT11%20APP/android/app/src/main/AndroidManifest.xml) and [`android/app/src/main/res/xml/network_security_config.xml`](file:///d:/ESP32%20DHT11%20APP/android/app/src/main/res/xml/network_security_config.xml).
- Includes:
  - `INTERNET`
  - `ACCESS_NETWORK_STATE`
  - `ACCESS_WIFI_STATE`
  - `CHANGE_WIFI_STATE`
  - `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` (for phone GPS door tagging)
  - `NEARBY_WIFI_DEVICES` (Android 13+ / API 33+)
- Cleartext HTTP traffic is explicitly scoped to `192.168.4.1`, `localhost`, and development subnets.

### iOS:
- Configured in [`ios/Runner/Info.plist`](file:///d:/ESP32%20DHT11%20APP/ios/Runner/Info.plist).
- Includes:
  - `NSLocalNetworkUsageDescription`: Informs users that local network access is needed to connect to the ESP32 Door Lock hotspot.
  - `NSLocationWhenInUseUsageDescription`: Discloses that location is used optionally for tagging door installation.
  - `NSAppTransportSecurity`: Scoped cleartext exception specifically for domain `192.168.4.1` and `NSAllowsLocalNetworking: true`.

---

## 5. Getting Started & Installation

### Prerequisites:
- Flutter SDK 3.19+ (tested on Flutter 3.44.8 / Dart 3.12.2)
- Android Studio / Xcode (for device deployment)

### Setup:
1. Open terminal in the project directory:
   ```bash
   cd "D:\ESP32 DHT11 APP"
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run the static analyzer:
   ```bash
   flutter analyze
   ```

4. Run unit and widget test suite:
   ```bash
   flutter test
   ```

5. Run on connected Android / iOS device:
   ```bash
   flutter run
   ```

---

## 6. Wi-Fi Hotspot Connection & Offline Troubleshooting Guide

1. **Power the ESP32**: Ensure the ESP32 door lock system is powered on and displaying the welcome screen on its OLED display.
2. **Open Wi-Fi Settings**: On your iPhone or Android phone, navigate to Wi-Fi settings.
3. **Connect to Hotspot**:
   - SSID: `ESP32_DOOR_LOCK`
   - Password: `12345678`
4. **Handle "No Internet Access" Notification**:
   - Because the ESP32 is an offline access point, your phone operating system will detect that it has no internet connectivity and may prompt: *"This network has no internet access. Stay connected?"*
   - Select **"Yes"** or **"Always connect"**.
5. **Mobile Data Routing**:
   - On some Android devices, the OS automatically routes HTTP requests through cellular data if the active Wi-Fi has no internet.
   - If the app shows a connection timeout, temporarily turn off **Mobile Data** in Quick Settings.
6. **Launch App**: Open the app and tap **"Test & Connect to ESP32"**. The app will immediately verify `/api/status`, measure ping latency, synchronize the calendar clock, and open the live dashboard.
