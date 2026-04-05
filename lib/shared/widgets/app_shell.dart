import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/config/app_colors.dart';
import 'celume_sidebar.dart';
import 'celume_app_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const SizedBox.shrink();
    }

    final user = authState.user;
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: CelumeAppBar(user: user),
      drawer: isSmallScreen
          ? Drawer(child: Material(color: AppColors.sidebarBg, child: CelumeSidebar(user: user)))
          : null,
      body: Row(
        children: [
          if (!isSmallScreen) CelumeSidebar(user: user),
          Expanded(child: child),
        ],
      ),
    );
  }
}
