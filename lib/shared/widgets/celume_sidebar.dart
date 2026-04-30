import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/models/user.dart';
import '../../core/socket/socket_service.dart';

class CelumeSidebar extends StatefulWidget {
  final User user;
  final VoidCallback? onCollapse;

  const CelumeSidebar({super.key, required this.user, this.onCollapse});

  @override
  State<CelumeSidebar> createState() => _CelumeSidebarState();
}

class _CelumeSidebarState extends State<CelumeSidebar> {
  int _unreadChat = 0;
  StreamSubscription<int>? _unreadSub;

  @override
  void initState() {
    super.initState();
    final socket = context.read<SocketService>();
    _unreadChat = socket.unreadCount;
    _unreadSub = socket.onUnreadCount.listen((count) {
      if (mounted) setState(() => _unreadChat = count);
    });
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar: collapse button ────────────────────────────────────
        if (widget.onCollapse != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: widget.onCollapse,
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
              widget.user.role.displayName,
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
                if (widget.user.hasPageAccess(AppConfig.pageTasks))
                  _NavItem(
                    icon: Icons.task_alt,
                    label: 'Tasks',
                    isActive: currentPath == '/tasks',
                    onTap: () => _navigate(context, '/tasks'),
                  ),
                if (widget.user.hasPageAccess(AppConfig.pageAttendance))
                  _NavItem(
                    icon: Icons.access_time,
                    label: 'Attendance',
                    isActive: currentPath == '/attendance',
                    onTap: () => _navigate(context, '/attendance'),
                  ),
                if (widget.user.hasPageAccess(AppConfig.pageChat))
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    isActive: currentPath == '/chat',
                    badge: _unreadChat > 0 ? _unreadChat : null,
                    onTap: () => _navigate(context, '/chat'),
                  ),
                if (widget.user.hasPageAccess(AppConfig.pageAnalytics))
                  _NavItem(
                    icon: Icons.bar_chart,
                    label: 'Analytics',
                    isActive: currentPath == '/analytics',
                    onTap: () => _navigate(context, '/analytics'),
                  ),
                if (widget.user.hasPageAccess(AppConfig.pageClients))
                  _NavItem(
                    icon: Icons.people_outline_rounded,
                    label: 'Clients',
                    isActive: currentPath == '/clients',
                    onTap: () => _navigate(context, '/clients'),
                  ),
                if (widget.user.hasPageAccess(AppConfig.pageAgents))
                  _NavItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Agents',
                    isActive: currentPath == '/agents',
                    onTap: () => _navigate(context, '/agents'),
                  ),
                if (widget.user.hasPageAccess(AppConfig.pageClients))
                  _NavItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    isActive: currentPath == '/calendar',
                    onTap: () => _navigate(context, '/calendar'),
                  ),
                if (widget.user.role == UserRole.superAdmin)
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
  final IconData   icon;
  final String     label;
  final bool       isActive;
  final VoidCallback onTap;
  final int?       badge; // unread count — null means no badge

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
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
        leading: badge != null
            ? Badge(
                label: Text(
                  badge! > 99 ? '99+' : '$badge',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: AppColors.accent,
                child: Icon(icon,
                    color: isActive ? AppColors.accent : AppColors.navItemText,
                    size: 20),
              )
            : Icon(icon,
                color: isActive ? AppColors.accent : AppColors.navItemText,
                size: 20),
        title: Text(
          label,
          style: TextStyle(
            color:      isActive ? Colors.white : AppColors.navItemText,
            fontSize:   14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        hoverColor:     AppColors.navItemHover,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense:          true,
      ),
    );
  }
}
