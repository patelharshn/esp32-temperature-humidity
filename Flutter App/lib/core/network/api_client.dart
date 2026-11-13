import 'dart:async';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_exceptions.dart';

/// Centralized HTTP client managing Dio, headers, interceptors, timeouts,
/// and session expiration.
class ApiClient {
  late final Dio _dio;
  String _baseUrl = ApiConfig.defaultBaseUrl;
  String? _authToken;
  void Function()? onSessionExpired;

  ApiClient({String? baseUrl, String? initialToken, this.onSessionExpired}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
    }
    _authToken = initialToken;

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(milliseconds: 8000),
        receiveTimeout: const Duration(milliseconds: 8000),
        sendTimeout: const Duration(milliseconds: 8000),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json',
          'Connection': 'close', // Essential for ESP32 single-socket WebServer
        },
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null && _authToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            if (!error.requestOptions.path.contains(ApiConfig.adminLoginEndpoint)) {
              onSessionExpired?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newUrl) {
    var clean = newUrl.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _baseUrl = clean;
    _dio.options.baseUrl = clean;
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  /// Generic GET request with centralized error handling
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected network error: $e');
    }
  }

  /// Generic POST request with centralized error handling
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected network error: $e');
    }
  }

  ApiException _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      final detailMsg = e.message ?? e.error?.toString() ?? 'Connection error';
      return ConnectionException(
        'Could not reach ESP32 at $_baseUrl ($detailMsg). Tip: Ensure your phone is connected to "ESP32_DOOR_LOCK" and Mobile Data is turned off if your phone routes offline Wi-Fi through cellular data.',
      );
    }

    final response = e.response;
    if (response != null) {
      final statusCode = response.statusCode;
      String? errorMessage;
      if (response.data is Map && response.data['error'] != null) {
        errorMessage = response.data['error'].toString();
      }

      if (statusCode == 401) {
        if (e.requestOptions.path.contains(ApiConfig.adminLoginEndpoint)) {
          return InvalidCredentialsException(errorMessage ?? 'Invalid admin password.');
        }
        return SessionExpiredException(errorMessage ?? 'Admin session expired or unauthorized.');
      } else if (statusCode == 404) {
        return CardNotFoundException(errorMessage ?? 'Resource not found on ESP32.');
      } else if (statusCode == 409) {
        return DeviceBusyException(errorMessage ?? 'ESP32 device is busy or door is unlocked.');
      } else {
        return ApiException(
          errorMessage ?? 'ESP32 API Error (HTTP $statusCode)',
          statusCode: statusCode,
          details: response.data,
        );
      }
    }

    return ApiException(e.message ?? 'Unknown network failure occurred: ${e.error}');
  }
}
