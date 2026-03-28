import 'package:flutter/material.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kPrimary  = Color(0xFF1A1A2E);
const _kAccent   = Color(0xFFE94560);
const _kBorder   = Color(0xFFE8ECF3);
const _kBg       = Color(0xFFF7F8FA);
const _kSurface  = Colors.white;
const _kMuted    = Color(0xFF9CA3AF);

const _kGreen    = Color(0xFF22C55E);
const _kYellow   = Color(0xFFF59E0B);
const _kRed      = Color(0xFFEF4444);

// ─── Enums ────────────────────────────────────────────────────────────────────

enum ClientHealth { green, yellow, red }

extension ClientHealthX on ClientHealth {
  String get label => switch (this) {
    ClientHealth.green  => 'Green',
    ClientHealth.yellow => 'Yellow',
    ClientHealth.red    => 'Red',
  };
  Color get color => switch (this) {
    ClientHealth.green  => _kGreen,
    ClientHealth.yellow => _kYellow,
    ClientHealth.red    => _kRed,
  };
}

enum CampaignStatus { active, paused, completed }

extension CampaignStatusX on CampaignStatus {
  String get label => switch (this) {
    CampaignStatus.active    => 'Active',
    CampaignStatus.paused    => 'Paused',
    CampaignStatus.completed => 'Completed',
  };
  Color get color => switch (this) {
    CampaignStatus.active    => _kGreen,
    CampaignStatus.paused    => _kYellow,
    CampaignStatus.completed => _kMuted,
  };
}

// ─── Models ───────────────────────────────────────────────────────────────────

class Campaign {
  final String         id;
  final String         name;
  final CampaignStatus status;
  final double         responseRate;

  const Campaign({
    required this.id,
    required this.name,
    required this.status,
    required this.responseRate,
  });
}

class ClientNote {
  final String   author;
  final String   text;
  final DateTime timestamp;

  const ClientNote({
    required this.author,
    required this.text,
    required this.timestamp,
  });
}

class Client {
  final String       id;
  String             name;
  String             contactName;
  String             contactRole;
  String             email;
  String             phone;
  String             whatsapp;
  String             product;
  String             assignedTo;
  DateTime           lastContact;
  DateTime           renewalDate;
  ClientHealth       health;
  List<Campaign>     campaigns;
  List<ClientNote>   notes;

  Client({
    required this.id,
    required this.name,
    required this.contactName,
    required this.contactRole,
    required this.email,
    required this.phone,
    required this.whatsapp,
    required this.product,
    required this.assignedTo,
    required this.lastContact,
    required this.renewalDate,
    required this.health,
    List<Campaign>?   campaigns,
    List<ClientNote>? notes,
  })  : campaigns = campaigns ?? [],
        notes     = notes     ?? [];

  bool get hasRenewalFlag =>
      renewalDate.difference(DateTime.now()).inDays < 30;
  bool get hasContactFlag =>
      DateTime.now().difference(lastContact).inDays > 7;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  Client?      _selected;
  ClientHealth? _filterHealth;
  final _noteCtrl = TextEditingController();

  // ── Mock data ──────────────────────────────────────────────────────────────

  late final List<Client> _clients = [
    Client(
      id:          '1',
      name:        'Acme Corp',
      contactName: 'John Smith',
      contactRole: 'CEO',
      email:       'john@acme.com',
      phone:       '+1 555-0101',
      whatsapp:    '+1 555-0101',
      product:     'WhatsApp Agent',
      assignedTo:  'Ravi',
      lastContact: DateTime.now().subtract(const Duration(days: 2)),
      renewalDate: DateTime.now().add(const Duration(days: 45)),
      health:      ClientHealth.green,
      campaigns: const [
        Campaign(id: 'c1', name: 'Q2 Outreach',    status: CampaignStatus.active,    responseRate: 38.5),
        Campaign(id: 'c2', name: 'Onboarding Flow', status: CampaignStatus.completed, responseRate: 61.0),
      ],
      notes: [
        ClientNote(author: 'Ravi',  text: 'Demo scheduled for next Monday.',      timestamp: DateTime.now().subtract(const Duration(days: 2))),
        ClientNote(author: 'Priya', text: 'Signed NDA. Contract review pending.', timestamp: DateTime.now().subtract(const Duration(days: 5))),
      ],
    ),
    Client(
      id:          '2',
      name:        'TechStart',
      contactName: 'Sarah Lee',
      contactRole: 'CTO',
      email:       'sarah@techstart.io',
      phone:       '+44 7700 900011',
      whatsapp:    '+44 7700 900011',
      product:     'Prompt Engine',
      assignedTo:  'Priya',
      lastContact: DateTime.now().subtract(const Duration(days: 8)),
      renewalDate: DateTime.now().add(const Duration(days: 12)),
      health:      ClientHealth.red,
      campaigns: const [
        Campaign(id: 'c3', name: 'Re-engagement', status: CampaignStatus.paused, responseRate: 14.2),
      ],
      notes: [
        ClientNote(author: 'Priya', text: 'Client raised concern about latency.', timestamp: DateTime.now().subtract(const Duration(days: 8))),
      ],
    ),
    Client(
      id:          '3',
      name:        'GlobalRetail',
      contactName: 'Amit Patel',
      contactRole: 'Head of Operations',
      email:       'amit@globalretail.com',
      phone:       '+91 98765 43210',
      whatsapp:    '+91 98765 43210',
      product:     'Frontend Suite',
      assignedTo:  'Ravi',
      lastContact: DateTime.now().subtract(const Duration(days: 4)),
      renewalDate: DateTime.now().add(const Duration(days: 28)),
      health:      ClientHealth.yellow,
      campaigns: const [
        Campaign(id: 'c4', name: 'Summer Campaign', status: CampaignStatus.active, responseRate: 29.3),
      ],
      notes: [
        ClientNote(author: 'Ravi', text: 'Requested dashboard customisation.', timestamp: DateTime.now().subtract(const Duration(days: 4))),
      ],
    ),
    Client(
      id:          '4',
      name:        'FinEdge',
      contactName: 'Lisa Brown',
      contactRole: 'Director',
      email:       'lisa@finedge.com',
      phone:       '+1 555-0202',
      whatsapp:    '+1 555-0202',
      product:     'Backend API',
      assignedTo:  'Karan',
      lastContact: DateTime.now().subtract(const Duration(days: 1)),
      renewalDate: DateTime.now().add(const Duration(days: 90)),
      health:      ClientHealth.green,
      campaigns: const [],
      notes: [
        ClientNote(author: 'Karan', text: 'Integration completed. Going live soon.', timestamp: DateTime.now().subtract(const Duration(days: 1))),
      ],
    ),
    Client(
      id:          '5',
      name:        'MediaHub',
      contactName: 'Carlos Diaz',
      contactRole: 'VP Marketing',
      email:       'carlos@mediahub.co',
      phone:       '+34 612 345 678',
      whatsapp:    '+34 612 345 678',
      product:     'WhatsApp Agent',
      assignedTo:  'Priya',
      lastContact: DateTime.now().subtract(const Duration(days: 3)),
      renewalDate: DateTime.now().add(const Duration(days: 55)),
      health:      ClientHealth.green,
      campaigns: const [
        Campaign(id: 'c5', name: 'Autumn Push',   status: CampaignStatus.active, responseRate: 44.1),
        Campaign(id: 'c6', name: 'Loyalty Series', status: CampaignStatus.paused, responseRate: 22.7),
      ],
      notes: [],
    ),
    Client(
      id:          '6',
      name:        'NovaBuild',
      contactName: 'Tom Wright',
      contactRole: 'Project Manager',
      email:       'tom@novabuild.io',
      phone:       '+61 400 111 222',
      whatsapp:    '+61 400 111 222',
      product:     'Prompt Engine',
      assignedTo:  'Karan',
      lastContact: DateTime.now().subtract(const Duration(days: 10)),
      renewalDate: DateTime.now().add(const Duration(days: 20)),
      health:      ClientHealth.yellow,
      campaigns: const [
        Campaign(id: 'c7', name: 'Re-activation', status: CampaignStatus.paused, responseRate: 8.9),
      ],
      notes: [
        ClientNote(author: 'Karan', text: 'Follow-up call needed urgently.', timestamp: DateTime.now().subtract(const Duration(days: 10))),
      ],
    ),
  ];

  // ── Derived ────────────────────────────────────────────────────────────────

  List<Client> get _filtered => _filterHealth == null
      ? _clients
      : _clients.where((c) => c.health == _filterHealth).toList();

  List<_RedFlag> get _flags {
    final flags = <_RedFlag>[];
    for (final c in _clients) {
      if (c.hasContactFlag) {
        final days = DateTime.now().difference(c.lastContact).inDays;
        flags.add(_RedFlag(clientName: c.name, reason: 'not contacted in $days days'));
      }
      if (c.hasRenewalFlag) {
        final days = c.renewalDate.difference(DateTime.now()).inDays;
        flags.add(_RedFlag(clientName: c.name, reason: 'renewal in $days days'));
      }
    }
    return flags;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final flags = _flags;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main area ─────────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              _TopBar(onAdd: _showAddClientDialog),

              // Red flags (only when present)
              if (flags.isNotEmpty)
                _RedFlagsSection(flags: flags),

              // Filter bar
              _FilterBar(
                active:   _filterHealth,
                onSelect: (h) => setState(() =>
                    _filterHealth = _filterHealth == h ? null : h),
              ),

              // Grid
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text('No clients match this filter.',
                            style: TextStyle(color: _kMuted, fontSize: 14)))
                    : _ClientGrid(
                        clients:    _filtered,
                        selectedId: _selected?.id,
                        onTap:      (c) =>
                            setState(() => _selected = _selected?.id == c.id ? null : c),
                      ),
              ),
            ],
          ),
        ),

        // ── Detail panel ──────────────────────────────────────────────────
        AnimatedContainer(
          duration:     const Duration(milliseconds: 220),
          curve:        Curves.easeInOut,
          width:        _selected != null ? 360 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            color:  _kSurface,
            border: Border(left: BorderSide(color: _kBorder)),
          ),
          child: _selected != null
              ? _ClientDetailPanel(
                  key:       ValueKey(_selected!.id),
                  client:    _selected!,
                  onClose:   () => setState(() => _selected = null),
                  onChanged: () => setState(() {}),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Add client dialog (stub — pre-wired for backend) ──────────────────────

  void _showAddClientDialog() {
    final nameCtrl    = TextEditingController();
    final contactCtrl = TextEditingController();
    final emailCtrl   = TextEditingController();

    showDialog<void>(
      context:            context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor:  _kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: const Text('New Client',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dlgField(nameCtrl,    'Company Name'),
              const SizedBox(height: 12),
              _dlgField(contactCtrl, 'Contact Person'),
              const SizedBox(height: 12),
              _dlgField(emailCtrl,   'Email'),
              const SizedBox(height: 16),
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color:  _kBg,
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: const Text(
                  'Click outside to save  ·  Leave name empty to discard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _kMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      final name = nameCtrl.text.trim();
      if (name.isNotEmpty) {
        setState(() {
          _clients.add(Client(
            id:          DateTime.now().millisecondsSinceEpoch.toString(),
            name:        name,
            contactName: contactCtrl.text.trim(),
            contactRole: '',
            email:       emailCtrl.text.trim(),
            phone:       '',
            whatsapp:    '',
            product:     '',
            assignedTo:  '',
            lastContact: DateTime.now(),
            renewalDate: DateTime.now().add(const Duration(days: 365)),
            health:      ClientHealth.green,
          ));
        });
      }
      nameCtrl.dispose();
      contactCtrl.dispose();
      emailCtrl.dispose();
    });
  }
}

// ─── Dialog text field helper ─────────────────────────────────────────────────

Widget _dlgField(TextEditingController ctrl, String label) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide:   BorderSide(color: _kBorder),
  );
  return TextField(
    controller: ctrl,
    style:      const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      labelText:     label,
      labelStyle:    const TextStyle(fontSize: 13, color: _kMuted),
      border:        border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide:   BorderSide(color: _kAccent),
      ),
      isDense:        true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

// ─── Red flag model ───────────────────────────────────────────────────────────

class _RedFlag {
  final String clientName;
  final String reason;
  const _RedFlag({required this.clientName, required this.reason});
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _TopBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        const Text('Clients',
            style: TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.bold,
                color:      _kPrimary)),
        const Spacer(),
        FilledButton.icon(
          onPressed:  onAdd,
          icon:       const Icon(Icons.add, size: 16),
          label:      const Text('Add Client', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            padding:         const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}

// ─── Red flags section ────────────────────────────────────────────────────────

class _RedFlagsSection extends StatelessWidget {
  final List<_RedFlag> flags;
  const _RedFlagsSection({required this.flags});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: _kRed),
            const SizedBox(width: 6),
            Text('Attention needed (${flags.length})',
                style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      _kRed)),
          ]),
          const SizedBox(height: 6),
          ...flags.map((f) => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              const Text('•  ', style: TextStyle(color: _kRed, fontSize: 13)),
              Text(f.clientName,
                  style: const TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w500,
                      color:      _kPrimary)),
              Text(' — ${f.reason}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ]),
          )),
        ],
      ),
    );
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final ClientHealth?              active;
  final void Function(ClientHealth) onSelect;
  const _FilterBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        _chip(null,               'All',    null),
        const SizedBox(width: 8),
        _chip(ClientHealth.green,  'Green',  _kGreen),
        const SizedBox(width: 8),
        _chip(ClientHealth.yellow, 'Yellow', _kYellow),
        const SizedBox(width: 8),
        _chip(ClientHealth.red,    'Red',    _kRed),
      ]),
    );
  }

  Widget _chip(ClientHealth? health, String label, Color? dot) {
    final isActive = active == health;
    return GestureDetector(
      onTap: health != null ? () => onSelect(health) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        isActive ? _kPrimary : _kSurface,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: isActive ? _kPrimary : _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 7, height: 7,
                decoration: BoxDecoration(
                    color: isActive ? Colors.white : dot,
                    shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : _kPrimary)),
        ]),
      ),
    );
  }
}

// ─── Client grid ──────────────────────────────────────────────────────────────

class _ClientGrid extends StatelessWidget {
  final List<Client>         clients;
  final String?              selectedId;
  final void Function(Client) onTap;

  const _ClientGrid({
    required this.clients,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth >= 900 ? 3 : 2;
      return GridView.builder(
        padding:   const EdgeInsets.all(20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          mainAxisSpacing:  14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.65,
        ),
        itemCount: clients.length,
        itemBuilder: (_, i) => _ClientCard(
          client:     clients[i],
          isSelected: clients[i].id == selectedId,
          onTap:      () => onTap(clients[i]),
        ),
      );
    });
  }
}

// ─── Client card ──────────────────────────────────────────────────────────────

class _ClientCard extends StatefulWidget {
  final Client     client;
  final bool       isSelected;
  final VoidCallback onTap;
  const _ClientCard({required this.client, required this.isSelected, required this.onTap});

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final renewalDays = c.renewalDate.difference(DateTime.now()).inDays;

    return MouseRegion(
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      cursor:   SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color:        _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? _kAccent
                  : _hovered
                      ? const Color(0xFFD1D5DB)
                      : _kBorder,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: _hovered || widget.isSelected
                ? [const BoxShadow(
                    color:      Colors.black12,
                    blurRadius: 8,
                    offset:     Offset(0, 2))]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: health + edit ──────────────────────────────────
                Row(children: [
                  _HealthDot(c.health),
                  const SizedBox(width: 6),
                  Text(c.health.label,
                      style: TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.w500,
                          color:      c.health.color)),
                  const Spacer(),
                  _CardButton(
                    label: 'Edit',
                    onTap: widget.onTap,
                  ),
                ]),
                const SizedBox(height: 8),

                // ── Company name ─────────────────────────────────────────
                Text(c.name,
                    style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      _kPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${c.contactName} · ${c.contactRole}',
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: _kBorder),
                ),

                // ── Meta rows ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                    children: [
                      _CardMeta('Product',      c.product.isEmpty ? '—' : c.product),
                      _CardMeta('Assigned',     c.assignedTo.isEmpty ? '—' : c.assignedTo),
                      _CardMeta('Last contact', _relativeDate(c.lastContact)),
                      Row(children: [
                        const Text('Renewal  ',
                            style: TextStyle(fontSize: 11, color: _kMuted)),
                        Text(
                          '$renewalDays days',
                          style: TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.w600,
                              color: renewalDays < 30 ? _kRed : _kPrimary),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Client detail panel ──────────────────────────────────────────────────────

class _ClientDetailPanel extends StatefulWidget {
  final Client    client;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const _ClientDetailPanel({
    super.key,
    required this.client,
    required this.onClose,
    required this.onChanged,
  });

  @override
  State<_ClientDetailPanel> createState() => _ClientDetailPanelState();
}

class _ClientDetailPanelState extends State<_ClientDetailPanel> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final renewalDays = c.renewalDate.difference(DateTime.now()).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          height:  52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            _HealthDot(c.health),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.name,
                  style: const TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      _kPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            InkWell(
              onTap:        widget.onClose,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width:  26, height: 26,
                decoration: BoxDecoration(
                  color:        _kBg,
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(color: _kBorder),
                ),
                child: Icon(Icons.close, size: 14, color: _kMuted),
              ),
            ),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Health row with change dropdown
                Row(children: [
                  const Icon(Icons.favorite_outline_rounded,
                      size: 14, color: _kMuted),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 62,
                    child: Text('Health',
                        style: TextStyle(fontSize: 12, color: _kMuted)),
                  ),
                  _HealthDot(c.health),
                  const SizedBox(width: 6),
                  DropdownButton<ClientHealth>(
                    value:     c.health,
                    isDense:   true,
                    underline: const SizedBox(),
                    style:     const TextStyle(fontSize: 12, color: _kPrimary),
                    items: ClientHealth.values.map((h) => DropdownMenuItem(
                      value: h,
                      child: Row(children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: h.color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(h.label, style: const TextStyle(fontSize: 12)),
                      ]),
                    )).toList(),
                    onChanged: (h) {
                      if (h != null) {
                        setState(() => c.health = h);
                        widget.onChanged();
                      }
                    },
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Contact ───────────────────────────────────────────────
                _PanelSection(label: 'Contact', children: [
                  _DetailRow(Icons.person_outline_rounded,     c.contactName.isEmpty ? '—' : '${c.contactName} · ${c.contactRole}'),
                  _DetailRow(Icons.email_outlined,             c.email.isEmpty ? '—' : c.email),
                  _DetailRow(Icons.phone_outlined,             c.phone.isEmpty ? '—' : c.phone),
                  _DetailRow(Icons.chat_bubble_outline_rounded, c.whatsapp.isEmpty ? '—' : c.whatsapp),
                ]),

                const SizedBox(height: 16),

                // ── Product & Contract ────────────────────────────────────
                _PanelSection(label: 'Product & Contract', children: [
                  _DetailRow(Icons.inventory_2_outlined, c.product.isEmpty ? '—' : c.product),
                  _DetailRow(Icons.event_outlined,        'Renewal in $renewalDays days',
                      valueColor: renewalDays < 30 ? _kRed : null),
                  _DetailRow(Icons.person_pin_outlined,  c.assignedTo.isEmpty ? '—' : 'Assigned to ${c.assignedTo}'),
                ]),

                const SizedBox(height: 16),

                // ── Active Campaigns ──────────────────────────────────────
                _SectionHeader(
                  label:  'Active Campaigns',
                  action: TextButton.icon(
                    onPressed: () {},
                    icon:  const Icon(Icons.add, size: 13),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _kAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                if (c.campaigns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No campaigns yet.',
                        style: TextStyle(fontSize: 12, color: _kMuted)),
                  )
                else
                  ...c.campaigns.map((cam) => _CampaignRow(campaign: cam)),

                const SizedBox(height: 16),

                // ── Linked Tasks ──────────────────────────────────────────
                _SectionHeader(
                  label:  'Linked Tasks',
                  action: TextButton.icon(
                    onPressed: () {},
                    icon:  const Icon(Icons.add, size: 13),
                    label: const Text('Add Task', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _kAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('No tasks linked yet.',
                      style: TextStyle(fontSize: 12, color: _kMuted)),
                ),

                const SizedBox(height: 16),

                // ── Notes ─────────────────────────────────────────────────
                _SectionHeader(label: 'Notes', action: null),
                const SizedBox(height: 8),

                // Notes list newest first
                if (c.notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('No notes yet.',
                        style: TextStyle(fontSize: 12, color: _kMuted)),
                  )
                else
                  ...c.notes.reversed.map((note) => _NoteItem(note: note)),

                const SizedBox(height: 8),

                // Note input
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      style:      const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText:  'Add a note...',
                        hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                        isDense:   true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:   const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:   const BorderSide(color: _kAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color:        _kAccent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final text = _noteCtrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          c.notes.add(ClientNote(
                            author:    'You',
                            text:      text,
                            timestamp: DateTime.now(),
                          ));
                          _noteCtrl.clear();
                        });
                        widget.onChanged();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.send_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _HealthDot extends StatelessWidget {
  final ClientHealth health;
  const _HealthDot(this.health);
  @override
  Widget build(BuildContext context) => Container(
    width: 9, height: 9,
    decoration: BoxDecoration(color: health.color, shape: BoxShape.circle),
  );
}

class _CardButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _CardButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        _kBg,
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: _kBorder),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: _kPrimary)),
    ),
  );
}

class _CardMeta extends StatelessWidget {
  final String label;
  final String value;
  const _CardMeta(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label  ',
        style: const TextStyle(fontSize: 11, color: _kMuted)),
    Flexible(
      child: Text(value,
          style: const TextStyle(fontSize: 11, color: _kPrimary,
              fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis),
    ),
  ]);
}

class _PanelSection extends StatelessWidget {
  final String        label;
  final List<Widget>  children;
  const _PanelSection({required this.label, required this.children});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize:      10,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.8,
              color:         _kMuted)),
      const SizedBox(height: 8),
      ...children.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 6), child: w)),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   value;
  final Color?   valueColor;
  const _DetailRow(this.icon, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: _kMuted),
    const SizedBox(width: 10),
    Expanded(
      child: Text(value,
          style: TextStyle(
              fontSize: 12,
              color: valueColor ?? const Color(0xFF374151)),
          overflow: TextOverflow.ellipsis),
    ),
  ]);
}

class _SectionHeader extends StatelessWidget {
  final String  label;
  final Widget? action;
  const _SectionHeader({required this.label, required this.action});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label.toUpperCase(),
        style: const TextStyle(
            fontSize:      10,
            fontWeight:    FontWeight.w700,
            letterSpacing: 0.8,
            color:         _kMuted)),
    const Spacer(),
    ?action,
  ]);
}

class _CampaignRow extends StatelessWidget {
  final Campaign campaign;
  const _CampaignRow({required this.campaign});
  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color:        _kBg,
      borderRadius: BorderRadius.circular(6),
      border:       Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Expanded(
        child: Text(campaign.name,
            style: const TextStyle(fontSize: 12, color: _kPrimary),
            overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 8),
      _StatusPill(campaign.status),
      const SizedBox(width: 8),
      Text('${campaign.responseRate.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 11, color: _kMuted)),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () {},
        child: const Text('View',
            style: TextStyle(fontSize: 11, color: _kAccent,
                fontWeight: FontWeight.w500)),
      ),
    ]),
  );
}

class _StatusPill extends StatelessWidget {
  final CampaignStatus status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext context) {
    final bg   = status.color.withValues(alpha: 0.12);
    final text = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

class _NoteItem extends StatelessWidget {
  final ClientNote note;
  const _NoteItem({required this.note});

  @override
  Widget build(BuildContext context) {
    final initials = note.author.isNotEmpty ? note.author[0].toUpperCase() : '?';
    final avatarColor = Color(0xFF6366F1 + (note.author.hashCode & 0x00FFFFFF));

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        _kBg,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius:          12,
              backgroundColor: avatarColor,
              child:           Text(initials,
                  style: const TextStyle(fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(note.author,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _kPrimary)),
            const SizedBox(width: 8),
            Text(_relativeDate(note.timestamp),
                style: const TextStyle(fontSize: 11, color: _kMuted)),
          ]),
          const SizedBox(height: 6),
          Text(note.text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151),
                  height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Date helper ──────────────────────────────────────────────────────────────

String _relativeDate(DateTime d) {
  final diff = DateTime.now().difference(d).inDays;
  if (diff == 0)  return 'Today';
  if (diff == 1)  return '1 day ago';
  return '$diff days ago';
}
