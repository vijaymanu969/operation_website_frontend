import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF414099);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);
const _kSurface = Colors.white;
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1A1A);

class Agent {
  String id;
  String companyName;
  String agentName;
  String phoneNumber;

  Agent({
    required this.id,
    required this.companyName,
    required this.agentName,
    required this.phoneNumber,
  });

  factory Agent.fromJson(Map<String, dynamic> j) => Agent(
        id: j['id'].toString(),
        companyName: (j['company_name'] ?? '').toString(),
        agentName: (j['agent_name'] ?? '').toString(),
        phoneNumber: (j['phone_number'] ?? '').toString(),
      );
}

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  static const String _phonePrefix = '+9140453074';

  List<Agent> _agents = [];
  bool _loading = true;
  String? _error;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  ApiClient get _api => context.read<ApiClient>();

  List<Agent> _parseAgentList(dynamic data) {
    List? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      raw = (data['agents'] ?? data['data'] ?? data['items']) as List?;
    }
    if (raw == null) return [];
    return raw
        .map((j) => Agent.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getAgents();
      final list = _parseAgentList(res.data);
      if (!mounted) return;
      setState(() {
        _agents = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Agents] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load agents';
      });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  bool get _isMobile {
    final w = MediaQuery.of(context).size.width;
    return w < 700;
  }

  List<Agent> get _filtered {
    if (_query.trim().isEmpty) return _agents;
    final q = _query.toLowerCase();
    return _agents
        .where((a) =>
            a.companyName.toLowerCase().contains(q) ||
            a.agentName.toLowerCase().contains(q) ||
            a.phoneNumber.contains(q))
        .toList();
  }

  Future<void> _copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $number'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _callNumber(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calling not supported on this device')),
      );
    }
  }

  Future<void> _showAgentDialog({Agent? existing}) async {
    final isEdit = existing != null;
    final companyCtl = TextEditingController(text: existing?.companyName ?? '');
    final nameCtl = TextEditingController(text: existing?.agentName ?? '');
    // Phone is stored as full E.164 (prefix + 2-digit suffix). The input field
    // only edits the 2-digit suffix.
    final existingSuffix = existing != null &&
            existing.phoneNumber.startsWith(_phonePrefix)
        ? existing.phoneNumber.substring(_phonePrefix.length)
        : '';
    final phoneCtl = TextEditingController(text: existingSuffix);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdit ? 'Edit Agent' : 'Add Agent',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _kText, fontSize: 18)),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LabeledField(
                  label: 'Company Name',
                  controller: companyCtl,
                  hint: 'e.g. Convey Labs',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Agent Name',
                  controller: nameCtl,
                  hint: 'e.g. Ravi Kumar',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Phone Number',
                  controller: phoneCtl,
                  hint: 'XX',
                  keyboardType: TextInputType.number,
                  prefixText: '$_phonePrefix ',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r'^\d{2}$').hasMatch(v.trim())) {
                      return 'Enter exactly 2 digits';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final payload = {
        'company_name': companyCtl.text.trim(),
        'agent_name': nameCtl.text.trim(),
        'phone_number': '$_phonePrefix${phoneCtl.text.trim()}',
      };
      try {
        if (isEdit) {
          await _api.updateAgent(existing.id, payload);
        } else {
          await _api.createAgent(payload);
        }
        await _loadAgents();
      } catch (e) {
        debugPrint('[Agents] save failed: $e');
        _showError(isEdit ? 'Failed to update agent' : 'Failed to create agent');
      }
    }
  }

  Future<void> _deleteAgent(Agent agent) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete agent?'),
        content: Text(
            'Remove ${agent.agentName} from ${agent.companyName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteAgent(agent.id);
        if (!mounted) return;
        setState(() => _agents.remove(agent));
      } catch (e) {
        _showError('Failed to delete agent');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: _isMobile ? 12 : 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearch(),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _kPrimary))
                    : _error != null
                        ? _buildErrorState()
                        : _filtered.isEmpty
                            ? _buildEmpty()
                            : _isMobile
                                ? _buildMobileList()
                                : _buildDesktopTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Agents',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _kText)),
              SizedBox(height: 4),
              Text('Manage company agents and their contact info',
                  style: TextStyle(fontSize: 13, color: _kMuted)),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(_isMobile ? 'Add' : 'Add Agent'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 14 : 18, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _showAgentDialog(),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search by company, agent, or phone…',
          hintStyle: TextStyle(color: _kMuted, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: _kMuted, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error ?? 'Something went wrong',
              style: const TextStyle(color: _kMuted, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: _loadAgents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 56, color: _kMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('No agents found',
              style: TextStyle(color: _kMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Company',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                            fontSize: 12))),
                Expanded(
                    flex: 3,
                    child: Text('Agent',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                            fontSize: 12))),
                Expanded(
                    flex: 4,
                    child: Text('Phone',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                            fontSize: 12))),
                SizedBox(width: 100),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: _kBorder),
              itemBuilder: (ctx, i) {
                final a = _filtered[i];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(a.companyName,
                            style: const TextStyle(
                                color: _kText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(a.agentName,
                            style: const TextStyle(
                                color: _kText, fontSize: 14)),
                      ),
                      Expanded(
                        flex: 4,
                        child: _PhoneCell(
                          number: a.phoneNumber,
                          onCopy: () => _copyNumber(a.phoneNumber),
                          onCall: () => _callNumber(a.phoneNumber),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: _kMuted),
                              tooltip: 'Edit',
                              onPressed: () =>
                                  _showAgentDialog(existing: a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _deleteAgent(a),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final a = _filtered[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.companyName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _kText)),
                        const SizedBox(height: 2),
                        Text(a.agentName,
                            style: const TextStyle(
                                fontSize: 13, color: _kMuted)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: _kMuted, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') _showAgentDialog(existing: a);
                      if (v == 'delete') _deleteAgent(a);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _PhoneCell(
                number: a.phoneNumber,
                onCopy: () => _copyNumber(a.phoneNumber),
                onCall: () => _callNumber(a.phoneNumber),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhoneCell extends StatelessWidget {
  final String number;
  final VoidCallback onCopy;
  final VoidCallback onCall;

  const _PhoneCell({
    required this.number,
    required this.onCopy,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: InkWell(
            onTap: onCall,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                number,
                style: const TextStyle(
                  color: _kPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: _kPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _IconBtn(
          icon: Icons.copy_rounded,
          tooltip: 'Copy number',
          onTap: onCopy,
        ),
        const SizedBox(width: 4),
        _IconBtn(
          icon: Icons.call,
          tooltip: 'Call',
          color: _kPrimary,
          onTap: onCall,
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (color ?? _kMuted).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color ?? _kMuted),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.prefixText,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kMuted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.w500),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
