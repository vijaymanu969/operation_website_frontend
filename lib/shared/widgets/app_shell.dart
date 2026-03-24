import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';
import 'celume_sidebar.dart';
import 'celume_app_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final role = authState is AuthAuthenticated ? authState.role : UserRole.staff;
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: CelumeAppBar(role: role),
      drawer: isSmallScreen
          ? Drawer(child: Material(color: const Color(0xFF1A1A2E), child: CelumeSidebar(role: role)))
          : null,
      body: Row(
        children: [
          if (!isSmallScreen) CelumeSidebar(role: role),
          Expanded(child: child),
        ],
      ),
    );
  }
}
