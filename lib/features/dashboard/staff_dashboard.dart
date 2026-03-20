import 'package:flutter/material.dart';
import '../../core/auth/user_role.dart';
import '../../shared/widgets/celume_sidebar.dart';
import '../../shared/widgets/celume_app_bar.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const role = UserRole.staff;
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: CelumeAppBar(role: role),
      drawer: isSmallScreen
          ? Drawer(child: Material(color: const Color(0xFF1A1A2E), child: CelumeSidebar(role: role)))
          : null,
      body: Row(
        children: [
          if (!isSmallScreen) const CelumeSidebar(role: role),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Team Member',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your tasks & daily overview',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
