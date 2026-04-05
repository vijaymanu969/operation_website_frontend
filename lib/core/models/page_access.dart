class PageAccess {
  final String pageName;
  final String permission; // 'view' or 'edit'

  const PageAccess({
    required this.pageName,
    required this.permission,
  });

  factory PageAccess.fromJson(Map<String, dynamic> json) {
    return PageAccess(
      pageName: json['page_name'] as String,
      permission: json['permission'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'page_name': pageName,
        'permission': permission,
      };

  bool get canEdit => permission == 'edit';
  bool get canView => permission == 'view' || permission == 'edit';
}
