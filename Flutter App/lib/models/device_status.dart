import '../core/utils/date_formatter.dart';

class DeviceStatus {
  final bool ok;
  final String device;
  final bool locked;
  final bool unlocked;
  final String wifiMode;
  final String ssid;
  final String ip;
  final int connectedClients;
  final int uptimeMs;
  final bool timeSynced;
  final bool registrationWaiting;
  final DateTime receivedAt;

  DeviceStatus({
    required this.ok,
    required this.device,
    required this.locked,
    required this.unlocked,
    required this.wifiMode,
    required this.ssid,
    required this.ip,
    required this.connectedClients,
    required this.uptimeMs,
    required this.timeSynced,
    required this.registrationWaiting,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      ok: json['ok'] == true,
      device: json['device']?.toString() ?? 'ESP32_DOOR_LOCK',
      locked: json['locked'] == true,
      unlocked: json['unlocked'] == true,
      wifiMode: json['wifi_mode']?.toString() ?? 'access_point',
      ssid: json['ssid']?.toString() ?? 'ESP32_DOOR_LOCK',
      ip: json['ip']?.toString() ?? '192.168.4.1',
      connectedClients: (json['connected_clients'] as num?)?.toInt() ?? 0,
      uptimeMs: (json['uptime_ms'] as num?)?.toInt() ?? 0,
      timeSynced: json['time_synced'] == true,
      registrationWaiting: json['registration_waiting'] == true,
    );
  }

  String get formattedUptime => DateFormatter.formatUptime(uptimeMs);

  bool get isDoorLocked => locked;
  bool get isDoorUnlocked => unlocked;
  bool get isGateOpen => unlocked;
  bool get isGateClosed => locked;
}
