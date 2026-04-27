import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

const _kGreen = Color(0xFF22C55E);
const _kAmber = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kBlue = Color(0xFF3B82F6);

// ─── Enums ────────────────────────────────────────────────────────────────────

enum ClientStage { lead, nod, onboarding, active, hold, churned }

extension ClientStageX on ClientStage {
  String get apiValue => switch (this) {
    ClientStage.lead => 'lead',
    ClientStage.nod => 'nod',
    ClientStage.onboarding => 'onboarding',
    ClientStage.active => 'active',
    ClientStage.hold => 'hold',
    ClientStage.churned => 'churned',
  };

  String get label => switch (this) {
    ClientStage.lead => 'Lead',
    ClientStage.nod => 'Nod Received',
    ClientStage.onboarding => 'Onboarding',
    ClientStage.active => 'Active',
    ClientStage.hold => 'On Hold',
    ClientStage.churned => 'Churned',
  };

  Color get bgColor => switch (this) {
    ClientStage.lead => const Color(0xFFDBEAFE),
    ClientStage.nod => const Color(0xFFFEF3C7),
    ClientStage.onboarding => const Color(0xFFFED7AA),
    ClientStage.active => const Color(0xFFD1FAE5),
    ClientStage.hold => const Color(0xFFE5E7EB),
    ClientStage.churned => const Color(0xFFFEE2E2),
  };

  Color get textColor => switch (this) {
    ClientStage.lead => const Color(0xFF1E40AF),
    ClientStage.nod => const Color(0xFF92400E),
    ClientStage.onboarding => const Color(0xFF9A3412),
    ClientStage.active => const Color(0xFF065F46),
    ClientStage.hold => const Color(0xFF374151),
    ClientStage.churned => const Color(0xFF991B1B),
  };
}

ClientStage _parseStage(String? s) => switch (s) {
  'lead' => ClientStage.lead,
  'nod' => ClientStage.nod,
  'onboarding' => ClientStage.onboarding,
  'active' => ClientStage.active,
  'hold' => ClientStage.hold,
  'churned' => ClientStage.churned,
  _ => ClientStage.lead,
};

enum OnboardingSubstage { creation, review, live }

extension OnboardingSubstageX on OnboardingSubstage {
  String get apiValue => switch (this) {
    OnboardingSubstage.creation => 'creation',
    OnboardingSubstage.review => 'review',
    OnboardingSubstage.live => 'live',
  };

  double get progress => switch (this) {
    OnboardingSubstage.creation => 0.33,
    OnboardingSubstage.review => 0.67,
    OnboardingSubstage.live => 1.0,
  };

  String get label => switch (this) {
    OnboardingSubstage.creation => 'Agent & KB Creation',
    OnboardingSubstage.review => 'Review & Test Calling',
    OnboardingSubstage.live => 'Live Deployment',
  };
}

OnboardingSubstage? _parseSubstage(String? s) => switch (s) {
  'creation' => OnboardingSubstage.creation,
  'review' => OnboardingSubstage.review,
  'live' => OnboardingSubstage.live,
  _ => null,
};

enum ClientProduct { engage, whatsapp, capi, ira, api }

extension ClientProductX on ClientProduct {
  String get apiValue => switch (this) {
    ClientProduct.engage => 'ENGAGE',
    ClientProduct.whatsapp => 'WhatsApp',
    ClientProduct.capi => 'CAPI',
    ClientProduct.ira => 'IRA',
    ClientProduct.api => 'API',
  };

  String get label => apiValue;
}

ClientProduct _parseProduct(String? s) => switch (s) {
  'ENGAGE' => ClientProduct.engage,
  'WhatsApp' => ClientProduct.whatsapp,
  'CAPI' => ClientProduct.capi,
  'IRA' => ClientProduct.ira,
  'API' => ClientProduct.api,
  _ => ClientProduct.engage,
};

// ─── Models ───────────────────────────────────────────────────────────────────

class Client {
  final String id;
  String name;
  String vertical;
  ClientProduct product;
  ClientStage stage;
  OnboardingSubstage? onboardingSubstage;
  String contactPerson;
  String contactEmail;
  String contactPhone;
  String notes;
  double? setupFee;
  double? monthlyFee;
  double? perCallRate;
  DateTime? contractStartDate;
  DateTime? contractEndDate;
  DateTime? leadDate;
  DateTime? nodReceivedDate;
  DateTime? onboardingStartDate;
  DateTime? goLiveDate;
  DateTime? churnedDate;
  // Stage-specific fields
  String? referralSource;
  String? problemStatement;
  String? companyHistory;
  String? companyWebsite;
  String? salesStrategy;
  String? planOfAction;
  String? roadmap;
  String? engagementTimeline;
  String? paymentStructure;
  int numProjects;
  int numCampaigns;
  int numSiteVisits;
  String? paymentTimeline;
  String? monthlyReportNotes;

  Client({
    required this.id,
    required this.name,
    required this.vertical,
    required this.product,
    required this.stage,
    this.onboardingSubstage,
    this.contactPerson = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.notes = '',
    this.setupFee,
    this.monthlyFee,
    this.perCallRate,
    this.contractStartDate,
    this.contractEndDate,
    this.leadDate,
    this.nodReceivedDate,
    this.onboardingStartDate,
    this.goLiveDate,
    this.churnedDate,
    this.referralSource,
    this.problemStatement,
    this.companyHistory,
    this.companyWebsite,
    this.salesStrategy,
    this.planOfAction,
    this.roadmap,
    this.engagementTimeline,
    this.paymentStructure,
    this.numProjects = 0,
    this.numCampaigns = 0,
    this.numSiteVisits = 0,
    this.paymentTimeline,
    this.monthlyReportNotes,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    vertical: j['vertical'] as String? ?? '',
    product: _parseProduct(j['product'] as String?),
    stage: _parseStage(j['stage'] as String?),
    onboardingSubstage: _parseSubstage(j['onboarding_substage'] as String?),
    contactPerson: j['contact_person'] as String? ?? '',
    contactEmail: j['contact_email'] as String? ?? '',
    contactPhone: j['contact_phone'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    setupFee: _parseNum(j['setup_fee']),
    monthlyFee: _parseNum(j['monthly_fee']),
    perCallRate: _parseNum(j['per_call_rate']),
    contractStartDate: _parseDate(j['contract_start_date']),
    contractEndDate: _parseDate(j['contract_end_date']),
    leadDate: _parseDate(j['lead_date']),
    nodReceivedDate: _parseDate(j['nod_received_date']),
    onboardingStartDate: _parseDate(j['onboarding_start_date']),
    goLiveDate: _parseDate(j['go_live_date']),
    churnedDate: _parseDate(j['churned_date']),
    referralSource: j['referral_source'] as String?,
    problemStatement: j['problem_statement'] as String?,
    companyHistory: j['company_history'] as String?,
    companyWebsite: j['company_website'] as String?,
    salesStrategy: j['sales_strategy'] as String?,
    planOfAction: j['plan_of_action'] as String?,
    roadmap: j['roadmap'] as String?,
    engagementTimeline: j['engagement_timeline'] as String?,
    paymentStructure: j['payment_structure'] as String?,
    numProjects: (j['num_projects'] as num?)?.toInt() ?? 0,
    numCampaigns: (j['num_campaigns'] as num?)?.toInt() ?? 0,
    numSiteVisits: (j['num_site_visits'] as num?)?.toInt() ?? 0,
    paymentTimeline: j['payment_timeline'] as String?,
    monthlyReportNotes: j['monthly_report_notes'] as String?,
  );

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  Client? _selected;
  ClientStage? _filterStage;
  ClientProduct? _filterProduct;
  final _searchCtrl = TextEditingController();
  String _search = '';

  List<Client> _clients = [];
  Map<ClientStage, int> _stageCounts = {};
  Map<ClientProduct, int> _productCounts = {};
  int _totalClients = 0;
  int _upcomingMeetings = 0;
  bool _loading = true;
  String? _error;
  final Set<String> _deletingClientIds = {};
  final Set<String> _selectedClientIds = {};
  bool _bulkDeleting = false;

  late final ApiClient _api = context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getClients(
          stage: _filterStage?.apiValue,
          product: _filterProduct?.apiValue,
          search: _search.isEmpty ? null : _search,
          limit: 100,
        ),
        _api.getDashboardStats(),
      ]);
      // Use dynamic indexing rather than explicit Map<String, dynamic> casts —
      // Dio may parse nested JSON as Map<dynamic, dynamic>, which fails the cast.
      final clientsData = results[0].data['data'];
      final list = ((clientsData?['clients'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final statsData = results[1].data['data'];
      final clientsBlock = statsData?['clients'];
      final meetingsBlock = statsData?['meetings'];

      int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;

      setState(() {
        _clients = list.map(Client.fromJson).toList();
        _totalClients = asInt(clientsBlock?['total']);
        if (_totalClients == 0 && _clients.isNotEmpty)
          _totalClients = _clients.length;
        _stageCounts = {
          for (final s in ClientStage.values)
            s: asInt(clientsBlock?['by_stage']?[s.apiValue]),
        };
        _productCounts = {
          for (final p in ClientProduct.values)
            p: asInt(clientsBlock?['by_product']?[p.apiValue]),
        };
        _upcomingMeetings = asInt(meetingsBlock?['upcoming_count']);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = _extractErrorMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopBar(
          onAdd: _showAddClientDialog,
          searchCtrl: _searchCtrl,
          onSearch: (v) {
            setState(() => _search = v);
            _debouncedLoad();
          },
        ),
        _StatsRow(
          stageCounts: _stageCounts,
          productCounts: _productCounts,
          total: _totalClients,
          upcomingMeetings: _upcomingMeetings,
        ),
        _StageFilterBar(
          active: _filterStage,
          onSelect: (s) {
            setState(() => _filterStage = _filterStage == s ? null : s);
            _loadClients();
          },
        ),
        _ProductFilterBar(
          active: _filterProduct,
          onSelect: (p) {
            setState(() => _filterProduct = _filterProduct == p ? null : p);
            _loadClients();
          },
        ),
        if (_selectedClientIds.isNotEmpty)
          _BulkDeleteBar(
            selectedCount: _selectedClientIds.length,
            totalVisible: _clients.length,
            deleting: _bulkDeleting,
            onSelectAll: _selectAllVisibleClients,
            onClear: _clearClientSelection,
            onDelete: _deleteSelectedClients,
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadClients)
              : _clients.isEmpty
              ? const _EmptyState()
              : _ClientList(
                  clients: _clients,
                  selectedId: _selected?.id,
                  deletingIds: _deletingClientIds,
                  selectedIds: _selectedClientIds,
                  selectionMode: _selectedClientIds.isNotEmpty,
                  onTap: (c) {
                    if (_selectedClientIds.isNotEmpty) {
                      _toggleClientSelection(c.id);
                      return;
                    }
                    if (isMobile) {
                      setState(() => _selected = c);
                      _showDetailBottomSheet(context, c);
                    } else {
                      setState(
                        () => _selected = _selected?.id == c.id ? null : c,
                      );
                    }
                  },
                  onDelete: (client) {
                    _deleteClient(client);
                  },
                  onToggleSelection: _toggleClientSelection,
                ),
        ),
      ],
    );

    if (isMobile) return content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: content),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: _selected != null ? 400 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            color: _kSurface,
            border: Border(left: BorderSide(color: _kBorder)),
          ),
          child: _selected != null
              ? _ClientDetailPanel(
                  key: ValueKey(_selected!.id),
                  client: _selected!,
                  api: _api,
                  onClose: () => setState(() => _selected = null),
                  onDelete: () {
                    _deleteClient(_selected!);
                  },
                  onUpdated: (updated) {
                    setState(() {
                      _selected = updated;
                      final idx = _clients.indexWhere(
                        (c) => c.id == updated.id,
                      );
                      if (idx != -1) _clients[idx] = updated;
                    });
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // Simple debounce for search
  int _searchTick = 0;
  Future<void> _debouncedLoad() async {
    final tick = ++_searchTick;
    await Future.delayed(const Duration(milliseconds: 350));
    if (tick != _searchTick) return;
    _loadClients();
  }

  void _showDetailBottomSheet(BuildContext context, Client client) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: _ClientDetailPanel(
                  key: ValueKey(client.id),
                  client: client,
                  api: _api,
                  onClose: () => Navigator.of(context).pop(),
                  onDelete: () {
                    final navigator = Navigator.of(context);
                    _deleteClient(client).then((deleted) {
                      if (deleted && mounted && navigator.canPop()) {
                        navigator.pop();
                      }
                    });
                  },
                  onUpdated: (updated) {
                    setState(() {
                      _selected = updated;
                      final idx = _clients.indexWhere(
                        (c) => c.id == updated.id,
                      );
                      if (idx != -1) _clients[idx] = updated;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _selected = null));
  }

  void _showAddClientDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AddClientDialog(
        api: _api,
        onAdded: (client) => setState(() {
          _clients.insert(0, client);
          _totalClients++;
          _stageCounts[client.stage] = (_stageCounts[client.stage] ?? 0) + 1;
          _productCounts[client.product] =
              (_productCounts[client.product] ?? 0) + 1;
        }),
      ),
    );
  }

  Future<bool> _deleteClient(Client client) async {
    if (_deletingClientIds.contains(client.id)) return false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete client?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will permanently delete ${client.name}. This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return false;
    if (!mounted) return false;

    setState(() => _deletingClientIds.add(client.id));
    try {
      final res = await _api.deleteClient(client.id);
      if (!mounted) return false;

      final statusCode = res.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw Exception('Delete failed with status $statusCode');
      }

      await _loadClients();
      if (!mounted) return false;

      final stillExists = _clients.any((c) => c.id == client.id);
      setState(() {
        _deletingClientIds.remove(client.id);
        _selectedClientIds.remove(client.id);
        if (_selected?.id == client.id && !stillExists) _selected = null;
      });

      if (stillExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delete returned $statusCode, but GET /clients still includes this client.',
            ),
            backgroundColor: _kRed,
          ),
        );
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client deleted')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _deletingClientIds.remove(client.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractErrorMessage(e)),
          backgroundColor: _kRed,
        ),
      );
      return false;
    }
  }

  void _toggleClientSelection(String id) {
    setState(() {
      if (_selectedClientIds.contains(id)) {
        _selectedClientIds.remove(id);
      } else {
        if (_selectedClientIds.length >= 50) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can delete up to 50 clients at once.'),
              backgroundColor: _kRed,
            ),
          );
          return;
        }
        _selectedClientIds.add(id);
      }
    });
  }

  void _selectAllVisibleClients() {
    final ids = _clients.map((c) => c.id).take(50).toSet();
    setState(() => _selectedClientIds
      ..clear()
      ..addAll(ids));
    if (_clients.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected the first 50 visible clients.'),
        ),
      );
    }
  }

  void _clearClientSelection() {
    setState(() => _selectedClientIds.clear());
  }

  Future<void> _deleteSelectedClients() async {
    if (_bulkDeleting || _selectedClientIds.isEmpty) return;
    final ids = _selectedClientIds.toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete selected clients?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will permanently delete ${ids.length} selected client(s). This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() {
      _bulkDeleting = true;
      _deletingClientIds.addAll(ids);
    });

    try {
      final res = await _api.bulkDeleteClients(ids);
      final statusCode = res.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw Exception('Bulk delete failed with status $statusCode');
      }

      await _loadClients();
      if (!mounted) return;

      final remainingIds = _clients.map((c) => c.id).toSet();
      final stillVisible = ids.where(remainingIds.contains).length;
      setState(() {
        _bulkDeleting = false;
        _deletingClientIds.removeAll(ids);
        _selectedClientIds.removeWhere((id) => !remainingIds.contains(id));
        if (_selected != null && !remainingIds.contains(_selected!.id)) {
          _selected = null;
        }
      });

      final message = res.data is Map && (res.data as Map)['message'] is String
          ? (res.data as Map)['message'] as String
          : '${ids.length - stillVisible} client(s) deleted';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stillVisible == 0
                ? message
                : '$message. $stillVisible still visible after refresh.',
          ),
          backgroundColor: stillVisible == 0 ? null : _kRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bulkDeleting = false;
        _deletingClientIds.removeAll(ids);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_extractErrorMessage(e)),
          backgroundColor: _kRed,
        ),
      );
    }
  }

}

// ─── Error helpers ────────────────────────────────────────────────────────────
String _extractErrorMessage(Object e) {
  final s = e.toString();
  try {
    // Try pulling backend error.message from Dio response
    final response = (e as dynamic).response;
    if (response?.data is Map) {
      final err = response.data['error'];
      if (err is Map && err['message'] is String)
        return err['message'] as String;
    }
  } catch (_) {}
  return s.length > 200 ? '${s.substring(0, 200)}…' : s;
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: _kRed),
          const SizedBox(height: 12),
          Text(
            'Failed to load clients',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _kMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  const _TopBar({
    required this.onAdd,
    required this.searchCtrl,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          const Text(
            'Clients',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kText,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearch,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name, contact, or notes...',
                  hintStyle: const TextStyle(fontSize: 13, color: _kMuted),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: _kMuted,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Client', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ─── Stats row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<ClientStage, int> stageCounts;
  final Map<ClientProduct, int> productCounts;
  final int total;
  final int upcomingMeetings;
  const _StatsRow({
    required this.stageCounts,
    required this.productCounts,
    required this.total,
    required this.upcomingMeetings,
  });

  @override
  Widget build(BuildContext context) {
    final whatsappCapi =
        (productCounts[ClientProduct.whatsapp] ?? 0) +
        (productCounts[ClientProduct.capi] ?? 0);
    final cards = [
      _StatCard(
        title: 'Total Clients',
        value: total.toString(),
        accent: _kPrimary,
      ),
      _StatCard(
        title: 'ENGAGE Clients',
        value: (productCounts[ClientProduct.engage] ?? 0).toString(),
        accent: _kPrimary,
      ),
      _StatCard(
        title: 'In Onboarding',
        value: (stageCounts[ClientStage.onboarding] ?? 0).toString(),
        accent: _kPrimary,
      ),
      _StatCard(
        title: 'Active',
        value: (stageCounts[ClientStage.active] ?? 0).toString(),
        accent: _kPrimary,
      ),
      _StatCard(
        title: 'WhatsApp + CAPI',
        value: whatsappCapi.toString(),
        accent: _kPrimary,
      ),
      _StatCard(
        title: 'Upcoming Meetings',
        value: upcomingMeetings.toString(),
        accent: _kPrimary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 1200
              ? 6
              : w >= 900
              ? 4
              : w >= 600
              ? 3
              : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            childAspectRatio: 1.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: cards,
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  const _StatCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 3, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stage filter bar ─────────────────────────────────────────────────────────
class _StageFilterBar extends StatelessWidget {
  final ClientStage? active;
  final ValueChanged<ClientStage> onSelect;
  const _StageFilterBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All Stages',
              isActive: active == null,
              onTap: () {
                if (active != null) onSelect(active!);
              },
            ),
            const SizedBox(width: 8),
            ...ClientStage.values.map(
              (s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: s.label,
                  isActive: active == s,
                  dotColor: s.bgColor,
                  onTap: () => onSelect(s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductFilterBar extends StatelessWidget {
  final ClientProduct? active;
  final ValueChanged<ClientProduct> onSelect;
  const _ProductFilterBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All Products',
              isActive: active == null,
              onTap: () {
                if (active != null) onSelect(active!);
              },
            ),
            const SizedBox(width: 8),
            ...ClientProduct.values.map(
              (p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: p.label,
                  isActive: active == p,
                  onTap: () => onSelect(p),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? dotColor;
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _kPrimary : _kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _kPrimary : _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : _kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Client list ──────────────────────────────────────────────────────────────
class _BulkDeleteBar extends StatelessWidget {
  final int selectedCount;
  final int totalVisible;
  final bool deleting;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  const _BulkDeleteBar({
    required this.selectedCount,
    required this.totalVisible,
    required this.deleting,
    required this.onSelectAll,
    required this.onClear,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: _kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          TextButton(
            onPressed:
                deleting || selectedCount == totalVisible ? null : onSelectAll,
            child: const Text('Select all'),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: deleting ? null : onClear,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: deleting ? null : onDelete,
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            icon: deleting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ClientList extends StatelessWidget {
  final List<Client> clients;
  final String? selectedId;
  final Set<String> deletingIds;
  final Set<String> selectedIds;
  final bool selectionMode;
  final ValueChanged<Client> onTap;
  final ValueChanged<Client> onDelete;
  final ValueChanged<String> onToggleSelection;
  const _ClientList({
    required this.clients,
    required this.selectedId,
    required this.deletingIds,
    required this.selectedIds,
    required this.selectionMode,
    required this.onTap,
    required this.onDelete,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: clients.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ClientCard(
        client: clients[i],
        isSelected: clients[i].id == selectedId,
        isDeleting: deletingIds.contains(clients[i].id),
        isChecked: selectedIds.contains(clients[i].id),
        showCheckbox: selectionMode,
        onTap: () => onTap(clients[i]),
        onDelete: () => onDelete(clients[i]),
        onToggleSelection: () => onToggleSelection(clients[i].id),
      ),
    );
  }
}

// ─── Client card ──────────────────────────────────────────────────────────────
class _ClientCard extends StatefulWidget {
  final Client client;
  final bool isSelected;
  final bool isDeleting;
  final bool isChecked;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleSelection;
  const _ClientCard({
    required this.client,
    required this.isSelected,
    required this.isDeleting,
    required this.isChecked,
    required this.showCheckbox,
    required this.onTap,
    required this.onDelete,
    required this.onToggleSelection,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? _kPrimary
                  : _hovered
                  ? const Color(0xFFD1D5DB)
                  : _kBorder,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: _hovered || widget.isSelected
                ? [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.showCheckbox) ...[
                    Checkbox(
                      value: widget.isChecked,
                      onChanged: widget.isDeleting
                          ? null
                          : (_) => widget.onToggleSelection(),
                      activeColor: _kPrimary,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${c.vertical} • ${c.product.label}',
                          style: const TextStyle(fontSize: 12, color: _kMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StageBadge(stage: c.stage),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed:
                        widget.isDeleting ? null : widget.onToggleSelection,
                    tooltip: widget.isChecked
                        ? 'Remove from selection'
                        : 'Select client',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      widget.isChecked
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 18,
                      color: widget.isChecked ? _kPrimary : _kMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.isDeleting ? null : widget.onDelete,
                    tooltip: 'Delete client',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: widget.isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kRed,
                            ),
                          )
                        : const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: _kRed,
                          ),
                  ),
                ],
              ),

              if (c.stage == ClientStage.onboarding &&
                  c.onboardingSubstage != null) ...[
                const SizedBox(height: 12),
                _OnboardingProgressBar(substage: c.onboardingSubstage!),
                const SizedBox(height: 10),
                _SubstageIndicators(current: c.onboardingSubstage!),
              ],

              if (c.contactPerson.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: _kMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Contact: ${c.contactPerson}',
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stage badge ──────────────────────────────────────────────────────────────
class _StageBadge extends StatelessWidget {
  final ClientStage stage;
  const _StageBadge({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: stage.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stage.label.toUpperCase(),
        style: TextStyle(
          color: stage.textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Onboarding progress bar ──────────────────────────────────────────────────
class _OnboardingProgressBar extends StatelessWidget {
  final OnboardingSubstage substage;
  const _OnboardingProgressBar({required this.substage});

  @override
  Widget build(BuildContext context) {
    final progress = substage.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              substage.label,
              style: const TextStyle(
                fontSize: 11,
                color: _kMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _kBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ─── Substage indicators ──────────────────────────────────────────────────────
class _SubstageIndicators extends StatelessWidget {
  final OnboardingSubstage current;
  const _SubstageIndicators({required this.current});

  @override
  Widget build(BuildContext context) {
    final values = OnboardingSubstage.values;
    final currentIndex = values.indexOf(current);
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _SubstageItem(
              label: _short(values[i]),
              status: i < currentIndex
                  ? _SubstageStatus.completed
                  : i == currentIndex
                  ? _SubstageStatus.active
                  : _SubstageStatus.pending,
            ),
          ),
        ],
      ],
    );
  }

  static String _short(OnboardingSubstage s) => switch (s) {
    OnboardingSubstage.creation => 'Agent & KB',
    OnboardingSubstage.review => 'Review',
    OnboardingSubstage.live => 'Live',
  };
}

enum _SubstageStatus { completed, active, pending }

class _SubstageItem extends StatelessWidget {
  final String label;
  final _SubstageStatus status;
  const _SubstageItem({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      _SubstageStatus.completed => (_kGreen, Colors.white),
      _SubstageStatus.active => (_kPrimary, Colors.white),
      _SubstageStatus.pending => (_kBg, _kMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 40, color: _kMuted),
        SizedBox(height: 12),
        Text(
          'No clients yet. Add your first client to get started.',
          style: TextStyle(color: _kMuted, fontSize: 14),
        ),
      ],
    ),
  );
}

// ─── Client detail panel ──────────────────────────────────────────────────────
class _ClientDetailPanel extends StatefulWidget {
  final Client client;
  final ApiClient api;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final ValueChanged<Client> onUpdated;

  const _ClientDetailPanel({
    super.key,
    required this.client,
    required this.api,
    required this.onClose,
    required this.onDelete,
    required this.onUpdated,
  });

  @override
  State<_ClientDetailPanel> createState() => _ClientDetailPanelState();
}

class _ClientDetailPanelState extends State<_ClientDetailPanel> {
  bool _savingStage = false;
  bool _savingSubstage = false;

  // Lead-stage editable fields
  late final _problemCtrl = TextEditingController(
    text: widget.client.problemStatement ?? '',
  );
  late final _strategyCtrl = TextEditingController(
    text: widget.client.salesStrategy ?? '',
  );
  late final _problemFocus = FocusNode();
  late final _strategyFocus = FocusNode();
  final Map<String, String> _pendingEdits = {};
  String? _savingField;

  // Roadmap documents (NOD stage)
  List<Map<String, dynamic>> _roadmaps = [];
  bool _loadingRoadmaps = false;
  bool _uploadingRoadmap = false;

  // Onboarding tasks (Onboarding stage)
  List<Map<String, dynamic>> _tasks = [];
  bool _loadingTasks = false;
  final Set<String> _togglingTaskIds = {};

  // Upcoming events (any stage)
  List<Map<String, dynamic>> _upcoming = [];
  bool _loadingUpcoming = false;

  @override
  void initState() {
    super.initState();
    _problemFocus.addListener(_flushOnBlur);
    _strategyFocus.addListener(_flushOnBlur);
    _fetchFreshClient();
    if (widget.client.stage == ClientStage.nod) _loadRoadmaps();
    if (widget.client.stage == ClientStage.onboarding) _loadTasks();
    _loadUpcoming();
  }

  Future<void> _loadUpcoming() async {
    setState(() => _loadingUpcoming = true);
    try {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 30));
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final res = await widget.api.getClientCalendar(
        widget.client.id,
        start: fmt(now),
        end: fmt(end),
      );
      final list = ((res.data['data']?['events'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _upcoming = list.take(10).toList();
        _loadingUpcoming = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUpcoming = false);
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final res = await widget.api.getClientOnboardingTasks(widget.client.id);
      final list = (res.data['data']['tasks'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _tasks = list;
        _loadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTasks = false);
      _showError(_extractErrorMessage(e));
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final id = task['id'] as String;
    if (_togglingTaskIds.contains(id)) return;
    final current = task['status'] as String;
    final next = current == 'completed' ? 'pending' : 'completed';
    setState(() => _togglingTaskIds.add(id));
    try {
      final res = await widget.api.updateOnboardingTaskStatus(id, next);
      if (!mounted) return;
      final data = res.data['data'] as Map<String, dynamic>;
      final updatedTask = data['task'] as Map<String, dynamic>;
      setState(() {
        final idx = _tasks.indexWhere((t) => t['id'] == id);
        if (idx != -1) {
          // Preserve joined fields not returned by the PATCH response
          _tasks[idx] = {..._tasks[idx], ...updatedTask};
        }
      });

      if (data['auto_promoted_to_active'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All live-substage tasks completed — client promoted to Active.',
            ),
            backgroundColor: _kGreen,
          ),
        );
        await _fetchFreshClient();
      } else if (data['substage_complete'] == true) {
        final msg = data['message'] as String? ?? 'Substage complete.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) _showError(_extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _togglingTaskIds.remove(id));
    }
  }

  Future<void> _loadRoadmaps() async {
    setState(() => _loadingRoadmaps = true);
    try {
      final res = await widget.api.getClientDocuments(
        widget.client.id,
        documentType: 'roadmap',
      );
      final docs = (res.data['data']['documents'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _roadmaps = docs;
        _loadingRoadmaps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoadmaps = false);
      _showError(_extractErrorMessage(e));
    }
  }

  Future<void> _uploadRoadmap() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    if (f.bytes == null) return;

    setState(() => _uploadingRoadmap = true);
    try {
      await widget.api.uploadClientDocument(
        clientId: widget.client.id,
        documentType: 'roadmap',
        bytes: f.bytes!,
        filename: f.name,
      );
      if (!mounted) return;
      await _loadRoadmaps();
    } catch (e) {
      if (mounted) _showError(_extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _uploadingRoadmap = false);
    }
  }

  Future<void> _deleteRoadmap(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete roadmap?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This removes the PDF from storage. Cannot be undone.',
          style: TextStyle(fontSize: 13, color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.deleteClientDocument(docId);
      if (!mounted) return;
      setState(() => _roadmaps.removeWhere((d) => d['id'] == docId));
    } catch (e) {
      if (mounted) _showError(_extractErrorMessage(e));
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _problemCtrl.dispose();
    _strategyCtrl.dispose();
    _problemFocus.dispose();
    _strategyFocus.dispose();
    super.dispose();
  }

  /// Fetch full client from GET /clients/:id so the panel always shows
  /// up-to-date data (including fields the list endpoint may trim later).
  Future<void> _fetchFreshClient() async {
    try {
      final res = await widget.api.getClient(widget.client.id);
      final fresh = Client.fromJson(
        res.data['data']['client'] as Map<String, dynamic>,
      );
      if (!mounted) return;
      // Only refresh text fields if user hasn't started typing
      if (!_problemFocus.hasFocus &&
          _pendingEdits['problem_statement'] == null) {
        _problemCtrl.text = fresh.problemStatement ?? '';
      }
      if (!_strategyFocus.hasFocus && _pendingEdits['sales_strategy'] == null) {
        _strategyCtrl.text = fresh.salesStrategy ?? '';
      }
      widget.onUpdated(fresh);
    } catch (_) {
      // Silent fail — fall back to the in-memory client we already have
    }
  }

  void _flushOnBlur() {
    if (_problemFocus.hasFocus || _strategyFocus.hasFocus) return;
    if (_pendingEdits.isEmpty) return;
    final data = Map<String, dynamic>.from(_pendingEdits);
    _pendingEdits.clear();
    _saveFields(data);
  }

  Future<void> _saveFields(Map<String, dynamic> data) async {
    setState(() => _savingField = data.keys.first);
    try {
      final res = await widget.api.updateClient(widget.client.id, data);
      final updated = Client.fromJson(
        res.data['data']['client'] as Map<String, dynamic>,
      );
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) _showError(_extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _savingField = null);
    }
  }

  Future<void> _changeStage(ClientStage newStage) async {
    if (newStage == widget.client.stage) return;

    // If moving to onboarding, ask for substage first
    String? substage;
    if (newStage == ClientStage.onboarding) {
      substage = await _pickOnboardingSubstage();
      if (substage == null) return;
    }

    setState(() => _savingStage = true);
    try {
      final res = await widget.api.changeClientStage(widget.client.id, {
        'new_stage': newStage.apiValue,
        if (substage != null) 'onboarding_substage': substage,
      });
      final updated = Client.fromJson(
        res.data['data']['client'] as Map<String, dynamic>,
      );
      widget.onUpdated(updated);
      // Reload side-data that depends on the new stage
      if (updated.stage == ClientStage.onboarding) await _loadTasks();
      if (updated.stage == ClientStage.nod) await _loadRoadmaps();
    } catch (e) {
      if (mounted) _showError(_extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _savingStage = false);
    }
  }

  Future<String?> _pickOnboardingSubstage() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Select onboarding substage',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Pick the starting substage for this client.',
          style: TextStyle(fontSize: 13, color: _kMuted),
        ),
        actions: OnboardingSubstage.values
            .map(
              (s) => TextButton(
                onPressed: () => Navigator.of(ctx).pop(s.apiValue),
                child: Text(s.label),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _changeSubstage(OnboardingSubstage newSub) async {
    if (newSub == widget.client.onboardingSubstage) return;
    setState(() => _savingSubstage = true);
    try {
      final res = await widget.api.changeOnboardingSubstage(widget.client.id, {
        'new_substage': newSub.apiValue,
      });
      final updated = Client.fromJson(
        res.data['data']['client'] as Map<String, dynamic>,
      );
      widget.onUpdated(updated);
      // Backend auto-seeds tasks for the new substage — reload the list
      await _loadTasks();
    } catch (e) {
      if (mounted) _showError(_extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _savingSubstage = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _kRed));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: widget.onDelete,
                tooltip: 'Delete client',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18, color: _kRed),
              ),
              InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Icon(Icons.close, size: 14, color: _kMuted),
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StageBadge(stage: c.stage),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${c.vertical} • ${c.product.label}',
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _PanelSection(
                  label: 'Details',
                  children: [
                    _DetailRow(
                      Icons.person_outline,
                      c.contactPerson.isEmpty ? '—' : c.contactPerson,
                    ),
                    _DetailRow(
                      Icons.email_outlined,
                      c.contactEmail.isEmpty ? '—' : c.contactEmail,
                    ),
                    _DetailRow(
                      Icons.phone_outlined,
                      c.contactPhone.isEmpty ? '—' : c.contactPhone,
                    ),
                    if (c.setupFee != null)
                      _DetailRow(
                        Icons.payments_outlined,
                        'Setup: ₹${c.setupFee!.toStringAsFixed(0)}',
                      ),
                    if (c.monthlyFee != null)
                      _DetailRow(
                        Icons.calendar_month,
                        'Monthly: ₹${c.monthlyFee!.toStringAsFixed(0)}',
                      ),
                    if (c.perCallRate != null)
                      _DetailRow(
                        Icons.phone_in_talk,
                        'Per call: ₹${c.perCallRate!.toStringAsFixed(0)}/min',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lead-stage editable inputs
                if (c.stage == ClientStage.lead) ...[
                  _PanelSection(
                    label: 'Lead Info',
                    children: [
                      _EditableField(
                        label: 'Problem Statement',
                        controller: _problemCtrl,
                        focusNode: _problemFocus,
                        saving: _savingField == 'problem_statement',
                        onChanged: (v) =>
                            _pendingEdits['problem_statement'] = v,
                      ),
                      const SizedBox(height: 10),
                      _EditableField(
                        label: 'Sales Strategy',
                        controller: _strategyCtrl,
                        focusNode: _strategyFocus,
                        saving: _savingField == 'sales_strategy',
                        onChanged: (v) => _pendingEdits['sales_strategy'] = v,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (_hasLeadFields(c)) ...[
                  // Client has moved past Lead — keep showing captured info read-only
                  _PanelSection(
                    label: 'Lead Info',
                    children: [
                      if (c.referralSource?.isNotEmpty ?? false)
                        _DetailRow(
                          Icons.share_outlined,
                          'Source: ${c.referralSource}',
                        ),
                      if (c.companyWebsite?.isNotEmpty ?? false)
                        _DetailRow(Icons.language, c.companyWebsite!),
                      if (c.problemStatement?.isNotEmpty ?? false)
                        _DetailRow(Icons.help_outline, c.problemStatement!),
                      if (c.salesStrategy?.isNotEmpty ?? false)
                        _DetailRow(Icons.psychology_outlined, c.salesStrategy!),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (_hasNodFields(c)) ...[
                  _PanelSection(
                    label: 'NOD Plan',
                    children: [
                      if (c.planOfAction?.isNotEmpty ?? false)
                        _DetailRow(Icons.assignment_outlined, c.planOfAction!),
                      if (c.roadmap?.isNotEmpty ?? false)
                        _DetailRow(Icons.map_outlined, c.roadmap!),
                      if (c.engagementTimeline?.isNotEmpty ?? false)
                        _DetailRow(
                          Icons.schedule_outlined,
                          c.engagementTimeline!,
                        ),
                      if (c.paymentStructure?.isNotEmpty ?? false)
                        _DetailRow(
                          Icons.account_balance_outlined,
                          c.paymentStructure!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // NOD-stage roadmap PDF upload
                if (c.stage == ClientStage.nod) ...[
                  _PanelSection(
                    label: 'Roadmap PDFs',
                    children: [
                      if (_loadingRoadmaps)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                        )
                      else if (_roadmaps.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No roadmap uploaded yet.',
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                        )
                      else
                        ..._roadmaps.map(
                          (d) => _RoadmapRow(
                            doc: d,
                            onOpen: () =>
                                _openDocument(d['file_url'] as String),
                            onDelete: () => _deleteRoadmap(d['id'] as String),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _uploadingRoadmap ? null : _uploadRoadmap,
                          icon: _uploadingRoadmap
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kPrimary,
                                  ),
                                )
                              : const Icon(
                                  Icons.upload_file_outlined,
                                  size: 16,
                                ),
                          label: Text(
                            _uploadingRoadmap
                                ? 'Uploading...'
                                : 'Upload Roadmap PDF',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kPrimary,
                            side: const BorderSide(color: _kPrimary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (c.stage == ClientStage.active) ...[
                  _PanelSection(
                    label: 'Active Metrics',
                    children: [
                      _DetailRow(
                        Icons.work_outline,
                        '${c.numProjects} projects',
                      ),
                      _DetailRow(
                        Icons.campaign_outlined,
                        '${c.numCampaigns} campaigns',
                      ),
                      _DetailRow(
                        Icons.home_work_outlined,
                        '${c.numSiteVisits} site visits',
                      ),
                      if (c.paymentTimeline?.isNotEmpty ?? false)
                        _DetailRow(Icons.payment_outlined, c.paymentTimeline!),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Onboarding substage picker
                if (c.stage == ClientStage.onboarding &&
                    c.onboardingSubstage != null) ...[
                  _PanelSection(
                    label: 'Onboarding Progress',
                    children: [
                      _OnboardingProgressBar(substage: c.onboardingSubstage!),
                      const SizedBox(height: 10),
                      _SubstageIndicators(current: c.onboardingSubstage!),
                      const SizedBox(height: 12),
                      _savingSubstage
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kPrimary,
                                ),
                              ),
                            )
                          : DropdownButton<OnboardingSubstage>(
                              value: c.onboardingSubstage,
                              isDense: true,
                              isExpanded: true,
                              underline: Container(height: 1, color: _kBorder),
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kText,
                              ),
                              items: OnboardingSubstage.values
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text('Move to: ${s.label}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (s) {
                                if (s != null) _changeSubstage(s);
                              },
                            ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Onboarding tasks grouped by substage
                  _PanelSection(
                    label: 'Onboarding Tasks',
                    children: [
                      if (_loadingTasks)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                        )
                      else if (_tasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No onboarding tasks yet.',
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                        )
                      else
                        ..._buildTaskGroups(),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Upcoming events (next 30 days)
                _PanelSection(
                  label: 'Upcoming',
                  children: [
                    if (_loadingUpcoming)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      )
                    else if (_upcoming.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No events in the next 30 days.',
                          style: TextStyle(fontSize: 12, color: _kMuted),
                        ),
                      )
                    else
                      ..._upcoming.map((e) => _UpcomingRow(event: e)),
                  ],
                ),
                const SizedBox(height: 16),

                // Timeline
                _PanelSection(
                  label: 'Timeline',
                  children: [
                    if (c.leadDate != null)
                      _DetailRow(
                        Icons.flag_outlined,
                        'Lead: ${_fmtDate(c.leadDate!)}',
                      ),
                    if (c.nodReceivedDate != null)
                      _DetailRow(
                        Icons.verified_outlined,
                        'Nod: ${_fmtDate(c.nodReceivedDate!)}',
                      ),
                    if (c.onboardingStartDate != null)
                      _DetailRow(
                        Icons.play_circle_outline,
                        'Onboarding: ${_fmtDate(c.onboardingStartDate!)}',
                      ),
                    if (c.goLiveDate != null)
                      _DetailRow(
                        Icons.rocket_launch_outlined,
                        'Go-live: ${_fmtDate(c.goLiveDate!)}',
                      ),
                    if (c.churnedDate != null)
                      _DetailRow(
                        Icons.close,
                        'Churned: ${_fmtDate(c.churnedDate!)}',
                        valueColor: _kRed,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stage change
                _PanelSection(
                  label: 'Change Stage',
                  children: [
                    _savingStage
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kPrimary,
                              ),
                            ),
                          )
                        : DropdownButton<ClientStage>(
                            value: c.stage,
                            isDense: true,
                            isExpanded: true,
                            underline: Container(height: 1, color: _kBorder),
                            style: const TextStyle(fontSize: 12, color: _kText),
                            items: ClientStage.values
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: s.bgColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          s.label,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (s) {
                              if (s != null) _changeStage(s);
                            },
                          ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes
                if (c.notes.isNotEmpty) ...[
                  _PanelSection(
                    label: 'Notes',
                    children: [
                      Text(
                        c.notes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTaskGroups() {
    const order = ['creation', 'review', 'live'];
    const labels = {
      'creation': 'Agent & KB Creation',
      'review': 'Review & Test Calling',
      'live': 'Live Deployment',
    };
    final bySub = <String, List<Map<String, dynamic>>>{};
    for (final t in _tasks) {
      bySub.putIfAbsent(t['substage'] as String, () => []).add(t);
    }

    final widgets = <Widget>[];
    for (final sub in order) {
      final list = bySub[sub];
      if (list == null || list.isEmpty) continue;
      final completed = list.where((t) => t['status'] == 'completed').length;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  labels[sub] ?? sub,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ),
              Text(
                '$completed/${list.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: _kMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
      for (final t in list) {
        widgets.add(
          _TaskRow(
            task: t,
            saving: _togglingTaskIds.contains(t['id']),
            onToggle: () => _toggleTask(t),
          ),
        );
      }
    }
    return widgets;
  }

  bool _hasLeadFields(Client c) =>
      (c.referralSource?.isNotEmpty ?? false) ||
      (c.companyWebsite?.isNotEmpty ?? false) ||
      (c.problemStatement?.isNotEmpty ?? false) ||
      (c.salesStrategy?.isNotEmpty ?? false);

  bool _hasNodFields(Client c) =>
      (c.planOfAction?.isNotEmpty ?? false) ||
      (c.roadmap?.isNotEmpty ?? false) ||
      (c.engagementTimeline?.isNotEmpty ?? false) ||
      (c.paymentStructure?.isNotEmpty ?? false);
}

// ─── Panel helpers ────────────────────────────────────────────────────────────
class _PanelSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _PanelSection({required this.label, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _kMuted,
        ),
      ),
      const SizedBox(height: 8),
      ...children.map(
        (w) => Padding(padding: const EdgeInsets.only(bottom: 6), child: w),
      ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? valueColor;
  const _DetailRow(this.icon, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 14, color: _kMuted),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor ?? const Color(0xFF374151),
          ),
        ),
      ),
    ],
  );
}

// ─── Editable multi-line field (save-on-blur) ────────────────────────────────
class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool saving;
  final ValueChanged<String> onChanged;
  const _EditableField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kMuted,
              ),
            ),
            if (saving) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _kPrimary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          maxLines: null,
          minLines: 3,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF374151),
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: 'Type here...',
            hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Roadmap PDF row ──────────────────────────────────────────────────────────
class _RoadmapRow extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _RoadmapRow({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = (doc['document_name'] as String?) ?? 'Roadmap';
    final sizeKb = (doc['file_size_kb'] as num?)?.toInt();
    final uploaded = doc['uploaded_at'] as String?;
    final sizeLabel = sizeKb == null
        ? ''
        : sizeKb > 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '$sizeKb KB';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 16, color: _kRed),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeLabel.isNotEmpty || uploaded != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (sizeLabel.isNotEmpty) sizeLabel,
                      if (uploaded != null) _relativeUploadDate(uploaded),
                    ].join(' • '),
                    style: const TextStyle(fontSize: 10, color: _kMuted),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 16, color: _kPrimary),
            onPressed: onOpen,
            tooltip: 'Open',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: _kRed),
            onPressed: onDelete,
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  static String _relativeUploadDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal()).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return '1 day ago';
    if (diff < 7) return '$diff days ago';
    return _fmtDate(dt.toLocal());
  }
}

// ─── Upcoming event row (per-client panel) ───────────────────────────────────
class _UpcomingRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _UpcomingRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? '';
    final title = event['title'] as String? ?? '';
    final date = event['date'] as String? ?? '';
    final time = event['time'] as String?;
    final color = type == 'meeting'
        ? const Color(0xFF3B82F6)
        : const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time != null ? '$date · $time' : date,
                    style: const TextStyle(fontSize: 10, color: _kMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                type.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Onboarding task row ──────────────────────────────────────────────────────
class _TaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool saving;
  final VoidCallback onToggle;
  const _TaskRow({
    required this.task,
    required this.saving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = (task['task_name'] as String?) ?? '';
    final status = task['status'] as String? ?? 'pending';
    final isCompleted = status == 'completed';
    final assignedTo = task['assigned_to_name'] as String?;
    final dueDateStr = task['due_date'] as String?;
    final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;

    final meta = <String>[];
    if (assignedTo != null && assignedTo.isNotEmpty) meta.add(assignedTo);
    if (dueDate != null) meta.add('Due ${_fmtDate(dueDate)}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: saving ? null : onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: saving
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPrimary,
                      )
                    : Icon(
                        isCompleted
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: isCompleted ? _kGreen : _kMuted,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted ? _kMuted : const Color(0xFF374151),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' • '),
                        style: const TextStyle(fontSize: 10, color: _kMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add client dialog ────────────────────────────────────────────────────────
class _AddClientDialog extends StatefulWidget {
  final ApiClient api;
  final ValueChanged<Client> onAdded;
  const _AddClientDialog({required this.api, required this.onAdded});

  @override
  State<_AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<_AddClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ClientProduct _product = ClientProduct.engage;
  String _vertical = 'Real Estate';
  ClientStage _stage = ClientStage.lead;
  OnboardingSubstage _sub = OnboardingSubstage.creation;
  bool _submitting = false;
  String? _error;

  static const _verticals = [
    'Real Estate',
    'Automotive',
    'Education',
    'Healthcare',
    'Finance',
    'E-commerce',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Add New Client',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _field(
                        _nameCtrl,
                        'Client Name *',
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'At least 3 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _dropdown<ClientProduct>(
                        label: 'Product *',
                        value: _product,
                        items: ClientProduct.values
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _product = v!),
                      ),
                      const SizedBox(height: 12),
                      _dropdown<String>(
                        label: 'Vertical *',
                        value: _vertical,
                        items: _verticals
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _vertical = v!),
                      ),
                      const SizedBox(height: 12),
                      _dropdown<ClientStage>(
                        label: 'Stage *',
                        value: _stage,
                        items: ClientStage.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _stage = v!),
                      ),
                      if (_stage == ClientStage.onboarding) ...[
                        const SizedBox(height: 12),
                        _dropdown<OnboardingSubstage>(
                          label: 'Onboarding Substage *',
                          value: _sub,
                          items: OnboardingSubstage.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _sub = v!),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _field(_contactCtrl, 'Contact Person'),
                      const SizedBox(height: 12),
                      _field(
                        _emailCtrl,
                        'Contact Email',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(v))
                            return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(_phoneCtrl, 'Contact Phone'),
                      const SizedBox(height: 12),
                      _field(_notesCtrl, 'Notes', maxLines: 3),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(fontSize: 12, color: _kRed),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Client'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'vertical': _vertical,
        'product': _product.apiValue,
        'stage': _stage.apiValue,
        if (_stage == ClientStage.onboarding)
          'onboarding_substage': _sub.apiValue,
        if (_contactCtrl.text.trim().isNotEmpty)
          'contact_person': _contactCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)
          'contact_email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'contact_phone': _phoneCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };
      final res = await widget.api.createClient(data);
      final client = Client.fromJson(
        res.data['data']['client'] as Map<String, dynamic>,
      );
      widget.onAdded(client);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = _extractErrorMessage(e);
      });
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _kBorder),
    );
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _kMuted),
        border: border,
        enabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _kPrimary),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _kBorder),
    );
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _kText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _kMuted),
        border: border,
        enabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _kPrimary),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _fmtDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
