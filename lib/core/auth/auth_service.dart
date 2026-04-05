import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  String? _cachedToken;
  User? _cachedUser;

  /// Get stored JWT token
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  /// Save JWT token and user data after login
  Future<void> saveSession(String token, User user) async {
    _cachedToken = token;
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Get cached user (set after login or checkAuth)
  User? get currentUser => _cachedUser;

  /// Update cached user (e.g. after fetching /auth/me)
  void setCurrentUser(User user) {
    _cachedUser = user;
  }

  /// Check if a token exists (doesn't validate it — API call will)
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear everything on logout
  Future<void> clearSession() async {
    _cachedToken = null;
    _cachedUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
