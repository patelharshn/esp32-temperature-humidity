/// Real-time Gate Barrier Telemetry Data model.
/// Represents response from ESP32 GET /api/sensors.
class SensorData {
  final bool ok;
  final bool gateOpen;
  final bool gateClosed;
  final int servoAngle;
  final int timestamp; // Unix epoch in seconds (0 if not synced)
  final int uptimeMs;
  final DateTime recordedAt;

  SensorData({
    required this.ok,
    required this.gateOpen,
    required this.gateClosed,
    required this.servoAngle,
    required this.timestamp,
    required this.uptimeMs,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  factory SensorData.fromJson(Map<String, dynamic> json) {
    final rawOpen = json['gate_open'] == true;
    final rawClosed = json['gate_closed'] == true || (!rawOpen && json.containsKey('gate_open'));
    final rawAngle = (json['servo_angle'] as num?)?.toInt() ?? (rawOpen ? 90 : 0);

    return SensorData(
      ok: json['ok'] == true,
      gateOpen: rawOpen,
      gateClosed: rawClosed,
      servoAngle: rawAngle,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      uptimeMs: (json['uptime_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ok': ok,
      'gate_open': gateOpen,
      'gate_closed': gateClosed,
      'servo_angle': servoAngle,
      'timestamp': timestamp,
      'uptime_ms': uptimeMs,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  bool get valid => ok;
  bool get isOpen => gateOpen || servoAngle >= 45;
  bool get isClosed => !isOpen;

  String get displayAngle => '$servoAngle°';
  String get statusLabel => isOpen ? 'OPEN (PASSING)' : 'CLOSED (SECURED)';

  // Fallback compatibility helpers for existing references if any
  double get temperatureC => isOpen ? 90.0 : 0.0;
  double get humidityPercent => isOpen ? 100.0 : 0.0;
  double get temperatureF => 0.0;
  String displayTemperature({bool inFahrenheit = false}) => displayAngle;
  String displayHumidity() => statusLabel;
}
