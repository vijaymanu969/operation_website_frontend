enum UserRole {
  ceo,
  techDirector,
  opsDirector,
  salesDirector,
  staff;

  static UserRole fromString(String role) {
    switch (role) {
      case 'ceo':
        return UserRole.ceo;
      case 'tech_director':
        return UserRole.techDirector;
      case 'ops_director':
        return UserRole.opsDirector;
      case 'sales_director':
        return UserRole.salesDirector;
      default:
        return UserRole.staff;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.ceo:
        return 'CEO';
      case UserRole.techDirector:
        return 'Tech Director';
      case UserRole.opsDirector:
        return 'Ops Director';
      case UserRole.salesDirector:
        return 'Sales Director';
      case UserRole.staff:
        return 'Staff';
    }
  }

  String get routePath {
    switch (this) {
      case UserRole.ceo:
        return '/dashboard/ceo';
      case UserRole.techDirector:
        return '/dashboard/tech';
      case UserRole.opsDirector:
        return '/dashboard/ops';
      case UserRole.salesDirector:
        return '/dashboard/sales';
      case UserRole.staff:
        return '/dashboard/staff';
    }
  }
}
