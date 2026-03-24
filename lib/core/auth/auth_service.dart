import 'package:shared_preferences/shared_preferences.dart';
import 'user_role.dart';

class AuthService {
  static const _roleKey = 'mock_role';
  static const _loggedInKey = 'mock_logged_in';

  Future<UserRole> login(String email, String password, UserRole role) async {
    // Mock login — no backend call, just persist chosen role
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_roleKey, role.name);
    return role;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInKey);
    await prefs.remove(_roleKey);
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  Future<UserRole> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleName = prefs.getString(_roleKey) ?? 'staff';
    return UserRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => UserRole.staff,
    );
  }
}
