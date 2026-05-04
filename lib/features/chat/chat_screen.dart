import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show ByteBuffer;
import 'dart:ui' show ImageFilter;
import 'dart:math' show min;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';
import '../../core/socket/socket_service.dart';

// ── Design tokens (match the rest of the app) ──────────────────────────────────
const _kAccent  = Color(0xFFE94560);
const _kPrimary = Color(0xFF1A1A2E);
const _kBg      = Color(0xFFF7F8FA);
const _kBorder  = Color(0xFFE8ECF3);

// ── Models ─────────────────────────────────────────────────────────────────────

enum _Status { online, away, offline }

class _Contact {
  final String  id;
  final String  name;
  final String  role;
  final String  initials;
  final Color   avatarColor;
  final _Status status;
  final String  lastSeen;  // display string e.g. "15 mins"
  final String  preview;   // last message snippet
  final int     unreadCount;

  const _Contact({
    required this.id,
    required this.name,
    required this.role,
    required this.initials,
    required this.avatarColor,
    required this.status,
    required this.lastSeen,
    required this.preview,
    this.unreadCount = 0,
  });
}

class _Message {
  // When dateLabel is non-null the row renders as a date separator, not a bubble.
  final String?        dateLabel;
  final String?        id;           // backend message ID — used for read-tick comparison
  final String?        createdAtIso; // raw ISO from backend — compared against last_read_by
  final String?        text;
  final bool           sent;
  final String         time;
  final String?        senderName;  // shown in group chats
  final String?        imageCaption;
  final _ChatTask?     task;       // task_review card
  final _PauseRequest? pauseReq;  // pause_request card
  final _IdeaRequest?  ideaReq;   // idea_request card
  // Attachment fields (from upload endpoint)
  final String?        attachmentUrl;
  final String?        attachmentType;
  final String?        attachmentName;
  final int?           attachmentSize;

  const _Message({
    this.dateLabel,
    this.id,
    this.createdAtIso,
    this.text,
    this.sent        = false,
    this.time        = '',
    this.senderName,
    this.imageCaption,
    this.task,
    this.pauseReq,
    this.ideaReq,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.attachmentSize,
  });
}

// ── Pause request model ───────────────────────────────────────────────────────

class _PauseRequest {
  final String  id;
  final String  reason;
  final String? note;
  final String  taskTitle;
  final String  requestedBy; // uuid — to detect if current user is assignee
  String        status;      // pending | approved | denied

  _PauseRequest({
    required this.id,
    required this.reason,
    this.note,
    required this.taskTitle,
    required this.requestedBy,
    this.status = 'pending',
  });

  factory _PauseRequest.fromJson(Map<String, dynamic> j) => _PauseRequest(
    id:          j['id'] as String? ?? '',
    reason:      (j['reason'] as String? ?? '').replaceAll('_', ' '),
    note:        j['note'] as String?,
    taskTitle:   j['task_title'] as String? ?? '',
    requestedBy: j['requested_by'] as String? ?? '',
    status:      j['status'] as String? ?? 'pending',
  );
}

// ── Idea request model ────────────────────────────────────────────────────────

class _IdeaRequest {
  final String id;
  final String reason;
  final String taskTitle;
  final String requestedBy;
  String       status; // pending | approved | denied

  _IdeaRequest({
    required this.id,
    required this.reason,
    required this.taskTitle,
    required this.requestedBy,
    this.status = 'pending',
  });

  factory _IdeaRequest.fromJson(Map<String, dynamic> j) => _IdeaRequest(
    id:          j['id'] as String? ?? '',
    reason:      j['reason'] as String? ?? '',
    taskTitle:   j['task_title'] as String? ?? '',
    requestedBy: j['requested_by'] as String? ?? '',
    status:      j['status'] as String? ?? 'pending',
  );
}

// ── Internal: rendered list item types ────────────────────────────────────────

class _DaySeparator {
  final String label;
  const _DaySeparator({required this.label});
}

// ── Task review models ────────────────────────────────────────────────────────

enum _TaskReviewStatus { pending, completed, rejected, none }

class _ChatTask {
  final String  messageId;  // ops_messages.id — needed to call reviewTask API
  final String  taskId;     // ops_tasks.id
  final String  title;
  final String  description;
  final String  assignee;
  final String  reviewerName;
  final String  reviewerId;
  final String  priority;   // Urgent / High / Medium / Low
  final String  type;
  final String  status;     // todo / in_progress / completed / etc.
  final String  date;       // display string
  final String? endDate;    // display string, nullable
  bool          isPaused;
  final int     commentCount;
  final bool    isNotification; // task_created — info card, no actions
  _TaskReviewStatus              reviewStatus;
  Map<String, dynamic>?          pendingPauseRequest; // non-null = pause needs approval

  _ChatTask({
    required this.messageId,
    required this.taskId,
    required this.title,
    required this.description,
    required this.assignee,
    this.reviewerName         = '',
    this.reviewerId           = '',
    required this.priority,
    required this.type,
    this.status               = '',
    required this.date,
    this.endDate              = null,
    this.isPaused             = false,
    this.commentCount         = 0,
    this.isNotification       = false,
    this.reviewStatus         = _TaskReviewStatus.pending,
    this.pendingPauseRequest,
  });
}

// ── Mock data ──────────────────────────────────────────────────────────────────

// ignore: unused_element
const _kContacts = <_Contact>[
  _Contact(
    id: '1', name: 'Kaiya George',    role: 'Project Manager',
    initials: 'KG', avatarColor: Color(0xFF5B8CFF),
    status: _Status.online,  lastSeen: '15 mins',
    preview: 'Sure, let me check the schedule.',
  ),
  _Contact(
    id: '2', name: 'Lindsey Curtis',  role: 'Designer',
    initials: 'LC', avatarColor: Color(0xFF1A1A2E),
    status: _Status.online,  lastSeen: '30 mins',
    preview: 'Please preview the image',
  ),
  _Contact(
    id: '3', name: 'Zain Geidt',      role: 'Content Writer',
    initials: 'ZG', avatarColor: Color(0xFF4CAF50),
    status: _Status.online,  lastSeen: '45 mins',
    preview: 'I want more detailed information.',
  ),
  _Contact(
    id: '4', name: 'Carla George',    role: 'Front-end Developer',
    initials: 'CG', avatarColor: Color(0xFF424242),
    status: _Status.away,    lastSeen: '2 days',
    preview: 'Can you review my PR?',
  ),
  _Contact(
    id: '5', name: 'Abram Schleifer', role: 'Digital Marketer',
    initials: 'AS', avatarColor: Color(0xFF607D8B),
    status: _Status.online,  lastSeen: '1 hour',
    preview: 'The campaign is live!',
  ),
  _Contact(
    id: '6', name: 'Lincoln Donin',   role: 'Product Designer',
    initials: 'LD', avatarColor: Color(0xFFE94560),
    status: _Status.offline, lastSeen: '3 days',
    preview: 'Let me know when you are free.',
  ),
];

// Messages per contact id — mutable so task status can change in-place.
// ignore: unused_element
final _kMessagesByContact = <String, List<_Message>>{
  '2': [
    const _Message(dateLabel: 'Yesterday'),
    const _Message(
      text: 'I want to make an appointment tomorrow from 2:00 to 5:00pm?',
      sent: false, time: '30 mins ago',
    ),
    const _Message(
      text: "If don't like something, I'll stay away from it.",
      sent: true,  time: '2 hours ago',
    ),
    const _Message(
      text: 'I want more detailed information.',
      sent: false, time: '2 hours ago',
    ),
    const _Message(
      text: 'They got there early, and got really good seats.',
      sent: true,  time: '2 hours ago',
    ),
    const _Message(imageCaption: 'Please preview the image', sent: false, time: '2 hours ago'),
    const _Message(dateLabel: 'Today'),
    const _Message(
      text: 'Good morning! Did you get a chance to look at the designs?',
      sent: false, time: '9:00 AM',
    ),
    const _Message(
      text: 'Yes, they look great! Just a few minor tweaks needed.',
      sent: true,  time: '9:15 AM',
    ),
    const _Message(
      text: 'Can you send me the updated file when ready?',
      sent: false, time: '9:20 AM',
    ),
  ],
  '1': [
    const _Message(dateLabel: 'Today'),
    const _Message(
      text: "Hey, I've finished the auth flow task. Marking it as done now.",
      sent: false, time: '10:30 AM',
    ),
    // Task review card — sent by the system when intern marks "Done"
    _Message(
      sent: false, time: '10:30 AM',
      task: _ChatTask(
        messageId:   'mock-msg-1',
        taskId:      'mock-task-1',
        title:       'Build auth flow',
        description: 'Implement GoTrue login, logout and session refresh',
        assignee:    'Bob',
        priority:    'High',
        type:        'Feature',
        date:        'Mar 30',
        commentCount: 2,
      ),
    ),
    const _Message(
      text: 'Nice work! Let me review it quickly.',
      sent: true, time: '10:45 AM',
    ),
  ],
  '3': [
    const _Message(dateLabel: 'Today'),
    const _Message(
      text: 'API docs are ready for review.',
      sent: false, time: '11:00 AM',
    ),
    _Message(
      sent: false, time: '11:00 AM',
      task: _ChatTask(
        messageId:   'mock-msg-2',
        taskId:      'mock-task-2',
        title:       'Write API documentation',
        description: 'Document all REST endpoints with examples and error codes',
        assignee:    'Charlie',
        priority:    'Low',
        type:        'Docs',
        date:        'Apr 2',
        commentCount: 0,
        reviewStatus: _TaskReviewStatus.completed,
      ),
    ),
    const _Message(
      text: 'Looks solid, approved!',
      sent: true, time: '11:20 AM',
    ),
  ],
};

// ── Screen ─────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final String? initialConvId;
  const ChatScreen({super.key, this.initialConvId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _selectedId = '';
  bool   _isMobile   = false; // updated each build, used in _loadConversations

  final _msgCtrl    = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late  final _msgFocus  = FocusNode(onKeyEvent: (_, event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      if (_msgCtrl.text.trim().isNotEmpty && _selectedId.isNotEmpty) {
        _sendMessage();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  });

  String _search = '';
  bool _loadingConversations = true;
  bool _loadingMessages = false;
  // Pagination state
  static const int _kMessagesPageSize = 30;
  bool _hasMoreMessages = false;
  bool _loadingMoreMessages = false;
  // API data
  List<Map<String, dynamic>> _conversations = [];
  List<_Message> _messages = [];
  String? _myUserId;

  // Per-conversation unread count (tracked via socket within this session)
  final Map<String, int> _unreadByConv = {};

  // last_read_by: maps other-user UUID → DateTime they last read up to
  Map<String, DateTime> _lastReadBy = {};

  bool _showScrollDown = false;

  StreamSubscription<html.Event>?           _pasteSub;

  // Socket subscriptions
  StreamSubscription<Map<String, dynamic>>? _newMsgSub;
  StreamSubscription<Map<String, dynamic>>? _reviewUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _conversationReadSub;
  StreamSubscription<Map<String, dynamic>>? _messagesReadSub;
  StreamSubscription<Set<String>>?          _onlineUsersSub;

  ApiClient       get _api    => context.read<ApiClient>();
  SocketService   get _socket => context.read<SocketService>();

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _myUserId = authState.user.id;
    }

    _scrollCtrl.addListener(_onScroll);
    _loadConversations();
    _subscribeSocket();
    _socket.clearUnreadCount();
    _pasteSub = html.window.on['paste'].listen((e) => _onClipboardPaste(e as html.ClipboardEvent));
  }

  void _subscribeSocket() {
    _newMsgSub        = _socket.onNewMessage.listen(_onSocketNewMessage);
    _reviewUpdatedSub = _socket.onReviewUpdated.listen(_onSocketReviewUpdated);
    _conversationReadSub = _socket.onConversationRead.listen(_onConversationRead);
    _messagesReadSub     = _socket.onMessagesRead.listen(_onMessagesRead);
    // Rebuild contact list when presence changes so dots update live.
    _onlineUsersSub   = _socket.onOnlineUsers.listen((_) { if (mounted) setState(() {}); });
  }

  void _onConversationRead(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    final unreadCount = data['unread_count'] as int?;
    if (convId == null || !mounted) return;
    
    // Update the unread count for this conversation
    setState(() {
      if (unreadCount != null && unreadCount == 0) {
        _unreadByConv.remove(convId);
      } else if (unreadCount != null) {
        _unreadByConv[convId] = unreadCount;
      }
    });
  }

  void _onMessagesRead(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    if (!mounted || convId != _selectedId) return;
    final readBy = data['read_by'] as String?;
    final readAt = data['read_at'] as String?;
    if (readBy == null || readAt == null) return;
    final dt = DateTime.tryParse(readAt);
    if (dt == null) return;
    setState(() => _lastReadBy[readBy] = dt);
  }

  void _onSocketNewMessage(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    // Always refresh sidebar preview
    _loadConversations();
    // If the message belongs to the open conversation, append it.
    // Skip own messages — they were already added optimistically in _sendMessage.
    if (convId == _selectedId) {
      final senderId = data['sender_id'] as String?;
      if (senderId == _myUserId) return;
      final parsed = _parseMessage(data);
      if (parsed != null && mounted) {
        setState(() => _messages.add(parsed));
        _scrollToBottom();
      }
    } else if (convId != null && mounted) {
      // Not the active chat — bump the per-conversation unread badge
      setState(() => _unreadByConv[convId] = (_unreadByConv[convId] ?? 0) + 1);
    }
  }

  void _onSocketReviewUpdated(Map<String, dynamic> data) {
    final msgId = data['message_id'] as String?;
    final status = data['review_status'] as String?;
    if (msgId == null || status == null || !mounted) return;
    setState(() {
      for (final msg in _messages) {
        if (msg.task?.messageId == msgId) {
          msg.task!.reviewStatus = _parseReviewStatus(status);
          break;
        }
      }
    });
  }

  /// Parses a raw message map (same shape as getMessages API) into a _Message.
  _Message? _parseMessage(Map<String, dynamic> m) {
    final type         = m['type'] as String? ?? 'text';
    final msgId        = m['id'] as String?;
    final createdAtIso = m['created_at'] as String?;
    final senderId     = m['sender_id'] as String?;
    final isSent       = senderId == _myUserId;
    final time         = _formatTime(createdAtIso ?? '');
    final senderName   = m['sender_name'] as String?;

    if (type == 'task_created' || type == 'task_review') {
      final isNotif = type == 'task_created';
      final task = m['task'] as Map<String, dynamic>?;
      String assigneeName = '';
      final assignees = task?['assignees'] as List?;
      if (assignees != null && assignees.isNotEmpty) {
        assigneeName = assignees.map((a) => (a as Map)['name']?.toString() ?? '').join(', ');
      }
      String reviewerName = '';
      String reviewerId   = '';
      final reviewers = task?['reviewers'] as List?;
      if (reviewers != null && reviewers.isNotEmpty) {
        reviewerName = reviewers.map((r) => (r as Map)['name']?.toString() ?? '').join(', ');
        reviewerId   = (reviewers.first as Map)['id']?.toString() ?? '';
      }
      final priorityRaw   = (task?['priority'] as String? ?? 'medium').toLowerCase();
      final priorityLabel = priorityRaw.isNotEmpty
          ? priorityRaw[0].toUpperCase() + priorityRaw.substring(1)
          : 'Medium';
      String? endDateStr;
      final rawEnd = task?['end_date'] as String?;
      if (rawEnd != null && rawEnd.isNotEmpty) {
        final dt = DateTime.tryParse(rawEnd);
        if (dt != null) endDateStr = _fmtDate(dt);
      }
      String dateStr = '';
      final rawDate = task?['date'] as String?;
      if (rawDate != null && rawDate.isNotEmpty) {
        final dt = DateTime.tryParse(rawDate);
        if (dt != null) dateStr = _fmtDate(dt);
      }
      return _Message(
        id: msgId, createdAtIso: createdAtIso,
        sent: isSent, time: time, senderName: senderName,
        task: task != null ? _ChatTask(
          messageId:           msgId ?? '',
          taskId:              task['id'] as String? ?? '',
          title:               task['title'] as String? ?? '',
          description:         task['description'] as String? ?? '',
          assignee:            assigneeName,
          reviewerName:        reviewerName,
          reviewerId:          reviewerId,
          priority:            priorityLabel,
          type:                task['type_name'] as String? ?? task['type'] as String? ?? '',
          status:              task['status'] as String? ?? '',
          date:                dateStr,
          endDate:             endDateStr,
          isPaused:            task['is_paused'] as bool? ?? false,
          isNotification:      isNotif,
          reviewStatus:        isNotif
              ? _TaskReviewStatus.none
              : _parseReviewStatus(m['review_status'] as String?),
          pendingPauseRequest: task['pending_pause_request'] as Map<String, dynamic>?,
        ) : null,
      );
    }

    return _Message(
      id: msgId, createdAtIso: createdAtIso,
      text:           m['content']         as String?,
      sent: isSent, time: time, senderName: senderName,
      attachmentUrl:  m['attachment_url']  as String?,
      attachmentType: m['attachment_type'] as String?,
      attachmentName: m['attachment_name'] as String?,
      attachmentSize: m['attachment_size'] as int?,
    );
  }

  void _selectConversation(String convId) {
    if (_selectedId == convId) return;
    if (_selectedId.isNotEmpty) _socket.leaveConversation(_selectedId);
    setState(() {
      _selectedId = convId;
      _unreadByConv.remove(convId);
    });
    _socket.joinConversation(convId);
    _loadMessages(convId);
    _markConversationAsRead(convId);
  }

  Future<void> _markConversationAsRead(String convId) async {
    try {
      await _api.markConversationAsRead(convId);
      // No need to reload - socket 'conversation_read' event will update the badge
    } catch (e) {
      // Silent fail - not critical for UX
      debugPrint('Failed to mark conversation as read: $e');
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 80;
    if (atBottom != !_showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }
    // Trigger lazy-load when within 200px of the top.
    if (_scrollCtrl.position.pixels <= 200 &&
        _hasMoreMessages &&
        !_loadingMoreMessages &&
        !_loadingMessages) {
      _loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _pasteSub?.cancel();
    _newMsgSub?.cancel();
    _reviewUpdatedSub?.cancel();
    _conversationReadSub?.cancel();
    _messagesReadSub?.cancel();
    _onlineUsersSub?.cancel();
    if (_selectedId.isNotEmpty) _socket.leaveConversation(_selectedId);
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _showNewChatDialog() async {
    // Load all users from directory
    List<Map<String, dynamic>> users = [];
    try {
      final res = await _api.getUserDirectory();
      users = (res.data as List).cast<Map<String, dynamic>>();
      // Remove self from the list
      users.removeWhere((u) => u['id'] == _myUserId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load users')),
        );
      }
      return;
    }
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _NewChatDialog(
        users: users,
        onUserSelected: (userId) async {
          Navigator.of(ctx).pop();
          // Create or open existing DM
          try {
            final res = await _api.createConversation({
              'type': 'direct',
              'member_ids': [userId],
            });
            final convId = (res.data as Map<String, dynamic>)['id'] as String;
            await _loadConversations();
            if (mounted) _selectConversation(convId);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to start conversation')),
              );
            }
          }
        },
        onGroupCreated: (name, memberIds) async {
          Navigator.of(ctx).pop();
          try {
            final res = await _api.createConversation({
              'type': 'group',
              'name': name,
              'member_ids': memberIds,
            });
            final convId = (res.data as Map<String, dynamic>)['id'] as String;
            await _loadConversations();
            if (mounted) _selectConversation(convId);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to create group')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingConversations = true);
    try {
      final res = await _api.getConversations(search: _search.isEmpty ? null : _search);
      _conversations = (res.data as List).cast<Map<String, dynamic>>();
      // Auto-select first conversation on desktop only.
      // On mobile we show the contacts list first (WhatsApp-style).
      // _isMobile is set each build — no BuildContext needed across the async gap.
      if (_selectedId.isEmpty && _conversations.isNotEmpty) {
        final deepLink = widget.initialConvId;
        final target = deepLink != null && _conversations.any((c) => c['id'] == deepLink)
            ? deepLink
            : (!_isMobile ? _conversations.first['id'] as String : null);
        if (target != null) _selectConversation(target);
      }
    } catch (_) {
      _conversations = [];
    }
    if (mounted) setState(() => _loadingConversations = false);
  }

  Future<void> _loadMessages(String conversationId) async {
    setState(() {
      _loadingMessages = true;
      _hasMoreMessages = false;
    });
    try {
      final res = await _api.getMessages(conversationId, limit: _kMessagesPageSize);
      final data = res.data as Map<String, dynamic>;
      final msgs = (data['messages'] as List).cast<Map<String, dynamic>>();
      _hasMoreMessages = data['has_more'] == true;

      // Populate _lastReadBy from server snapshot so ticks are correct on load.
      final rawLastRead = data['last_read_by'] as Map<String, dynamic>?;
      _lastReadBy = {};
      rawLastRead?.forEach((userId, ts) {
        if (userId != _myUserId) {
          final dt = DateTime.tryParse(ts as String? ?? '');
          if (dt != null) _lastReadBy[userId] = dt;
        }
      });

      _messages = msgs
          .map(_parseHistoryMessage)
          .toList()
          .reversed
          .toList(); // API returns newest first, we want oldest first
    } catch (_) {
      _messages = [];
    }
    if (mounted) setState(() => _loadingMessages = false);
    _scrollToBottom();
  }

  /// Loads the next page of older messages and prepends them, preserving the
  /// user's scroll position so they don't jump to the top.
  Future<void> _loadMoreMessages() async {
    if (_loadingMoreMessages || !_hasMoreMessages) return;
    if (_messages.isEmpty) return;
    final convId = _selectedId;
    if (convId.isEmpty) return;
    final cursor = _messages.first.createdAtIso;
    if (cursor == null || cursor.isEmpty) return;

    setState(() => _loadingMoreMessages = true);

    // Capture scroll position so we can restore it after the prepend.
    final beforeMax = _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;
    final beforePixels = _scrollCtrl.hasClients ? _scrollCtrl.position.pixels : 0.0;

    try {
      final res = await _api.getMessages(convId, limit: _kMessagesPageSize, cursor: cursor);
      if (convId != _selectedId || !mounted) return; // user switched chats mid-flight
      final data = res.data as Map<String, dynamic>;
      final msgs = (data['messages'] as List).cast<Map<String, dynamic>>();
      final older = msgs.map(_parseHistoryMessage).toList().reversed.toList();
      setState(() {
        _messages.insertAll(0, older);
        _hasMoreMessages = data['has_more'] == true;
      });

      // Restore scroll position: after the prepend, the new max is larger;
      // shift pixels by the delta so the user sees the same content they were
      // looking at before, instead of jumping to the top.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollCtrl.hasClients) return;
        final afterMax = _scrollCtrl.position.maxScrollExtent;
        final delta = afterMax - beforeMax;
        if (delta > 0) _scrollCtrl.jumpTo(beforePixels + delta);
      });
    } catch (_) {/* keep existing messages on error */} finally {
      if (mounted) setState(() => _loadingMoreMessages = false);
    }
  }

  _Message _parseHistoryMessage(Map<String, dynamic> m) {
    final type         = m['type'] as String? ?? 'text';
    final msgId        = m['id'] as String?;
    final createdAtIso = m['created_at'] as String?;
    final senderId     = m['sender_id'] as String?;
    final isSent       = senderId == _myUserId;
    final time         = _formatTime(createdAtIso ?? '');
    final senderName   = m['sender_name'] as String?;

    if (type == 'idea_request') {
      final ir = m['idea_request'] as Map<String, dynamic>?;
      if (ir != null) {
        return _Message(
          id: msgId, createdAtIso: createdAtIso,
          sent: isSent, time: time, senderName: senderName,
          ideaReq: _IdeaRequest.fromJson(ir),
        );
      }
    }

    if (type == 'pause_request') {
      final pr = m['pause_request'] as Map<String, dynamic>?;
      if (pr != null) {
        return _Message(
          id: msgId, createdAtIso: createdAtIso,
          sent: isSent, time: time, senderName: senderName,
          pauseReq: _PauseRequest.fromJson(pr),
        );
      }
    }

    if (type == 'task_created' || type == 'task_review') {
      final isNotif = type == 'task_created';
      final task = m['task'] as Map<String, dynamic>?;
      String assigneeName = '';
      final assignees = task?['assignees'] as List?;
      if (assignees != null && assignees.isNotEmpty) {
        assigneeName = assignees.map((a) => (a as Map)['name']?.toString() ?? '').join(', ');
      } else {
        assigneeName = task?['person_name']?.toString() ?? '';
      }
      final priorityRaw = (task?['priority'] as String? ?? 'medium').toLowerCase();
      final priorityLabel = priorityRaw.isNotEmpty
          ? priorityRaw[0].toUpperCase() + priorityRaw.substring(1)
          : 'Medium';
      String reviewerName = '';
      String reviewerId   = '';
      final reviewers = task?['reviewers'] as List?;
      if (reviewers != null && reviewers.isNotEmpty) {
        reviewerName = reviewers.map((r) => (r as Map)['name']?.toString() ?? '').join(', ');
        reviewerId   = (reviewers.first as Map)['id']?.toString() ?? '';
      }
      String? endDateStr;
      final rawEnd = task?['end_date'] as String?;
      if (rawEnd != null && rawEnd.isNotEmpty) {
        final dt = DateTime.tryParse(rawEnd);
        if (dt != null) endDateStr = _fmtDate(dt);
      }
      String dateStr = '';
      final rawDate = task?['date'] as String?;
      if (rawDate != null && rawDate.isNotEmpty) {
        final dt = DateTime.tryParse(rawDate);
        if (dt != null) dateStr = _fmtDate(dt);
      }
      return _Message(
        id: msgId, createdAtIso: createdAtIso,
        sent: isSent, time: time, senderName: senderName,
        task: task != null ? _ChatTask(
          messageId:           m['id'] as String? ?? '',
          taskId:              task['id'] as String? ?? '',
          title:               task['title'] as String? ?? '',
          description:         task['description'] as String? ?? '',
          assignee:            assigneeName,
          reviewerName:        reviewerName,
          reviewerId:          reviewerId,
          priority:            priorityLabel,
          type:                task['type_name'] as String? ?? task['type'] as String? ?? '',
          status:              task['status'] as String? ?? '',
          date:                dateStr,
          endDate:             endDateStr,
          isPaused:            task['is_paused'] as bool? ?? false,
          isNotification:      isNotif,
          reviewStatus:        isNotif
              ? _TaskReviewStatus.none
              : _parseReviewStatus(m['review_status'] as String?),
          pendingPauseRequest: task['pending_pause_request'] as Map<String, dynamic>?,
        ) : null,
      );
    }

    return _Message(
      id: msgId, createdAtIso: createdAtIso,
      text:           m['content']         as String?,
      sent: isSent, time: time, senderName: senderName,
      attachmentUrl:  m['attachment_url']  as String?,
      attachmentType: m['attachment_type'] as String?,
      attachmentName: m['attachment_name'] as String?,
      attachmentSize: _parseSize(m['attachment_size']),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  static _TaskReviewStatus _parseReviewStatus(String? s) => switch (s) {
    'completed' => _TaskReviewStatus.completed,
    'rejected'  => _TaskReviewStatus.rejected,
    _           => _TaskReviewStatus.pending,
  };

  String _formatTime(String isoString) {
    if (isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    final local = dt.toLocal();
    final clock = _clockTime(local);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(msgDay).inDays;
    if (diffDays == 0) return clock;
    if (diffDays == 1) return 'Yesterday, $clock';
    if (local.year == now.year) return '${_fmtDate(local)}, $clock';
    return '${_fmtDate(local)}, ${local.year}, $clock';
  }

  static String _clockTime(DateTime local) {
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }

  /// "Today" / "Yesterday" / "May 3" / "May 3, 2025"
  static String _dayLabel(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(msgDay).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (local.year == now.year) return _fmtDate(local);
    return '${_fmtDate(local)}, ${local.year}';
  }

  void _scrollToBottom() {
    // Two frames: first lets the ListView measure all items, second does the jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    });
  }

  // Build a _Contact from API conversation data
  _Contact _contactFromConversation(Map<String, dynamic> conv) {
    final members = (conv['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isGroup = conv['type'] == 'group';

    // For DMs: show the other person. For groups: show the group name.
    final other = members.firstWhere(
      (m) => m['id'] != _myUserId,
      orElse: () => members.isNotEmpty ? members.first : <String, dynamic>{},
    );
    final name = isGroup
        ? (conv['name'] as String? ?? 'Group')
        : (other['name'] as String? ?? 'Unknown');
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final lastMsg = conv['last_message'] as Map<String, dynamic>?;
    final lastType = lastMsg?['type'] as String?;
    final preview = lastType == 'task_created'
        ? 'New task assigned'
        : lastType == 'task_review'
            ? 'Task review'
            : lastType == 'pause_request'
                ? 'Pause request'
                : lastType == 'idea_request'
                    ? 'Idea move request'
                    : lastMsg?['content'] as String? ?? '';

    // Subtitle: DM → last message preview, Group → member names
    final subtitle = isGroup
        ? members.map((m) => m['name'] as String? ?? '').join(', ')
        : preview;

    // For DMs check live socket presence; groups don't have a single status.
    final otherId = isGroup ? null : other['id'] as String?;
    final status  = (!isGroup && otherId != null && _socket.isUserOnline(otherId))
        ? _Status.online
        : _Status.offline;

    final convId = conv['id'] as String;

    final backendUnread = conv['unread_count'] as int? ?? 0;
    final sessionUnread = _unreadByConv[convId] ?? 0;
    // Take whichever is higher — session tracks new socket messages after page load
    final unreadCount = sessionUnread > backendUnread ? sessionUnread : backendUnread;

    // Format last message timestamp for display
    final lastMsgTime = lastMsg?['created_at'] as String?;
    String lastSeen = '';
    if (lastMsgTime != null) {
      try {
        final dt = DateTime.parse(lastMsgTime).toLocal();
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          final h = dt.hour.toString().padLeft(2, '0');
          final m = dt.minute.toString().padLeft(2, '0');
          lastSeen = '$h:$m';
        } else {
          lastSeen = '${dt.day}/${dt.month}';
        }
      } catch (_) {}
    }

    return _Contact(
      id:          convId,
      name:        name,
      role:        subtitle,
      initials:    initials,
      avatarColor: _avatarColor(name),
      status:      status,
      lastSeen:    lastSeen,
      preview:     preview,
      unreadCount: unreadCount,
    );
  }

  static Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF5B8CFF), const Color(0xFF1A1A2E), const Color(0xFF4CAF50),
      const Color(0xFF424242), const Color(0xFF607D8B), const Color(0xFFE94560),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  _Contact get _active {
    final conv = _conversations.firstWhere(
      (c) => c['id'] == _selectedId,
      orElse: () => <String, dynamic>{},
    );
    if (conv.isEmpty) {
      return const _Contact(
        id: '', name: 'Select a chat', role: '', initials: '',
        avatarColor: Color(0xFF9E9E9E), status: _Status.offline,
        lastSeen: '', preview: '',
      );
    }
    return _contactFromConversation(conv);
  }

  @override
  Widget build(BuildContext context) {
    _isMobile = MediaQuery.of(context).size.width < 700;

    if (_isMobile) {
      // On mobile: show contacts list OR chat panel — not both at once
      final showChat = _selectedId.isNotEmpty;
      if (showChat) return _buildRightPanel(showBack: true);
      return _buildLeftPanel(fullWidth: true);
    }

    return Row(
      children: [
        _buildLeftPanel(),
        Container(width: 1, color: _kBorder), // vertical divider
        Expanded(child: _buildRightPanel()),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LEFT PANEL — contact list
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildLeftPanel({bool fullWidth = false}) {
    final contacts = _conversations.map((c) => _contactFromConversation(c)).toList();
    final filtered = _search.isEmpty
        ? contacts
        : contacts
            .where((c) =>
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.role.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    final panel = Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Text('Chats',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_square, size: 18, color: _kPrimary),
                tooltip: 'New chat',
                onPressed: _showNewChatDialog,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        // ── Contact rows ──────────────────────────────────────────────────
        Expanded(
          child: _loadingConversations
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('No conversations', style: TextStyle(color: Colors.grey, fontSize: 13)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _buildContactRow(filtered[i]),
                    ),
        ),
      ],
    );

    if (fullWidth) return panel;
    return SizedBox(width: 300, child: panel);
  }

  Widget _buildContactRow(_Contact c) {
    final isActive = c.id == _selectedId;
    return InkWell(
      onTap: () => _selectConversation(c.id),
      child: Container(
        // Subtle accent tint on the active row so it's obvious which chat is open.
        color: isActive ? _kAccent.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar + online-status dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: c.avatarColor,
                  child: Text(c.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: _StatusDot(c.status),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // Name + role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kPrimary)),
                  const SizedBox(height: 2),
                  Text(c.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            // Unread badge or timestamp
            if (c.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              )
            else
              Text(c.lastSeen,
                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — conversation
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildRightPanel({bool showBack = false}) {
    final contact = _active;
    return Column(
      children: [
        _buildTopBar(contact, showBack: showBack),
        Container(height: 1, color: _kBorder),
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _selectedId.isEmpty
                  ? const Center(child: Text('Select a conversation', style: TextStyle(color: Colors.grey)))
                  : Stack(
                      children: [
                        _buildMessages(contact),
                        if (_showScrollDown)
                          Positioned(
                            bottom: 12,
                            right: 16,
                            child: AnimatedOpacity(
                              opacity: _showScrollDown ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () => _scrollCtrl.animateTo(
                                  _scrollCtrl.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                ),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _kAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
        Container(height: 1, color: _kBorder),
        _buildInputBar(),
      ],
    );
  }

  Map<String, dynamic> get _activeConv => _conversations.firstWhere(
    (c) => c['id'] == _selectedId,
    orElse: () => <String, dynamic>{},
  );

  bool get _isGroupChat => _activeConv['type'] == 'group';

  bool get _canManageMembers {
    if (!_isGroupChat) return false;
    // Show the button for superAdmin, group creator, or when created_by is
    // null (legacy groups before migration). The backend enforces the real
    // 403 — this is just UX gating.
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated &&
        authState.user.role == UserRole.superAdmin) { return true; }
    final createdBy = _activeConv['created_by'];
    // If created_by is null (legacy group) or matches current user → show
    return createdBy == null || createdBy == _myUserId;
  }

  List<Map<String, dynamic>> get _activeMembers {
    final conv = _conversations.firstWhere(
      (c) => c['id'] == _selectedId,
      orElse: () => <String, dynamic>{},
    );
    return (conv['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // Top bar: avatar + name + status label + optional back button + call / video / more icons
  Widget _buildTopBar(_Contact c, {bool showBack = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () {
                if (_selectedId.isNotEmpty) {
                  _socket.leaveConversation(_selectedId);
                }
                setState(() => _selectedId = '');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.avatarColor,
                child: Text(c.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: _StatusDot(c.status),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary)),
              Text(_statusLabel(c.status),
                  style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(c.status))),
            ],
          ),
          const Spacer(),
          if (_canManageMembers) ...[
            IconButton(
              icon: Icon(Icons.group_outlined, size: 20, color: Colors.grey[600]),
              onPressed: _showManageMembers,
              tooltip: 'Members',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey[600]),
              onPressed: _confirmDeleteConversation,
              tooltip: 'Delete group',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteConversation() async {
    final name = _active.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Delete group?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "$name"? All messages will be lost.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteConversation(_selectedId);
      setState(() => _selectedId = '');
      _messages.clear();
      _loadConversations();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete group')),
        );
      }
    }
  }

  Future<void> _showManageMembers() async {
    // Load all users for the "add" picker
    List<Map<String, dynamic>> allUsers = [];
    try {
      final res = await _api.getUserDirectory();
      allUsers = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _ManageMembersDialog(
        members:  _activeMembers,
        allUsers: allUsers,
        myUserId: _myUserId ?? '',
        onAdd: (ids) async {
          try {
            await _api.addGroupMembers(_selectedId, ids);
            await _loadConversations();
            if (mounted) setState(() {});
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to add members')),
              );
            }
          }
        },
        onRemove: (userId) async {
          try {
            await _api.removeGroupMember(_selectedId, userId);
            await _loadConversations();
            if (mounted) setState(() {});
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to remove member: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // Scrollable message list — date separators are computed and interleaved
  // here from each message's `createdAtIso`, instead of stored as records.
  Widget _buildMessages(_Contact contact) {
    final messages = _messages;

    // Build a flat render list: each item is either a `_Message` or a
    // `_DaySeparator` (computed on the fly when the day changes).
    final items = <Object>[];
    String? lastDayKey;
    for (final msg in messages) {
      if (msg.dateLabel != null) {
        // Mock data still uses a literal label — render as-is, no key.
        items.add(_DaySeparator(label: msg.dateLabel!));
        continue;
      }
      final iso = msg.createdAtIso;
      DateTime? dt;
      if (iso != null && iso.isNotEmpty) dt = DateTime.tryParse(iso)?.toLocal();
      if (dt != null) {
        final dayKey =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        if (dayKey != lastDayKey) {
          items.add(_DaySeparator(label: _dayLabel(dt)));
          lastDayKey = dayKey;
        }
      }
      items.add(msg);
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      // Top loading spinner is item 0 when more pages exist.
      itemCount: items.length + (_loadingMoreMessages ? 1 : 0),
      itemBuilder: (_, i) {
        if (_loadingMoreMessages && i == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final idx = _loadingMoreMessages ? i - 1 : i;
        final item = items[idx];
        if (item is _DaySeparator) {
          return _buildDateSeparator(item.label);
        }
        final msg = item as _Message;
        if (msg.task != null)          return _buildTaskReviewCard(msg, contact);
        if (msg.pauseReq != null)      return _buildPauseRequestCard(msg, contact);
        if (msg.ideaReq != null)       return _buildIdeaRequestCard(msg, contact);
        if (msg.imageCaption != null)  return _buildImageMessage(msg, contact);
        if (msg.attachmentUrl != null || msg.attachmentName != null) {
          return _buildAttachmentBubble(msg, contact);
        }
        if (msg.text == null || msg.text!.isEmpty) return const SizedBox.shrink();
        return _buildTextBubble(msg, contact);
      },
    );

  }

  // "Yesterday" / "Today" separator line
  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider(color: _kBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ),
        const Expanded(child: Divider(color: _kBorder)),
      ]),
    );
  }

  // Plain text message bubble — left (received) or right (sent)
  Widget _buildTextBubble(_Message msg, _Contact contact) {
    final isSent = msg.sent;
    return LayoutBuilder(builder: (context, constraints) {
      final bubbleMaxWidth = constraints.maxWidth * 0.72;
      return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        // Sent = end (right), received = start (left)
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar shown only for received messages
          if (!isSent) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: contact.avatarColor,
              child: Text(contact.initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bubbleMaxWidth,
              ),
              child: Column(
                crossAxisAlignment:
                    isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender name — shown in group chats for received messages
                  if (!isSent && _isGroupChat && msg.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(msg.senderName!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _avatarColor(msg.senderName!))),
                    ),
                  // Bubble — accent bg for sent, light gray for received
                  GestureDetector(
                    onDoubleTap: () {
                      Clipboard.setData(ClipboardData(text: msg.text ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied to clipboard'),
                          duration: Duration(milliseconds: 1500),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSent ? _kAccent : _kBg,
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(12),
                          topRight:    const Radius.circular(12),
                          bottomLeft:  Radius.circular(isSent ? 12 : 2),
                          bottomRight: Radius.circular(isSent ? 2  : 12),
                        ),
                        border: isSent ? null : Border.all(color: _kBorder),
                      ),
                      child: _buildBubbleContent(msg.text ?? '', isSent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Timestamp + read ticks (sent messages only)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSent
                            ? msg.time
                            : _isGroupChat
                                ? msg.time
                                : '${contact.name}, ${msg.time}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                      if (isSent) ...[
                        const SizedBox(width: 3),
                        _buildReadTick(msg),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isSent) const SizedBox(width: 8),
        ],
      ),
    );
    }); // LayoutBuilder
  }

  bool _isMessageRead(_Message msg) {
    final iso = msg.createdAtIso;
    if (iso == null) return false;
    final sentAt = DateTime.tryParse(iso);
    if (sentAt == null) return false;
    return _lastReadBy.values.any((readAt) => !readAt.isBefore(sentAt));
  }

  Widget _buildReadTick(_Message msg) {
    final read = _isMessageRead(msg);
    return Icon(
      read ? Icons.done_all_rounded : Icons.done_rounded,
      size: 13,
      color: read ? const Color(0xFF34B7F1) : Colors.grey[400],
    );
  }

  // Renders plain text or a formatted JSON block with a copy button.
  Widget _buildBubbleContent(String text, bool isSent) {
    final trimmed = text.trim();
    // Detect JSON: must start with { or [
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final parsed   = jsonDecode(trimmed);
        final pretty   = const JsonEncoder.withIndent('  ').convert(parsed);
        final codeBg   = isSent ? Colors.black12 : const Color(0xFFEEF1F6);
        final codeText = isSent ? Colors.white    : _kPrimary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('JSON',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSent ? Colors.white70 : Colors.grey[500])),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pretty));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(milliseconds: 1500),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Icon(Icons.copy_rounded,
                      size: 14,
                      color: isSent ? Colors.white70 : Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        codeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                pretty,
                style: TextStyle(
                    fontSize:   11,
                    fontFamily: 'monospace',
                    height:     1.5,
                    color:      codeText),
              ),
            ),
          ],
        );
      } catch (_) {
        // Not valid JSON — fall through to plain text
      }
    }
    
    // Check if text contains URLs
    return _buildTextWithLinks(text, isSent);
  }

  // Build text with clickable links
  Widget _buildTextWithLinks(String text, bool isSent) {
    // URL regex pattern
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    
    final matches = urlPattern.allMatches(text);
    
    if (matches.isEmpty) {
      // No links, return plain text
      return Text(text,
          style: TextStyle(
              fontSize: 13, color: isSent ? Colors.white : _kPrimary));
    }
    
    // Build text with clickable links
    final spans = <InlineSpan>[];
    int lastIndex = 0;
    
    for (final match in matches) {
      // Add text before the link
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
              fontSize: 13, color: isSent ? Colors.white : _kPrimary),
        ));
      }
      
      // Add clickable link
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          fontSize: 13,
          color: isSent ? Colors.white : const Color(0xFF0085FF),
          decoration: TextDecoration.underline,
          decorationColor: isSent ? Colors.white : const Color(0xFF0085FF),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchURL(url),
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text after the last link
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
            fontSize: 13, color: isSent ? Colors.white : _kPrimary),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  // Launch URL in browser
  Future<void> _launchURL(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid URL: $urlString')),
        );
      }
    }
  }

  // Image message — thumbnail placeholder + caption + timestamp
  Widget _buildImageMessage(_Message msg, _Contact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: contact.avatarColor,
            child: Text(contact.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image placeholder — a soft blue-gray rectangle mimicking
                      // the mountain-fog photo in the reference screenshot.
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(9)),
                        child: Container(
                          height: 130,
                          color: const Color(0xFFB0C4DE),
                          child: const Center(
                            child: Icon(Icons.image_outlined,
                                size: 40, color: Colors.white60),
                          ),
                        ),
                      ),
                      // Caption below the image
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(msg.imageCaption!,
                            style: const TextStyle(
                                fontSize: 12, color: _kPrimary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('${contact.name}, ${msg.time}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Task review card inside chat ────────────────────────────────────────────

  Future<void> _reviewPauseFromChat(_ChatTask task, String reqId, String status) async {
    final previous = task.pendingPauseRequest;
    setState(() {
      task.pendingPauseRequest = null;
      if (status == 'approved') task.isPaused = true;
    });
    try {
      await _api.reviewPauseRequest(reqId, status);
    } catch (_) {
      if (!mounted) return;
      setState(() => task.pendingPauseRequest = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $status pause request')),
      );
    }
  }

  Future<void> _reviewTaskFromChat(_ChatTask task, String status) async {
    // No messageId means it's a mock task — just update locally
    if (task.messageId.isEmpty || task.messageId.startsWith('mock-')) {
      setState(() {
        task.reviewStatus = status == 'completed'
            ? _TaskReviewStatus.completed
            : _TaskReviewStatus.rejected;
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    // Optimistic update
    final previous = task.reviewStatus;
    setState(() {
      task.reviewStatus = status == 'completed'
          ? _TaskReviewStatus.completed
          : _TaskReviewStatus.rejected;
    });

    try {
      await _api.reviewTaskFromChat(task.messageId, status);
    } catch (_) {
      if (!mounted) return;
      // Revert on failure
      setState(() => task.reviewStatus = previous);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to ${status == 'completed' ? 'approve' : 'reject'} task')),
      );
    }
  }

  Widget _buildTaskReviewCard(_Message msg, _Contact contact) {
    final task = msg.task!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: contact.avatarColor,
            child: Text(contact.initials,
                style: const TextStyle(
                    color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChatTaskCard(
                  task:          task,
                  onReject:      () => _reviewTaskFromChat(task, 'rejected'),
                  onComplete:    () => _reviewTaskFromChat(task, 'completed'),
                  onTap:         () => _showTaskPreview(context, task),
                  currentUserId: _myUserId,
                  onPauseReview: (reqId, status) => _reviewPauseFromChat(task, reqId, status),
                ),
                const SizedBox(height: 4),
                Text('${contact.name}, ${msg.time}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseRequestCard(_Message msg, _Contact contact) {
    final pr = msg.pauseReq!;
    final isReviewer = pr.requestedBy != _myUserId; // reviewer is the non-requester
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: contact.avatarColor,
            child: Text(contact.initials,
                style: const TextStyle(
                    color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PauseRequestCard(
                  pauseReq:  pr,
                  isReviewer: isReviewer,
                  onApprove: () => _reviewPauseReqCard(pr, 'approved'),
                  onDeny:    () => _reviewPauseReqCard(pr, 'denied'),
                ),
                const SizedBox(height: 4),
                Text('${contact.name}, ${msg.time}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewPauseReqCard(_PauseRequest pr, String status) async {
    final previous = pr.status;
    setState(() => pr.status = status);
    try {
      await _api.reviewPauseRequest(pr.id, status);
    } catch (_) {
      if (!mounted) return;
      setState(() => pr.status = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $status pause request')),
      );
    }
  }

  Widget _buildIdeaRequestCard(_Message msg, _Contact contact) {
    final ir = msg.ideaReq!;
    final isReviewer = ir.requestedBy != _myUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: contact.avatarColor,
            child: Text(contact.initials,
                style: const TextStyle(
                    color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IdeaRequestCard(
                  ideaReq:    ir,
                  isReviewer: isReviewer,
                  onApprove:  () => _reviewIdeaReqCard(ir, 'approved'),
                  onDeny:     () => _reviewIdeaReqCard(ir, 'denied'),
                ),
                const SizedBox(height: 4),
                Text('${contact.name}, ${msg.time}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewIdeaReqCard(_IdeaRequest ir, String status) async {
    final previous = ir.status;
    setState(() => ir.status = status);
    try {
      await _api.reviewIdeaRequest(ir.id, status);
    } catch (_) {
      if (!mounted) return;
      setState(() => ir.status = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $status idea request')),
      );
    }
  }

  // ── Task preview dialog ──────────────────────────────────────────────────────

  void _showTaskPreview(BuildContext context, _ChatTask task) {
    final isCompleted = task.reviewStatus == _TaskReviewStatus.completed;
    final isRejected  = task.reviewStatus == _TaskReviewStatus.rejected;

    final priorityColor = switch (task.priority) {
      'High'   => const Color(0xFFEF4444),
      'Medium' => const Color(0xFFF59E0B),
      'Low'    => const Color(0xFF3B82F6),
      _        => const Color(0xFF9CA3AF),
    };

    final rawStatus = task.status.isNotEmpty ? task.status : (isCompleted ? 'completed' : isRejected ? 'rejected' : 'in_review');
    final statusLabel = rawStatus.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
    final statusColor = switch (rawStatus) {
      'completed'   => const Color(0xFF10B981),
      'rejected'    => const Color(0xFFEF4444),
      'in_progress' => const Color(0xFF6366F1),
      'todo'        => const Color(0xFF9CA3AF),
      'paused'      => const Color(0xFFF59E0B),
      _             => const Color(0xFFF59E0B),
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: min(560.0, MediaQuery.of(ctx).size.width * 0.9),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(task.title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E))),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE8ECF3)),
                            ),
                            child: const Icon(Icons.close, size: 14, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ]),
                    ),

                    // ── Body ───────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          if (task.description.isNotEmpty) ...[
                            Text(task.description,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
                            const SizedBox(height: 16),
                          ],

                          // Status
                          _previewRow(Icons.check_circle_outline_rounded, 'Status',
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: statusColor)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Priority
                          _previewRow(Icons.flag_outlined, 'Priority',
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(
                                      color: priorityColor, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(task.priority,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E))),
                            ]),
                          ),
                          const SizedBox(height: 10),

                          // Type
                          _previewRow(Icons.label_outline_rounded, 'Type',
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(task.type,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: Color(0xFF6366F1))),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Assignee
                          _previewRow(Icons.person_outline_rounded, 'Person',
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(0xFF6366F1 + (task.assignee.hashCode & 0x00FFFFFF)),
                                child: Text(task.assignee.isNotEmpty ? task.assignee[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 9, color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              Text(task.assignee,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E))),
                            ]),
                          ),
                          const SizedBox(height: 10),

                          // Date
                          _previewRow(Icons.calendar_today_outlined, 'Due date',
                            Text(task.date,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E))),
                          ),

                          // Comments
                          if (task.commentCount > 0) ...[
                            const SizedBox(height: 10),
                            _previewRow(Icons.chat_bubble_outline_rounded, 'Comments',
                              Text('${task.commentCount}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E))),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String label, Widget value) {
    return Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
      const SizedBox(width: 8),
      SizedBox(
        width: 70,
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ),
      value,
    ]);
  }

  // ── Bottom input bar ────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Emoji picker trigger
          IconButton(
            icon: Icon(Icons.sentiment_satisfied_alt_outlined,
                size: 22, color: Colors.grey[500]),
            onPressed: () {},
            tooltip: 'Emoji',
          ),
          // Text field — expands vertically as user types
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode:  _msgFocus,
                maxLines: 6,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          // Attachment
          IconButton(
            icon: Icon(Icons.attach_file_outlined,
                size: 20, color: Colors.grey[500]),
            onPressed: _selectedId.isEmpty ? null : _pickAndUploadFile,
            tooltip: 'Attach file',
          ),
          // Voice memo
          IconButton(
            icon: Icon(Icons.mic_none_outlined,
                size: 20, color: Colors.grey[500]),
            onPressed: () {},
            tooltip: 'Voice message',
          ),
          // Send button — accent fill when active, gray when empty
          // AnimatedContainer gives a smooth color transition as text is typed.
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 18),
              color: hasText ? Colors.white : Colors.grey[400],
              style: IconButton.styleFrom(
                backgroundColor: hasText ? _kAccent : _kBg,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
                side: hasText ? null : const BorderSide(color: _kBorder),
              ),
              onPressed: hasText ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _selectedId.isEmpty) return;
    _msgCtrl.clear();

    // Optimistically add the message locally
    final nowIso = DateTime.now().toUtc().toIso8601String();
    setState(() {
      _messages.add(_Message(
        createdAtIso: nowIso,
        text: text, sent: true,
        time: _formatTime(nowIso),
      ));
    });
    _scrollToBottom();

    try {
      await _api.sendMessage(_selectedId, text);
      // Reload conversations to update last_message preview
      _loadConversations();
    } catch (_) {}
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    await _uploadBytes(bytes, file.name, _mimeFromExtension(file.extension ?? ''),
        knownSize: file.size);
  }

  void _onClipboardPaste(html.ClipboardEvent event) {
    debugPrint('[Paste] fired, selectedId=$_selectedId, items=${event.clipboardData?.items?.length}');
    if (!mounted || _selectedId.isEmpty) return;
    final items = event.clipboardData?.items;
    if (items == null) return;
    for (int i = 0; i < (items.length ?? 0); i++) {
      final item = items[i];
      final mime = item.type ?? '';
      if (mime.startsWith('image/')) {
        final blob = item.getAsFile();
        if (blob == null) continue;
        event.preventDefault();
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoad.first.then((_) {
          final bytes = (reader.result as ByteBuffer).asUint8List();
          final ext   = mime.split('/').last;
          final name  = 'screenshot.${ext == 'jpeg' ? 'jpg' : ext}';
          _uploadBytes(bytes, name, mime);
        });
        return;
      }
    }
  }

  Future<void> _uploadBytes(
    List<int> bytes,
    String fileName,
    String mimeType, {
    int? knownSize,
  }) async {
    if (_selectedId.isEmpty) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    setState(() {
      _messages.add(_Message(
        createdAtIso:   nowIso,
        sent:           true,
        time:           _formatTime(nowIso),
        attachmentName: fileName,
        attachmentSize: knownSize ?? bytes.length,
        attachmentType: mimeType,
      ));
    });
    _scrollToBottom();

    try {
      final caption = _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim();
      final res = await _api.uploadMessageFile(
        _selectedId, bytes, fileName,
        content: caption,
      );
      _msgCtrl.clear();
      if (!mounted) return;
      final m = res.data as Map<String, dynamic>;
      setState(() {
        _messages.removeLast();
        _messages.add(_Message(
          id:             m['id']              as String?,
          createdAtIso:   m['created_at']      as String?,
          sent:           true,
          time:           _formatTime(m['created_at'] as String? ?? ''),
          text:           m['content']         as String?,
          attachmentUrl:  m['attachment_url']  as String?,
          attachmentType: m['attachment_type'] as String?,
          attachmentName: m['attachment_name'] as String?,
          attachmentSize: _parseSize(m['attachment_size']),
        ));
      });
      _scrollToBottom();
      _loadConversations();
    } catch (e) {
      debugPrint('[Upload] error: $e');
      if (!mounted) return;
      setState(() => _messages.removeLast());
      String msg = 'Failed to upload file';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] is String) msg = data['error'] as String;
        debugPrint('[Upload] status: ${e.response?.statusCode}, body: $data');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  static int? _parseSize(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      'gif'           => 'image/gif',
      'webp'          => 'image/webp',
      'pdf'           => 'application/pdf',
      _               => 'application/octet-stream',
    };
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Widget _buildAttachmentBubble(_Message msg, _Contact contact) {
    final isSent       = msg.sent;
    final isImage      = msg.attachmentType?.startsWith('image/') == true;
    final isPdf        = msg.attachmentType == 'application/pdf';
    final name         = msg.attachmentName ?? 'file';
    final sizeLabel    = msg.attachmentSize != null ? _formatFileSize(msg.attachmentSize!) : '';

    return LayoutBuilder(builder: (context, constraints) {
    final bubbleMaxWidth = constraints.maxWidth * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: contact.avatarColor,
              child: Text(contact.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bubbleMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isSent && _isGroupChat && msg.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(msg.senderName!,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: _avatarColor(msg.senderName!))),
                    ),
                  GestureDetector(
                    onTap: msg.attachmentUrl != null ? () => _launchURL(msg.attachmentUrl!) : null,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isSent ? _kAccent : _kBg,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(12),
                        topRight:    const Radius.circular(12),
                        bottomLeft:  Radius.circular(isSent ? 12 : 2),
                        bottomRight: Radius.circular(isSent ? 2  : 12),
                      ),
                      border: isSent ? null : Border.all(color: _kBorder),
                    ),
                    child: isImage && msg.attachmentUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft:     const Radius.circular(12),
                              topRight:    const Radius.circular(12),
                              bottomLeft:  Radius.circular(isSent ? 12 : 2),
                              bottomRight: Radius.circular(isSent ? 2  : 12),
                            ),
                            child: Image.network(
                              msg.attachmentUrl!,
                              width: 260,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildFileRow(
                                  name, sizeLabel, isPdf, isSent, uploading: false),
                            ),
                          )
                        : _buildFileRow(name, sizeLabel, isPdf, isSent,
                            uploading: msg.attachmentUrl == null),
                  ),
                ),
                if (msg.text != null && msg.text!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSent ? _kAccent : _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: isSent ? null : Border.all(color: _kBorder),
                    ),
                    child: Text(msg.text!,
                        style: TextStyle(fontSize: 13, color: isSent ? Colors.white : _kPrimary)),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSent ? msg.time : _isGroupChat ? msg.time : '${contact.name}, ${msg.time}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                    if (isSent) ...[
                      const SizedBox(width: 3),
                      _buildReadTick(msg),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
          if (isSent) const SizedBox(width: 8),
        ],
      ),
    );
    }); // LayoutBuilder
  }

  Widget _buildFileRow(String name, String size, bool isPdf, bool isSent, {bool uploading = false}) {
    final iconColor = isSent ? Colors.white70 : Colors.grey[600]!;
    final textColor = isSent ? Colors.white : _kPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          uploading
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: isSent ? Colors.white70 : _kAccent))
              : Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                  size: 22, color: iconColor),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (size.isNotEmpty)
                  Text(size, style: TextStyle(fontSize: 10, color: isSent ? Colors.white60 : Colors.grey[500])),
              ],
            ),
          ),
          if (!uploading) ...[
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, size: 14, color: iconColor),
          ],
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _statusColor(_Status s) => switch (s) {
    _Status.online  => Colors.green,
    _Status.away    => Colors.orange,
    _Status.offline => Colors.red,
  };

  String _statusLabel(_Status s) => switch (s) {
    _Status.online  => 'Online',
    _Status.away    => 'Away',
    _Status.offline => 'Offline',
  };
}

// ── Small reusable status dot widget ───────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final _Status status;
  const _StatusDot(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _Status.online  => Colors.green,
      _Status.away    => Colors.orange,
      _Status.offline => Colors.red,
    };
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // White ring so the dot is legible against any avatar color.
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

// ─── Task review card (reuses visual style of _TaskCard from tasks_screen) ───

const _kGreen  = Color(0xFF10B981);
const _kHigh   = Color(0xFFEF4444);
const _kMedium = Color(0xFFF59E0B);
const _kLow    = Color(0xFF3B82F6);
const _kMuted  = Color(0xFF9CA3AF);

class _ChatTaskCard extends StatelessWidget {
  final _ChatTask    task;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback? onTap;
  final String?      currentUserId;
  final void Function(String reqId, String status)? onPauseReview;

  const _ChatTaskCard({
    required this.task,
    required this.onReject,
    required this.onComplete,
    this.onTap,
    this.currentUserId,
    this.onPauseReview,
  });

  Color get _priorityColor => switch (task.priority) {
    'Urgent' => const Color(0xFF7C3AED),
    'High'   => _kHigh,
    'Medium' => _kMedium,
    'Low'    => _kLow,
    _        => _kMuted,
  };

  @override
  Widget build(BuildContext context) {
    final isNotif     = task.isNotification;
    final taskDone    = task.status == 'completed';
    final isPending   = !isNotif && task.reviewStatus == _TaskReviewStatus.pending && !taskDone;
    final isCompleted = !isNotif && (task.reviewStatus == _TaskReviewStatus.completed || taskDone);
    final isRejected  = !isNotif && task.reviewStatus == _TaskReviewStatus.rejected && !taskDone;

    final borderColor = isNotif
        ? const Color(0xFF6366F1)
        : isCompleted
            ? _kGreen
            : isRejected
                ? _kHigh
                : _kBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: borderColor, width: isCompleted || isRejected ? 1.5 : 1),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFF0FDF4)
                  : isRejected
                      ? const Color(0xFFFFF5F5)
                      : _kBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(children: [
              Icon(
                isNotif
                    ? Icons.task_alt_rounded
                    : isCompleted
                        ? Icons.check_circle_rounded
                        : isRejected
                            ? Icons.cancel_rounded
                            : Icons.assignment_outlined,
                size:  15,
                color: isNotif
                    ? const Color(0xFF6366F1)
                    : isCompleted ? _kGreen : isRejected ? _kHigh : _kPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                isNotif
                    ? 'New Task Assigned'
                    : isCompleted
                        ? 'Task Completed'
                        : isRejected
                            ? 'Task Rejected'
                            : 'Task Review',
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color: isNotif
                      ? const Color(0xFF6366F1)
                      : isCompleted ? _kGreen : isRejected ? _kHigh : _kPrimary,
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: _kBorder),

          // ── Card body (mirrors _TaskCard layout) ────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority + Type badges + paused badge
                Row(children: [
                  _Badge(task.priority, _priorityColor),
                  if (task.type.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(task.type, const Color(0xFF6366F1)),
                  ],
                  const Spacer(),
                  if (task.isPaused) ...[
                    const Icon(Icons.pause_circle_outline_rounded,
                        size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                  ],
                  if (isCompleted)
                    const Icon(Icons.check_circle_rounded, size: 14, color: _kGreen),
                ]),
                const SizedBox(height: 8),

                // Title
                Text(task.title,
                    style: TextStyle(
                      fontSize:      13,
                      fontWeight:    FontWeight.w600,
                      color:         isCompleted ? _kMuted : _kPrimary,
                      decoration:    isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: _kMuted,
                    )),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(task.description,
                      style: const TextStyle(fontSize: 11, color: _kMuted, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: _kBorder),
                const SizedBox(height: 10),

                // Assignee + reviewer
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.assignee.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius:          10,
                            backgroundColor: Color(0xFF6366F1 + (task.assignee.hashCode & 0x00FFFFFF)),
                            child: Text(task.assignee[0].toUpperCase(),
                                style: const TextStyle(fontSize: 9, color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(task.assignee,
                                style: const TextStyle(fontSize: 11, color: _kMuted),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (task.reviewerName.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 11, color: _kMuted),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(task.reviewerName,
                                style: const TextStyle(fontSize: 11, color: _kMuted),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Date + end_date + comment count
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.date.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: _kMuted),
                          const SizedBox(width: 3),
                          Text(
                            task.endDate != null
                                ? '${task.date} → ${task.endDate}'
                                : task.date,
                            style: const TextStyle(fontSize: 10, color: _kMuted),
                          ),
                        ],
                      ),
                    ],
                    if (task.commentCount > 0) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 11, color: _kMuted),
                          const SizedBox(width: 3),
                          Text('${task.commentCount}',
                              style: const TextStyle(fontSize: 10, color: _kMuted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Pause approve/deny (when pause request pending & viewer is reviewer) ──
          if (!isNotif &&
              task.pendingPauseRequest != null &&
              currentUserId != null &&
              currentUserId == task.reviewerId) ...[
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.pause_circle_outline_rounded,
                        size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pause requested — ${task.pendingPauseRequest!['reason'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  if ((task.pendingPauseRequest!['note'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Text(task.pendingPauseRequest!['note'] as String,
                          style: const TextStyle(fontSize: 11, color: _kMuted)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onPauseReview?.call(
                            task.pendingPauseRequest!['id'] as String, 'denied'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kHigh,
                          side: const BorderSide(color: _kHigh),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Deny', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onPauseReview?.call(
                            task.pendingPauseRequest!['id'] as String, 'approved'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Approve Pause', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ] else if (!isNotif && task.pendingPauseRequest != null) ...[
            // Assignee sees read-only pending pill
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                const Text('Pause awaiting approval',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B))),
              ]),
            ),
          ],

          // ── Action buttons (only reviewer can approve/reject) ─────────────
          if (isPending && currentUserId != null && task.reviewerId == currentUserId) ...[
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kHigh,
                      side:    const BorderSide(color: _kHigh),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onComplete,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Mark Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ]),
            ),
          ],

          // ── Status pill (after action taken) ────────────────────────────
          if (!isNotif && !isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size:  12,
                    color: isCompleted ? _kGreen : _kHigh,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted ? 'Completed' : 'Rejected',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      isCompleted ? _kGreen : _kHigh,
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

// ─── Reusable badge (priority / type) ─────────────────────────────────────────

// ─── Pause request card ───────────────────────────────────────────────────────

class _PauseRequestCard extends StatelessWidget {
  final _PauseRequest pauseReq;
  final bool         isReviewer;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _PauseRequestCard({
    required this.pauseReq,
    required this.isReviewer,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final isPending  = pauseReq.status == 'pending';
    final isApproved = pauseReq.status == 'approved';

    final borderColor = isApproved
        ? _kGreen
        : pauseReq.status == 'denied'
            ? _kHigh
            : const Color(0xFFF59E0B);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isApproved
                  ? const Color(0xFFF0FDF4)
                  : pauseReq.status == 'denied'
                      ? const Color(0xFFFFF5F5)
                      : const Color(0xFFFFFBEB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(children: [
              Icon(
                isApproved
                    ? Icons.check_circle_rounded
                    : pauseReq.status == 'denied'
                        ? Icons.cancel_rounded
                        : Icons.pause_circle_outline_rounded,
                size:  15,
                color: isApproved ? _kGreen : pauseReq.status == 'denied' ? _kHigh : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                isApproved ? 'Pause Approved' : pauseReq.status == 'denied' ? 'Pause Denied' : 'Pause Requested',
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color: isApproved ? _kGreen : pauseReq.status == 'denied' ? _kHigh : const Color(0xFFF59E0B),
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: _kBorder),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pauseReq.taskTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.label_outline_rounded, size: 12, color: _kMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Reason: ${pauseReq.reason}',
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (pauseReq.note != null && pauseReq.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.notes_rounded, size: 12, color: _kMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(pauseReq.note!,
                          style: const TextStyle(fontSize: 12, color: _kMuted),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ],
            ),
          ),

          // Approve / Deny buttons — reviewer only, pending only
          if (isPending && isReviewer) ...[
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDeny,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kHigh,
                      side:    const BorderSide(color: _kHigh),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Deny', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ]),
            ),
          ] else if (!isPending) ...[
            // Status stamp
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 12,
                    color: isApproved ? _kGreen : _kHigh,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isApproved ? 'Approved' : 'Denied',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      isApproved ? _kGreen : _kHigh,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Idea request card ────────────────────────────────────────────────────────

class _IdeaRequestCard extends StatelessWidget {
  final _IdeaRequest ideaReq;
  final bool         isReviewer;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _IdeaRequestCard({
    required this.ideaReq,
    required this.isReviewer,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final isPending  = ideaReq.status == 'pending';
    final isApproved = ideaReq.status == 'approved';

    final accentColor = const Color(0xFF8B5CF6); // violet for ideas
    final borderColor = isApproved
        ? _kGreen
        : ideaReq.status == 'denied'
            ? _kHigh
            : accentColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isApproved
                  ? const Color(0xFFF0FDF4)
                  : ideaReq.status == 'denied'
                      ? const Color(0xFFFFF5F5)
                      : const Color(0xFFF5F3FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(children: [
              Icon(
                isApproved
                    ? Icons.check_circle_rounded
                    : ideaReq.status == 'denied'
                        ? Icons.cancel_rounded
                        : Icons.lightbulb_outline_rounded,
                size:  15,
                color: isApproved ? _kGreen : ideaReq.status == 'denied' ? _kHigh : accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                isApproved ? 'Moved to Ideas' : ideaReq.status == 'denied' ? 'Idea Denied' : 'Idea Move Requested',
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color: isApproved ? _kGreen : ideaReq.status == 'denied' ? _kHigh : accentColor,
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: _kBorder),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ideaReq.taskTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.notes_rounded, size: 12, color: _kMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(ideaReq.reason,
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
            ),
          ),

          // Approve / Deny — reviewer + pending only
          if (isPending && isReviewer) ...[
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDeny,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kHigh,
                      side:    const BorderSide(color: _kHigh),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Deny', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Move to Ideas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                ),
              ]),
            ),
          ] else if (!isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 12,
                    color: isApproved ? _kGreen : _kHigh,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isApproved ? 'Moved to Ideas' : 'Denied',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      isApproved ? _kGreen : _kHigh,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

// ─── New Chat Dialog ─────────────────────────────────────────────────────────

class _NewChatDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final void Function(String userId)                    onUserSelected;
  final void Function(String name, List<String> ids)    onGroupCreated;

  const _NewChatDialog({
    required this.users,
    required this.onUserSelected,
    required this.onGroupCreated,
  });

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  bool _groupMode = false;
  final Set<String> _selected = {};
  final _groupNameCtrl = TextEditingController();
  final _searchCtrl    = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? widget.users
      : widget.users
          .where((u) =>
              (u['name'] as String).toLowerCase().contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 360,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(children: [
                Text(_groupMode ? 'New Group' : 'New Chat',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _groupMode = !_groupMode;
                    _selected.clear();
                  }),
                  child: Text(
                    _groupMode ? 'Direct' : 'Group',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),

            // ── Group name field (only in group mode) ──────────────────
            if (_groupMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _groupNameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:  'Group name',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    isDense:   true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

            // ── Search ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:  'Search people...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // ── User list ──────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final u    = _filtered[i];
                  final id   = u['id'] as String;
                  final name = u['name'] as String;
                  final role = u['role'] as String? ?? '';
                  final initials = name
                      .split(' ')
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase();
                  final isSel = _selected.contains(id);

                  return InkWell(
                    onTap: () {
                      if (_groupMode) {
                        setState(() {
                          if (isSel) {
                            _selected.remove(id);
                          } else {
                            _selected.add(id);
                          }
                        });
                      } else {
                        widget.onUserSelected(id);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              _kAccent.withValues(alpha: 0.12),
                          child: Text(initials,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kAccent)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kPrimary)),
                              if (role.isNotEmpty)
                                Text(role,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        if (_groupMode)
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: isSel ? _kAccent : Colors.transparent,
                              border: Border.all(
                                  color: isSel ? _kAccent : _kBorder,
                                  width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: isSel
                                ? const Icon(Icons.check,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),

            // ── Create group button (only in group mode) ───────────────
            if (_groupMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.length < 2 ||
                            _groupNameCtrl.text.trim().isEmpty
                        ? null
                        : () => widget.onGroupCreated(
                              _groupNameCtrl.text.trim(),
                              _selected.toList(),
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Create Group (${_selected.length} members)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Manage Group Members Dialog ─────────────────────────────────────────────

class _ManageMembersDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> allUsers;
  final String                     myUserId;
  final Future<void> Function(List<String> ids) onAdd;
  final Future<void> Function(String userId)    onRemove;

  const _ManageMembersDialog({
    required this.members,
    required this.allUsers,
    required this.myUserId,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<_ManageMembersDialog> {
  late List<Map<String, dynamic>> _members;
  bool _showAddPicker = false;
  final Set<String> _toAdd = {};

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.members);
  }

  List<Map<String, dynamic>> get _nonMembers {
    final memberIds = _members.map((m) => m['id']).toSet();
    return widget.allUsers.where((u) => !memberIds.contains(u['id'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 340,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(children: [
                const Text('Group Members',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
                const Spacer(),
                if (!_showAddPicker)
                  TextButton.icon(
                    onPressed: () => setState(() => _showAddPicker = true),
                    icon: const Icon(Icons.person_add_rounded, size: 14),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),

            // ── Add-member picker ────────────────────────────────────
            if (_showAddPicker) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _nonMembers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Everyone is already in this group',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: _nonMembers.map((u) {
                            final id = u['id'] as String;
                            final name = u['name'] as String;
                            final sel = _toAdd.contains(id);
                            return InkWell(
                              onTap: () => setState(() {
                                if (sel) { _toAdd.remove(id); } else { _toAdd.add(id); }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Row(children: [
                                  Icon(
                                    sel ? Icons.check_box : Icons.check_box_outline_blank,
                                    size: 16,
                                    color: sel ? _kAccent : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 13, color: _kPrimary)),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              if (_toAdd.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await widget.onAdd(_toAdd.toList());
                        if (mounted) {
                          // Refresh local state
                          for (final id in _toAdd) {
                            final u = widget.allUsers.firstWhere(
                              (x) => x['id'] == id,
                              orElse: () => <String, dynamic>{},
                            );
                            if (u.isNotEmpty) _members.add(u);
                          }
                          setState(() {
                            _toAdd.clear();
                            _showAddPicker = false;
                          });
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text('Add ${_toAdd.length} member${_toAdd.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
            ],

            const Divider(height: 1),

            // ── Current members list ─────────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final m    = _members[i];
                  final id   = m['id'] as String;
                  final name = m['name'] as String? ?? '';
                  final role = m['role'] as String? ?? '';
                  final isMe = id == widget.myUserId;
                  final initials = name
                      .split(' ')
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase();

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _kAccent.withValues(alpha: 0.12),
                        child: Text(initials,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kAccent)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isMe ? '$name (you)' : name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kPrimary)),
                            if (role.isNotEmpty)
                              Text(role,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      // Remove button — can't remove yourself
                      if (!isMe && _members.length > 2)
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              size: 18, color: Colors.grey[400]),
                          tooltip: 'Remove',
                          onPressed: () async {
                            await widget.onRemove(id);
                            if (mounted) {
                              setState(() => _members.removeAt(i));
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
