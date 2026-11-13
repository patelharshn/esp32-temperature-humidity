import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;
  final String note;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    required this.note,
  });

  String get formattedString {
    return 'Lat: ${latitude.toStringAsFixed(5)}, Long: ${longitude.toStringAsFixed(5)} (±${accuracy?.toStringAsFixed(0) ?? '?'}m) [Captured by Phone at ${timestamp.toLocal().toString().split('.').first}]';
  }
}

class LocationService {
  LocationService();

  Future<LocationResult> getCurrentPhoneLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled on your phone. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions were denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable in phone settings.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    return LocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
      note: 'Mobile phone GPS position at moment of configuration',
    );
  }
}
