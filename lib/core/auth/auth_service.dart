import '../models/user.dart';

/// With HttpOnly cookies, the JWT lives in a Secure HttpOnly cookie that
/// JavaScript / Dart cannot read. The frontend just caches the current User
/// object so widgets can read role/name without an extra API roundtrip.
class AuthService {
  User? _cachedUser;

  /// Cached user (set after login or /auth/me).
  User? get currentUser => _cachedUser;

  void setCurrentUser(User user) {
    _cachedUser = user;
  }

  /// Clear the cached user. Note: this does NOT clear the cookie — only the
  /// backend can do that via POST /auth/logout (Set-Cookie with empty value).
  void clearSession() {
    _cachedUser = null;
  }
}
