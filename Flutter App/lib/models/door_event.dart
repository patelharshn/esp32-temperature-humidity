import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/date_formatter.dart';

class DoorEvent {
  final int id;
  final String type;
  final String uid;
  final String result;
  final int uptimeMs;
  final int timestamp; // Unix epoch in seconds (0 = uncalibrated)
  final String timestampSource;

  DoorEvent({
    required this.id,
    required this.type,
    required this.uid,
    required this.result,
    required this.uptimeMs,
    required this.timestamp,
    required this.timestampSource,
  });

  factory DoorEvent.fromJson(Map<String, dynamic> json) {
    return DoorEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'unknown',
      uid: json['uid']?.toString() ?? '',
      result: json['result']?.toString() ?? 'unknown',
      uptimeMs: (json['uptime_ms'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      timestampSource: json['timestamp_source']?.toString() ?? 'uptime_only',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'uid': uid,
      'result': result,
      'uptime_ms': uptimeMs,
      'timestamp': timestamp,
      'timestamp_source': timestampSource,
    };
  }

  bool get isCalendarTimeSynced => timestamp > 0;

  bool get isAccessGranted =>
      result.toLowerCase() == 'granted' ||
      result.toLowerCase() == 'success' ||
      result.toLowerCase() == 'opened_by_app';

  bool get isDenied =>
      result.toLowerCase() == 'denied' || result.toLowerCase() == 'failed';

  bool get isGateControl => type == 'gate_control';

  bool get isAdminEvent {
    return type.startsWith('admin_') ||
        type == 'rfid_card_registered' ||
        type == 'rfid_card_removed' ||
        type == 'password_attempt' ||
        type == 'gate_control';
  }

  String get displayTitle {
    switch (type) {
      case 'rfid_access':
        return isAccessGranted ? 'RFID Access Granted' : 'RFID Access Denied';
      case 'password_attempt':
        return 'Keypad Password Attempt';
      case 'rfid_card_registered':
        if (result == 'already_registered') return 'Card Already Registered';
        return 'RFID Card Registered';
      case 'rfid_card_removed':
        return 'RFID Card Removed';
      case 'gate_control':
        if (result == 'opened_by_app') return 'Gate Opened (Remote App)';
        if (result == 'closed_by_app') return 'Gate Closed (Remote App)';
        if (result == 'auto_closed_after_5_seconds') return 'Gate Auto-Closed (Safety Timer)';
        return 'Gate Control: ${result.replaceAll('_', ' ').toUpperCase()}';
      case 'admin_login':
        return isAccessGranted ? 'Admin Login (App)' : 'Failed Admin Login (App)';
      case 'admin_login_keypad':
        return 'Admin Login (Keypad)';
      case 'admin_logout':
        return 'Admin Logout';
      case 'admin_password_changed':
        return 'Admin Password Changed';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String get displayDescription {
    if (type == 'gate_control') {
      if (result == 'opened_by_app') {
        return 'Remote barrier raise command triggered via Flutter app.';
      }
      if (result == 'closed_by_app') {
        return 'Remote barrier lower command triggered via Flutter app.';
      }
      if (result == 'auto_closed_after_5_seconds') {
        return 'Automatic safety timeout: Barrier lowered after 5 seconds.';
      }
      return 'Result: ${result.replaceAll('_', ' ')}';
    }
    if (uid.isNotEmpty) {
      return 'Card UID: $uid • Result: ${result.toUpperCase()}';
    }
    return 'Result: ${result.toUpperCase()}';
  }

  String get displayTime {
    if (isCalendarTimeSynced) {
      return DateFormatter.formatEpoch(timestamp);
    }
    return 'Uptime: ${DateFormatter.formatUptime(uptimeMs)} (No Clock Sync)';
  }

  IconData get icon {
    switch (type) {
      case 'rfid_access':
        return isAccessGranted ? Icons.credit_card : Icons.credit_card_off;
      case 'password_attempt':
        return Icons.pin;
      case 'rfid_card_registered':
        if (result == 'already_registered') return Icons.warning_amber_rounded;
        return Icons.add_card;
      case 'rfid_card_removed':
        return Icons.credit_card_off;
      case 'gate_control':
        if (result == 'opened_by_app') return Icons.lock_open_rounded;
        if (result == 'closed_by_app') return Icons.lock_rounded;
        if (result == 'auto_closed_after_5_seconds') return Icons.timer_outlined;
        return Icons.garage_outlined;
      case 'admin_login':
      case 'admin_login_keypad':
        return Icons.admin_panel_settings;
      case 'admin_logout':
        return Icons.logout;
      case 'admin_password_changed':
        return Icons.lock_reset;
      default:
        return Icons.security;
    }
  }

  Color get statusColor {
    if (result == 'already_registered') return AppColors.warning;
    if (type == 'gate_control') {
      if (result == 'opened_by_app') return AppColors.unlocked;
      if (result == 'closed_by_app') return AppColors.locked;
      if (result == 'auto_closed_after_5_seconds') return AppColors.warning;
    }
    if (isAccessGranted) return AppColors.success;
    if (isDenied) return AppColors.error;
    return AppColors.info;
  }
}
