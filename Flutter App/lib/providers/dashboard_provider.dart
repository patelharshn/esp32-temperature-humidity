import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_exceptions.dart';
import '../models/device_status.dart';
import '../models/door_event.dart';
import '../models/sensor_data.dart';
import '../repositories/device_repository.dart';
import '../repositories/rfid_repository.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';

class DashboardProvider extends ChangeNotifier {
  final DeviceRepository _deviceRepository;
  final RfidRepository _rfidRepository;
  final AuthProvider _authProvider;
  final ConnectionProvider _connectionProvider;

  DeviceStatus? _status;
  SensorData? _sensorData;
  DoorEvent? _lastEvent;
  int _cardCount = 0;
  int _totalEventCount = 0;
  bool _isLoading = false;
  bool _isAutoRefreshing = false;
  bool _isControllingGate = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  DateTime? _lastSyncTime;
  double _autoCloseRemaining = 0.0;

  DashboardProvider(
    this._deviceRepository,
    this._rfidRepository,
    this._authProvider,
    this._connectionProvider,
  );

  DeviceStatus? get status => _status;
  SensorData? get sensorData => _sensorData;
  DoorEvent? get lastEvent => _lastEvent;
  int get cardCount => _cardCount;
  int get totalEventCount => _totalEventCount;
  bool get isLoading => _isLoading;
  bool get isAutoRefreshing => _isAutoRefreshing;
  bool get isControllingGate => _isControllingGate;
  String? get errorMessage => _errorMessage;
  double get autoCloseRemaining => _autoCloseRemaining;
  bool get isGateOpen => _status?.isDoorUnlocked ?? false;

  /// Starts the 2.0-second live polling loop when the dashboard screen is active
  void startAutoRefresh() {
    if (_isAutoRefreshing) return;
    _isAutoRefreshing = true;
    _refreshTimer?.cancel();

    // Initial immediate fetch
    fetchDashboardData(silent: _status != null);

    // Periodic 2-second timer
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (_isAutoRefreshing) {
        fetchDashboardData(silent: true);
      }
    });
  }

  /// Stops polling when navigating away to conserve battery and avoid unnecessary hotspot traffic
  void stopAutoRefresh() {
    _isAutoRefreshing = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _autoCloseRemaining = 5.0;
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_autoCloseRemaining > 0.1) {
        _autoCloseRemaining = double.parse((_autoCloseRemaining - 0.1).toStringAsFixed(1));
        notifyListeners();
      } else {
        _autoCloseRemaining = 0.0;
        _countdownTimer?.cancel();
        _countdownTimer = null;
        fetchDashboardData(silent: true);
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_autoCloseRemaining > 0.0) {
      _autoCloseRemaining = 0.0;
      notifyListeners();
    }
  }

  /// Commands the ESP32 to open the gate barrier via POST /api/gate/open
  Future<bool> openGateBarrier() async {
    _isControllingGate = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _deviceRepository.openGate();
      if (success) {
        _startCountdown();
        await fetchDashboardData(silent: true);
      }
      return success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to open gate barrier: $e';
      return false;
    } finally {
      _isControllingGate = false;
      notifyListeners();
    }
  }

  /// Commands the ESP32 to close the gate barrier via POST /api/gate/close
  Future<bool> closeGateBarrier() async {
    _isControllingGate = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _deviceRepository.closeGate();
      if (success) {
        _stopCountdown();
        await fetchDashboardData(silent: true);
      }
      return success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to close gate barrier: $e';
      return false;
    } finally {
      _isControllingGate = false;
      notifyListeners();
    }
  }

  /// Fetches status and sensor data from ESP32
  Future<void> fetchDashboardData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // 1. Fetch live Device Status
      final stopwatch = Stopwatch()..start();
      final newStatus = await _deviceRepository.getStatus();
      stopwatch.stop();

      _status = newStatus;
      _connectionProvider.setConnectedStatus(newStatus, stopwatch.elapsedMilliseconds);

      // Handle auto-close countdown sync
      if (newStatus.isDoorUnlocked) {
        if (_countdownTimer == null && _autoCloseRemaining <= 0.0) {
          _startCountdown();
        }
      } else {
        if (_countdownTimer != null) {
          _stopCountdown();
        }
      }

      // 2. Fetch live Sensor Data (Gate Barrier Telemetry)
      final newSensors = await _deviceRepository.getSensors();
      _sensorData = newSensors;

      // 3. Periodic time sync check (every 5 minutes or if time unsynced)
      if (!newStatus.timeSynced ||
          _lastSyncTime == null ||
          DateTime.now().difference(_lastSyncTime!).inMinutes >= 5) {
        _deviceRepository.syncDeviceTime().then((synced) {
          if (synced) _lastSyncTime = DateTime.now();
        }).catchError((_) {});
      }

      // 4. Fetch authenticated details if logged in
      if (_authProvider.isAuthenticated) {
        try {
          final cards = await _rfidRepository.getRegisteredCards();
          _cardCount = cards.length;

          final events = await _rfidRepository.getEvents();
          _totalEventCount = events.length;
          if (events.isNotEmpty) {
            _lastEvent = events.first;
          }
        } catch (_) {
          final cachedEvents = _rfidRepository.getCachedEvents();
          if (cachedEvents.isNotEmpty) {
            _totalEventCount = cachedEvents.length;
            _lastEvent = cachedEvents.first;
          }
        }
      } else {
        final cachedEvents = _rfidRepository.getCachedEvents();
        if (cachedEvents.isNotEmpty) {
          _totalEventCount = cachedEvents.length;
          _lastEvent = cachedEvents.first;
        }
      }

      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _connectionProvider.setDisconnectedStatus(e.message);
    } catch (e) {
      _errorMessage = 'Failed to refresh dashboard data: $e';
      _connectionProvider.setDisconnectedStatus(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    _stopCountdown();
    super.dispose();
  }
}
