import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_door_lock/core/config/api_config.dart';
import 'package:esp32_door_lock/core/utils/date_formatter.dart';
import 'package:esp32_door_lock/models/admin_session.dart';
import 'package:esp32_door_lock/models/device_status.dart';
import 'package:esp32_door_lock/models/door_event.dart';
import 'package:esp32_door_lock/models/rfid_card.dart';
import 'package:esp32_door_lock/models/sensor_data.dart';

void main() {
  group('ESP32 API & Model Verification', () {
    test('DeviceStatus matches /api/status ESP32 payload', () {
      final json = {
        "ok": true,
        "device": "ESP32_DOOR_LOCK",
        "locked": true,
        "unlocked": false,
        "wifi_mode": "access_point",
        "ssid": "ESP32_DOOR_LOCK",
        "ip": "192.168.4.1",
        "connected_clients": 1,
        "uptime_ms": 150000,
        "time_synced": true,
        "registration_waiting": false
      };

      final status = DeviceStatus.fromJson(json);

      expect(status.ok, isTrue);
      expect(status.device, equals('ESP32_DOOR_LOCK'));
      expect(status.locked, isTrue);
      expect(status.unlocked, isFalse);
      expect(status.isDoorLocked, isTrue);
      expect(status.ip, equals('192.168.4.1'));
      expect(status.connectedClients, equals(1));
      expect(status.timeSynced, isTrue);
      expect(status.registrationWaiting, isFalse);
      expect(status.formattedUptime, equals('2m 30s'));
    });

    test('SensorData correctly handles valid readings from /api/sensors', () {
      final json = {
        "ok": true,
        "temperature_c": 28.5,
        "humidity_percent": 65.0,
        "valid": true,
        "timestamp": 1794300050,
        "uptime_ms": 124500
      };

      final data = SensorData.fromJson(json);

      expect(data.ok, isTrue);
      expect(data.valid, isTrue);
      expect(data.temperatureC, equals(28.5));
      expect(data.humidityPercent, equals(65.0));
      expect(data.displayTemperature(), equals('28.5°C'));
      expect(data.displayHumidity(), equals('65.0%'));
      expect(data.temperatureF, closeTo(83.3, 0.1));
    });

    test('SensorData correctly handles invalid (-999.0 / -1.0) readings', () {
      final json = {
        "ok": true,
        "temperature_c": -999.0,
        "humidity_percent": -1.0,
        "valid": false,
        "timestamp": 0,
        "uptime_ms": 12000
      };

      final data = SensorData.fromJson(json);

      expect(data.valid, isFalse);
      expect(data.displayTemperature(), equals('--'));
      expect(data.displayHumidity(), equals('--'));
    });

    test('DoorEvent distinguishes synchronized vs uptime-only events', () {
      final syncedJson = {
        "id": 1,
        "type": "rfid_access",
        "uid": "1A 2B 3C 4D",
        "result": "granted",
        "uptime_ms": 45000,
        "timestamp": 1794300000,
        "timestamp_source": "phone_sync"
      };

      final unsyncedJson = {
        "id": 2,
        "type": "password_attempt",
        "uid": "",
        "result": "denied",
        "uptime_ms": 12000,
        "timestamp": 0,
        "timestamp_source": "uptime_only"
      };

      final syncedEvent = DoorEvent.fromJson(syncedJson);
      final unsyncedEvent = DoorEvent.fromJson(unsyncedJson);

      expect(syncedEvent.isCalendarTimeSynced, isTrue);
      expect(syncedEvent.isAccessGranted, isTrue);
      expect(syncedEvent.isDenied, isFalse);
      expect(syncedEvent.displayTitle, equals('RFID Access Granted'));

      expect(unsyncedEvent.isCalendarTimeSynced, isFalse);
      expect(unsyncedEvent.isAccessGranted, isFalse);
      expect(unsyncedEvent.isDenied, isTrue);
      expect(unsyncedEvent.displayTime, contains('No Clock Sync'));
    });

    test('AdminSession expiration calculation', () {
      final session = AdminSession(
        token: 'abcdef1234567890abcdef1234567890',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );

      expect(session.isExpired, isFalse);
      expect(session.remainingSeconds, greaterThan(1700));

      final expiredSession = AdminSession(
        token: 'token',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.remainingSeconds, equals(0));
    });

    test('RfidCard format and label verification', () {
      final card = RfidCard(uid: '1a2b3c4d', label: 'Master Key');

      expect(card.formattedUid, equals('1A 2B 3C 4D'));
      expect(card.displayName, equals('Master Key'));
      expect(card.hasCustomLabel, isTrue);
    });

    test('ApiConfig endpoint constants verification', () {
      expect(ApiConfig.statusEndpoint, equals('/api/status'));
      expect(ApiConfig.sensorsEndpoint, equals('/api/sensors'));
      expect(ApiConfig.adminLoginEndpoint, equals('/api/admin/login'));
      expect(ApiConfig.rfidCardsEndpoint, equals('/api/rfid/cards'));
      expect(ApiConfig.eventsEndpoint, equals('/api/events'));
      expect(ApiConfig.timeSyncEndpoint, equals('/api/time-sync'));
      expect(ApiConfig.rfidRegisterEndpoint, equals('/api/rfid/register'));
      expect(ApiConfig.rfidRemoveEndpoint, equals('/api/rfid/remove'));

      expect(
        ApiConfig.buildUrl('http://192.168.4.1/', '/api/status'),
        equals('http://192.168.4.1/api/status'),
      );
    });

    test('DateFormatter uptime formatting test', () {
      expect(DateFormatter.formatUptime(0), equals('0s'));
      expect(DateFormatter.formatUptime(45000), equals('45s'));
      expect(DateFormatter.formatUptime(125000), equals('2m 5s'));
      expect(DateFormatter.formatUptime(3665000), equals('1h 1m 5s'));
    });
  });
}
