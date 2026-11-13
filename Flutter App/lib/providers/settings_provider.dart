import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final LocationService _locationService;

  ThemeMode _themeMode = ThemeMode.dark;
  String _doorLocation = 'Main Entrance Door';
  String? _phoneGpsLocation;
  bool _isLocating = false;
  String? _locationError;

  SettingsProvider(this._storageService, this._locationService) {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  String get doorLocation => _doorLocation;
  String? get phoneGpsLocation => _phoneGpsLocation;
  bool get isLocating => _isLocating;
  String? get locationError => _locationError;

  void _loadSettings() {
    final savedTheme = _storageService.getThemeMode();
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }

    _doorLocation = _storageService.getDoorLocation();
    _phoneGpsLocation = _storageService.getDoorGps();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'dark';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.system) modeStr = 'system';
    await _storageService.setThemeMode(modeStr);
    notifyListeners();
  }

  Future<void> updateDoorLocation(String location) async {
    _doorLocation = location.trim();
    await _storageService.setDoorLocation(_doorLocation);
    notifyListeners();
  }

  /// Captures current mobile phone GPS location and records it explicitly as phone's location
  Future<bool> capturePhoneLocation() async {
    _isLocating = true;
    _locationError = null;
    notifyListeners();

    try {
      final loc = await _locationService.getCurrentPhoneLocation();
      _phoneGpsLocation = loc.formattedString;
      await _storageService.setDoorGps(_phoneGpsLocation);
      _isLocating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLocating = false;
      _locationError = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> clearPhoneGps() async {
    _phoneGpsLocation = null;
    await _storageService.setDoorGps(null);
    notifyListeners();
  }
}
