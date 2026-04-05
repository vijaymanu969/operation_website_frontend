import 'package:dio/dio.dart';
import '../auth/auth_service.dart';
import '../config/app_config.dart';

class ApiClient {
  final Dio dio;
  final AuthService _authService;

  /// Callback to trigger logout when a 401 is received.
  /// Set by AuthBloc after construction.
  void Function()? onUnauthorized;

  ApiClient({required AuthService authService})
      : _authService = authService,
        dio = Dio(BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _authService.clearSession();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Response> login(String email, String password) {
    return dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> getMe() {
    return dio.get('/auth/me');
  }

  Future<Response> changePassword(String oldPassword, String newPassword) {
    return dio.put('/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<Response> getUsers({String? role, bool? isActive}) {
    final params = <String, dynamic>{};
    if (role != null) params['role'] = role;
    if (isActive != null) params['is_active'] = isActive;
    return dio.get('/users', queryParameters: params);
  }

  Future<Response> getUser(String id) {
    return dio.get('/users/$id');
  }

  Future<Response> createUser(Map<String, dynamic> data) {
    return dio.post('/users', data: data);
  }

  Future<Response> updateUser(String id, Map<String, dynamic> data) {
    return dio.put('/users/$id', data: data);
  }

  Future<Response> deleteUser(String id) {
    return dio.delete('/users/$id');
  }

  Future<Response> getUserAccess(String id) {
    return dio.get('/users/$id/access');
  }

  Future<Response> setUserAccess(String id, List<Map<String, dynamic>> pages) {
    return dio.put('/users/$id/access', data: {'pages': pages});
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────

  Future<Response> getTasks({Map<String, dynamic>? filters}) {
    return dio.get('/tasks', queryParameters: filters);
  }

  Future<Response> getTask(String id) {
    return dio.get('/tasks/$id');
  }

  Future<Response> createTask(Map<String, dynamic> data) {
    return dio.post('/tasks', data: data);
  }

  Future<Response> updateTask(String id, Map<String, dynamic> data) {
    return dio.put('/tasks/$id', data: data);
  }

  Future<Response> deleteTask(String id) {
    return dio.delete('/tasks/$id');
  }

  Future<Response> changeTaskStatus(String id, String status) {
    return dio.put('/tasks/$id/status', data: {'status': status});
  }

  Future<Response> addTaskComment(String id, String text) {
    return dio.post('/tasks/$id/comments', data: {'text': text});
  }

  Future<Response> reorderTasks(List<Map<String, dynamic>> tasks) {
    return dio.put('/tasks/reorder', data: {'tasks': tasks});
  }

  // ── Task Types ─────────────────────────────────────────────────────────────

  Future<Response> getTaskTypes() {
    return dio.get('/tasks/types');
  }

  Future<Response> createTaskType(Map<String, dynamic> data) {
    return dio.post('/tasks/types', data: data);
  }

  Future<Response> updateTaskType(String id, Map<String, dynamic> data) {
    return dio.put('/tasks/types/$id', data: data);
  }

  Future<Response> deleteTaskType(String id) {
    return dio.delete('/tasks/types/$id');
  }

  // ── Task Pause/Resume ─────────────────────────────────────────────────────

  Future<Response> pauseTask(String id, String reason, {String? note}) {
    final data = <String, dynamic>{'reason': reason};
    if (note != null) data['note'] = note;
    return dio.put('/tasks/$id/pause', data: data);
  }

  Future<Response> resumeTask(String id) {
    return dio.put('/tasks/$id/resume');
  }

  Future<Response> getTaskTime(String id) {
    return dio.get('/tasks/$id/time');
  }

  // ── Idea Bank ──────────────────────────────────────────────────────────────

  Future<Response> requestIdeaMove(String taskId, String reason) {
    return dio.post('/tasks/$taskId/idea-request', data: {'reason': reason});
  }

  Future<Response> reviewIdeaRequest(String requestId, String status) {
    return dio.put('/idea-requests/$requestId', data: {'status': status});
  }

  Future<Response> getIdeaRequests({String? status}) {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return dio.get('/idea-requests', queryParameters: params);
  }

  // ── Stagnant & Archive ─────────────────────────────────────────────────────

  Future<Response> getStagnantTasks({String? health}) {
    final params = <String, dynamic>{};
    if (health != null) params['health'] = health;
    return dio.get('/tasks/stagnant', queryParameters: params);
  }

  Future<Response> archiveTask(String id) {
    return dio.put('/tasks/$id/archive');
  }

  // ── Attendance ─────────────────────────────────────────────────────────────

  Future<Response> getAttendance({String? startDate, String? endDate, String? userId}) {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (userId != null) params['user_id'] = userId;
    return dio.get('/attendance', queryParameters: params);
  }

  Future<Response> bulkUpsertAttendance(List<Map<String, dynamic>> rows) {
    return dio.post('/attendance/bulk', data: {'rows': rows});
  }

  Future<Response> updateAttendance(String id, Map<String, dynamic> data) {
    return dio.put('/attendance/$id', data: data);
  }

  Future<Response> deleteAttendance(String id) {
    return dio.delete('/attendance/$id');
  }

  Future<Response> getAttendanceSummary({String? startDate, String? endDate}) {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    return dio.get('/attendance/summary', queryParameters: params);
  }

  Future<Response> getAttendanceDaily(String date) {
    return dio.get('/attendance/daily', queryParameters: {'date': date});
  }

  Future<Response> getAttendanceTrends({
    required String startDate,
    required String endDate,
    String groupBy = 'week',
  }) {
    return dio.get('/attendance/trends', queryParameters: {
      'start_date': startDate,
      'end_date': endDate,
      'group_by': groupBy,
    });
  }

  Future<Response> getAttendancePunctuality({
    required String startDate,
    required String endDate,
  }) {
    return dio.get('/attendance/punctuality', queryParameters: {
      'start_date': startDate,
      'end_date': endDate,
    });
  }

  Future<Response> getAttendanceComparison({
    required String startDate,
    required String endDate,
  }) {
    return dio.get('/attendance/comparison', queryParameters: {
      'start_date': startDate,
      'end_date': endDate,
    });
  }

  Future<Response> getLeavePatterns({
    required String startDate,
    required String endDate,
  }) {
    return dio.get('/attendance/leave-patterns', queryParameters: {
      'start_date': startDate,
      'end_date': endDate,
    });
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<Response> getConversations({String? search}) {
    final params = <String, dynamic>{};
    if (search != null) params['search'] = search;
    return dio.get('/chat/conversations', queryParameters: params);
  }

  Future<Response> createConversation(Map<String, dynamic> data) {
    return dio.post('/chat/conversations', data: data);
  }

  Future<Response> getMessages(String conversationId, {int? limit, String? cursor}) {
    final params = <String, dynamic>{};
    if (limit != null) params['limit'] = limit;
    if (cursor != null) params['cursor'] = cursor;
    return dio.get('/chat/conversations/$conversationId/messages', queryParameters: params);
  }

  Future<Response> sendMessage(String conversationId, String content) {
    return dio.post('/chat/conversations/$conversationId/messages', data: {
      'content': content,
    });
  }

  Future<Response> reviewTaskFromChat(String messageId, String status) {
    return dio.put('/chat/messages/$messageId/review', data: {'status': status});
  }

  // ── Analytics ──────────────────────────────────────────────────────────────

  Future<Response> getAnalyticsDashboard({String? startDate, String? endDate}) {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    return dio.get('/analytics/dashboard', queryParameters: params);
  }
}
