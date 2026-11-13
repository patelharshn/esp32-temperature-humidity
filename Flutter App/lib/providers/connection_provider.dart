import 'dart:async';
import 'package:flutter/material.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/device_status.dart';
import '../repositories/device_repository.dart';
import '../services/storage_service.dart';

enum ConnectionStateStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class ConnectionProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final DeviceRepository _deviceRepository;
  final StorageService _storageService;

  ConnectionStateStatus _status = ConnectionStateStatus.disconnected;
  String? _errorMessage;
  int? _latencyMs;
  DeviceStatus? _lastStatus;
  DateTime? _lastCheckedAt;
  bool _isTimeSynced = false;

  ConnectionProvider(this._apiClient, this._deviceRepository, this._storageService) {
    // Initialize base URL from stored settings
    final storedUrl = _storageService.getBaseUrl();
    _apiClient.updateBaseUrl(storedUrl);
  }

  ConnectionStateStatus get status => _status;
  bool get isConnected => _status == ConnectionStateStatus.connected;
  bool get isConnecting => _status == ConnectionStateStatus.connecting;
  String? get errorMessage => _errorMessage;
  int? get latencyMs => _latencyMs;
  DeviceStatus? get lastStatus => _lastStatus;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  bool get isTimeSynced => _isTimeSynced;
  String get currentBaseUrl => _apiClient.baseUrl;

  /// Updates connection state when another provider (e.g. Dashboard) receives live status
  void setConnectedStatus(DeviceStatus deviceStatus, [int? latency]) {
    _status = ConnectionStateStatus.connected;
    _lastStatus = deviceStatus;
    _lastCheckedAt = DateTime.now();
    _isTimeSynced = deviceStatus.timeSynced;
    if (latency != null) _latencyMs = latency;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets error/disconnected status
  void setDisconnectedStatus(String? error) {
    _status = ConnectionStateStatus.error;
    _errorMessage = error;
    _latencyMs = null;
    notifyListeners();
  }

  /// Tests connection to the ESP32, measures latency, and auto-syncs time if successful
  Future<bool> checkConnection({bool silent = false}) async {
    if (!silent) {
      _status = ConnectionStateStatus.connecting;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final stopwatch = Stopwatch()..start();
      final deviceStatus = await _deviceRepository.getStatus();
      stopwatch.stop();

      _status = ConnectionStateStatus.connected;
      _latencyMs = stopwatch.elapsedMilliseconds;
      _lastStatus = deviceStatus;
      _lastCheckedAt = DateTime.now();
      _errorMessage = null;

      // Automatically sync time if device time is uncalibrated
      if (!deviceStatus.timeSynced) {
        syncTime().catchError((_) => false);
      } else {
        _isTimeSynced = true;
      }

      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = ConnectionStateStatus.error;
      _errorMessage = e.message;
      _latencyMs = null;
      notifyListeners();
      return false;
    } catch (e) {
      _status = ConnectionStateStatus.error;
      _errorMessage = 'Could not reach ESP32 ($e). Ensure phone Wi-Fi is connected to "${ApiConfig.defaultSsid}".';
      _latencyMs = null;
      notifyListeners();
      return false;
    }
  }

  /// Synchronizes device time with current smartphone Unix epoch
  Future<bool> syncTime() async {
    try {
      final success = await _deviceRepository.syncDeviceTime();
      _isTimeSynced = success;
      notifyListeners();
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Updates the target ESP32 IP address or URL
  Future<void> updateIpAddress(String newIp) async {
    String clean = newIp.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    _apiClient.updateBaseUrl(clean);
    await _storageService.setBaseUrl(clean);
    notifyListeners();
    await checkConnection();
  }

  /// Resets back to default 192.168.4.1
  Future<void> resetToDefault() async {
    await updateIpAddress(ApiConfig.defaultBaseUrl);
  }
}
