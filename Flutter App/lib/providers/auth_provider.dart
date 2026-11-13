import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/admin_session.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final ApiClient _apiClient;

  AdminSession? _session;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authRepository, this._apiClient) {
    // Check cached session
    _session = _authRepository.getCachedSession();
    if (_session != null && !_session!.isExpired) {
      _apiClient.setAuthToken(_session!.token);
    } else {
      _session = null;
    }

    // Attach session expiration callback
    _apiClient.onSessionExpired = _handleSessionExpired;
  }

  bool get isAuthenticated => _session != null && !_session!.isExpired;
  AdminSession? get session => _session;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _handleSessionExpired() {
    _session = null;
    _errorMessage = 'Session expired. Please log in again.';
    notifyListeners();
  }

  Future<bool> login(String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _authRepository.login(password);
      _session = session;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred during login.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.logout();
    } finally {
      _session = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.changePassword(newPassword);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to change admin password.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
