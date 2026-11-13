import '../models/admin_session.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthRepository {
  final ApiService _apiService;
  final StorageService _storageService;

  AuthRepository(this._apiService, this._storageService);

  AdminSession? getCachedSession() {
    return _storageService.getAdminSession();
  }

  Future<AdminSession> login(String password) async {
    final session = await _apiService.login(password);
    await _storageService.saveAdminSession(session);
    return session;
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {
      // Even if network call fails, clear local session token
    } finally {
      await _storageService.clearAdminSession();
    }
  }

  Future<void> changePassword(String newPassword) async {
    await _apiService.changeAdminPassword(newPassword);
  }

  bool isAuthenticated() {
    final session = getCachedSession();
    return session != null && !session.isExpired;
  }
}
