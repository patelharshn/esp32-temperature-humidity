/// Exceptions thrown by API operations against the ESP32 Door Lock
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

/// Thrown when connection to the ESP32 hotspot fails or times out
class ConnectionException extends ApiException {
  ConnectionException([
    super.message = 'Unable to reach the ESP32 Door Lock. Ensure you are connected to the "ESP32_DOOR_LOCK" Wi-Fi hotspot.',
    int? statusCode,
  ]) : super(statusCode: statusCode);
}

/// Thrown when admin credentials are invalid (HTTP 401 on login)
class InvalidCredentialsException extends ApiException {
  InvalidCredentialsException([
    super.message = 'Invalid admin password. Please try again.',
  ]) : super(statusCode: 401);
}

/// Thrown when an admin session has expired or token is missing/invalid
class SessionExpiredException extends ApiException {
  SessionExpiredException([
    super.message = 'Admin session has expired or is unauthorized. Please log in again.',
  ]) : super(statusCode: 401);
}

/// Thrown when the device reports a conflict (e.g. door unlocked or busy during card add/remove)
class DeviceBusyException extends ApiException {
  DeviceBusyException([
    super.message = 'Device is busy, in card registration mode, or door is unlocked.',
  ]) : super(statusCode: 409);
}

/// Thrown when a card UID is not found on the ESP32
class CardNotFoundException extends ApiException {
  CardNotFoundException([
    super.message = 'The specified RFID card UID is not registered on the ESP32.',
  ]) : super(statusCode: 404);
}
