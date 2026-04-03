import 'dart:ui' show ImageFilter;
import 'dart:math' show min;
import 'package:flutter/material.dart';

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
  final String? dateLabel;
  final String? text;
  final bool    sent;          // true = me (right), false = them (left)
  final String  time;
  final String? imageCaption;  // non-null → render image placeholder + caption
  final _ChatTask? task;       // non-null → render task review card

  const _Message({
    this.dateLabel,
    this.text,
    this.sent        = false,
    this.time        = '',
    this.imageCaption,
    this.task,
  });
}

// ── Task review models ────────────────────────────────────────────────────────

enum _TaskReviewStatus { pending, completed, rejected }

class _ChatTask {
  final String title;
  final String description;
  final String assignee;
  final String priority;  // High / Medium / Low
  final String type;
  final String date;       // display string
  final int    commentCount;
  _TaskReviewStatus reviewStatus;

  _ChatTask({
    required this.title,
    required this.description,
    required this.assignee,
    required this.priority,
    required this.type,
    required this.date,
    this.commentCount   = 0,
    this.reviewStatus   = _TaskReviewStatus.pending,
  });
}

// ── Mock data ──────────────────────────────────────────────────────────────────

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
  String _selectedId = '2'; // Lindsey Curtis active by default

  final _msgCtrl    = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _search = '';

  @override
  void initState() {
    super.initState();
    // Rebuild when text field changes so send-button activates/deactivates.
    _msgCtrl.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  _Contact get _active =>
      _kContacts.firstWhere((c) => c.id == _selectedId);

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
    final filtered = _search.isEmpty
        ? _kContacts
        : _kContacts
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
                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                  onPressed: () {},
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
            child: ListView.builder(
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
      onTap: () => setState(() => _selectedId = c.id),
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
        Expanded(child: _buildMessages(contact)),
        Container(height: 1, color: _kBorder),
        _buildInputBar(),
      ],
    );
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
          IconButton(
            icon: Icon(Icons.call_outlined, size: 20, color: Colors.grey[600]),
            onPressed: () {},
            tooltip: 'Voice call',
          ),
          IconButton(
            icon: Icon(Icons.videocam_outlined, size: 20, color: Colors.grey[600]),
            onPressed: () {},
            tooltip: 'Video call',
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // Scrollable message list
  Widget _buildMessages(_Contact contact) {
    final messages = _kMessagesByContact[contact.id] ?? [];
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        if (msg.dateLabel != null)     return _buildDateSeparator(msg.dateLabel!);
        if (msg.task != null)          return _buildTaskReviewCard(msg, contact);
        if (msg.imageCaption != null)  return _buildImageMessage(msg, contact);
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
                    // "tail" corner points toward the avatar side
                    bottomLeft:  Radius.circular(isSent ? 12 : 2),
                    bottomRight: Radius.circular(isSent ? 2  : 12),
                  ),
                  border: isSent ? null : Border.all(color: _kBorder),
                ),
                child: Text(msg.text!,
                    style: TextStyle(
                        fontSize: 13,
                        color: isSent ? Colors.white : _kPrimary)),
              ),
              const SizedBox(height: 4),
              // Timestamp: include sender name for received messages
              Text(
                isSent
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
                task:     task,
                onReject:   () => setState(() => task.reviewStatus = _TaskReviewStatus.rejected),
                onComplete: () => setState(() => task.reviewStatus = _TaskReviewStatus.completed),
                onTap:      () => _showTaskPreview(context, task),
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

  void _sendMessage() {
    // Real implementation would send to backend/WebSocket.
    // For now just clear the field.
    _msgCtrl.clear();
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

  const _ChatTaskCard({
    required this.task,
    required this.onReject,
    required this.onComplete,
    this.onTap,
  });

  Color get _priorityColor => switch (task.priority) {
    'High'   => _kHigh,
    'Medium' => _kMedium,
    'Low'    => _kLow,
    _        => _kMuted,
  };

  @override
  Widget build(BuildContext context) {
    final isPending   = task.reviewStatus == _TaskReviewStatus.pending;
    final isCompleted = task.reviewStatus == _TaskReviewStatus.completed;
    final isRejected  = task.reviewStatus == _TaskReviewStatus.rejected;

    final borderColor = isCompleted
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
                isCompleted
                    ? Icons.check_circle_rounded
                    : isRejected
                        ? Icons.cancel_rounded
                        : Icons.assignment_outlined,
                size:  15,
                color: isCompleted ? _kGreen : isRejected ? _kHigh : _kPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                isCompleted
                    ? 'Task Completed'
                    : isRejected
                        ? 'Task Rejected'
                        : 'Task Review',
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? _kGreen : isRejected ? _kHigh : _kPrimary,
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
                // Priority + Type badges
                Row(children: [
                  _Badge(task.priority, _priorityColor),
                  const SizedBox(width: 6),
                  _Badge(task.type, const Color(0xFF6366F1)),
                  const Spacer(),
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

                // Assignee + meta
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
                  const Spacer(),
                  if (task.commentCount > 0) ...[
                    Icon(Icons.chat_bubble_outline_rounded, size: 11, color: _kMuted),
                    const SizedBox(width: 3),
                    Text('${task.commentCount}',
                        style: const TextStyle(fontSize: 10, color: _kMuted)),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.calendar_today_outlined, size: 11, color: _kMuted),
                  const SizedBox(width: 3),
                  Text(task.date,
                      style: const TextStyle(fontSize: 10, color: _kMuted)),
                ]),
              ],
            ),
          ),

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
          if (!isPending)
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
