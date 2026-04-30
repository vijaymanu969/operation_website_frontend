import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/config/app_colors.dart';

class DashboardUpdate {
  final String id;
  final String title;
  final String body;
  final String? publishedAt;

  DashboardUpdate({
    required this.id,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  factory DashboardUpdate.fromJson(Map<String, dynamic> j) => DashboardUpdate(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? j['content'] ?? '').toString(),
        publishedAt: j['published_at']?.toString(),
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _checkedUpdates = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdates());
  }

  Future<void> _checkUpdates() async {
    if (_checkedUpdates) return;
    _checkedUpdates = true;
    try {
      final res = await _api.getUnreadDashboardUpdates();
      final updates = _parseUpdates(res.data);
      if (!mounted || updates.isEmpty) return;
      await _showUpdatesQueue(updates);
    } catch (_) {
      // Silently ignore — updates are non-critical and the user shouldn't be
      // blocked from the dashboard if the endpoint is unreachable.
    }
  }

  List<DashboardUpdate> _parseUpdates(dynamic data) {
    final root = data is Map ? (data['data'] ?? data) : data;
    List? raw;
    if (root is List) {
      raw = root;
    } else if (root is Map) {
      raw = (root['updates'] ?? root['items'] ?? root['rows']) as List?;
    }
    return (raw ?? [])
        .map((e) => DashboardUpdate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _showUpdatesQueue(List<DashboardUpdate> updates) async {
    for (final update in updates) {
      if (!mounted) return;
      final acknowledged = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _UpdateDialog(update: update),
      );
      if (acknowledged != true) {
        // User somehow closed without ack (shouldn't happen — re-show next
        // session). Stop the queue so we don't auto-ack the rest.
        return;
      }
      try {
        await _api.acknowledgeDashboardUpdate(update.id);
      } catch (_) {
        // Best-effort; we'll re-show next session if it failed.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return const SizedBox.shrink();
    }

    final user = authState.user;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${user.name}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.displayName,
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Dashboard content coming soon — will show analytics overview, stagnant tasks, and attendance summary.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final DashboardUpdate update;

  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _scrolledToEnd = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrolledToEnd) return;
      // If content is short enough to need no scrolling, mark read immediately
      // after first frame; otherwise require the user to reach the bottom.
      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 4) {
        setState(() => _scrolledToEnd = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.maxScrollExtent <= 0) {
        setState(() => _scrolledToEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width < 600 ? width * 0.92 : 520.0;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'NEW',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                u.title.isEmpty ? 'Update' : u.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (u.publishedAt != null && u.publishedAt!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          u.publishedAt!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    Text(
                      u.body,
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          if (!_scrolledToEnd)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Scroll to the end to continue',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _scrolledToEnd
                ? () => Navigator.of(context).pop(true)
                : null,
            child: const Text("I've read this"),
          ),
        ],
      ),
    );
  }
}
