import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  io.Socket? _socket;

  final _newMessageCtrl    = StreamController<Map<String, dynamic>>.broadcast();
  final _reviewUpdatedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationCtrl  = StreamController<Map<String, dynamic>>.broadcast();
  final _unreadCountCtrl   = StreamController<int>.broadcast();
  final _onlineUsersCtrl   = StreamController<Set<String>>.broadcast();
  // Task board events
  final _taskCreatedCtrl       = StreamController<Map<String, dynamic>>.broadcast();
  final _taskUpdatedCtrl       = StreamController<Map<String, dynamic>>.broadcast();
  final _taskDeletedCtrl       = StreamController<Map<String, dynamic>>.broadcast();
  final _taskStatusChangedCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage    => _newMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onReviewUpdated => _reviewUpdatedCtrl.stream;
  Stream<Map<String, dynamic>> get onNotification  => _notificationCtrl.stream;
  Stream<int>                  get onUnreadCount   => _unreadCountCtrl.stream;
  Stream<Set<String>>          get onOnlineUsers   => _onlineUsersCtrl.stream;
  Stream<Map<String, dynamic>> get onTaskCreated       => _taskCreatedCtrl.stream;
  Stream<Map<String, dynamic>> get onTaskUpdated       => _taskUpdatedCtrl.stream;
  Stream<Map<String, dynamic>> get onTaskDeleted       => _taskDeletedCtrl.stream;
  Stream<Map<String, dynamic>> get onTaskStatusChanged => _taskStatusChangedCtrl.stream;

  int          _unreadCount = 0;
  int          get unreadCount  => _unreadCount;

  final Set<String> _onlineUsers = {};
  Set<String>  get onlineUsers  => Set.unmodifiable(_onlineUsers);

  bool get isConnected => _socket?.connected ?? false;

  /// Seed online users from the REST GET /users/online response.
  void seedOnlineUsers(List<String> ids) {
    _onlineUsers
      ..clear()
      ..addAll(ids);
    _onlineUsersCtrl.add(Set.unmodifiable(_onlineUsers));
  }

  bool isUserOnline(String userId) => _onlineUsers.contains(userId);

  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      AppConfig.baseUrl,
      <String, dynamic>{
        'transports':          ['polling', 'websocket'],
        'withCredentials':     true,
        'autoConnect':         false,
        'reconnection':        true,
        'reconnectionDelay':   2000,      // start at 2 s
        'reconnectionDelayMax': 30000,    // cap at 30 s
        'randomizationFactor': 0.5,
        'timeout':             20000,     // connection timeout
      },
    );

    _socket!
      ..on('connect', (_) => debugPrint('[Socket] Connected'))
      ..on('disconnect', (reason) => debugPrint('[Socket] Disconnected: $reason'))
      ..on('connect_error', (e) => debugPrint('[Socket] Error: $e'))
      ..on('new_message', (data) {
        if (data is Map) {
          _newMessageCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('review_updated', (data) {
        if (data is Map) {
          _reviewUpdatedCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('notification', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          _notificationCtrl.add(payload);
          _unreadCount++;
          _unreadCountCtrl.add(_unreadCount);
        }
      })
      ..on('user_online', (data) {
        if (data is Map) {
          final userId = data['userId'] as String?;
          if (userId != null) {
            _onlineUsers.add(userId);
            _onlineUsersCtrl.add(Set.unmodifiable(_onlineUsers));
          }
        }
      })
      ..on('user_offline', (data) {
        if (data is Map) {
          final userId = data['userId'] as String?;
          if (userId != null) {
            _onlineUsers.remove(userId);
            _onlineUsersCtrl.add(Set.unmodifiable(_onlineUsers));
          }
        }
      })
      ..on('task_created', (data) {
        if (data is Map) _taskCreatedCtrl.add(Map<String, dynamic>.from(data));
      })
      ..on('task_updated', (data) {
        if (data is Map) _taskUpdatedCtrl.add(Map<String, dynamic>.from(data));
      })
      ..on('task_deleted', (data) {
        if (data is Map) _taskDeletedCtrl.add(Map<String, dynamic>.from(data));
      })
      ..on('task_status_changed', (data) {
        if (data is Map) _taskStatusChangedCtrl.add(Map<String, dynamic>.from(data));
      });

    _socket!.connect();
  }

  /// Call when the user opens the Chat page — clears the badge.
  void clearUnreadCount() {
    _unreadCount = 0;
    _unreadCountCtrl.add(0);
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
    debugPrint('[Socket] Joined conv:$conversationId');
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', conversationId);
    debugPrint('[Socket] Left conv:$conversationId');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _onlineUsers.clear();
  }

  void dispose() {
    disconnect();
    _newMessageCtrl.close();
    _reviewUpdatedCtrl.close();
    _notificationCtrl.close();
    _unreadCountCtrl.close();
    _onlineUsersCtrl.close();
    _taskCreatedCtrl.close();
    _taskUpdatedCtrl.close();
    _taskDeletedCtrl.close();
    _taskStatusChangedCtrl.close();
  }
}
