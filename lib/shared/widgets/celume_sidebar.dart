import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';

class CelumeSidebar extends StatelessWidget {
  final UserRole role;

  const CelumeSidebar({super.key, required this.role});

  static const _primaryColor = Color(0xFF1A1A2E);
  static const _accentColor = Color(0xFFE94560);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    if (isSmallScreen) {
      return _buildDrawerContent(context);
    }

    return Container(
      width: 260,
      color: _primaryColor,
      child: _buildDrawerContent(context),
    );
  }

  Widget _buildDrawerContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────────
        const SizedBox(height: 40),
        Center(
          child: Text(
            'CELUME OPS',
            style: TextStyle(
              color: _accentColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.displayName,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Nav items (scrollable if height is tight) ──────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NavItem(
                  icon:  Icons.dashboard,
                  label: 'Dashboard',
                  onTap: () => context.go(role.routePath),
                ),
                _NavItem(
                  icon:  Icons.task_alt,
                  label: 'Tasks',
                  onTap: () => context.go('/tasks'),
                ),
                _NavItem(
                  icon:  Icons.access_time,
                  label: 'Attendance',
                  onTap: () => context.go('/attendance'),
                ),
                _NavItem(
                  icon:  Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () => context.go('/chat'),
                ),
                _NavItem(
                  icon:  Icons.bar_chart,
                  label: 'Analytics',
                  onTap: () => context.go('/analytics'),
                ),
                _NavItem(
                  icon:  Icons.people_outline_rounded,
                  label: 'Clients',
                  onTap: () => context.go('/clients'),
                ),
              ],
            ),
          ),
        ),

        // ── Logout — always pinned at bottom ──────────────────────────────
        _NavItem(
          icon:  Icons.logout,
          label: 'Logout',
          onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      onTap: onTap,
      hoverColor: Colors.white10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
