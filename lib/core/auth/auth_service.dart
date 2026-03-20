import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'user_role.dart';

class AuthService {
  static const _baseUrl = 'http://localhost/gotrue';
  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final Dio _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  Future<String> login(String email, String password) async {
    final response = await _dio.post(
      '/token?grant_type=password',
      data: {
        'email': email,
        'password': password,
      },
      options: Options(contentType: Headers.jsonContentType),
    );

    final accessToken = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);

    return accessToken;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;
    return !JwtDecoder.isExpired(token);
  }

  UserRole getRoleFromToken(String token) {
    final decoded = JwtDecoder.decode(token);
    final role = decoded['role'] as String? ?? 'staff';
    return UserRole.fromString(role);
  }
}
