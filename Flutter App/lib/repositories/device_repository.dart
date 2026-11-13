import '../models/device_status.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class DeviceRepository {
  final ApiService _apiService;
  final StorageService _storageService;

  DeviceRepository(this._apiService, this._storageService);

  Future<DeviceStatus> getStatus() async {
    return await _apiService.getStatus();
  }

  Future<SensorData> getSensors() async {
    final sensor = await _apiService.getSensors();
    if (sensor.valid) {
      await _storageService.appendSensorReading(sensor);
    }
    return sensor;
  }

  Future<bool> openGate() async {
    return await _apiService.openGate();
  }

  Future<bool> closeGate() async {
    return await _apiService.closeGate();
  }

  Future<bool> syncDeviceTime([int? epoch]) async {
    return await _apiService.syncTime(epoch);
  }

  Future<int> measureLatency() async {
    return await _apiService.ping();
  }

  List<SensorData> getStoredSensorHistory() {
    return _storageService.getSensorHistory();
  }

  Future<void> clearStoredSensorHistory() async {
    await _storageService.clearSensorHistory();
  }
}
