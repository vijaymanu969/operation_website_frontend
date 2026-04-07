import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/models/user.dart';

class CelumeSidebar extends StatelessWidget {
  final User user;
  final VoidCallback? onCollapse;

  const CelumeSidebar({super.key, required this.user, this.onCollapse});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar: collapse button ────────────────────────────────────
        if (onCollapse != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: onCollapse,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:        Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    color: Colors.white70,
                    size:  16,
                  ),
                ),
              ),
            ),
          ),

        // ── Header ──────────────────────────────────────────────────────
        const SizedBox(height: 16),
        Center(
          child: Text(
            'CELUME OPS',
            style: TextStyle(
              color:         AppColors.accent,
              fontSize:      22,
              fontWeight:    FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.displayName,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Nav items ───────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isActive: currentPath == '/dashboard',
                  onTap: () => _navigate(context, '/dashboard'),
                ),
                if (user.hasPageAccess(AppConfig.pageTasks))
                  _NavItem(
                    icon: Icons.task_alt,
                    label: 'Tasks',
                    isActive: currentPath == '/tasks',
                    onTap: () => _navigate(context, '/tasks'),
                  ),
                if (user.hasPageAccess(AppConfig.pageAttendance))
                  _NavItem(
                    icon: Icons.access_time,
                    label: 'Attendance',
                    isActive: currentPath == '/attendance',
                    onTap: () => _navigate(context, '/attendance'),
                  ),
                if (user.hasPageAccess(AppConfig.pageChat))
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    isActive: currentPath == '/chat',
                    onTap: () => _navigate(context, '/chat'),
                  ),
                if (user.hasPageAccess(AppConfig.pageAnalytics))
                  _NavItem(
                    icon: Icons.bar_chart,
                    label: 'Analytics',
                    isActive: currentPath == '/analytics',
                    onTap: () => _navigate(context, '/analytics'),
                  ),
                if (user.hasPageAccess(AppConfig.pageClients))
                  _NavItem(
                    icon: Icons.people_outline_rounded,
                    label: 'Clients',
                    isActive: currentPath == '/clients',
                    onTap: () => _navigate(context, '/clients'),
                  ),
                if (user.role == UserRole.superAdmin)
                  _NavItem(
                    icon: Icons.admin_panel_settings,
                    label: 'User Management',
                    isActive: currentPath == '/users',
                    onTap: () => _navigate(context, '/users'),
                  ),
              ],
            ),
          ),
        ),

        // ── Logout ──────────────────────────────────────────────────────
        _NavItem(
          icon: Icons.logout,
          label: 'Logout',
          isActive: false,
          onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _navigate(BuildContext context, String path) {
    if (MediaQuery.of(context).size.width < 800) {
      Navigator.of(context).pop();
    }
    context.go(path);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isActive ? AppColors.accent : AppColors.navItemText,
            size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.navItemText,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        hoverColor: AppColors.navItemHover,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
      ),
    );
  }
}
