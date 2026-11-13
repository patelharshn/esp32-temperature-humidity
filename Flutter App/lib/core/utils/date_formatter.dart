import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm:ss a');
  static final DateFormat _timeOnlyFormat = DateFormat('hh:mm:ss a');
  static final DateFormat _dateOnlyFormat = DateFormat('MMM dd, yyyy');

  /// Formats a Unix epoch in seconds into human-readable date & time
  static String formatEpoch(int? epochSeconds) {
    if (epochSeconds == null || epochSeconds <= 0) {
      return 'Unsynchronized (Uptime only)';
    }
    final dateTime = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return _dateTimeFormat.format(dateTime);
  }

  /// Formats a DateTime instance
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _dateTimeFormat.format(dateTime);
  }

  /// Formats time only
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _timeOnlyFormat.format(dateTime);
  }

  /// Formats date only
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _dateOnlyFormat.format(dateTime);
  }

  /// Formats ESP32 millisecond uptime into human readable string (e.g., 2d 5h 14m 20s)
  static String formatUptime(int uptimeMs) {
    if (uptimeMs <= 0) return '0s';

    final totalSeconds = (uptimeMs / 1000).floor();
    final days = (totalSeconds / 86400).floor();
    final hours = ((totalSeconds % 86400) / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    if (minutes > 0 || hours > 0 || days > 0) parts.add('${minutes}m');
    parts.add('${seconds}s');

    return parts.join(' ');
  }

  /// Formats relative time (e.g. "Just now", "5m ago", "2h ago")
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return _dateOnlyFormat.format(dateTime);
    }
  }
}
