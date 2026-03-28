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

  const _Message({
    this.dateLabel,
    this.text,
    this.sent        = false,
    this.time        = '',
    this.imageCaption,
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

// Messages shown for the active contact (Lindsey Curtis by default).
const _kMessages = <_Message>[
  _Message(dateLabel: 'Yesterday'),
  _Message(
    text: 'I want to make an appointment tomorrow from 2:00 to 5:00pm?',
    sent: false, time: '30 mins ago',
  ),
  _Message(
    text: "If don't like something, I'll stay away from it.",
    sent: true,  time: '2 hours ago',
  ),
  _Message(
    text: 'I want more detailed information.',
    sent: false, time: '2 hours ago',
  ),
  _Message(
    text: 'They got there early, and got really good seats.',
    sent: true,  time: '2 hours ago',
  ),
  // Image message — imageCaption non-null triggers the image bubble.
  _Message(imageCaption: 'Please preview the image', sent: false, time: '2 hours ago'),
  _Message(dateLabel: 'Today'),
  _Message(
    text: 'Good morning! Did you get a chance to look at the designs?',
    sent: false, time: '9:00 AM',
  ),
  _Message(
    text: 'Yes, they look great! Just a few minor tweaks needed.',
    sent: true,  time: '9:15 AM',
  ),
  _Message(
    text: 'Can you send me the updated file when ready?',
    sent: false, time: '9:20 AM',
  ),
];

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
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _kMessages.length,
      itemBuilder: (_, i) {
        final msg = _kMessages[i];
        if (msg.dateLabel != null)     return _buildDateSeparator(msg.dateLabel!);
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
