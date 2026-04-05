import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/auth_bloc.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const CelumeOpsApp());
}

class CelumeOpsApp extends StatefulWidget {
  const CelumeOpsApp({super.key});

  @override
  State<CelumeOpsApp> createState() => _CelumeOpsAppState();
}

class _CelumeOpsAppState extends State<CelumeOpsApp> {
  late final AuthService _authService;
  late final ApiClient _apiClient;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _apiClient = ApiClient(authService: _authService);
    _authBloc = AuthBloc(authService: _authService, apiClient: _apiClient);
    _appRouter = AppRouter(authBloc: _authBloc);
    _authBloc.add(AuthCheckRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        RepositoryProvider.value(value: _apiClient),
      ],
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
    );
  }
}
