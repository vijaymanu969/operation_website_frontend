import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/app_config.dart';

class ApiClient {
  final Dio dio;

  /// Callback to trigger logout when a 401 is received.
  /// Set by AuthBloc after construction.
  void Function()? onUnauthorized;

  ApiClient()
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
          // Dio web adapter reads this on every request to set
          // XMLHttpRequest.withCredentials = true
          extra: {'withCredentials': true},
        )) {
    // Also set it on the adapter instance for older Dio versions
    // that read it from the adapter instead of options.extra
    dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Force withCredentials on every request so the browser always
        // sends the HttpOnly auth cookie cross-origin.
        options.extra['withCredentials'] = true;
        debugPrint('[API] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('[API ERROR] ${error.requestOptions.method} '
            '${error.requestOptions.uri} → '
            '${error.response?.statusCode} ${error.response?.data}');
        // Don't trigger global logout for auth endpoints — a failed login
        // or session check shouldn't recursively dispatch a logout event.
        final path = error.requestOptions.path;
        final isAuthEndpoint = path.contains('/auth/');
        if (error.response?.statusCode == 401 && !isAuthEndpoint) {
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

  Future<Response> logout() {
    return dio.post('/auth/logout');
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

  /// Lightweight user directory for pickers (person, reviewer, @mentions, etc.).
  /// Returns only id, name, color, role for active users. Any authenticated user can call.
  Future<Response> getUserDirectory() {
    return dio.get('/users/directory');
  }

  /// Returns { online: [userId, ...] } — currently connected user IDs.
  Future<Response> getOnlineUsers() {
    return dio.get('/users/online');
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

  Future<Response> pinTask(String id) {
    return dio.post('/tasks/$id/pin');
  }

  Future<Response> unpinTask(String id) {
    return dio.delete('/tasks/$id/pin');
  }

  Future<Response> deleteTask(String id) {
    return dio.delete('/tasks/$id');
  }

  Future<Response> deleteTasks(List<String> ids) {
    return dio.delete('/tasks', data: {'ids': ids});
  }

  Future<Response> changeTaskStatus(String id, String status) {
    return dio.put('/tasks/$id/status', data: {'status': status});
  }

  Future<Response> getTaskComments(String id) {
    return dio.get('/tasks/$id/comments');
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

  Future<Response> getPauseRequests({String? status, String? taskId}) {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (taskId != null) params['task_id'] = taskId;
    return dio.get('/tasks/pause-requests', queryParameters: params);
  }

  Future<Response> reviewPauseRequest(String requestId, String status) {
    return dio.put('/tasks/pause-requests/$requestId', data: {'status': status});
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

  Future<Response> importAttendance({
    required List<int> bytes,
    required String filename,
  }) {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return dio.post('/attendance/import', data: form);
  }

  Future<Response> updateAttendance(String id, Map<String, dynamic> data) {
    return dio.put('/attendance/$id', data: data);
  }

  Future<Response> deleteAttendance(String id) {
    return dio.delete('/attendance/$id');
  }

  Future<Response> deleteAttendanceByDate(String date) {
    return dio.delete('/attendance/by-date', queryParameters: {'date': date});
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

  Future<Response> uploadMessageFile(
    String conversationId,
    List<int> bytes,
    String fileName, {
    String? content,
  }) {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (content != null && content.isNotEmpty) 'content': content,
    });
    return dio.post(
      '/chat/conversations/$conversationId/messages/upload',
      data: formData,
    );
  }

  Future<Response> markConversationAsRead(String conversationId) {
    return dio.post('/chat/conversations/$conversationId/mark-read');
  }

  Future<Response> deleteConversation(String conversationId) {
    return dio.delete('/chat/conversations/$conversationId');
  }

  Future<Response> addGroupMembers(String conversationId, List<String> memberIds) {
    return dio.post('/chat/conversations/$conversationId/members',
        data: {'member_ids': memberIds});
  }

  Future<Response> removeGroupMember(String conversationId, String userId) {
    return dio.delete('/chat/conversations/$conversationId/members/$userId');
  }

  Future<Response> reviewTaskFromChat(String messageId, String status) {
    return dio.put('/chat/messages/$messageId/review', data: {'status': status});
  }

  // ── Clients ────────────────────────────────────────────────────────────────

  Future<Response> getClients({
    int?    page,
    int?    limit,
    String? stage,
    String? product,
    String? vertical,
    String? onboardingSubstage,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) {
    final params = <String, dynamic>{};
    if (page != null)               params['page']                = page;
    if (limit != null)              params['limit']               = limit;
    if (stage != null)              params['stage']               = stage;
    if (product != null)            params['product']             = product;
    if (vertical != null)           params['vertical']            = vertical;
    if (onboardingSubstage != null) params['onboarding_substage'] = onboardingSubstage;
    if (search != null && search.isNotEmpty) params['search']     = search;
    if (sortBy != null)             params['sort_by']             = sortBy;
    if (sortOrder != null)          params['sort_order']          = sortOrder;
    return dio.get('/clients', queryParameters: params);
  }

  Future<Response> getClient(String id) {
    return dio.get('/clients/$id');
  }

  Future<Response> createClient(Map<String, dynamic> data) {
    return dio.post('/clients', data: data);
  }

  Future<Response> updateClient(String id, Map<String, dynamic> data) {
    return dio.put('/clients/$id', data: data);
  }

  Future<Response> deleteClient(String id) {
    return dio.delete(
      '/clients/$id',
      queryParameters: {'hard_delete': true},
    );
  }

  Future<Response> bulkDeleteClients(List<String> ids) {
    return dio.post('/clients/bulk-delete', data: {'ids': ids});
  }

  Future<Response> changeClientStage(String id, Map<String, dynamic> data) {
    return dio.patch('/clients/$id/stage', data: data);
  }

  Future<Response> changeOnboardingSubstage(String id, Map<String, dynamic> data) {
    return dio.patch('/clients/$id/onboarding-substage', data: data);
  }

  Future<Response> getClientHistory(String id) {
    return dio.get('/clients/$id/history');
  }

  Future<Response> getClientTimeline(String id) {
    return dio.get('/clients/$id/timeline');
  }

  Future<Response> getDashboardStats() {
    return dio.get('/dashboard/stats');
  }

  Future<Response> getClientDocuments(String clientId, {String? documentType}) {
    final params = <String, dynamic>{};
    if (documentType != null) params['document_type'] = documentType;
    return dio.get('/clients/$clientId/documents', queryParameters: params);
  }

  Future<Response> uploadClientDocument({
    required String       clientId,
    required String       documentType,
    required List<int>    bytes,
    required String       filename,
    String?               documentName,
    String?               notes,
  }) {
    final form = FormData.fromMap({
      'document_type': documentType,
      'file':          MultipartFile.fromBytes(bytes, filename: filename),
      if (documentName != null && documentName.isNotEmpty) 'document_name': documentName,
      if (notes        != null && notes.isNotEmpty)        'notes':         notes,
    });
    return dio.post('/clients/$clientId/documents', data: form);
  }

  Future<Response> deleteClientDocument(String docId) {
    return dio.delete('/client-documents/$docId');
  }

  Future<Response> getClientOnboardingTasks(String clientId, {String? substage, String? status}) {
    final params = <String, dynamic>{};
    if (substage != null) params['substage'] = substage;
    if (status   != null) params['status']   = status;
    return dio.get('/clients/$clientId/tasks', queryParameters: params);
  }

  Future<Response> updateOnboardingTaskStatus(String taskId, String status, {String? notes}) {
    return dio.patch('/onboarding-tasks/$taskId/status', data: {
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  // ── Calendar ───────────────────────────────────────────────────────────────

  /// Cross-client calendar. Dates are YYYY-MM-DD.
  Future<Response> getClientsCalendar({
    String? start,
    String? end,
    List<String>? types,
  }) {
    final params = <String, dynamic>{};
    if (start != null) params['start'] = start;
    if (end   != null) params['end']   = end;
    if (types != null && types.isNotEmpty) params['types'] = types.join(',');
    return dio.get('/clients/calendar', queryParameters: params);
  }

  /// Per-client calendar.
  Future<Response> getClientCalendar(String clientId, {
    String? start,
    String? end,
    List<String>? types,
  }) {
    final params = <String, dynamic>{};
    if (start != null) params['start'] = start;
    if (end   != null) params['end']   = end;
    if (types != null && types.isNotEmpty) params['types'] = types.join(',');
    return dio.get('/clients/$clientId/calendar', queryParameters: params);
  }

  Future<Response> getUpcomingMeetings({int daysAhead = 7, int limit = 10}) {
    return dio.get('/meetings/upcoming', queryParameters: {
      'days_ahead': daysAhead,
      'limit':      limit,
    });
  }

  // ── Analytics ──────────────────────────────────────────────────────────────

  Future<Response> getAnalyticsDashboard({String? startDate, String? endDate}) {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    return dio.get('/analytics/dashboard', queryParameters: params);
  }

  Future<Response> getUserSummary(String userId) {
    return dio.get('/analytics/users/$userId/summary');
  }

  /// Summary for the currently logged-in user (workers/interns use this).
  Future<Response> getMyUserSummary() {
    return dio.get('/analytics/users/me/summary');
  }

  // ── Web Push ───────────────────────────────────────────────────────────────

  Future<Response> getVapidPublicKey() {
    return dio.get('/users/push/vapid-public-key');
  }

  Future<Response> subscribePush(Map<String, dynamic> subscription) {
    return dio.post('/users/push/subscribe', data: subscription);
  }

  Future<Response> unsubscribePush(String endpoint) {
    return dio.delete('/users/push/subscribe', data: {'endpoint': endpoint});
  }

  Future<Response> getTaskPerformance({String? userId, String? startDate, String? endDate}) {
    final params = <String, dynamic>{};
    if (userId != null)    params['user_id']    = userId;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null)   params['end_date']   = endDate;
    return dio.get('/analytics/tasks/performance', queryParameters: params);
  }
}
