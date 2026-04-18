import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/config/app_config.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFFE94560);
const _kBorder  = Color(0xFFE8ECF3);
const _kBg      = Color(0xFFF7F8FA);
const _kPrimary = Color(0xFF1A1A2E);

// Per-user color palette — keys are matched against user names (uppercase).
// Falls back to grey for users not listed here.
const _kEmployeeColors = <String, Color>{
  'VIJAY':      Color(0xFFE05A3A),
  'VIDHYADHAR': Color(0xFF3A7BD5),
  'HARSHA':     Color(0xFF9E9E9E),
  'VISWAS':     Color(0xFF2E9E5B),
  'ASHWIN':     Color(0xFFD63B7A),
  'PRABHAS':    Color(0xFF7C5CBF),
};

// ─── Parsing ──────────────────────────────────────────────────────────────────

bool _isLeave(String raw) {
  final s = raw.trim().toLowerCase();
  return s.startsWith('leave') || s == 'leave or wfh';
}

bool _isHoliday(String raw) => raw.trim().isEmpty;

double? _parseHours(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty || _isLeave(cleaned)) return null;
  final stripped = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
  final parts = stripped.split('-');
  if (parts.length < 2) return null;
  final login  = _parseTime(parts[0].trim());
  final logout = _parseTime(parts[1].trim());
  if (login == null || logout == null) return null;
  double diff = logout - login;
  if (diff < 0) diff += 12.0;
  if (diff <= 0 || diff > 16) return null;
  return diff;
}

double? _parseTime(String s) {
  if (s.isEmpty) return null;
  final seg = s.split(':');
  final h = double.tryParse(seg[0]) ?? 0;
  final m = seg.length > 1 ? (double.tryParse(seg[1]) ?? 0) : 0;
  return h + m / 60.0;
}

String _fmtHours(double h) {
  final mins = (h * 60).round();
  return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
}

// ─── Summary ──────────────────────────────────────────────────────────────────

class _EmployeeSummary {
  final String name;
  final double totalHours;
  final int daysPresent;
  final int leaves;
  final Color color;
  const _EmployeeSummary({
    required this.name, required this.totalHours,
    required this.daysPresent, required this.leaves, required this.color,
  });
  double get avgPerDay => daysPresent == 0 ? 0 : totalHours / daysPresent;
}

List<_EmployeeSummary> _computeSummaries(
    List<String> employees, List<Map<String, String>> rows) {
  return employees.map((emp) {
    double total = 0; int days = 0; int leaves = 0;
    for (final row in rows) {
      final raw = row[emp] ?? '';
      if (_isLeave(raw)) {
        leaves++;
      } else {
        final h = _parseHours(raw);
        if (h != null) { total += h; days++; }
      }
    }
    return _EmployeeSummary(
      name: emp, totalHours: total, daysPresent: days,
      leaves: leaves, color: _kEmployeeColors[emp] ?? Colors.grey,
    );
  }).toList();
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final List<Map<String, String>> _rows = [];
  bool _loadingData = true;

  // Dynamic employee list — loaded from backend users
  List<String> _employees = [];

  // Currently viewed month (1st of the month at local midnight)
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  // Map user_name (uppercase) → user_id for saving
  Map<String, String> _employeeIds = {};

  // Controllers & focus nodes keyed by "${row}_${emp}" or row index for date
  final Map<String, TextEditingController> _controllers   = {};
  final Map<String, FocusNode>             _focusNodes    = {};
  final List<TextEditingController>        _dateCtrl      = [];
  final List<FocusNode>                    _dateFocus     = [];

  // col 0 = date, col 1..N = employee columns
  int get _totalCols => 1 + _employees.length;

  ApiClient get _api => context.read<ApiClient>();

  // ── Scroll controllers ───────────────────────────────────────────────────────
  // _hScrollEmp → body employee-cells SingleChildScrollView (drives the header
  //               row directly via Transform; no separate header controller)
  // _vScroll    → left date ListView
  // _vScroll2   → right employee ListView (bidirectionally synced with _vScroll)
  final _hScrollEmp    = ScrollController();
  final _vScroll       = ScrollController();
  final _vScroll2      = ScrollController();
  late final _tableFocusNode = FocusNode();
  bool _syncingV = false;

  // Cached summaries — invalidated when data changes, rebuilt lazily.
  List<_EmployeeSummary>? _cachedSummaries;
  // Server-computed summaries (preferred when fresh)
  List<_EmployeeSummary>? _apiSummaries;

  // Backend-parsed login_time/logout_time keyed by "date|EMPLOYEE".
  // Populated from GET /attendance response — drives AM/PM cell coloring.
  // Values are 24-hour strings with PM inference already applied ("19:30").
  final Map<String, String> _loginTimes  = {};
  final Map<String, String> _logoutTimes = {};

  // Backend record IDs keyed by "date|EMPLOYEE" — needed for DELETE.
  final Map<String, int> _recordIds = {};
  Timer? _analysisDebounce;
  Timer? _saveDebounce;

  /// Debounce save — waits 2 seconds of inactivity then bulk-saves
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _saveAttendance);
  }

  // ── asdf sequence tracker ────────────────────────────────────────────────────
  // Tracks progress through the 'asdf' shortcut sequence across outer-focus keys.
  String _seqBuf = '';

  // ── Perf / scroll diagnostics ───────────────────────────────────────────────
  int    _buildCount     = 0;
  int    _setStateCount  = 0;
  DateTime? _lastBuildTime;

  // scroll chain counters (reset every second by a periodic timer)
  int  _pointerEvents    = 0;   // onPointerSignal fires
  int  _hChangeEvents    = 0;   // _onHScrollChange fires
  int  _vChangeEvents    = 0;   // _onVScrollChange fires (date col)
  int  _v2ChangeEvents   = 0;   // _onVScroll2Change fires (employee col)
  int  _lbRebuildCount   = 0;   // ListenableBuilder rebuilds
  Timer? _perfReportTimer;

  // ── Probe A: frame timings (slow-frame detector) ───────────────────────────
  int _slowFrames       = 0;
  double _worstBuildMs  = 0;
  double _worstRasterMs = 0;

  // ── Probe B: cell itemBuilder rebuild counter ──────────────────────────────
  // Incremented inside the right-side ListView.builder itemBuilder on each call.
  // Horizontal scroll should NOT rebuild cells — if this climbs during h-scroll,
  // something is forcing rebuilds that shouldn't happen.
  int _cellRebuilds = 0;

  // ── Probe C: touch / pointer-move tracking ─────────────────────────────────
  // Measures cadence of onPointerMove events and the worst gap between them.
  // If moves arrive every 16 ms but the worst gap jumps to 100 ms, Flutter's
  // event loop is stalling (i.e. rebuild work is blocking the main thread).
  int _pointerMoves = 0;
  int _worstMoveGapMs = 0;
  DateTime? _lastMoveAt;

  bool _isShiftHeld(PointerScrollEvent event) =>
      HardwareKeyboard.instance.isShiftPressed;

  // Track right mouse button state for horizontal scroll gesture.
  bool _rightButtonHeld = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _hScrollEmp.addListener(_onHScrollEmpChange);
    _vScroll.addListener(_onVScrollChange);
    _vScroll2.addListener(_onVScroll2Change);
    // Probe A: frame-timings callback. Logs slow frames (>16 ms = dropped @ 60Hz).
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    // Print a scroll-chain report every second.
    _perfReportTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final hasActivity = _pointerEvents > 0 || _hChangeEvents > 0 ||
          _vChangeEvents > 0 || _v2ChangeEvents > 0 ||
          _lbRebuildCount > 0 || _pointerMoves > 0 || _cellRebuilds > 0 ||
          _slowFrames > 0;
      if (!hasActivity) return;
      String ctrlState(ScrollController c, String label) {
        if (!c.hasClients) return '$label:NO_CLIENTS';
        return '$label: off=${c.offset.toStringAsFixed(0)} '
            'max=${c.position.maxScrollExtent.toStringAsFixed(0)} '
            'viewport=${c.position.viewportDimension.toStringAsFixed(0)}';
      }
      debugPrint(
        '[Scroll/s] sigs=$_pointerEvents moves=$_pointerMoves '
        'worstMoveGap=${_worstMoveGapMs}ms | '
        'hChange=$_hChangeEvents  vChange=$_vChangeEvents  v2Change=$_v2ChangeEvents | '
        'cellRebuilds=$_cellRebuilds  slowFrames=$_slowFrames '
        'worstBuild=${_worstBuildMs.toStringAsFixed(1)}ms '
        'worstRaster=${_worstRasterMs.toStringAsFixed(1)}ms\n'
        '          rows=${_rows.length} contentH=${(_rows.length * 36).toStringAsFixed(0)}px\n'
        '          [Ctrl] ${ctrlState(_vScroll, "vScroll")}\n'
        '                 ${ctrlState(_vScroll2, "vScroll2")}\n'
        '                 ${ctrlState(_hScrollEmp, "hScrollEmp")}',
      );
      _pointerEvents   = 0;
      _hChangeEvents   = 0;
      _vChangeEvents   = 0;
      _v2ChangeEvents  = 0;
      _lbRebuildCount  = 0;
      _pointerMoves    = 0;
      _worstMoveGapMs  = 0;
      _cellRebuilds    = 0;
      _slowFrames      = 0;
      _worstBuildMs    = 0;
      _worstRasterMs   = 0;
    });
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final buildMs  = t.buildDuration.inMicroseconds  / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      if (buildMs + rasterMs > 16.0) _slowFrames++;
      if (buildMs  > _worstBuildMs)  _worstBuildMs  = buildMs;
      if (rasterMs > _worstRasterMs) _worstRasterMs = rasterMs;
    }
  }

  void _onPointerMoveProbe(PointerMoveEvent event) {
    _pointerMoves++;
    final now = DateTime.now();
    if (_lastMoveAt != null) {
      final gap = now.difference(_lastMoveAt!).inMilliseconds;
      if (gap > _worstMoveGapMs) _worstMoveGapMs = gap;
    }
    _lastMoveAt = now;
  }

  // ── Horizontal scroll (single controller drives body; header reads it
  //    directly via Transform in the widget tree — no sync needed) ──────────
  void _syncHTo(double v) {
    if (!_hScrollEmp.hasClients) return;
    _hScrollEmp.jumpTo(v.clamp(0.0, _hScrollEmp.position.maxScrollExtent));
  }

  void _onHScrollEmpChange() { _hChangeEvents++; }

  // ── Vertical sync (bidirectional: date column ↔ employee column) ────────────
  void _onVScrollChange() {
    _vChangeEvents++;
    if (_syncingV) return;
    if (_vScroll2.hasClients) {
      _syncingV = true;
      _vScroll2.jumpTo(
          _vScroll.offset.clamp(0.0, _vScroll2.position.maxScrollExtent));
      _syncingV = false;
    }
  }

  void _onVScroll2Change() {
    _v2ChangeEvents++;
    if (_syncingV) return;
    if (_vScroll.hasClients) {
      _syncingV = true;
      _vScroll.jumpTo(
          _vScroll2.offset.clamp(0.0, _vScroll.position.maxScrollExtent));
      _syncingV = false;
    }
  }

  // ── Focus helpers ───────────────────────────────────────────────────────────

  /// Returns the FocusNode for (row, col) — col 0 = date, col 1..N = employee.
  FocusNode? _fn(int row, int col) {
    if (row < 0 || row >= _rows.length) return null;
    if (col == 0) return row < _dateFocus.length ? _dateFocus[row] : null;
    final emp = _employees[col - 1];
    return _focusNodes['${row}_$emp'];
  }

  /// Creates a FocusNode that handles Tab / Shift+Tab / Escape.
  FocusNode _makeFN(int row, int col) {
    final node = FocusNode();
    node.onKeyEvent = (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.tab:
          _moveFocus(row, col,
              forward: !HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.escape:
          node.unfocus();
          // Return focus to outer table so asdf shortcuts work immediately.
          _tableFocusNode.requestFocus();
          return KeyEventResult.handled;
        default:
          return KeyEventResult.ignored;
      }
    };
    return node;
  }

  /// Navigate to the next/previous cell. Tab at end of last row adds a new row.
  void _moveFocus(int row, int col, {required bool forward}) {
    int r = row, c = col;
    if (forward) {
      c++;
      if (c >= _totalCols) { c = 0; r++; }
      if (r >= _rows.length) {
        // Tab past last cell → add row, then focus its date
        _addRow(focusAfter: true);
        return;
      }
    } else {
      c--;
      if (c < 0) { c = _totalCols - 1; r--; }
      if (r < 0) { r = 0; c = 0; }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fn(r, c)?.requestFocus());
  }

  // ── Data management ─────────────────────────────────────────────────────────

  Future<void> _loadAttendance() async {
    setState(() => _loadingData = true);
    try {
      // 1. Load users via the directory endpoint — no PII, callable by any
      //    authenticated user (workers/interns included).
      final usersRes = await _api.getUserDirectory();
      final users = (usersRes.data as List).cast<Map<String, dynamic>>();
      _employees = users
          .map((u) => (u['name'] as String).toUpperCase())
          .toList();
      _employeeIds = {
        for (final u in users)
          (u['name'] as String).toUpperCase(): u['id'] as String,
      };

      // 2. Load attendance for the currently viewed month
      final m = _viewMonth;
      final lastDay = DateTime(m.year, m.month + 1, 0).day;
      final startDate = '${m.year}-${m.month.toString().padLeft(2, '0')}-01';
      final endDate   = '${m.year}-${m.month.toString().padLeft(2, '0')}-'
          '${lastDay.toString().padLeft(2, '0')}';
      final attRes = await _api.getAttendance(startDate: startDate, endDate: endDate);
      final attData = (attRes.data as List).cast<Map<String, dynamic>>();

      // 3. Transform API data → row format: {date: 'DD-MM-YYYY', EMPLOYEE: 'raw_value', ...}
      _loginTimes.clear();
      _logoutTimes.clear();
      _recordIds.clear();

      final rowMap = <String, Map<String, String>>{}; // date string → row
      for (final entry in attData) {
        // API returns full ISO ('2026-04-05T18:30:00.000Z') — parse it
        final dt = DateTime.parse(entry['date'] as String).toLocal();
        final displayDate =
            '${dt.day.toString().padLeft(2, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.year}';
        final userName = (entry['user_name'] as String? ?? '').toUpperCase();
        final rawValue = entry['raw_value'] as String? ?? '';

        rowMap.putIfAbsent(displayDate, () {
          final row = <String, String>{'date': displayDate};
          for (final emp in _employees) { row[emp] = ''; }
          return row;
        });
        rowMap[displayDate]![userName] = rawValue;

        // Cache record ID + backend-parsed login/logout times.
        final recordId = entry['id'];
        final loginT   = entry['login_time']  as String?;
        final logoutT  = entry['logout_time'] as String?;
        final key      = '$displayDate|$userName';
        if (recordId is int) _recordIds[key] = recordId;
        if (loginT  != null) _loginTimes[key]  = loginT;
        if (logoutT != null) _logoutTimes[key] = logoutT;
      }

      // Sort rows by date
      final sortedKeys = rowMap.keys.toList()..sort((a, b) {
        final ap = a.split('-');
        final bp = b.split('-');
        final da = DateTime(int.parse(ap[2]), int.parse(ap[1]), int.parse(ap[0]));
        final db = DateTime(int.parse(bp[2]), int.parse(bp[1]), int.parse(bp[0]));
        return da.compareTo(db);
      });

      _rows.clear();
      for (final key in sortedKeys) {
        _rows.add(rowMap[key]!);
      }

      _rebuildCells();
      // Fetch server-computed summary in the background (non-blocking)
      _loadSummariesFromApi(startDate, endDate);
    } catch (e) {
      // No fallback — show empty state and surface the error
      _rows.clear();
      _rebuildCells();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance: $e')),
        );
      }
    }
    if (mounted) setState(() => _loadingData = false);
  }

  /// Fetch server-computed per-user summary for the given range.
  /// This is the truth source — local _computeSummaries is a fallback.
  Future<void> _loadSummariesFromApi(String startDate, String endDate) async {
    try {
      final res = await _api.getAttendanceSummary(
          startDate: startDate, endDate: endDate);
      final list = (res.data as List).cast<Map<String, dynamic>>();
      final mapped = list.map((row) {
        final name = (row['user_name'] as String? ?? '').toUpperCase();
        return _EmployeeSummary(
          name:         name,
          totalHours:   (row['total_hours']  as num?)?.toDouble() ?? 0,
          daysPresent:  row['days_present']  as int?    ?? 0,
          leaves:       row['days_leave']    as int?    ?? 0,
          color:        _kEmployeeColors[name] ?? Colors.grey,
        );
      }).toList();
      // Order summaries to match _employees order so the UI is stable
      mapped.sort((a, b) {
        final ai = _employees.indexOf(a.name);
        final bi = _employees.indexOf(b.name);
        return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
      });
      if (mounted) setState(() => _apiSummaries = mapped);
    } catch (_) {
      // silent — local fallback already in place
    }
  }

  /// Save all attendance data to backend via bulk upsert
  Future<void> _saveAttendance() async {
    final bulkRows = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final dateStr = row['date'] ?? '';
      if (dateStr.isEmpty) continue;
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final apiDate = '${parts[2]}-${parts[1]}-${parts[0]}'; // YYYY-MM-DD

      for (final emp in _employees) {
        final userId = _employeeIds[emp];
        if (userId == null) continue;
        final rawValue = row[emp] ?? '';
        if (rawValue.isEmpty) continue; // skip cleared cells — already deleted via API
        bulkRows.add({
          'user_id': userId,
          'date': apiDate,
          'raw_value': rawValue,
        });
      }
    }
    if (bulkRows.isNotEmpty) {
      try {
        await _api.bulkUpsertAttendance(bulkRows);
        // Refresh server summaries for the currently viewed month
        final m = _viewMonth;
        final last = DateTime(m.year, m.month + 1, 0).day;
        final s = '${m.year}-${m.month.toString().padLeft(2, '0')}-01';
        final e = '${m.year}-${m.month.toString().padLeft(2, '0')}-'
            '${last.toString().padLeft(2, '0')}';
        _loadSummariesFromApi(s, e);
      } catch (_) {}
    }
  }

  /// Full rebuild of controllers + focus nodes from _rows.
  void _rebuildCells() {
    for (final c in _controllers.values) { c.dispose(); }
    for (final f in _focusNodes.values)  { f.dispose(); }
    for (final c in _dateCtrl)           { c.dispose(); }
    for (final f in _dateFocus)          { f.dispose(); }
    _controllers.clear();
    _focusNodes.clear();
    _dateCtrl.clear();
    _dateFocus.clear();

    for (var i = 0; i < _rows.length; i++) {
      _dateCtrl.add(TextEditingController(text: _rows[i]['date'] ?? ''));
      _dateFocus.add(_makeFN(i, 0));
      for (var j = 0; j < _employees.length; j++) {
        final emp = _employees[j];
        _controllers['${i}_$emp'] =
            TextEditingController(text: _rows[i][emp] ?? '');
        _focusNodes['${i}_$emp'] = _makeFN(i, j + 1);
      }
    }
  }

  /// Computes the next calendar day after the last dated row (format DD-MM-YYYY).
  String _nextDate() {
    for (var i = _rows.length - 1; i >= 0; i--) {
      final d = _rows[i]['date'] ?? '';
      if (d.isEmpty) continue;
      final p = d.split('-');
      if (p.length != 3) continue;
      try {
        final date = DateTime(
            int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        final next = date.add(const Duration(days: 1));
        return '${next.day.toString().padLeft(2, '0')}-'
               '${next.month.toString().padLeft(2, '0')}-'
               '${next.year}';
      } catch (_) { continue; }
    }
    final t = DateTime.now();
    return '${t.day.toString().padLeft(2, '0')}-'
           '${t.month.toString().padLeft(2, '0')}-${t.year}';
  }

  void _addRow({bool focusAfter = false}) {
    final date = _nextDate();
    final row  = <String, String>{'date': date};
    for (final emp in _employees) { row[emp] = ''; }
    setState(() {
      _rows.add(row);
      _rebuildCells();
      _cachedSummaries = null;
      _setStateCount++;
      debugPrint('[Perf] setState #$_setStateCount (_addRow)');
    });
    if (focusAfter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fn(_rows.length - 1, 0)?.requestFocus();
        // Scroll both columns to bottom so new row is visible.
        for (final c in [_vScroll, _vScroll2]) {
          if (c.hasClients) {
            c.animateTo(c.position.maxScrollExtent,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut);
          }
        }
      });
    }
  }

  /// Delete all attendance records for a row's date via the by-date endpoint,
  /// then remove the row from local state.
  Future<void> _deleteRowByDate(int i) async {
    final dateStr = _rows[i]['date'] ?? '';
    if (dateStr.isEmpty) return;
    final parts = dateStr.split('-');
    if (parts.length != 3) return;
    final apiDate = '${parts[2]}-${parts[1]}-${parts[0]}'; // YYYY-MM-DD

    // Remove from local state immediately
    setState(() {
      // Clean up cached IDs and times for this row
      for (final emp in _employees) {
        final key = '$dateStr|$emp';
        _recordIds.remove(key);
        _loginTimes.remove(key);
        _logoutTimes.remove(key);
      }
      _rows.removeAt(i);
      _rebuildCells();
      _cachedSummaries = null;
    });

    // Fire backend delete
    try {
      await _api.deleteAttendanceByDate(apiDate);
    } catch (_) {}
  }

  @override
  void dispose() {
    _perfReportTimer?.cancel();
    _analysisDebounce?.cancel();
    _saveDebounce?.cancel();
    for (final c in _controllers.values) { c.dispose(); }
    for (final f in _focusNodes.values)  { f.dispose(); }
    for (final c in _dateCtrl)           { c.dispose(); }
    for (final f in _dateFocus)          { f.dispose(); }
    _tableFocusNode.dispose();
    _hScrollEmp.removeListener(_onHScrollEmpChange);
    _vScroll.removeListener(_onVScrollChange);
    _vScroll2.removeListener(_onVScroll2Change);
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _hScrollEmp.dispose();
    _vScroll.dispose();
    _vScroll2.dispose();
    super.dispose();
  }

  // ── Analysis cache helpers ───────────────────────────────────────────────────
  // Prefer server-computed summaries when available; fall back to local
  // compute (used during edits before debounced save lands).
  List<_EmployeeSummary> get _summaries =>
      _apiSummaries ??
      (_cachedSummaries ??= _computeSummaries(_employees, _rows));

  /// Called from cell onChanged. If the value ends with 'asdf', strips those
  /// 4 chars, updates [ctrl] and [dataMap][key], then adds a new row.
  /// Returns true if the shortcut was triggered (caller should skip normal update).
  bool _checkAsdf(String v, TextEditingController ctrl, Map<String, String> dataMap, String key) {
    if (!v.endsWith('asdf')) return false;
    final stripped = v.substring(0, v.length - 4);
    dataMap[key] = stripped;
    ctrl.value = TextEditingValue(
      text: stripped,
      selection: TextSelection.collapsed(offset: stripped.length),
    );
    _addRow(focusAfter: true);
    return true;
  }

  /// Extract the 24-hour hour component from a "HH:MM" string from the backend.
  /// Returns null if the input is null/empty/invalid.
  int? _hourOf(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.isEmpty) return null;
    return int.tryParse(parts[0]);
  }

  /// Format hour in 12-hour style, zero-padded (e.g. 13 → 01, 9 → 09).
  String _fmt12Padded(int hour24) {
    final h = hour24 % 12;
    return (h == 0 ? 12 : h).toString().padLeft(2, '0');
  }

  /// Format hour in 12-hour style, NOT padded (e.g. 13 → 1, 9 → 9).
  /// Used for logout half per backend convention: `09:00-7:30`.
  String _fmt12Unpadded(int hour24) {
    final h = hour24 % 12;
    return (h == 0 ? 12 : h).toString();
  }

  /// Double-tap logic (format is LOGIN-LOGOUT, both plain 12h clock times,
  /// no AM/PM markers — backend does all inference and math).
  /// - Empty cell → pick login time, store as "HH:MM-"
  /// - Cell has "HH:MM-" (login only) → pick logout, store as "HH:MM-H:MM"
  Future<void> _pickTime(int rowIndex, String emp) async {
    final row = _rows[rowIndex];
    final ctrl = _controllers['${rowIndex}_$emp']!;
    final current = (row[emp] ?? '').trim();

    // Check if login is already filled (format: "HH:MM-")
    final hasLogin = RegExp(r'^\d{2}:\d{2}-$').hasMatch(current);

    if (!hasLogin) {
      // ── Morning: pick login time ──
      final loginTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        helpText: 'Select login time',
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );
      if (loginTime == null || !mounted) return;

      final value = '${_fmt12Padded(loginTime.hour)}:'
          '${loginTime.minute.toString().padLeft(2, '0')}-';

      setState(() {
        row[emp] = value;
        ctrl.text = value;
        _cachedSummaries = null;
      });
    } else {
      // ── Evening: pick logout time, store as-is. No math. Backend handles
      //   duration/AM-PM inference via parseHours / parseLogoutTime.
      final logoutTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
        helpText: 'Select logout time',
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );
      if (logoutTime == null || !mounted) return;

      final logoutStr = '${_fmt12Unpadded(logoutTime.hour)}:'
          '${logoutTime.minute.toString().padLeft(2, '0')}';
      final value = '$current$logoutStr';

      setState(() {
        row[emp] = value;
        ctrl.text = value;
        _cachedSummaries = null;
      });
    }
    _scheduleAnalysisUpdate();
  }

  // ── Month navigation ────────────────────────────────────────────────────

  bool get _isViewingCurrentMonth {
    final now = DateTime.now();
    return _viewMonth.year == now.year && _viewMonth.month == now.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
      _apiSummaries = null;
      _cachedSummaries = null;
      _loadingData = true;
    });
    _loadAttendance();
  }

  void _jumpToMonth(DateTime m) {
    setState(() {
      _viewMonth = DateTime(m.year, m.month, 1);
      _apiSummaries = null;
      _cachedSummaries = null;
      _loadingData = true;
    });
    _loadAttendance();
  }

  /// Pick an Excel file and POST it to /attendance/import.
  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading…'), duration: Duration(seconds: 2)),
      );
    }

    try {
      final res = await _api.importAttendance(
          bytes: bytes, filename: file.name);
      final data = res.data as Map<String, dynamic>? ?? {};
      final imported  = data['imported']         as int?    ?? 0;
      final unmatched = (data['unmatched_users'] as List?)?.cast<String>() ?? [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(unmatched.isEmpty
                ? 'Imported $imported records'
                : 'Imported $imported records · Unmatched: ${unmatched.join(", ")}'),
          ),
        );
      }
      // Reload everything from the server so the grid reflects the import
      _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  /// Schedule an analysis refresh 600 ms after the last keystroke.
  void _scheduleAnalysisUpdate() {
    _analysisDebounce?.cancel();
    _scheduleSave();
    // Drop server summary so the local fallback (which reflects the user's
    // in-progress edits) is shown until the next save lands.
    _apiSummaries = null;
    _analysisDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() { _cachedSummaries = null; });
        _setStateCount++;
        debugPrint('[Perf] debounced setState #$_setStateCount '
            '(analysis refresh)');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final now = DateTime.now();
    if (_lastBuildTime != null) {
      final gap = now.difference(_lastBuildTime!).inMilliseconds;
      debugPrint('[Perf] build #$_buildCount  Δt=${gap}ms since last build');
    }
    _lastBuildTime = now;

    if (_loadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    final topBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          const Text('Attendance',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          // ── Month navigator + import button (scrollable on narrow screens) ──
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MonthNav(
                    month:   _viewMonth,
                    onPrev:  () => _changeMonth(-1),
                    onNext:  () => _changeMonth(1),
                    onToday: _isViewingCurrentMonth ? null : () => _jumpToMonth(
                        DateTime(DateTime.now().year, DateTime.now().month, 1)),
                  ),
                  const SizedBox(width: 12),
                  isMobile
                      ? IconButton(
                          onPressed: _importExcel,
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                          ),
                          tooltip: 'Import Excel',
                        )
                      : OutlinedButton.icon(
                          onPressed: _importExcel,
                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                          label: const Text('Import Excel',
                              style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(color: Color(0xFF6366F1)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            minimumSize:   Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

    if (isMobile) {
      return DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topBar,
            Container(
              color: Colors.white,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Table'),
                  Tab(text: 'Summary'),
                ],
                labelColor: _kAccent,
                unselectedLabelColor: Color(0xFF6B7280),
                indicatorColor: _kAccent,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTableWithHScroll(),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: _kBorder)),
                    ),
                    child: _AnalysisPanel(summaries: _summaries),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topBar,
        // ── Main body: table left | analysis right ────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─ Left 50%: attendance table ─────────────────────────────────
              Expanded(child: _buildTableWithHScroll()),
              // ─ Right 50%: analysis panel ──────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: _kBorder)),
                  ),
                  child: _AnalysisPanel(summaries: _summaries),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Table with sticky date column ─────────────────────────────────────────

  Widget _buildTableWithHScroll() {
    return Focus(
      focusNode: _tableFocusNode,
      autofocus: true,
      // Tracks 'asdf' sequence when no cell is focused (outer Focus is primary).
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!node.hasPrimaryFocus)  return KeyEventResult.ignored;
        final seqMap = {
          LogicalKeyboardKey.keyA: 'a',
          LogicalKeyboardKey.keyS: 's',
          LogicalKeyboardKey.keyD: 'd',
          LogicalKeyboardKey.keyF: 'f',
        };
        final ch = seqMap[event.logicalKey];
        if (ch != null) {
          _seqBuf += ch;
          if ('asdf'.startsWith(_seqBuf)) {
            if (_seqBuf == 'asdf') {
              _seqBuf = '';
              _addRow(focusAfter: true);
            }
            return KeyEventResult.handled; // consume partial sequence
          }
        }
        _seqBuf = ''; // any other key resets
        return KeyEventResult.ignored;
      },
      child: _buildTable(),
    );
  }

  bool get _canEdit {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    return state.user.hasEditAccess(AppConfig.pageAttendance);
  }

  Widget _buildTable() {
    const dateWidth = 110.0;
    const delWidth  = 28.0;
    const colWidth  = 160.0;
    const headerH   = 40.0;
    const rowH      = 36.0;
    final canEdit   = _canEdit;
    final totalEmpW = _employees.length * colWidth;

    return Column(
      children: [
        // ── Column headers ─────────────────────────────────────────────────
        Container(
          height: headerH,
          color: _kPrimary,
          child: Row(
            children: [
              // Fixed: DATE label (+ delete column spacer for edit users)
              SizedBox(
                width: canEdit ? delWidth + dateWidth : dateWidth,
                child: Padding(
                  padding: EdgeInsets.only(left: canEdit ? delWidth + 10 : 10),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('DATE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ),
              ),
              // Employee name headers — driven directly by the body's
              // _hScrollEmp via a Transform (no second controller, no sync).
              Expanded(
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _hScrollEmp,
                    builder: (_, child) {
                      final off = _hScrollEmp.hasClients ? _hScrollEmp.offset : 0.0;
                      return Transform.translate(
                        offset: Offset(-off, 0),
                        child: child,
                      );
                    },
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: double.infinity,
                      child: SizedBox(
                      width: totalEmpW,
                      child: Row(
                        children: _employees.map((e) => SizedBox(
                          width: colWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(e,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5),
                                overflow: TextOverflow.ellipsis),
                          ),
                        )).toList(),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Body: fixed date column LEFT | scrollable employee cells RIGHT ──
        // ListViews are natively scrollable. Listener kept only for right-click+wheel
        // → horizontal scroll (no native equivalent) and pointer-move probe.
        Expanded(
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons & kSecondaryMouseButton != 0) {
                _rightButtonHeld = true;
              }
              _lastMoveAt = null;
            },
            onPointerMove: _onPointerMoveProbe,
            onPointerUp: (event) {
              _rightButtonHeld = false;
            },
            onPointerCancel: (event) {
              _rightButtonHeld = false;
            },
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _pointerEvents++;
                final forceHorizontal = _rightButtonHeld || _isShiftHeld(event);
                final hasVScroll = _vScroll.hasClients &&
                    _vScroll.position.maxScrollExtent > 0;
                final hasHScroll = _hScrollEmp.hasClients &&
                    _hScrollEmp.position.maxScrollExtent > 0;

                // Wheel routing:
                //   Shift or right-click held  → always horizontal
                //   Otherwise: vertical if scrollable, else horizontal
                if (forceHorizontal ||
                    (!hasVScroll && hasHScroll && event.scrollDelta.dy != 0)) {
                  if (hasHScroll) {
                    _syncHTo(
                      (_hScrollEmp.offset + event.scrollDelta.dy)
                          .clamp(0.0, _hScrollEmp.position.maxScrollExtent),
                    );
                  }
                  return;
                }
                if (hasVScroll && event.scrollDelta.dy != 0) {
                  _vScroll.jumpTo(
                    (_vScroll.offset + event.scrollDelta.dy)
                        .clamp(0.0, _vScroll.position.maxScrollExtent),
                  );
                }
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: fixed date column (+ delete button for edit users)
                SizedBox(
                  width: canEdit ? delWidth + dateWidth : dateWidth,
                  child: ListView.builder(
                    controller: _vScroll,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rows.length,
                    itemExtent: rowH,
                    cacheExtent: 3000, // pre-build all rows — tiny dataset
                  itemBuilder: (_, i) {
                    final row = _rows[i];
                    final isHoliday = _employees.every(
                        (e) => _isHoliday(row[e] ?? ''));
                    return RepaintBoundary(child: GestureDetector(
                      onDoubleTap: i == _rows.length - 1
                          ? () => _addRow(focusAfter: true)
                          : null,
                      child: Container(
                      height: rowH,
                      decoration: BoxDecoration(
                        color: isHoliday
                            ? const Color(0xFFFFFD80)
                            : (i.isOdd ? Colors.white : _kBg),
                        border: const Border(
                            bottom: BorderSide(color: _kBorder)),
                      ),
                      child: Row(children: [
                        // Delete row button (edit users only)
                        if (canEdit)
                          SizedBox(
                            width: delWidth,
                            child: Center(
                              child: InkWell(
                                onTap: () => _deleteRowByDate(i),
                                borderRadius: BorderRadius.circular(3),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(Icons.close,
                                      size: 12, color: Colors.grey[400]),
                                ),
                              ),
                            ),
                          ),
                        // Date cell
                        SizedBox(
                          width: dateWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _FocusableTextCell(
                              controller: _dateCtrl[i],
                              focusNode: _dateFocus[i],
                              onChanged: (v) {
                                if (_checkAsdf(v, _dateCtrl[i], row, 'date')) return;
                                row['date'] = v;
                                _scheduleAnalysisUpdate();
                              },
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _kPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    ));
                  },
                ),
              ),

              // RIGHT: employee cells. The horizontal SingleChildScrollView is
              // kept (so _hScrollEmp.position exists and the inner SizedBox gets
              // unbounded width), but its gesture recognizer is disabled via
              // NeverScrollableScrollPhysics. An explicit GestureDetector drives
              // the controller — this is the only horizontal recognizer in the
              // arena, so it never competes with the inner ListView's vertical.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    // Single recognizer drives BOTH axes — no arena competition.
                    // dx → horizontal, dy → vertical (drives _vScroll, which
                    // syncs _vScroll2 via the existing listener).
                    if (_hScrollEmp.hasClients && details.delta.dx != 0) {
                      _hScrollEmp.jumpTo(
                        (_hScrollEmp.offset - details.delta.dx).clamp(
                          0.0,
                          _hScrollEmp.position.maxScrollExtent,
                        ),
                      );
                    }
                    if (_vScroll.hasClients && details.delta.dy != 0) {
                      _vScroll.jumpTo(
                        (_vScroll.offset - details.delta.dy).clamp(
                          0.0,
                          _vScroll.position.maxScrollExtent,
                        ),
                      );
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _hScrollEmp,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalEmpW,
                      child: ListView.builder(
                        controller: _vScroll2,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rows.length,
                        itemExtent: rowH,
                        cacheExtent: 3000, // pre-build all rows — tiny dataset
                        itemBuilder: (_, i) {
                          _cellRebuilds++;
                          final row = _rows[i];
                          return RepaintBoundary(child: SizedBox(
                            height: rowH,
                            child: Row(
                              children: _employees.map((emp) {
                                final raw    = row[emp] ?? '';
                                final isLeave = _isLeave(raw);
                                final parsed  = _parseHours(raw);
                                Color? bg;
                                if (isLeave) {
                                  bg = const Color(0xFFFFF3CD);
                                } else if (!_isHoliday(raw) && parsed == null) {
                                  bg = const Color(0xFFFFEBEE);
                                }
                                // Backend-parsed times for AM/PM colouring.
                                final tKey      = '${row['date']}|$emp';
                                final loginHr   = _hourOf(_loginTimes[tKey]);
                                final logoutHr  = _hourOf(_logoutTimes[tKey]);
                                final canEdit = _canEdit;
                                return _TimeCellWithHoverClear(
                                  width: colWidth,
                                  bg: bg,
                                  hasValue: raw.isNotEmpty,
                                  loginHour:  loginHr,
                                  logoutHour: logoutHr,
                                  onDoubleTap: canEdit ? () => _pickTime(i, emp) : null,
                                  onClear: canEdit ? () {
                                    final tKey = '${row['date']}|$emp';
                                    final id = _recordIds[tKey];
                                    setState(() {
                                      row[emp] = '';
                                      _controllers['${i}_$emp']!.text = '';
                                      _cachedSummaries = null;
                                      _recordIds.remove(tKey);
                                      _loginTimes.remove(tKey);
                                      _logoutTimes.remove(tKey);
                                    });
                                    // Delete from backend if record exists
                                    if (id != null) {
                                      _api.deleteAttendance(id.toString());
                                    }
                                    _scheduleAnalysisUpdate();
                                  } : null,
                                  child: _FocusableTextCell(
                                    controller: _controllers['${i}_$emp']!,
                                    focusNode:  _focusNodes['${i}_$emp']!,
                                    readOnly:   !canEdit,
                                    onChanged: canEdit ? (v) {
                                      if (_checkAsdf(v, _controllers['${i}_$emp']!, row, emp)) return;
                                      row[emp] = v;
                                      _scheduleAnalysisUpdate();
                                    } : null,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLeave
                                          ? Colors.orange[800]
                                          : Colors.grey[800],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ));
                        },
                      ),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Old bottom scrollbar removed — Scrollbar now wraps the body directly.
      ],
    );
  }
}

// ─── Lightweight cell editor: shows Text when not focused, TextField when focused.
//    TextField is one of the heaviest leaf widgets in Flutter — replacing it
//    with a Text widget for the (very common) non-focused case dramatically
//    reduces build/layout cost during scroll.

class _FocusableTextCell extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle? style;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const _FocusableTextCell({
    required this.controller,
    required this.focusNode,
    this.style,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<_FocusableTextCell> createState() => _FocusableTextCellState();
}

class _FocusableTextCellState extends State<_FocusableTextCell> {
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    final hasFocus = widget.focusNode.hasFocus;
    if (_editing != hasFocus) setState(() => _editing = hasFocus);
  }

  void _onTextChange() {
    // Only need to rebuild the Text view when not editing — TextField
    // updates itself when focused.
    if (!mounted || _editing) return;
    setState(() {});
  }

  void _enterEdit() {
    if (widget.readOnly) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        controller: widget.controller,
        focusNode:  widget.focusNode,
        readOnly:   widget.readOnly,
        onChanged:  widget.onChanged,
        style:      widget.style,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      );
    }
    // Non-editing path: a Focus widget keeps the FocusNode attached so
    // external requestFocus (e.g. Tab navigation) works, plus a Text widget
    // displaying the current controller value. SizedBox.expand makes the
    // tap target span the full cell — without it, an empty cell has zero
    // hit area because Text("") is zero-sized.
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: !widget.readOnly,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.readOnly ? null : _enterEdit,
        child: SizedBox.expand(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                widget.controller.text,
                style: widget.style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Time cell with hover X to clear ─────────────────────────────────────────

class _TimeCellWithHoverClear extends StatefulWidget {
  final double width;
  final Color? bg;
  final bool hasValue;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onClear;
  final Widget child;
  // Backend-parsed 24h hours (with PM inference applied). Null = unknown.
  final int? loginHour;
  final int? logoutHour;

  const _TimeCellWithHoverClear({
    required this.width,
    required this.bg,
    required this.hasValue,
    this.onDoubleTap,
    this.onClear,
    required this.child,
    this.loginHour,
    this.logoutHour,
  });

  @override
  State<_TimeCellWithHoverClear> createState() =>
      _TimeCellWithHoverClearState();
}

class _TimeCellWithHoverClearState extends State<_TimeCellWithHoverClear> {
  bool _hovered = false;

  // Soft palette — readable over white, yellow-leave, and pink-invalid backgrounds.
  static const _amColor = Color(0xFF60A5FA); // sky-400 (AM)
  static const _pmColor = Color(0xFFFB923C); // orange-400 (PM)

  Color? _halfColor(int? hour24) {
    if (hour24 == null) return null;
    return hour24 < 12 ? _amColor : _pmColor;
  }

  @override
  Widget build(BuildContext context) {
    final loginClr  = _halfColor(widget.loginHour);
    final logoutClr = _halfColor(widget.logoutHour);
    // MouseRegion is expensive on drag-scroll (fires enter/exit + setState on
    // every cell the pointer passes over). Only attach it on wide screens where
    // the hover-to-clear UX makes sense; on mobile hover never triggers anyway.
    final isWide = MediaQuery.of(context).size.width >= 700;

    final inner = GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        width: widget.width,
        color: widget.bg,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            widget.child,
            // AM/PM indicator — thin bar pinned to the bottom of the cell
            if (loginClr != null || logoutClr != null)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: loginClr ?? Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: logoutClr ?? Colors.transparent,
                    ),
                  ),
                ]),
              ),
            if (isWide && _hovered && widget.hasValue && widget.onClear != null)
              GestureDetector(
                onTap: widget.onClear,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 11, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );

    if (!isWide) return inner;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: inner,
    );
  }
}

// ─── Analysis Panel ───────────────────────────────────────────────────────────

class _AnalysisPanel extends StatelessWidget {
  final List<_EmployeeSummary> summaries;
  const _AnalysisPanel({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final maxH = summaries
        .map((s) => s.totalHours)
        .fold(0.0, (a, b) => a > b ? a : b);

    // Team aggregate strip
    final teamHours  = summaries.fold<double>(0, (a, s) => a + s.totalHours);
    final teamDays   = summaries.fold<int>(0, (a, s) => a + s.daysPresent);
    final teamLeaves = summaries.fold<int>(0, (a, s) => a + s.leaves);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.insights_rounded, size: 16, color: _kAccent),
            const SizedBox(width: 6),
            const Text('Team Summary',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary)),
            const Spacer(),
            Flexible(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(_fmtHours(teamHours),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 10, color: const Color(0xFFD1D5DB)),
                  const SizedBox(width: 8),
                  Text('${teamDays}d',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981))),
                  const SizedBox(width: 6),
                  Text('·',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  const SizedBox(width: 6),
                  Text('${teamLeaves}L',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kAccent)),
                ]),
              ),
            ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Stat cards 2-column grid ────────────────────────────────────
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth < 480 ? 1 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 2.6 : 2.0,
                children: summaries.map((s) => _StatCard(s)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Bar chart section ──────────────────────────────────────────
          Row(children: [
            const Icon(Icons.bar_chart_rounded, size: 14, color: _kPrimary),
            const SizedBox(width: 6),
            const Text('Total Hours',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                    letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 12),
          ...summaries.map((s) => _BarRow(s, maxH)),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
              border:       Border.all(color: _kBorder),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Holidays (empty rows) excluded · avg/day only counts days with logout',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600], height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _EmployeeSummary s;
  const _StatCard(this.s);

  @override
  Widget build(BuildContext context) {
    final hh = s.totalHours.floor();
    final mm = ((s.totalHours - hh) * 60).round();
    final initials = s.name.isEmpty ? '?' : s.name[0].toUpperCase();
    final properName = s.name.isEmpty
        ? ''
        : s.name[0] + s.name.substring(1).toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent top strip — person's color
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── Header: avatar + name ─────────────────────────────
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(initials,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: s.color)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        properName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary,
                            letterSpacing: 0.2),
                      ),
                    ),
                  ]),

                  // ── Big hours number ──────────────────────────────────
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: _kPrimary),
                      children: [
                        TextSpan(
                            text: '$hh',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.0)),
                        const TextSpan(
                            text: 'h ',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280))),
                        TextSpan(
                            text: mm.toString().padLeft(2, '0'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280))),
                        const TextSpan(
                            text: 'm',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),

                  // ── Stat pills row ────────────────────────────────────
                  Row(
                    children: [
                      _Chip(icon: Icons.check_circle_rounded,
                          label: '${s.daysPresent}d',
                          color: const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      _Chip(icon: Icons.event_busy_rounded,
                          label: '${s.leaves}L',
                          color: _kAccent),
                      const SizedBox(width: 6),
                      _Chip(icon: Icons.trending_up_rounded,
                          label: _fmtHours(s.avgPerDay),
                          color: const Color(0xFF6366F1)),
                    ],
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _BarRow extends StatelessWidget {
  final _EmployeeSummary s;
  final double maxH;
  const _BarRow(this.s, this.maxH);

  @override
  Widget build(BuildContext context) {
    final frac = maxH == 0 ? 0.0 : (s.totalHours / maxH).clamp(0.0, 1.0);
    final properName = s.name.isEmpty
        ? ''
        : s.name[0] + s.name.substring(1).toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Colored dot + name
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              properName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                      color:        const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(5)),
                ),
                TweenAnimationBuilder<double>(
                  tween:    Tween(begin: 0, end: frac),
                  duration: const Duration(milliseconds: 700),
                  curve:    Curves.easeOutCubic,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          colors: [
                            s.color.withValues(alpha: 0.7),
                            s.color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(_fmtHours(s.totalHours),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ─── Month navigator ─────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final DateTime       month;
  final VoidCallback   onPrev;
  final VoidCallback   onNext;
  final VoidCallback?  onToday;  // null = already on current month

  const _MonthNav({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color:        _kBg,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _iconBtn(Icons.chevron_left_rounded, onPrev),
        SizedBox(
          width: 130,
          child: Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
          ),
        ),
        _iconBtn(Icons.chevron_right_rounded, onNext),
        if (onToday != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onToday,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Today',
                  style: TextStyle(
                      fontSize: 11,
                      color: _kAccent,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: _kPrimary),
      ),
    );
  }
}
