import '../auth/user_role.dart';
import 'page_access.dart';

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final List<PageAccess> pageAccess;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.pageAccess = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final accessList = json['page_access'] as List<dynamic>? ?? [];
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      isActive: json['is_active'] as bool? ?? true,
      pageAccess: accessList
          .map((e) => PageAccess.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.value,
        'is_active': isActive,
        'page_access': pageAccess.map((e) => e.toJson()).toList(),
      };

  /// super_admin bypasses all page access checks
  bool get isSuperAdmin => role == UserRole.superAdmin;

  /// Check if user has at least view access to a page
  bool hasPageAccess(String pageName) {
    if (isSuperAdmin) return true;
    return pageAccess.any((a) => a.pageName == pageName && a.canView);
  }

  /// Check if user has edit access to a page
  bool hasEditAccess(String pageName) {
    if (isSuperAdmin) return true;
    return pageAccess.any((a) => a.pageName == pageName && a.canEdit);
  }
}
