import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_bloc.dart';
import '../auth/user_role.dart';
import '../config/app_config.dart';
import '../../features/login/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/users/user_management_screen.dart';
import '../../shared/widgets/app_shell.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _GoRouterAuthNotifier(authBloc),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isAuthenticated = authState is AuthAuthenticated;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) {
        return '/login';
      }

      if (isAuthenticated && isOnLogin) {
        return '/dashboard';
      }

      // Page access guard
      if (isAuthenticated) {
        final user = authState.user;
        final location = state.matchedLocation;

        // Map routes to page names
        final pageForRoute = _pageNameForRoute(location);
        if (pageForRoute != null && !user.hasPageAccess(pageForRoute)) {
          return '/dashboard';
        }

        // /users is super_admin only
        if (location == '/users' && user.role != UserRole.superAdmin) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) {
              final taskId = state.uri.queryParameters['task'];
              return taskId != null ? TasksScreen(initialTaskId: taskId) : const TasksScreen();
            },
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) {
              final convId = state.uri.queryParameters['conv'];
              return convId != null ? ChatScreen(initialConvId: convId) : const ChatScreen();
            },
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
        ],
      ),
    ],
  );

  /// Maps a route path to its page_access name.
  /// Returns null for routes that don't need page access (dashboard, users).
  static String? _pageNameForRoute(String route) {
    switch (route) {
      case '/tasks':
        return AppConfig.pageTasks;
      case '/attendance':
        return AppConfig.pageAttendance;
      case '/chat':
        return AppConfig.pageChat;
      case '/analytics':
        return AppConfig.pageAnalytics;
      case '/clients':
        return AppConfig.pageClients;
      default:
        return null;
    }
  }
}

class _GoRouterAuthNotifier extends ChangeNotifier {
  _GoRouterAuthNotifier(AuthBloc authBloc) {
    authBloc.stream.listen((_) => notifyListeners());
  }
}
