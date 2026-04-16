import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/user_role.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_config.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _selectedUser; // full user with page_access
  bool _isCreating = false;
  bool _saving = false;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _formRole = UserRole.worker;
  String _formColor = 'gray';
  bool _formIsActive = true;
  Map<String, String?> _formPageAccess = {};

  static const _allPages = [
    AppConfig.pageTasks,
    AppConfig.pageAttendance,
    AppConfig.pageChat,
    AppConfig.pageAnalytics,
    AppConfig.pageClients,
  ];

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getUsers();
      setState(() {
        _users = List<Map<String, dynamic>>.from(res.data as List);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['error']?.toString() ?? 'Failed to load users';
        _loading = false;
      });
    }
  }

  void _openCreateForm() {
    setState(() {
      _selectedUser = null;
      _isCreating = true;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _formRole = UserRole.worker;
      _formColor = 'gray';
      _formIsActive = true;
      _formPageAccess = {for (var p in _allPages) p: null};
    });
  }

  Future<void> _openEditForm(Map<String, dynamic> user) async {
    // Fetch full user with page_access
    try {
      final res = await _api.getUser(user['id']);
      final fullUser = res.data as Map<String, dynamic>;
      final accessList = fullUser['page_access'] as List? ?? [];

      final accessMap = <String, String?>{};
      for (var p in _allPages) {
        accessMap[p] = null;
      }
      for (var a in accessList) {
        accessMap[a['page_name']] = a['permission'];
      }

      setState(() {
        _selectedUser = fullUser;
        _isCreating = false;
        _nameCtrl.text = fullUser['name'] ?? '';
        _emailCtrl.text = fullUser['email'] ?? '';
        _passwordCtrl.clear();
        _formRole = UserRole.fromString(fullUser['role'] ?? 'worker');
        _formColor = (fullUser['color'] as String?) ?? 'gray';
        _formIsActive = fullUser['is_active'] ?? true;
        _formPageAccess = accessMap;
      });
    } on DioException catch (e) {
      _showError(e.response?.data?['error']?.toString() ?? 'Failed to load user');
    }
  }

  void _closeForm() {
    setState(() {
      _selectedUser = null;
      _isCreating = false;
    });
  }

  Future<void> _saveUser() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
    if (_isCreating && _passwordCtrl.text.isEmpty) return;

    setState(() => _saving = true);

    try {
      if (_isCreating) {
        // 1. Create user
        final res = await _api.createUser({
          'name':     _nameCtrl.text.trim(),
          'email':    _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'role':     _formRole.value,
          'color':    _formColor,
        });
        final newUserId = res.data['id'] as String;

        // 2. Set page access
        final pages = _buildAccessList();
        if (pages.isNotEmpty) {
          await _api.setUserAccess(newUserId, pages);
        }
      } else if (_selectedUser != null) {
        final userId = _selectedUser!['id'] as String;

        // 1. Update user
        await _api.updateUser(userId, {
          'name':      _nameCtrl.text.trim(),
          'email':     _emailCtrl.text.trim(),
          'role':      _formRole.value,
          'color':     _formColor,
          'is_active': _formIsActive,
        });

        // 2. Update page access
        final pages = _buildAccessList();
        await _api.setUserAccess(userId, pages);
      }

      _closeForm();
      await _loadUsers();
    } on DioException catch (e) {
      _showError(e.response?.data?['error']?.toString() ?? 'Failed to save user');
    } finally {
      setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _buildAccessList() {
    final pages = <Map<String, dynamic>>[];
    _formPageAccess.forEach((page, perm) {
      if (perm != null) {
        pages.add({'page_name': page, 'permission': perm});
      }
    });
    return pages;
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final isActive = user['is_active'] as bool? ?? true;

    try {
      if (isActive) {
        await _api.deleteUser(userId); // soft delete = deactivate
      } else {
        await _api.updateUser(userId, {'is_active': true});
      }
      await _loadUsers();
    } on DioException catch (e) {
      _showError(e.response?.data?['error']?.toString() ?? 'Failed to update user');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final showForm = _isCreating || _selectedUser != null;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'User Management',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              isMobile
                  ? IconButton(
                      onPressed: () => _openCreateFormMobile(context),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _openCreateForm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: _loadUsers,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : isMobile
                        ? _buildUserCards(context)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildUserTable()),
                              if (showForm) ...[
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: _buildFormPanel()),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  // ── Mobile card list ─────────────────────────────────────────────────────

  Widget _buildUserCards(BuildContext context) {
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final user = _users[i];
        final role = UserRole.fromString(user['role'] ?? 'worker');
        final isActive = user['is_active'] as bool? ?? true;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(user['email'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      _RoleBadge(role: role),
                      const SizedBox(width: 6),
                      _StatusBadge(isActive: isActive),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit',
                onPressed: () => _openEditFormMobile(context, user),
                color: Colors.grey[600],
              ),
              IconButton(
                icon: Icon(
                  isActive ? Icons.block : Icons.check_circle_outline,
                  size: 18,
                ),
                tooltip: isActive ? 'Deactivate' : 'Activate',
                onPressed: () => _toggleActive(user),
                color: isActive ? AppColors.error : AppColors.success,
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateFormMobile(BuildContext context) {
    _openCreateForm();
    _showFormBottomSheet(context);
  }

  Future<void> _openEditFormMobile(
      BuildContext context, Map<String, dynamic> user) async {
    await _openEditForm(user);
    if (mounted) _showFormBottomSheet(context);
  }

  void _showFormBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // drag indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: _buildFormPanel(),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _closeForm());
  }

  Widget _buildUserTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
            rows: _users.map((user) {
              final role = UserRole.fromString(user['role'] ?? 'worker');
              final isActive = user['is_active'] as bool? ?? true;
              final isSelected = _selectedUser?['id'] == user['id'];

              return DataRow(
                selected: isSelected,
                color: isSelected
                    ? WidgetStateProperty.all(AppColors.accent.withValues(alpha: 0.05))
                    : null,
                cells: [
                  DataCell(Text(user['name'] ?? '')),
                  DataCell(Text(user['email'] ?? '', style: TextStyle(color: Colors.grey[600]))),
                  DataCell(_RoleBadge(role: role)),
                  DataCell(_StatusBadge(isActive: isActive)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Edit',
                        onPressed: () => _openEditForm(user),
                        color: Colors.grey[600],
                      ),
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.block : Icons.check_circle_outline,
                          size: 18,
                        ),
                        tooltip: isActive ? 'Deactivate' : 'Activate',
                        onPressed: () => _toggleActive(user),
                        color: isActive ? AppColors.error : AppColors.success,
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isCreating ? 'Create User' : 'Edit User',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _closeForm,
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameCtrl,
              decoration: _inputDecoration('Name'),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailCtrl,
              decoration: _inputDecoration('Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            if (_isCreating) ...[
              TextField(
                controller: _passwordCtrl,
                decoration: _inputDecoration('Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
            ],

            DropdownButtonFormField<UserRole>(
              initialValue: _formRole,
              decoration: _inputDecoration('Role'),
              items: UserRole.values
                  .where((r) => r != UserRole.superAdmin)
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.displayName)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _formRole = v);
              },
            ),
            const SizedBox(height: 16),

            // ── Color picker ────────────────────────────────────────────────
            const Text('Color', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppColors.userColorKeys.map((key) {
                final color = AppColors.userColor(key);
                final selected = _formColor == key;
                return GestureDetector(
                  onTap: () => setState(() => _formColor = key),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black87 : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text('Active', style: TextStyle(fontSize: 14)),
              value: _formIsActive,
              onChanged: (v) => setState(() => _formIsActive = v),
              activeThumbColor: AppColors.accent,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 32),

            const Text(
              'Page Access',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._allPages.map((page) => _buildPageAccessRow(page)),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isCreating ? 'Create User' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageAccessRow(String page) {
    final currentPerm = _formPageAccess[page];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              page[0].toUpperCase() + page.substring(1),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          _PermissionChip(
            label: 'None',
            isSelected: currentPerm == null,
            onTap: () => setState(() => _formPageAccess[page] = null),
          ),
          const SizedBox(width: 6),
          _PermissionChip(
            label: 'View',
            isSelected: currentPerm == 'view',
            onTap: () => setState(() => _formPageAccess[page] = 'view'),
          ),
          const SizedBox(width: 6),
          _PermissionChip(
            label: 'Edit',
            isSelected: currentPerm == 'edit',
            onTap: () => setState(() => _formPageAccess[page] = 'edit'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}

// ── Small widgets ───────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.displayName,
        style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          color: isActive ? AppColors.success : AppColors.error,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PermissionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
