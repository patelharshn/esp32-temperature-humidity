import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/api_config.dart';
import '../models/admin_session.dart';
import '../models/door_event.dart';
import '../models/sensor_data.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _keyBaseUrl = 'esp32_base_url';
  static const String _keyAdminSession = 'admin_session';
  static const String _keyCardLabels = 'rfid_card_labels';
  static const String _keyDoorLocation = 'door_installation_location';
  static const String _keyDoorGps = 'door_phone_gps';
  static const String _keySensorHistory = 'sensor_readings_history';
  static const String _keyCachedEvents = 'cached_events_history';
  static const String _keyThemeMode = 'app_theme_mode'; // 'system', 'light', 'dark'
  static const String _keyUseFahrenheit = 'use_fahrenheit';

  // ---------------- Base URL ----------------
  String getBaseUrl() {
    return _prefs.getString(_keyBaseUrl) ?? ApiConfig.defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  // ---------------- Admin Session ----------------
  AdminSession? getAdminSession() {
    final raw = _prefs.getString(_keyAdminSession);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = AdminSession.fromJson(json);
      if (session.isExpired) {
        clearAdminSession();
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAdminSession(AdminSession session) async {
    await _prefs.setString(_keyAdminSession, jsonEncode(session.toJson()));
  }

  Future<void> clearAdminSession() async {
    await _prefs.remove(_keyAdminSession);
  }

  // ---------------- RFID Card Nicknames/Labels ----------------
  Map<String, String> getCardLabels() {
    final raw = _prefs.getString(_keyCardLabels);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setCardLabel(String uid, String label) async {
    final labels = getCardLabels();
    if (label.trim().isEmpty) {
      labels.remove(uid.toUpperCase());
    } else {
      labels[uid.toUpperCase()] = label.trim();
    }
    await _prefs.setString(_keyCardLabels, jsonEncode(labels));
  }

  // ---------------- Fixed Door Location & Phone GPS ----------------
  String getDoorLocation() {
    return _prefs.getString(_keyDoorLocation) ?? 'Main Door (Front Entrance)';
  }

  Future<void> setDoorLocation(String location) async {
    await _prefs.setString(_keyDoorLocation, location.trim());
  }

  String? getDoorGps() {
    return _prefs.getString(_keyDoorGps);
  }

  Future<void> setDoorGps(String? gps) async {
    if (gps == null) {
      await _prefs.remove(_keyDoorGps);
    } else {
      await _prefs.setString(_keyDoorGps, gps);
    }
  }

  // ---------------- Sensor History (Actual received data only) ----------------
  List<SensorData> getSensorHistory() {
    final raw = _prefs.getString(_keySensorHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SensorData.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendSensorReading(SensorData data) async {
    if (!data.valid) return;
    final current = getSensorHistory();
    current.add(data);
    // Keep up to 100 actual real-time readings for trend charting
    if (current.length > 100) {
      current.removeRange(0, current.length - 100);
    }
    final encoded = jsonEncode(current.map((e) => e.toJson()).toList());
    await _prefs.setString(_keySensorHistory, encoded);
  }

  Future<void> clearSensorHistory() async {
    await _prefs.remove(_keySensorHistory);
  }

  // ---------------- Cached Events History ----------------
  List<DoorEvent> getCachedEvents() {
    final raw = _prefs.getString(_keyCachedEvents);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => DoorEvent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> mergeCachedEvents(List<DoorEvent> fetchedEvents) async {
    final current = getCachedEvents();
    final currentMap = {for (var e in current) '${e.id}_${e.uptimeMs}': e};

    for (var ev in fetchedEvents) {
      currentMap['${ev.id}_${ev.uptimeMs}'] = ev;
    }

    final merged = currentMap.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    // Keep up to 250 historical events locally
    if (merged.length > 250) {
      merged.removeRange(250, merged.length);
    }

    final encoded = jsonEncode(merged.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyCachedEvents, encoded);
  }

  // ---------------- Preferences ----------------
  String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'dark';
  Future<void> setThemeMode(String mode) async => await _prefs.setString(_keyThemeMode, mode);

  bool getUseFahrenheit() => _prefs.getBool(_keyUseFahrenheit) ?? false;
  Future<void> setUseFahrenheit(bool val) async => await _prefs.setBool(_keyUseFahrenheit, val);
}
