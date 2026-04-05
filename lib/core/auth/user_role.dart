enum UserRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Admin'),
  worker('worker', 'Worker'),
  intern('intern', 'Intern');

  final String value;
  final String displayName;

  const UserRole(this.value, this.displayName);

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (r) => r.value == role,
      orElse: () => UserRole.worker,
    );
  }
}
