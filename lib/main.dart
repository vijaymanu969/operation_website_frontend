import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authBloc = AuthBloc(authService: _authService);
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
    return BlocProvider.value(
      value: _authBloc,
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
