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
    // With HttpOnly cookies we can't peek at the cookie from JS/Dart, so the
    // only way to know if the user is authenticated is to ask the server.
    // /auth/me will succeed if the cookie is valid, 401 otherwise.
    try {
      final meResponse = await apiClient.getMe();
      final user = User.fromJson(meResponse.data as Map<String, dynamic>);
      authService.setCurrentUser(user);
      emit(AuthAuthenticated(user: user));
    } catch (_) {
      // No cookie / expired / invalid — treat as logged out
      authService.clearSession();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. POST /auth/login — backend sets the HttpOnly cookie via Set-Cookie.
      //    The response body no longer carries a token; we don't need to read
      //    or store it from the frontend.
      await apiClient.login(event.email, event.password);

      // 2. GET /auth/me — relies on the cookie that was just set, returns the
      //    full user with page_access.
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
    // Tell the server to clear the cookie. We don't care if it fails (e.g.
    // already expired) — we still drop our local user state.
    try {
      await apiClient.logout();
    } catch (_) {}
    authService.clearSession();
    emit(AuthUnauthenticated());
  }
}
