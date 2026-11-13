/// Centralized API Configuration for the ESP32 Smart Gate Barrier System.
/// 
/// All endpoints, default URLs, timeout values, and network constants are defined here.
/// Never hardcode API URLs elsewhere in the application.
class ApiConfig {
  ApiConfig._();

  /// Default Wi-Fi Access Point configuration created by the ESP32 firmware
  static const String defaultSsid = 'ESP32_DOOR_LOCK';
  static const String defaultApPassword = '12345678';
  static const String defaultIp = '192.168.4.1';
  static const int defaultPort = 80;

  /// Default base URL pointing to the ESP32 Wi-Fi SoftAP
  static const String defaultBaseUrl = 'http://192.168.4.1';

  /// Network timeout settings (in milliseconds) tuned for local ESP32 AP
  static const Duration connectTimeout = Duration(milliseconds: 5000);
  static const Duration receiveTimeout = Duration(milliseconds: 5000);
  static const Duration sendTimeout = Duration(milliseconds: 5000);

  // -------------------------------------------------------------
  // API Endpoints
  // -------------------------------------------------------------

  /// Public Endpoints
  static const String statusEndpoint = '/api/status';
  static const String sensorsEndpoint = '/api/sensors';
  static const String timeSyncEndpoint = '/api/time-sync';
  static const String adminLoginEndpoint = '/api/admin/login';

  /// Gate Barrier Control Endpoints (Require `Authorization: Bearer <token>`)
  static const String gateOpenEndpoint = '/api/gate/open';
  static const String gateCloseEndpoint = '/api/gate/close';

  /// Protected Endpoints (Require `Authorization: Bearer <token>`)
  static const String adminLogoutEndpoint = '/api/admin/logout';
  static const String adminChangePasswordEndpoint = '/api/admin/change-password';
  static const String rfidCardsEndpoint = '/api/rfid/cards';
  static const String eventsEndpoint = '/api/events';
  static const String rfidRegisterEndpoint = '/api/rfid/register';
  static const String rfidCancelEndpoint = '/api/rfid/cancel';
  static const String rfidRemoveEndpoint = '/api/rfid/remove';

  /// Build full URL dynamically based on active base URL
  static String buildUrl(String baseUrl, String endpoint) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$cleanBase$cleanEndpoint';
  }
}
