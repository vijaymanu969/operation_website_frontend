import 'package:flutter/material.dart';
import '../../core/auth/user_role.dart';

class CelumeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserRole role;
  final VoidCallback? onMenuPressed;

  const CelumeAppBar({super.key, required this.role, this.onMenuPressed});

  static const _primaryColor = Color(0xFF1A1A2E);

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return AppBar(
      backgroundColor: _primaryColor,
      leading: isSmallScreen
          ? IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Text(
        'Celume Operations — ${role.displayName}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
