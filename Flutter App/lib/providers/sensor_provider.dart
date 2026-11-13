import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_exceptions.dart';
import '../models/sensor_data.dart';
import '../repositories/device_repository.dart';
import '../services/storage_service.dart';

class SensorProvider extends ChangeNotifier {
  final DeviceRepository _deviceRepository;
  final StorageService _storageService;

  SensorData? _latestReading;
  List<SensorData> _history = [];
  bool _isLoading = false;
  bool _isAutoPolling = false;
  String? _errorMessage;
  Timer? _pollTimer;
  bool _useFahrenheit = false;

  SensorProvider(this._deviceRepository, this._storageService) {
    _useFahrenheit = _storageService.getUseFahrenheit();
    _history = _deviceRepository.getStoredSensorHistory();
    if (_history.isNotEmpty) {
      _latestReading = _history.last;
    }
  }

  SensorData? get latestReading => _latestReading;
  List<SensorData> get history => _history;
  bool get isLoading => _isLoading;
  bool get isAutoPolling => _isAutoPolling;
  String? get errorMessage => _errorMessage;
  bool get useFahrenheit => _useFahrenheit;

  bool get isGateOpen => _latestReading?.isOpen ?? false;
  int get currentAngle => _latestReading?.servoAngle ?? 0;

  void toggleTemperatureUnit() {
    _useFahrenheit = !_useFahrenheit;
    _storageService.setUseFahrenheit(_useFahrenheit);
    notifyListeners();
  }

  /// Starts live telemetry polling loop (every 2 seconds)
  void startPolling() {
    if (_isAutoPolling) return;
    _isAutoPolling = true;
    _pollTimer?.cancel();

    fetchLatestReading(silent: _latestReading != null);

    _pollTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (_isAutoPolling) {
        fetchLatestReading(silent: true);
      }
    });
  }

  void stopPolling() {
    _isAutoPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> fetchLatestReading({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final reading = await _deviceRepository.getSensors();
      _latestReading = reading;
      _history = _deviceRepository.getStoredSensorHistory();
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to fetch gate telemetry: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    await _deviceRepository.clearStoredSensorHistory();
    _history = [];
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
