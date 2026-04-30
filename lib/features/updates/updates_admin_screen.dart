import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';

const _kPrimary = Color(0xFF414099);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);
const _kSurface = Colors.white;
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1A1A);

class AdminUpdate {
  String id;
  String title;
  String body;
  bool isActive;
  String? publishedAt;
  int ackCount;
  int totalActiveUsers;

  AdminUpdate({
    required this.id,
    required this.title,
    required this.body,
    required this.isActive,
    this.publishedAt,
    required this.ackCount,
    required this.totalActiveUsers,
  });

  factory AdminUpdate.fromJson(Map<String, dynamic> j) => AdminUpdate(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        isActive: j['is_active'] == true,
        publishedAt: j['published_at']?.toString(),
        ackCount: (j['ack_count'] as num?)?.toInt() ?? 0,
        totalActiveUsers: (j['total_active_users'] as num?)?.toInt() ?? 0,
      );
}

class UpdatesAdminScreen extends StatefulWidget {
  const UpdatesAdminScreen({super.key});

  @override
  State<UpdatesAdminScreen> createState() => _UpdatesAdminScreenState();
}

class _UpdatesAdminScreenState extends State<UpdatesAdminScreen> {
  List<AdminUpdate> _updates = [];
  bool _loading = true;
  String? _error;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getDashboardUpdatesAdmin();
      final root = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
      List? raw;
      if (root is List) {
        raw = root;
      } else if (root is Map) {
        raw = (root['updates'] ?? root['items'] ?? root['rows']) as List?;
      }
      final list = (raw ?? [])
          .map((e) => AdminUpdate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _updates = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load updates';
      });
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[600] : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showEditor({AdminUpdate? existing}) async {
    final isEdit = existing != null;
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    final bodyCtl = TextEditingController(text: existing?.body ?? '');
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isEdit ? 'Edit Update' : 'New Update',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          content: SizedBox(
            width: 540,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    label: 'Title',
                    controller: titleCtl,
                    hint: 'e.g. Agents page added',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Body',
                    controller: bodyCtl,
                    hint: 'Describe what changed. Plain text works best.',
                    maxLines: 8,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          value: isActive,
                          activeThumbColor: _kPrimary,
                          onChanged: (v) => setLocal(() => isActive = v),
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Active' : 'Disabled',
                            style: const TextStyle(fontSize: 13, color: _kText)),
                      ],
                    ),
                  ],
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
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(isEdit ? 'Save' : 'Publish'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final payload = <String, dynamic>{
      'title': titleCtl.text.trim(),
      'body': bodyCtl.text.trim(),
    };
    if (isEdit) payload['is_active'] = isActive;

    try {
      if (isEdit) {
        await _api.updateDashboardUpdate(existing.id, payload);
        _toast('Update saved');
      } else {
        await _api.createDashboardUpdate(payload);
        _toast('Update published');
      }
      await _load();
    } catch (_) {
      _toast(isEdit ? 'Failed to save update' : 'Failed to publish update',
          isError: true);
    }
  }

  Future<void> _resetAcks(AdminUpdate u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force re-acknowledgement?'),
        content: Text(
            'All users who already acknowledged "${u.title}" will be asked to read it again on their next dashboard load.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Reset Acks', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.resetDashboardUpdateAcks(u.id);
      _toast('Acknowledgements cleared');
      await _load();
    } catch (_) {
      _toast('Failed to reset acks', isError: true);
    }
  }

  Future<void> _delete(AdminUpdate u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete update?'),
        content: Text(
            'Permanently delete "${u.title}"? This also clears all acknowledgement records.'),
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
    if (ok != true) return;
    try {
      await _api.deleteDashboardUpdate(u.id);
      _toast('Update deleted');
      await _load();
    } catch (_) {
      _toast('Failed to delete update', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                    : _error != null
                        ? _buildError()
                        : _updates.isEmpty
                            ? _buildEmpty()
                            : ListView.separated(
                                itemCount: _updates.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, i) =>
                                    _buildUpdateRow(_updates[i]),
                              ),
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
              Text('Dashboard Updates',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: _kText)),
              SizedBox(height: 4),
              Text('Author and manage release notes shown to users on login.',
                  style: TextStyle(fontSize: 13, color: _kMuted)),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          onPressed: () => _showEditor(),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined,
              size: 56, color: _kMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('No updates yet',
              style: TextStyle(color: _kMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error ?? 'Something went wrong',
              style: const TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: _load,
            child:
                const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateRow(AdminUpdate u) {
    final ackPct = u.totalActiveUsers > 0
        ? (u.ackCount / u.totalActiveUsers * 100).round()
        : 0;
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
                child: Text(
                  u.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: _kText),
                ),
              ),
              if (!u.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('DISABLED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kMuted)),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: _kMuted),
                onSelected: (v) {
                  if (v == 'edit') _showEditor(existing: u);
                  if (v == 'reset') _resetAcks(u);
                  if (v == 'delete') _delete(u);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                      value: 'reset',
                      child: Text('Reset acknowledgements')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            u.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: _kText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 14, color: _kMuted.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                '${u.ackCount}/${u.totalActiveUsers} acknowledged ($ackPct%)',
                style: const TextStyle(fontSize: 12, color: _kMuted),
              ),
              const SizedBox(width: 16),
              if (u.publishedAt != null && u.publishedAt!.isNotEmpty) ...[
                Icon(Icons.schedule,
                    size: 14, color: _kMuted.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(u.publishedAt!,
                    style: const TextStyle(fontSize: 12, color: _kMuted)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: _kMuted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 3 : 1,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
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
