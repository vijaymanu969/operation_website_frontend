import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/auth_bloc.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/socket/socket_service.dart';

void main() {
  usePathUrlStrategy();
  runApp(const CelumeOpsApp());
}

class CelumeOpsApp extends StatefulWidget {
  const CelumeOpsApp({super.key});

  @override
  State<CelumeOpsApp> createState() => _CelumeOpsAppState();
}

class _CelumeOpsAppState extends State<CelumeOpsApp> {
  late final AuthService    _authService;
  late final ApiClient      _apiClient;
  late final AuthBloc       _authBloc;
  late final AppRouter      _appRouter;
  late final SocketService  _socketService;
  late final PushService    _pushService;

  @override
  void initState() {
    super.initState();
    _authService   = AuthService();
    _apiClient     = ApiClient();
    _socketService = SocketService();
    _pushService   = PushService(_apiClient);
    _authBloc      = AuthBloc(authService: _authService, apiClient: _apiClient);
    _appRouter     = AppRouter(authBloc: _authBloc);
    _authBloc.add(AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        RepositoryProvider.value(value: _apiClient),
        RepositoryProvider.value(value: _socketService),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthAuthenticated) {
            _socketService.connect();
            // Seed initial online users list
            try {
              final res = await _apiClient.getOnlineUsers();
              final ids = ((res.data as Map)['online'] as List)
                  .cast<String>();
              _socketService.seedOnlineUsers(ids);
            } catch (_) {}
            // Register for web push notifications
            _pushService.subscribe();
          } else if (state is AuthUnauthenticated) {
            _pushService.unsubscribe();
            _socketService.disconnect();
          }
        },
        child: MaterialApp.router(
          title: 'Celume Ops',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A1A2E),
              primary: const Color(0xFF1A1A2E),
            ),
            useMaterial3: true,
          ),
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}
