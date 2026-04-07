import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/config/app_colors.dart';
import 'celume_sidebar.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const SizedBox.shrink();
    }

    final user = authState.user;
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    if (isSmallScreen) {
      return Scaffold(
        drawer: Drawer(
          child: Material(
            color: AppColors.sidebarBg,
            child: CelumeSidebar(
              user: user,
              onCollapse: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        body: Builder(
          builder: (ctx) => Stack(children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: 8, top: 8,
              child: _ToggleButton(
                icon: Icons.menu,
                onTap: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          if (_open)
            SizedBox(
              width: 260,
              child: Material(
                color: AppColors.sidebarBg,
                child: CelumeSidebar(
                  user: user,
                  onCollapse: () => setState(() => _open = false),
                ),
              ),
            ),
          Expanded(
            child: _open
                ? widget.child
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left gutter for the toggle button
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 14),
                        child: _ToggleButton(
                          icon: Icons.keyboard_double_arrow_right_rounded,
                          onTap: () => setState(() => _open = true),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: widget.child),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _ToggleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(6),
            border:       Border.all(color: const Color(0xFFE8ECF3)),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}
