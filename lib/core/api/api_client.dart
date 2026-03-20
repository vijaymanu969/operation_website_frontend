import 'package:dio/dio.dart';
import '../auth/auth_service.dart';

class ApiClient {
  final Dio dio;
  final AuthService _authService;

  ApiClient({required AuthService authService})
      : _authService = authService,
        dio = Dio() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }
}
