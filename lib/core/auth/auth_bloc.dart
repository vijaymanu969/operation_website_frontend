import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'auth_service.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import 'user_role.dart';

// ── Events ──────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {}

// ── States ──────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated({required this.user});

  UserRole get role => user.role;

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Bloc ────────────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;
  final ApiClient apiClient;

  AuthBloc({required this.authService, required this.apiClient})
      : super(AuthInitial()) {
    // When we get a 401, trigger logout
    apiClient.onUnauthorized = () => add(AuthLogoutRequested());

    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final hasToken = await authService.hasToken();
    if (!hasToken) {
      emit(AuthUnauthenticated());
      return;
    }

    // Token exists — validate it by calling /auth/me
    try {
      final meResponse = await apiClient.getMe();
      final user = User.fromJson(meResponse.data as Map<String, dynamic>);
      authService.setCurrentUser(user);
      emit(AuthAuthenticated(user: user));
    } catch (_) {
      // Token expired or invalid
      await authService.clearSession();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. Call POST /auth/login
      final loginResponse = await apiClient.login(event.email, event.password);
      final data = loginResponse.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final loginUser = User.fromJson(data['user'] as Map<String, dynamic>);

      // 2. Save token
      await authService.saveSession(token, loginUser);

      // 3. Call GET /auth/me to get full user with page_access
      final meResponse = await apiClient.getMe();
      final fullUser = User.fromJson(meResponse.data as Map<String, dynamic>);
      authService.setCurrentUser(fullUser);

      emit(AuthAuthenticated(user: fullUser));
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString() ?? 'Login failed'
          : 'Login failed — check your connection';
      emit(AuthFailure(message));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await authService.clearSession();
    emit(AuthUnauthenticated());
  }
}
