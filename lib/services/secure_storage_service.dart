import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const String _authTokenKey = 'auth_token';

  // Save auth token securely
  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _authTokenKey, value: token);
    } catch (e) {
      AppLogger.error('Error saving auth token', e);
      rethrow;
    }
  }

  // Get auth token securely
  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _authTokenKey);
    } catch (e) {
      AppLogger.error('Error reading auth token', e);
      return null;
    }
  }

  // Delete auth token
  Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: _authTokenKey);
    } catch (e) {
      AppLogger.error('Error deleting auth token', e);
      rethrow;
    }
  }
}
