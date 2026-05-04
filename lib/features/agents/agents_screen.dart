import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/config/app_config.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF414099);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);
const _kSurface = Colors.white;
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1A1A);

const String _kPhonePrefix = '+9140453074';
const String _kRealEstateVertical = 'realestate';
const String _kVisaVertical = 'visa';

// ─── Model ────────────────────────────────────────────────────────────────────

class TestCallCard {
  String id;
  String cardName;
  String agentName;
  String agentNumber;
  String campaignId;
  String verticalName;
  String? createdAt;

  TestCallCard({
    required this.id,
    required this.cardName,
    required this.agentName,
    required this.agentNumber,
    required this.campaignId,
    required this.verticalName,
    this.createdAt,
  });

  factory TestCallCard.fromJson(Map<String, dynamic> j) => TestCallCard(
        id: (j['id'] ?? j['campaign_id'] ?? '').toString(),
        cardName: (j['card_name'] ?? j['campaign_name'] ?? j['name'] ?? '')
            .toString(),
        agentName:
            (j['agent_name'] ?? j['agent'] ?? j['name'] ?? '').toString(),
        agentNumber: (j['agent_number'] ??
                j['from_number'] ??
                j['phone_number'] ??
                j['number'] ??
                '')
            .toString(),
        campaignId: (j['campaign_id'] ?? j['id'] ?? '').toString(),
        verticalName: _normalizeVerticalName(j['vertical_name']?.toString()),
        createdAt: j['created_at']?.toString(),
      );
}

class CampaignVertical {
  final String? id;
  final String name;
  final String slug;
  final String baseUrl;
  final String adminKeyLast4;
  final bool isActive;
  final String source;
  final int cardCount;

  CampaignVertical({
    this.id,
    required this.name,
    required this.slug,
    required this.baseUrl,
    required this.adminKeyLast4,
    required this.isActive,
    required this.source,
    required this.cardCount,
  });

  factory CampaignVertical.fromJson(Map<String, dynamic> j) => CampaignVertical(
        id: j['id']?.toString(),
        name: (j['name'] ?? '').toString(),
        slug: _normalizeVerticalName(j['slug']?.toString()),
        baseUrl: (j['base_url'] ?? '').toString(),
        adminKeyLast4: (j['admin_key_last4'] ?? '').toString(),
        isActive: j['is_active'] != false,
        source: (j['source'] ?? 'database').toString(),
        cardCount: int.tryParse(
              (j['card_count'] ?? 0).toString(),
            ) ??
            0,
      );

  CampaignVertical copyWith({int? cardCount}) => CampaignVertical(
        id: id,
        name: name,
        slug: slug,
        baseUrl: baseUrl,
        adminKeyLast4: adminKeyLast4,
        isActive: isActive,
        source: source,
        cardCount: cardCount ?? this.cardCount,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<CampaignVertical> _verticals = [];
  List<TestCallCard> _cards = [];
  String? _selectedVerticalName;
  bool _loading = true;
  String? _error;

  ApiClient get _api => context.read<ApiClient>();

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  bool get _canEdit {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    return state.user.hasEditAccess(AppConfig.pageAgents);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final verticals = await _fetchVerticals();
      final selected = _resolveSelectedVertical(verticals);
      final cards =
          selected == null ? <TestCallCard>[] : await _fetchCards(selected);
      if (!mounted) return;
      setState(() {
        _verticals = verticals;
        _selectedVerticalName = selected;
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _readableError(e, fallback: 'Failed to load cards');
      });
    }
  }

  Future<List<CampaignVertical>> _fetchVerticals() async {
    final verticalsRes = await _api.getTestCallVerticals();
    final countsRes = await _api.getTestCallCardVerticals();
    final verticalsRoot = verticalsRes.data is Map
        ? (verticalsRes.data['data'] ?? verticalsRes.data)
        : verticalsRes.data;
    final countsRoot = countsRes.data is Map
        ? (countsRes.data['data'] ?? countsRes.data)
        : countsRes.data;

    List? verticalsRaw;
    if (verticalsRoot is List) {
      verticalsRaw = verticalsRoot;
    } else if (verticalsRoot is Map) {
      verticalsRaw =
          (verticalsRoot['verticals'] ?? verticalsRoot['items'] ?? verticalsRoot['rows'])
              as List?;
    }

    List? countsRaw;
    if (countsRoot is List) {
      countsRaw = countsRoot;
    } else if (countsRoot is Map) {
      countsRaw =
          (countsRoot['verticals'] ?? countsRoot['items'] ?? countsRoot['rows'])
              as List?;
    }

    final counts = <String, int>{};
    for (final item in countsRaw ?? []) {
      final map = Map<String, dynamic>.from(item as Map);
      final slug = _normalizeVerticalName(
        (map['slug'] ?? map['name'] ?? '').toString(),
      );
      counts[slug] = int.tryParse(
            (map['card_count'] ?? map['campaign_count'] ?? 0).toString(),
          ) ??
          0;
    }

    final verticals = (verticalsRaw ?? [])
        .map((e) => CampaignVertical.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((v) => v.isActive)
        .map((v) => v.copyWith(cardCount: counts[v.slug] ?? 0))
        .toList();
    verticals.sort((a, b) {
      if (a.slug == _kRealEstateVertical) return -1;
      if (b.slug == _kRealEstateVertical) return 1;
      if (a.slug == _kVisaVertical) return -1;
      if (b.slug == _kVisaVertical) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return verticals;
  }

  Future<List<TestCallCard>> _fetchCards(String verticalName) async {
    final res = await _api.getTestCallCards(verticalName: verticalName);
    final root = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
    List? raw;
    if (root is List) {
      raw = root;
    } else if (root is Map) {
      raw = (root['campaigns'] ??
          root['cards'] ??
          root['items'] ??
          root['rows']) as List?;
    }
    return (raw ?? []).map((e) {
      final card = TestCallCard.fromJson(Map<String, dynamic>.from(e as Map));
      card.verticalName = verticalName;
      return card;
    }).toList();
  }

  String? _resolveSelectedVertical(List<CampaignVertical> verticals) {
    if (verticals.isEmpty) return _kRealEstateVertical;
    final current = _selectedVerticalName;
    if (current != null && verticals.any((v) => v.slug == current)) {
      return current;
    }
    if (verticals.any((v) => v.slug == _kRealEstateVertical)) {
      return _kRealEstateVertical;
    }
    return _kRealEstateVertical;
  }

  Future<void> _selectVertical(String verticalName) async {
    if (!_verticals.any((v) => v.slug == verticalName)) return;
    if (_selectedVerticalName == verticalName) return;
    setState(() {
      _selectedVerticalName = verticalName;
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _fetchCards(verticalName);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _readableError(e, fallback: 'Failed to load cards');
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _readableError(Object e, {required String fallback}) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map) {
        final msg = (body['error'] ?? body['message'])?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
      if (e.response?.statusCode == 403) {
        return 'You do not have access to this action';
      }
    }
    return fallback;
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

  // ── Card create / edit / delete ──────────────────────────────────────────

  Future<void> _showCardDialog({TestCallCard? existing}) async {
    if (!_canEdit) return;
    final isEdit = existing != null;
    var verticalName = isEdit
        ? _normalizeVerticalName(existing!.verticalName)
        : _kRealEstateVertical;
    final activeVerticals = _verticals.isEmpty
        ? [
            CampaignVertical(
              name: 'Real Estate',
              slug: _kRealEstateVertical,
              baseUrl: '',
              adminKeyLast4: '',
              isActive: true,
              source: 'env',
              cardCount: 0,
            ),
          ]
        : _verticals;
    if (!activeVerticals.any((v) => v.slug == verticalName)) {
      verticalName = activeVerticals.first.slug;
    }
    final cardCtl = TextEditingController(text: existing?.cardName ?? '');
    final agentCtl = TextEditingController(text: existing?.agentName ?? '');

    final existingSuffix =
        existing != null && existing.agentNumber.startsWith(_kPhonePrefix)
            ? existing.agentNumber.substring(_kPhonePrefix.length)
            : '';
    final numberCtl = TextEditingController(text: existingSuffix);
    final campaignCtl = TextEditingController(text: existing?.campaignId ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _kSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      hint: 'XX',
                      keyboardType: TextInputType.number,
                      prefixText: '$_kPhonePrefix ',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Required';
                        if (!RegExp(r'^\d{2}$').hasMatch(t)) {
                          return 'Enter exactly 2 digits';
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
                    _VerticalSelector(
                      value: verticalName,
                      verticals: activeVerticals,
                      onChanged: (value) =>
                          setLocal(() => verticalName = value),
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
      ),
    );

    if (saved != true) return;

    final fullNumber = '$_kPhonePrefix${numberCtl.text.trim()}';

    final payload = <String, dynamic>{
      'card_name': cardCtl.text.trim(),
      'agent_name': agentCtl.text.trim(),
      'agent_number': fullNumber,
      'campaign_id': campaignCtl.text.trim(),
      'vertical_name': verticalName,
    };

    try {
      if (isEdit) {
        await _api.updateTestCallCard(existing!.id, payload);
        _toast('Card saved');
      } else {
        await _api.createTestCallCard(payload);
        _toast('Card created');
      }
      await _load();
    } catch (e) {
      _toast(
        _readableError(e,
            fallback: isEdit ? 'Failed to save card' : 'Failed to create card'),
        isError: true,
      );
    }
  }

  Future<void> _renameCard(TestCallCard card) async {
    if (!_canEdit) return;
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
    if (ok != true) return;
    try {
      await _api.updateTestCallCard(card.id, {
        'card_name': ctl.text.trim(),
        'vertical_name': card.verticalName,
      });
      await _load();
    } catch (e) {
      _toast(_readableError(e, fallback: 'Failed to rename card'),
          isError: true);
    }
  }

  Future<void> _deleteCard(TestCallCard card) async {
    if (!_canEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text(
            'Remove "${card.cardName}"? This deletes the card for everyone.'),
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
      await _api.deleteTestCallCard(card.id);
      _toast('Card deleted');
      await _load();
    } catch (e) {
      _toast(_readableError(e, fallback: 'Failed to delete card'),
          isError: true);
    }
  }

  Future<void> _showVerticalManager() async {
    final canEdit = _canEdit;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Test Call Verticals',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: _kText, fontSize: 18)),
        content: SizedBox(
          width: 720,
          child: _verticals.isEmpty
              ? const Text('No active verticals found.',
                  style: TextStyle(color: _kMuted))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final vertical in _verticals) ...[
                      _VerticalManagementRow(
                        vertical: vertical,
                        canEdit: canEdit,
                        onEdit: () {
                          Navigator.of(ctx).pop();
                          _showVerticalDialog(existing: vertical);
                        },
                        onDeactivate: () {
                          Navigator.of(ctx).pop();
                          _deactivateVertical(vertical);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: _kMuted)),
          ),
          if (canEdit)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Vertical'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showVerticalDialog();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showVerticalDialog({CampaignVertical? existing}) async {
    if (!_canEdit) return;
    final isEdit = existing != null;
    if (isEdit && existing!.source == 'env') {
      _toast('This vertical is configured in server env', isError: true);
      return;
    }

    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final slugCtl = TextEditingController(text: existing?.slug ?? '');
    final baseUrlCtl = TextEditingController(text: existing?.baseUrl ?? '');
    final adminKeyCtl = TextEditingController();
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _kSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isEdit ? 'Edit Vertical' : 'New Vertical',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _kText, fontSize: 18)),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field(
                    label: 'Name',
                    controller: nameCtl,
                    hint: 'e.g. Visa',
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Slug',
                    controller: slugCtl,
                    hint: 'e.g. visa',
                    enabled: !isEdit,
                    validator: (v) {
                      final slug = _slugFromInput(v);
                      if (slug.isEmpty) return 'Required';
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(slug)) {
                        return 'Use lowercase letters, numbers, or underscore';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: 'Base URL',
                    controller: baseUrlCtl,
                    hint: 'https://api.example.com',
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: isEdit ? 'New Admin Key (optional)' : 'Admin Key',
                    controller: adminKeyCtl,
                    hint: isEdit
                        ? 'Leave blank to keep existing key'
                        : 'secret-admin-key',
                    obscure: true,
                    validator: (v) => isEdit ? null : _required(v),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    activeColor: _kPrimary,
                    onChanged: (value) =>
                        setLocal(() => isActive = value ?? true),
                    title: const Text('Active',
                        style: TextStyle(color: _kText, fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
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
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final adminKey = adminKeyCtl.text.trim();
    final payload = <String, dynamic>{
      'name': nameCtl.text.trim(),
      'base_url': baseUrlCtl.text.trim(),
      'is_active': isActive,
    };
    if (!isEdit) {
      payload['slug'] = _slugFromInput(slugCtl.text);
      payload['admin_key'] = adminKey;
    } else if (adminKey.isNotEmpty) {
      payload['admin_key'] = adminKey;
    }
    adminKeyCtl.clear();

    try {
      if (isEdit) {
        await _api.updateTestCallVertical(existing!.slug, payload);
        _toast('Vertical saved');
      } else {
        await _api.createTestCallVertical(payload);
        _toast('Vertical created');
      }
      await _load();
    } catch (e) {
      _toast(
        _readableError(e,
            fallback:
                isEdit ? 'Failed to save vertical' : 'Failed to create vertical'),
        isError: true,
      );
    }
  }

  Future<void> _deactivateVertical(CampaignVertical vertical) async {
    if (!_canEdit) return;
    if (vertical.source == 'env') {
      _toast('This vertical is configured in server env', isError: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate vertical?'),
        content: Text('Deactivate "${_verticalLabel(vertical.slug)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Deactivate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deactivateTestCallVertical(vertical.slug);
      _toast('Vertical deactivated');
      await _load();
    } catch (e) {
      _toast(_readableError(e, fallback: 'Failed to deactivate vertical'),
          isError: true);
    }
  }

  // ── Test call popup ──────────────────────────────────────────────────────

  Future<void> _showCallPopup(TestCallCard card) async {
    final phoneCtl = TextEditingController(text: '+91');
    bool sending = false;
    bool replaceExisting = false;
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
            child: SingleChildScrollView(
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
                    const SizedBox(height: 8),
                    Text(
                      'From: ${card.agentNumber}  ·  Campaign: ${card.campaignId}',
                      style: const TextStyle(color: _kMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: replaceExisting,
                            activeColor: _kPrimary,
                            onChanged: sending
                                ? null
                                : (value) => setLocal(
                                      () => replaceExisting = value ?? false,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Replace existing lead for this number',
                            style: TextStyle(color: _kText, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                        replace: replaceExisting,
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
      final res = await _api.dispatchTestCall(
        card.id,
        numbers: [
          [number, null, card.agentName],
        ],
        replace: replace,
      );

      final data = res.data;
      Map? envelope;
      if (data is Map) {
        envelope = data['data'] is Map ? data['data'] as Map : data;
      }
      if (envelope != null) {
        final results = envelope['results'];
        if (results is List && results.isNotEmpty) {
          final first = Map<String, dynamic>.from(results.first as Map);
          final ok = first['success'] == true;
          if (ok) {
            return _CallOutcome.ok(
                toNumber: first['to']?.toString() ?? number);
          }
          return _CallOutcome.fail(
              first['error']?.toString() ?? 'Call dispatch failed');
        }
        // Some responses may only have a top-level message without results.
        final msg = envelope['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          return _CallOutcome.ok(toNumber: number);
        }
      }
      return _CallOutcome.ok(toNumber: number);
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
              if (_verticals.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildVerticalTabs(),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _kPrimary))
                    : _error != null
                        ? _buildError()
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
    final canEdit = _canEdit;
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
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: _kMuted),
        ),
        const SizedBox(width: 4),
        OutlinedButton.icon(
          icon: const Icon(Icons.tune, size: 18),
          label: Text(_isMobile ? 'Verticals' : 'Manage Verticals'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPrimary,
            side: const BorderSide(color: _kBorder),
            padding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 12 : 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _showVerticalManager,
        ),
        const SizedBox(width: 8),
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
          onPressed: canEdit && _selectedVerticalName != null
              ? () => _showCardDialog()
              : null,
        ),
      ],
    );
  }

  Widget _buildVerticalTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            _isMobile ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final vertical in _verticals)
              _VerticalOptionTile(
                width: tileWidth,
                vertical: vertical,
                selected: vertical.slug == _selectedVerticalName,
                onTap: () => _selectVertical(vertical.slug),
              ),
          ],
        );
      },
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
          Text(
              _selectedVerticalName == null
                  ? 'No verticals yet'
                  : 'No cards in ${_verticalLabel(_selectedVerticalName!)}',
              style: const TextStyle(color: _kMuted, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Create your first test call card to get started.',
              style: TextStyle(color: _kMuted, fontSize: 12)),
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
              style: const TextStyle(color: _kMuted, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: _load,
            child: const Text('Retry'),
          ),
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
        canEdit: _canEdit,
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
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDialNumber;
  final VoidCallback onCopyNumber;

  const _CardTile({
    required this.card,
    required this.canEdit,
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
                      onTap: canEdit ? onRename : null,
                      child: Tooltip(
                        message: canEdit ? 'Click to rename' : card.cardName,
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
                  if (canEdit)
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

class _VerticalOptionTile extends StatelessWidget {
  final double width;
  final CampaignVertical vertical;
  final bool selected;
  final VoidCallback onTap;

  const _VerticalOptionTile({
    required this.width,
    required this.vertical,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? _kPrimary.withValues(alpha: 0.08) : _kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? _kPrimary : _kBorder),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? _kPrimary : _kMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _verticalLabel(vertical.slug),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _kPrimary : _kText,
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${vertical.cardCount} cards',
                  style: TextStyle(
                    color: selected ? _kPrimary : _kMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _VerticalManagementRow extends StatelessWidget {
  final CampaignVertical vertical;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _VerticalManagementRow({
    required this.vertical,
    required this.canEdit,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isEnv = vertical.source == 'env';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vertical.name.isEmpty
                            ? _verticalLabel(vertical.slug)
                            : vertical.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SourceBadge(source: vertical.source),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${vertical.slug}  ·  ${vertical.cardCount} cards'
                  '${vertical.adminKeyLast4.isNotEmpty ? '  ·  key ...${vertical.adminKeyLast4}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                ),
                if (isEnv)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Configured in server env',
                      style: TextStyle(color: _kMuted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (canEdit && !isEnv) ...[
            IconButton(
              tooltip: 'Edit vertical',
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18, color: _kMuted),
            ),
            IconButton(
              tooltip: 'Deactivate vertical',
              onPressed: onDeactivate,
              icon: const Icon(Icons.block, size: 18, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isEnv = source == 'env';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isEnv ? _kPrimary : Colors.green).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isEnv ? 'env' : 'database',
        style: TextStyle(
          color: isEnv ? _kPrimary : Colors.green[700],
          fontSize: 11,
          fontWeight: FontWeight.w600,
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

String _slugFromInput(String? name) {
  final raw = (name ?? '').trim().toLowerCase();
  return raw.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
}

String _normalizeVerticalName(String? name) {
  final raw = (name ?? '').trim().toLowerCase();
  if (raw.isEmpty) return _kRealEstateVertical;
  if (raw == 'real_estate') return _kRealEstateVertical;
  return _slugFromInput(raw);
}

String _verticalLabel(String name) {
  final normalized = _normalizeVerticalName(name);
  if (normalized == _kVisaVertical) return 'Visa';
  if (normalized == _kRealEstateVertical) return 'Real Estate';
  return normalized
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _VerticalSelector extends StatelessWidget {
  final String value;
  final List<CampaignVertical> verticals;
  final ValueChanged<String> onChanged;

  const _VerticalSelector({
    required this.value,
    required this.verticals,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vertical',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _kMuted,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: [
            for (final vertical in verticals)
              DropdownMenuItem(
                value: vertical.slug,
                child: Text(_verticalLabel(vertical.slug)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          decoration: InputDecoration(
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

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscure;
  final bool enabled;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.obscure = false,
    this.enabled = true,
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
                fontSize: 12, fontWeight: FontWeight.w500, color: _kMuted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          validator: validator,
          obscureText: obscure,
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
