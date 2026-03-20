import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';
import '../../shared/widgets/celume_sidebar.dart';
import '../../shared/widgets/celume_app_bar.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Charts & analytics coming soon', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
