import 'dart:async';
import 'dart:convert';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/admin_session.dart';
import '../models/device_status.dart';
import '../models/door_event.dart';
import '../models/sensor_data.dart';

class ApiService {
  final ApiClient _client;

  ApiService(this._client);

  ApiClient get client => _client;

  /// Helper to safely extract a JSON Map whether Dio delivered a Map, String, or raw buffer
  Map<String, dynamic> _parseMap(dynamic data) {
    if (data == null) {
      throw ApiException('Empty response received from ESP32');
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      final clean = data.trim();
      if (clean.isEmpty) {
        throw ApiException('Empty body from ESP32');
      }
      final decoded = jsonDecode(clean);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw ApiException('Expected JSON object from ESP32, got: ${data.runtimeType}');
  }

  /// Pings the ESP32 status endpoint and returns round-trip latency in milliseconds
  Future<int> ping() async {
    final stopwatch = Stopwatch()..start();
    await _client.get(ApiConfig.statusEndpoint);
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  /// Fetches system and door status from GET /api/status
  Future<DeviceStatus> getStatus() async {
    final response = await _client.get(ApiConfig.statusEndpoint);
    final map = _parseMap(response.data);
    return DeviceStatus.fromJson(map);
  }

  /// Fetches live Gate Barrier telemetry from GET /api/sensors
  Future<SensorData> getSensors() async {
    final response = await _client.get(ApiConfig.sensorsEndpoint);
    final map = _parseMap(response.data);
    return SensorData.fromJson(map);
  }

  /// Commands the ESP32 to open the gate barrier via POST /api/gate/open
  Future<bool> openGate() async {
    final response = await _client.post(ApiConfig.gateOpenEndpoint);
    final map = _parseMap(response.data);
    return map['ok'] == true;
  }

  /// Commands the ESP32 to close the gate barrier via POST /api/gate/close
  Future<bool> closeGate() async {
    final response = await _client.post(ApiConfig.gateCloseEndpoint);
    final map = _parseMap(response.data);
    return map['ok'] == true;
  }

  /// Synchronizes device Unix time with the ESP32 via POST /api/time-sync
  Future<bool> syncTime([int? epochSeconds]) async {
    final epoch = epochSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final response = await _client.post(
      ApiConfig.timeSyncEndpoint,
      data: {'epoch': epoch},
    );

    try {
      final map = _parseMap(response.data);
      return map['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Admin login via POST /api/admin/login
  Future<AdminSession> login(String password) async {
    final cleanPassword = password.trim();
    if (cleanPassword.isEmpty) {
      throw ApiException('Password cannot be empty');
    }

    final response = await _client.post(
      ApiConfig.adminLoginEndpoint,
      data: {'password': cleanPassword},
    );

    final data = _parseMap(response.data);
    if (data['ok'] == true && data['token'] != null) {
      final token = data['token'].toString();
      final expiresInSeconds = (data['expires_in_seconds'] as num?)?.toInt() ?? 1800;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));

      _client.setAuthToken(token);
      return AdminSession(token: token, expiresAt: expiresAt);
    }
    throw ApiException('Authentication response missing session token');
  }

  /// Admin logout via POST /api/admin/logout
  Future<void> logout() async {
    try {
      await _client.post(ApiConfig.adminLogoutEndpoint);
    } finally {
      _client.setAuthToken(null);
    }
  }

  /// Changes the admin password via POST /api/admin/change-password
  Future<void> changeAdminPassword(String newPassword) async {
    final clean = newPassword.trim();
    if (clean.length < 4 || clean.length > 8) {
      throw ApiException('Admin password must be between 4 and 8 digits');
    }
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      throw ApiException('Admin password must contain numbers only (0-9)');
    }

    final response = await _client.post(
      ApiConfig.adminChangePasswordEndpoint,
      data: {'newPassword': clean},
    );

    final data = _parseMap(response.data);
    final ok = data['ok'] == true;
    if (!ok) {
      final err = data['error'];
      throw ApiException(err?.toString() ?? 'Failed to update admin password');
    }
  }

  /// Fetches registered RFID cards from GET /api/rfid/cards (requires admin auth)
  Future<List<String>> getRfidCards() async {
    final response = await _client.get(ApiConfig.rfidCardsEndpoint);
    final data = _parseMap(response.data);
    if (data['cards'] is List) {
      return (data['cards'] as List).map((e) => e.toString().toUpperCase()).toList();
    }
    return [];
  }

  /// Fetches security event logs from GET /api/events (requires admin auth)
  Future<List<DoorEvent>> getEvents() async {
    final response = await _client.get(ApiConfig.eventsEndpoint);
    final data = _parseMap(response.data);
    if (data['events'] is List) {
      final rawList = data['events'] as List;
      return rawList.map((e) {
        if (e is Map) {
          return DoorEvent.fromJson(Map<String, dynamic>.from(e));
        }
        return DoorEvent.fromJson({});
      }).toList();
    }
    return [];
  }

  /// Initiates new RFID card registration mode on ESP32 via POST /api/rfid/register
  Future<Map<String, dynamic>> startRfidRegistration() async {
    final response = await _client.post(ApiConfig.rfidRegisterEndpoint);
    return _parseMap(response.data);
  }

  /// Cancels RFID card registration mode on ESP32 via POST /api/rfid/cancel
  Future<void> cancelRfidRegistration() async {
    try {
      await _client.post(ApiConfig.rfidCancelEndpoint);
    } catch (_) {}
  }

  /// Removes an RFID card UID from ESP32 via POST /api/rfid/remove
  Future<void> removeRfidCard(String uid) async {
    final cleanUid = uid.trim().toUpperCase();
    final response = await _client.post(
      ApiConfig.rfidRemoveEndpoint,
      data: {'uid': cleanUid},
    );

    final data = _parseMap(response.data);
    final ok = data['ok'] == true;
    if (!ok) {
      final err = data['error'];
      throw ApiException(err?.toString() ?? 'Failed to remove RFID card');
    }
  }
}
