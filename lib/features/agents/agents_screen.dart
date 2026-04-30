import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF414099);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);
const _kSurface = Colors.white;
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1A1A);

const _kStorageKey = 'testCallCards';

// ─── Model ────────────────────────────────────────────────────────────────────

class TestCallCard {
  String id;
  String cardName;
  String agentName;
  String agentNumber;
  String campaignId;
  String apiKey;
  String createdAt;

  TestCallCard({
    required this.id,
    required this.cardName,
    required this.agentName,
    required this.agentNumber,
    required this.campaignId,
    required this.apiKey,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardName': cardName,
        'agentName': agentName,
        'agentNumber': agentNumber,
        'campaignId': campaignId,
        'apiKey': apiKey,
        'createdAt': createdAt,
      };

  factory TestCallCard.fromJson(Map<String, dynamic> j) => TestCallCard(
        id: (j['id'] ?? '').toString(),
        cardName: (j['cardName'] ?? '').toString(),
        agentName: (j['agentName'] ?? '').toString(),
        agentNumber: (j['agentNumber'] ?? '').toString(),
        campaignId: (j['campaignId'] ?? '').toString(),
        apiKey: (j['apiKey'] ?? '').toString(),
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<TestCallCard> _cards = [];
  bool _loading = true;

  late final Dio _platformDio = Dio(BaseOptions(
    baseUrl: AppConfig.aiPlatformBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    List<TestCallCard> cards = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          cards = decoded
              .map((e) => TestCallCard.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {/* ignore bad payload */}
    }
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kStorageKey,
      jsonEncode(_cards.map((c) => c.toJson()).toList()),
    );
  }

  // ── Toast helper ─────────────────────────────────────────────────────────

  Future<void> _dialNumber(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _toast('Calling not supported on this device', isError: true);
    }
  }

  Future<void> _copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    _toast('Copied $number');
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[600] : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Card create / edit / delete ──────────────────────────────────────────

  Future<void> _showCardDialog({TestCallCard? existing}) async {
    final isEdit = existing != null;
    final cardCtl = TextEditingController(text: existing?.cardName ?? '');
    final agentCtl = TextEditingController(text: existing?.agentName ?? '');
    final numberCtl = TextEditingController(text: existing?.agentNumber ?? '');
    final campaignCtl = TextEditingController(text: existing?.campaignId ?? '');
    final apiKeyCtl = TextEditingController(text: existing?.apiKey ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdit ? 'Edit Card' : 'New Test Call Card',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _kText, fontSize: 18)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field(
                    label: 'Card Name',
                    controller: cardCtl,
                    hint: 'e.g. Consultancy Agent',
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Agent Name',
                    controller: agentCtl,
                    hint: 'e.g. Sneha',
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Agent Number',
                    controller: numberCtl,
                    hint: '+914045307441',
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Required';
                      if (!RegExp(r'^\+\d{8,15}$').hasMatch(t)) {
                        return 'E.164 format, e.g. +914045307441';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Campaign ID',
                    controller: campaignCtl,
                    hint: 'e.g. 8458948c-4daf-49a8-8379-aa9bb50c5394',
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'API Key',
                    controller: apiKeyCtl,
                    hint: 'Organization API key',
                    obscure: true,
                    validator: _required,
                  ),
                ],
              ),
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
            child: Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );

    if (saved == true) {
      setState(() {
        if (isEdit) {
          existing.cardName = cardCtl.text.trim();
          existing.agentName = agentCtl.text.trim();
          existing.agentNumber = numberCtl.text.trim();
          existing.campaignId = campaignCtl.text.trim();
          existing.apiKey = apiKeyCtl.text.trim();
        } else {
          _cards.add(TestCallCard(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            cardName: cardCtl.text.trim(),
            agentName: agentCtl.text.trim(),
            agentNumber: numberCtl.text.trim(),
            campaignId: campaignCtl.text.trim(),
            apiKey: apiKeyCtl.text.trim(),
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ));
        }
      });
      await _saveCards();
    }
  }

  Future<void> _renameCard(TestCallCard card) async {
    final ctl = TextEditingController(text: card.cardName);
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename card'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: _Field(
              label: 'Card Name',
              controller: ctl,
              validator: _required,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => card.cardName = ctl.text.trim());
      await _saveCards();
    }
  }

  Future<void> _deleteCard(TestCallCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text(
            'Remove "${card.cardName}"? This only deletes the saved card, not anything on the backend.'),
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
      setState(() => _cards.removeWhere((c) => c.id == card.id));
      await _saveCards();
    }
  }

  // ── Test call popup ──────────────────────────────────────────────────────

  Future<void> _showCallPopup(TestCallCard card) async {
    final phoneCtl = TextEditingController(text: '+91');
    bool replace = false;
    bool sending = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _kSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Call via ${card.agentName}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _kText, fontSize: 18)),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    label: 'Phone Number',
                    controller: phoneCtl,
                    hint: '+917075527199',
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Required';
                      if (!RegExp(r'^\+\d{8,15}$').hasMatch(t)) {
                        return 'E.164 format, e.g. +917075527199';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: replace,
                        activeColor: _kPrimary,
                        onChanged: sending
                            ? null
                            : (v) => setLocal(() => replace = v ?? false),
                      ),
                      const Expanded(
                        child: Text('Replace existing lead for this number',
                            style: TextStyle(color: _kText, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${card.agentNumber}  ·  Campaign: ${card.campaignId}',
                    style: const TextStyle(color: _kMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: _kMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setLocal(() => sending = true);
                      final result = await _dispatchCall(
                        card: card,
                        number: phoneCtl.text.trim(),
                        replace: replace,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (!mounted) return;
                      if (result.success) {
                        _toast(
                            'Call dispatched to ${result.toNumber ?? phoneCtl.text.trim()}');
                      } else {
                        _toast(result.errorMessage ?? 'Call failed',
                            isError: true);
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Call'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_CallOutcome> _dispatchCall({
    required TestCallCard card,
    required String number,
    required bool replace,
  }) async {
    try {
      final res = await _platformDio.post(
        '/api/v1/campaigns/${card.campaignId}/test-call',
        data: {
          'numbers': [number],
          'replace': replace,
        },
        options: Options(headers: {'x-api-key': card.apiKey}),
      );
      final data = res.data;
      if (data is Map) {
        final results = data['results'];
        if (results is List && results.isNotEmpty) {
          final first = Map<String, dynamic>.from(results.first as Map);
          final ok = first['success'] == true;
          if (ok) {
            return _CallOutcome.ok(toNumber: first['to']?.toString() ?? number);
          }
          return _CallOutcome.fail(
              first['error']?.toString() ?? 'Call dispatch failed');
        }
        return _CallOutcome.fail(
            data['message']?.toString() ?? 'Unexpected response shape');
      }
      return _CallOutcome.fail('Unexpected response');
    } on DioException catch (e) {
      final body = e.response?.data;
      String? msg;
      if (body is Map) {
        msg = (body['error'] ?? body['message'])?.toString();
      } else if (body is String && body.isNotEmpty) {
        msg = body;
      }
      msg ??= e.message ?? 'Network error';
      return _CallOutcome.fail('${e.response?.statusCode ?? ''} $msg'.trim());
    } catch (e) {
      return _CallOutcome.fail(e.toString());
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _kPrimary))
                    : _cards.isEmpty
                        ? _buildEmpty()
                        : _buildGrid(),
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
              Text('Test Calls',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _kText)),
              SizedBox(height: 4),
              Text('Saved agent configurations for quick test dispatch',
                  style: TextStyle(fontSize: 13, color: _kMuted)),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(_isMobile ? 'New' : 'New Card'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 14 : 18, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _showCardDialog(),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_in_talk_outlined,
              size: 56, color: _kMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('No cards yet',
              style: TextStyle(color: _kMuted, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Create your first test call card to get started.',
              style: TextStyle(color: _kMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final width = MediaQuery.of(context).size.width;
    int cols;
    if (width < 700) {
      cols = 1;
    } else if (width < 1100) {
      cols = 2;
    } else if (width < 1500) {
      cols = 3;
    } else {
      cols = 4;
    }

    return GridView.builder(
      itemCount: _cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 168,
      ),
      itemBuilder: (ctx, i) => _CardTile(
        card: _cards[i],
        onTap: () => _showCallPopup(_cards[i]),
        onRename: () => _renameCard(_cards[i]),
        onEdit: () => _showCardDialog(existing: _cards[i]),
        onDelete: () => _deleteCard(_cards[i]),
        onDialNumber: () => _dialNumber(_cards[i].agentNumber),
        onCopyNumber: () => _copyNumber(_cards[i].agentNumber),
      ),
    );
  }
}

// ─── Card tile ────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final TestCallCard card;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDialNumber;
  final VoidCallback onCopyNumber;

  const _CardTile({
    required this.card,
    required this.onTap,
    required this.onRename,
    required this.onEdit,
    required this.onDelete,
    required this.onDialNumber,
    required this.onCopyNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onRename,
                      child: Tooltip(
                        message: 'Click to rename',
                        child: Text(
                          card.cardName.isEmpty ? '(unnamed)' : card.cardName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: _kMuted),
                    onSelected: (v) {
                      if (v == 'rename') onRename();
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                card.agentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: onDialNumber,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          card.agentNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kPrimary,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: _kPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _NumIconBtn(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy number',
                    onTap: onCopyNumber,
                  ),
                  const SizedBox(width: 4),
                  _NumIconBtn(
                    icon: Icons.call,
                    tooltip: 'Call',
                    color: _kPrimary,
                    onTap: onDialNumber,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.campaignId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kMuted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call, size: 12, color: _kPrimary),
                        SizedBox(width: 4),
                        Text('Call',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _NumIconBtn({
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
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: (color ?? _kMuted).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color ?? _kMuted),
        ),
      ),
    );
  }
}

// ─── Field widget + helpers ───────────────────────────────────────────────────

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscure;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.obscure = false,
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
          keyboardType: keyboardType,
          validator: validator,
          obscureText: obscure,
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

// ─── Call outcome ─────────────────────────────────────────────────────────────

class _CallOutcome {
  final bool success;
  final String? toNumber;
  final String? errorMessage;

  _CallOutcome._({required this.success, this.toNumber, this.errorMessage});

  factory _CallOutcome.ok({String? toNumber}) =>
      _CallOutcome._(success: true, toNumber: toNumber);
  factory _CallOutcome.fail(String message) =>
      _CallOutcome._(success: false, errorMessage: message);
}
