import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/models/user.dart';

class CelumeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User user;
  final VoidCallback? onMenuPressed;

  const CelumeAppBar({super.key, required this.user, this.onMenuPressed});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return AppBar(
      backgroundColor: AppColors.primary,
      leading: isSmallScreen
          ? IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Text(
        'Celume Operations — ${user.name}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
