import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  const _Contact({
    required this.id,
    required this.name,
    required this.role,
    required this.initials,
    required this.avatarColor,
    required this.status,
    required this.lastSeen,
    required this.preview,
  });
}

class _Message {
  // When dateLabel is non-null the row renders as a date separator, not a bubble.
  final String?        dateLabel;
  final String?        text;
  final bool           sent;
  final String         time;
  final String?        senderName;  // shown in group chats
  final String?        imageCaption;
  final _ChatTask?     task;       // task_review card
  final _PauseRequest? pauseReq;  // pause_request card
  final _IdeaRequest?  ideaReq;   // idea_request card

  const _Message({
    this.dateLabel,
    this.text,
    this.sent        = false,
    this.time        = '',
    this.senderName,
    this.imageCaption,
    this.task,
    this.pauseReq,
    this.ideaReq,
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
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _selectedId = '';

  final _msgCtrl    = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _search = '';
  bool _loadingConversations = true;
  bool _loadingMessages = false;

  // API data
  List<Map<String, dynamic>> _conversations = [];
  List<_Message> _messages = [];
  String? _myUserId;

  // Socket subscriptions
  StreamSubscription<Map<String, dynamic>>? _newMsgSub;
  StreamSubscription<Map<String, dynamic>>? _reviewUpdatedSub;
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

    _loadConversations();
    _subscribeSocket();
    _socket.clearUnreadCount();
  }

  void _subscribeSocket() {
    _newMsgSub        = _socket.onNewMessage.listen(_onSocketNewMessage);
    _reviewUpdatedSub = _socket.onReviewUpdated.listen(_onSocketReviewUpdated);
    // Rebuild contact list when presence changes so dots update live.
    _onlineUsersSub   = _socket.onOnlineUsers.listen((_) { if (mounted) setState(() {}); });
  }

  void _onSocketNewMessage(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String?;
    // Always refresh sidebar preview
    _loadConversations();
    // If the message belongs to the open conversation, append it
    if (convId == _selectedId) {
      final parsed = _parseMessage(data);
      if (parsed != null && mounted) {
        setState(() => _messages.add(parsed));
        _scrollToBottom();
      }
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
    final type      = m['type'] as String? ?? 'text';
    final senderId  = m['sender_id'] as String?;
    final isSent    = senderId == _myUserId;
    final time      = _formatTime(m['created_at'] as String? ?? '');
    final senderName = m['sender_name'] as String?;

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
          type:                '',
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

    return _Message(text: m['content'] as String?, sent: isSent, time: time, senderName: senderName);
  }

  void _selectConversation(String convId) {
    if (_selectedId == convId) return;
    if (_selectedId.isNotEmpty) _socket.leaveConversation(_selectedId);
    setState(() => _selectedId = convId);
    _socket.joinConversation(convId);
    _loadMessages(convId);
  }

  @override
  void dispose() {
    _newMsgSub?.cancel();
    _reviewUpdatedSub?.cancel();
    _onlineUsersSub?.cancel();
    if (_selectedId.isNotEmpty) _socket.leaveConversation(_selectedId);
    _msgCtrl.dispose();
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
      if (_conversations.isNotEmpty && _selectedId.isEmpty) {
        _selectConversation(_conversations.first['id'] as String);
      }
    } catch (_) {
      _conversations = [];
    }
    if (mounted) setState(() => _loadingConversations = false);
  }

  Future<void> _loadMessages(String conversationId) async {
    setState(() => _loadingMessages = true);
    try {
      final res = await _api.getMessages(conversationId);
      final data = res.data as Map<String, dynamic>;
      final msgs = (data['messages'] as List).cast<Map<String, dynamic>>();

      _messages = msgs.map((m) {
        final type = m['type'] as String? ?? 'text';
        final senderId = m['sender_id'] as String?;
        final isSent = senderId == _myUserId;
        final time = _formatTime(m['created_at'] as String? ?? '');
        final senderName = m['sender_name'] as String?;

        if (type == 'idea_request') {
          final ir = m['idea_request'] as Map<String, dynamic>?;
          if (ir != null) {
            return _Message(
              sent:       isSent,
              time:       time,
              senderName: senderName,
              ideaReq:    _IdeaRequest.fromJson(ir),
            );
          }
        }

        if (type == 'pause_request') {
          final pr = m['pause_request'] as Map<String, dynamic>?;
          if (pr != null) {
            return _Message(
              sent:       isSent,
              time:       time,
              senderName: senderName,
              pauseReq:   _PauseRequest.fromJson(pr),
            );
          }
        }

        if (type == 'task_created' || type == 'task_review') {
          final isNotif = type == 'task_created';
          final task = m['task'] as Map<String, dynamic>?;
          // Extract all assignee names
          String assigneeName = '';
          final assignees = task?['assignees'] as List?;
          if (assignees != null && assignees.isNotEmpty) {
            assigneeName = assignees
                .map((a) => (a as Map)['name']?.toString() ?? '')
                .join(', ');
          } else {
            assigneeName = task?['person_name']?.toString() ?? '';
          }
          final priorityRaw = (task?['priority'] as String? ?? 'medium').toLowerCase();
          final priorityLabel = priorityRaw.isNotEmpty
              ? priorityRaw[0].toUpperCase() + priorityRaw.substring(1)
              : 'Medium';
          // Extract all reviewer names
          String reviewerName = '';
          String reviewerId   = '';
          final reviewers = task?['reviewers'] as List?;
          if (reviewers != null && reviewers.isNotEmpty) {
            reviewerName = reviewers
                .map((r) => (r as Map)['name']?.toString() ?? '')
                .join(', ');
            reviewerId = (reviewers.first as Map)['id']?.toString() ?? '';
          }
          // Format end_date
          String? endDateStr;
          final rawEnd = task?['end_date'] as String?;
          if (rawEnd != null && rawEnd.isNotEmpty) {
            final dt = DateTime.tryParse(rawEnd);
            if (dt != null) endDateStr = _fmtDate(dt);
          }
          // Format start date
          String dateStr = '';
          final rawDate = task?['date'] as String?;
          if (rawDate != null && rawDate.isNotEmpty) {
            final dt = DateTime.tryParse(rawDate);
            if (dt != null) dateStr = _fmtDate(dt);
          }
          return _Message(
            sent:       isSent,
            time:       time,
            senderName: senderName,
            task: task != null ? _ChatTask(
              messageId:    m['id'] as String? ?? '',
              taskId:       task['id'] as String? ?? '',
              title:        task['title'] as String? ?? '',
              description:  task['description'] as String? ?? '',
              assignee:     assigneeName,
              reviewerName:        reviewerName,
              reviewerId:          reviewerId,
              priority:            priorityLabel,
              type:                '',
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
          text:       m['content'] as String?,
          sent:       isSent,
          time:       time,
          senderName: senderName,
        );
      }).toList().reversed.toList(); // API returns newest first, we want oldest first
    } catch (_) {
      _messages = [];
    }
    if (mounted) setState(() => _loadingMessages = false);
    _scrollToBottom();
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
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
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

    // Subtitle: DM → role, Group → member names
    final subtitle = isGroup
        ? members.map((m) => m['name'] as String? ?? '').join(', ')
        : other['role'] as String? ?? '';

    // For DMs check live socket presence; groups don't have a single status.
    final otherId = isGroup ? null : other['id'] as String?;
    final status  = (!isGroup && otherId != null && _socket.isUserOnline(otherId))
        ? _Status.online
        : _Status.offline;

    return _Contact(
      id:          conv['id'] as String,
      name:        name,
      role:        subtitle,
      initials:    initials,
      avatarColor: _avatarColor(name),
      status:      status,
      lastSeen:    '',
      preview:     preview,
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

  Widget _buildLeftPanel() {
    final contacts = _conversations.map((c) => _contactFromConversation(c)).toList();
    final filtered = _search.isEmpty
        ? contacts
        : contacts
            .where((c) =>
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.role.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return SizedBox(
      width: 300,
      child: Column(
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
      ),
    );
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
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            // Timestamp — top-right aligned
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

  Widget _buildRightPanel() {
    final contact = _active;
    return Column(
      children: [
        _buildTopBar(contact),
        Container(height: 1, color: _kBorder),
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _selectedId.isEmpty
                  ? const Center(child: Text('Select a conversation', style: TextStyle(color: Colors.grey)))
                  : _buildMessages(contact),
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

  // Top bar: avatar + name + status label + call / video / more icons
  Widget _buildTopBar(_Contact c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
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

  // Scrollable message list
  Widget _buildMessages(_Contact contact) {
    final messages = _messages;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        if (msg.dateLabel != null)     return _buildDateSeparator(msg.dateLabel!);
        if (msg.task != null)          return _buildTaskReviewCard(msg, contact);
        if (msg.pauseReq != null)      return _buildPauseRequestCard(msg, contact);
        if (msg.ideaReq != null)       return _buildIdeaRequestCard(msg, contact);
        if (msg.imageCaption != null)  return _buildImageMessage(msg, contact);
        // Plain text — but skip rendering if there's nothing to show
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
          Column(
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
              Container(
                constraints: const BoxConstraints(maxWidth: 340),
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
                child: Text(msg.text ?? '',
                    style: TextStyle(
                        fontSize: 13,
                        color: isSent ? Colors.white : _kPrimary)),
              ),
              const SizedBox(height: 4),
              // Timestamp
              Text(
                isSent
                    ? msg.time
                    : _isGroupChat
                        ? msg.time
                        : '${contact.name}, ${msg.time}',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
          if (isSent) const SizedBox(width: 8),
        ],
      ),
    );
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 220,
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
          Column(
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
          Column(
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
          Column(
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

    final statusColor = isCompleted
        ? const Color(0xFF10B981)
        : isRejected
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final statusLabel = isCompleted ? 'Completed' : isRejected ? 'Rejected' : 'In Review';

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
                maxLines: null,   // grows vertically with content
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
            onPressed: () {},
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
    setState(() {
      _messages.add(_Message(text: text, sent: true, time: _formatTime(DateTime.now().toIso8601String())));
    });
    _scrollToBottom();

    try {
      await _api.sendMessage(_selectedId, text);
      // Reload conversations to update last_message preview
      _loadConversations();
    } catch (_) {}
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
    final isPending   = !isNotif && task.reviewStatus == _TaskReviewStatus.pending;
    final isCompleted = !isNotif && task.reviewStatus == _TaskReviewStatus.completed;
    final isRejected  = !isNotif && task.reviewStatus == _TaskReviewStatus.rejected;

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
      width: 320,
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
                Row(children: [
                  if (task.assignee.isNotEmpty) ...[
                    CircleAvatar(
                      radius:          10,
                      backgroundColor: Color(0xFF6366F1 + (task.assignee.hashCode & 0x00FFFFFF)),
                      child: Text(task.assignee[0].toUpperCase(),
                          style: const TextStyle(fontSize: 9, color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 5),
                    Text(task.assignee,
                        style: const TextStyle(fontSize: 11, color: _kMuted)),
                  ],
                  if (task.reviewerName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.shield_outlined, size: 11, color: _kMuted),
                    const SizedBox(width: 3),
                    Text(task.reviewerName,
                        style: const TextStyle(fontSize: 11, color: _kMuted)),
                  ],
                ]),
                const SizedBox(height: 6),
                // Date + end_date + comment count
                Row(children: [
                  if (task.date.isNotEmpty) ...[
                    Icon(Icons.calendar_today_outlined, size: 11, color: _kMuted),
                    const SizedBox(width: 3),
                    Text(
                      task.endDate != null
                          ? '${task.date} → ${task.endDate}'
                          : task.date,
                      style: const TextStyle(fontSize: 10, color: _kMuted),
                    ),
                  ],
                  const Spacer(),
                  if (task.commentCount > 0) ...[
                    Icon(Icons.chat_bubble_outline_rounded, size: 11, color: _kMuted),
                    const SizedBox(width: 3),
                    Text('${task.commentCount}',
                        style: const TextStyle(fontSize: 10, color: _kMuted)),
                  ],
                ]),
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
                    Text(
                      'Pause requested — ${task.pendingPauseRequest!['reason'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600),
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

          // ── Action buttons (only when pending) ──────────────────────────
          if (isPending) ...[
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
      width: 320,
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.label_outline_rounded, size: 12, color: _kMuted),
                  const SizedBox(width: 4),
                  Text('Reason: ${pauseReq.reason}',
                      style: const TextStyle(fontSize: 12, color: _kMuted)),
                ]),
                if (pauseReq.note != null && pauseReq.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.notes_rounded, size: 12, color: _kMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(pauseReq.note!,
                          style: const TextStyle(fontSize: 12, color: _kMuted)),
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
      width: 320,
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.notes_rounded, size: 12, color: _kMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(ideaReq.reason,
                        style: const TextStyle(fontSize: 12, color: _kMuted)),
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
