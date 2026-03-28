import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_bloc.dart';
import '../auth/user_role.dart';
import '../../features/login/login_screen.dart';
import '../../features/dashboard/ceo_dashboard.dart';
import '../../features/dashboard/tech_director_dashboard.dart';
import '../../features/dashboard/ops_director_dashboard.dart';
import '../../features/dashboard/sales_director_dashboard.dart';
import '../../features/dashboard/staff_dashboard.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/clients/clients_screen.dart';
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
        return (authState as AuthAuthenticated).role.routePath;
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
            path: '/dashboard/ceo',
            builder: (context, state) => const CeoDashboard(),
          ),
          GoRoute(
            path: '/dashboard/tech',
            builder: (context, state) => const TechDirectorDashboard(),
          ),
          GoRoute(
            path: '/dashboard/ops',
            builder: (context, state) => const OpsDirectorDashboard(),
          ),
          GoRoute(
            path: '/dashboard/sales',
            builder: (context, state) => const SalesDirectorDashboard(),
          ),
          GoRoute(
            path: '/dashboard/staff',
            builder: (context, state) => const StaffDashboard(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsScreen(),
          ),
        ],
      ),
    ],
  );
}

class _GoRouterAuthNotifier extends ChangeNotifier {
  _GoRouterAuthNotifier(AuthBloc authBloc) {
    authBloc.stream.listen((_) => notifyListeners());
  }
}
