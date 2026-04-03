import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFFE94560);
const _kBorder  = Color(0xFFE8ECF3);
const _kBg      = Color(0xFFF7F8FA);
const _kPrimary = Color(0xFF1A1A2E);

const _kEmployees = ['VIJAY', 'VIDHYADHAR', 'HARSHA', 'VISWAS', 'ASHWIN', 'PRABHAS'];

const _kEmployeeColors = <String, Color>{
  'VIJAY':      Color(0xFFE05A3A),
  'VIDHYADHAR': Color(0xFF3A7BD5),
  'HARSHA':     Color(0xFF9E9E9E),
  'VISWAS':     Color(0xFF2E9E5B),
  'ASHWIN':     Color(0xFFD63B7A),
  'PRABHAS':    Color(0xFF7C5CBF),
};

const _kSeedData = <String, Map<String, String>>{
  '16-02-2026': {'VIJAY':'11:45:00-9:45','VIDHYADHAR':'12:15:00-8','HARSHA':'12:15:00-8','VISWAS':'11:45:00-7:30','ASHWIN':'01:30:00-9:','PRABHAS':'09:00:00-5:10'},
  '17-02-2026': {'VIJAY':'11:30:00-9:15','VIDHYADHAR':'11:50:00-9:15','HARSHA':'11:50:00-9:15','VISWAS':'11:28:00-8','ASHWIN':'11:30:00-9:15','PRABHAS':'09:00:00-5:00'},
  '18-02-2026': {'VIJAY':'01:25:00-7:10','VIDHYADHAR':'12:30:00-6','HARSHA':'12:30:00-6','VISWAS':'10:15:00-7:10','ASHWIN':'leave or wfh','PRABHAS':'09:00:00-5:00'},
  '19-02-2026': {'VIJAY':'11:56:00-9','VIDHYADHAR':'12:41:00-6','HARSHA':'12:41:00-6','VISWAS':'10:35:00-9','ASHWIN':'leave','PRABHAS':'09:00:00-5:00'},
  '20-02-2026': {'VIJAY':'12:25:00-7:30','VIDHYADHAR':'leave','HARSHA':'leave','VISWAS':'12:25:00-7:30','ASHWIN':'12:14:00-7:30','PRABHAS':'09:00:00-5:00'},
  '21-02-2026': {'VIJAY':'leave','VIDHYADHAR':'leave','HARSHA':'leave','VISWAS':'leave','ASHWIN':'12:30:00-5','PRABHAS':'leave'},
  '23-02-2026': {'VIJAY':'leave','VIDHYADHAR':'leave','HARSHA':'leave','VISWAS':'10:45:00-5','ASHWIN':'12:20:00-5','PRABHAS':'09:00:00-4:50'},
  '24-02-2026': {'VIJAY':'leave','VIDHYADHAR':'leave','HARSHA':'leave','VISWAS':'10:45:00-5','ASHWIN':'leave','PRABHAS':'09:00:00-5:00'},
  '25-02-2026': {},
  '26-02-2026': {},
  '27-02-2026': {'VIJAY':'11:52:00-9:10','VIDHYADHAR':'leave','HARSHA':'leave','VISWAS':'11:52:00-9:10','ASHWIN':'11:52:00-9:10','PRABHAS':'09:00:00-5:00'},
  '28-02-2026': {'VIJAY':'12:30:00-6','VIDHYADHAR':'leave','HARSHA':'leave','VISWAS':'12:30:00-6','ASHWIN':'01:40:00-9','PRABHAS':'leave'},
  '02-03-2026': {'VIJAY':'10:40:00-3:25','VIDHYADHAR':'11:35:00-8:30','HARSHA':'11:35:00-8:30','VISWAS':'11:10:00-8:30','ASHWIN':'12:36:00-8:30','PRABHAS':'09:00:00-6:15'},
  '03-03-2026': {'VIJAY':'11:53:00-9:40','VIDHYADHAR':'11:20:00-9:40','HARSHA':'11:20:00-9:40','VISWAS':'11:00:00-9:40','ASHWIN':'11:53:00-9:40','PRABHAS':'09:00:00-3:00'},
  '04-03-2026': {'VIJAY':'11:21:00-5:20','VIDHYADHAR':'11:40:00-8:00','HARSHA':'11:40:00-8:00','VISWAS':'10:40:00-8','ASHWIN':'11:21:00-8','PRABHAS':'09:00:00-5:20'},
  '05-03-2026': {'VIJAY':'11:36:00-8','VIDHYADHAR':'10:30:00-5:30','HARSHA':'10:30:00-5:30','VISWAS':'11:36:00-8','ASHWIN':'leave(fever)','PRABHAS':'09:00:00-5:00'},
  '06-03-2026': {'VIJAY':'11:00:00-8','VIDHYADHAR':'12:05:00-8','HARSHA':'','VISWAS':'10:50:00-8','ASHWIN':'11:00:00-8','PRABHAS':''},
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

  // Controllers & focus nodes keyed by "${row}_${emp}" or row index for date
  final Map<String, TextEditingController> _controllers   = {};
  final Map<String, FocusNode>             _focusNodes    = {};
  final List<TextEditingController>        _dateCtrl      = [];
  final List<FocusNode>                    _dateFocus     = [];

  // col 0 = date, col 1..N = employee columns
  int get _totalCols => 1 + _kEmployees.length;

  // ── Scroll controllers ───────────────────────────────────────────────────────
  // _hScroll    → header employee-name SingleChildScrollView
  // _hScrollEmp → body employee-cells SingleChildScrollView (synced with _hScroll)
  // _hScrollBar → bottom scrollbar     (synced with _hScroll)
  // _vScroll    → left date ListView   (responds to mouse-wheel naturally)
  // _vScroll2   → right employee ListView (NeverScrollable; driven by _vScroll sync)
  final _hScroll       = ScrollController();
  final _hScrollEmp    = ScrollController();
  final _hScrollBar    = ScrollController();
  final _vScroll       = ScrollController();
  final _vScroll2      = ScrollController();
  late final _tableFocusNode = FocusNode();
  bool _syncingH = false;
  bool _syncingV = false;

  // Cached summaries — invalidated when data changes, rebuilt lazily.
  List<_EmployeeSummary>? _cachedSummaries;
  Timer? _analysisDebounce;

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
  int  _lbRebuildCount   = 0;   // ListenableBuilder rebuilds
  Timer? _perfReportTimer;

  // per-event timing (latest jumpTo latency)
  final Stopwatch _jumpToWatch = Stopwatch();

  bool _isShiftHeld(PointerScrollEvent event) =>
      HardwareKeyboard.instance.isShiftPressed;

  // Track right mouse button state for horizontal scroll gesture.
  bool _rightButtonHeld = false;

  @override
  void initState() {
    super.initState();
    _seedData();
    _hScroll.addListener(_onHScrollChange);
    _hScrollEmp.addListener(_onHScrollEmpChange);
    _hScrollBar.addListener(_onHScrollBarChange);
    _vScroll.addListener(_onVScrollChange);
    // Print a scroll-chain report every second.
    _perfReportTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pointerEvents == 0 && _hChangeEvents == 0 && _lbRebuildCount == 0) return;
      debugPrint(
        '[Scroll/s] pointerEvents=$_pointerEvents  '
        'hChangeCallbacks=$_hChangeEvents  '
        'LB-rebuilds=$_lbRebuildCount (should be 0 with new arch)  '
        '| lastJumpTo=${_jumpToWatch.elapsedMicroseconds}µs',
      );
      _pointerEvents  = 0;
      _hChangeEvents  = 0;
      _lbRebuildCount = 0;
    });
  }

  // ── Horizontal sync (3-way: header ↔ body ↔ scrollbar) ──────────────────────
  void _syncHTo(double v) {
    if (_syncingH) return;
    _syncingH = true;
    for (final c in [_hScroll, _hScrollEmp, _hScrollBar]) {
      if (c.hasClients) c.jumpTo(v.clamp(0.0, c.position.maxScrollExtent));
    }
    _syncingH = false;
  }

  void _onHScrollChange()    { _hChangeEvents++; _syncHTo(_hScroll.offset); }
  void _onHScrollEmpChange() { _syncHTo(_hScrollEmp.offset); }
  void _onHScrollBarChange() { _syncHTo(_hScrollBar.offset); }

  // ── Vertical sync (date column → employee column) ────────────────────────────
  void _onVScrollChange() {
    if (_syncingV) return;
    if (_vScroll2.hasClients) {
      _syncingV = true;
      _vScroll2.jumpTo(
          _vScroll.offset.clamp(0.0, _vScroll2.position.maxScrollExtent));
      _syncingV = false;
    }
  }

  // ── Focus helpers ───────────────────────────────────────────────────────────

  /// Returns the FocusNode for (row, col) — col 0 = date, col 1..N = employee.
  FocusNode? _fn(int row, int col) {
    if (row < 0 || row >= _rows.length) return null;
    if (col == 0) return row < _dateFocus.length ? _dateFocus[row] : null;
    final emp = _kEmployees[col - 1];
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

  void _seedData() {
    for (final entry in _kSeedData.entries) {
      final row = <String, String>{'date': entry.key};
      for (final emp in _kEmployees) { row[emp] = entry.value[emp] ?? ''; }
      _rows.add(row);
    }
    _rebuildCells();
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
      for (var j = 0; j < _kEmployees.length; j++) {
        final emp = _kEmployees[j];
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
    for (final emp in _kEmployees) { row[emp] = ''; }
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

  void _deleteRow(int i) {
    setState(() {
      _rows.removeAt(i);
      _rebuildCells();
      _cachedSummaries = null;
      _setStateCount++;
      debugPrint('[Perf] setState #$_setStateCount (_deleteRow)');
    });
  }

  @override
  void dispose() {
    _perfReportTimer?.cancel();
    _analysisDebounce?.cancel();
    for (final c in _controllers.values) { c.dispose(); }
    for (final f in _focusNodes.values)  { f.dispose(); }
    for (final c in _dateCtrl)           { c.dispose(); }
    for (final f in _dateFocus)          { f.dispose(); }
    _tableFocusNode.dispose();
    _hScroll.removeListener(_onHScrollChange);
    _hScrollEmp.removeListener(_onHScrollEmpChange);
    _hScrollBar.removeListener(_onHScrollBarChange);
    _vScroll.removeListener(_onVScrollChange);
    _hScroll.dispose();
    _hScrollEmp.dispose();
    _hScrollBar.dispose();
    _vScroll.dispose();
    _vScroll2.dispose();
    super.dispose();
  }

  // ── Analysis cache helpers ───────────────────────────────────────────────────
  List<_EmployeeSummary> get _summaries =>
      _cachedSummaries ??= _computeSummaries(_kEmployees, _rows);

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

  /// Format hour in 12-hour style (e.g. 13 → 01, 9 → 09).
  String _fmt12(int hour24) {
    final h = hour24 % 12;
    return (h == 0 ? 12 : h).toString().padLeft(2, '0');
  }

  /// Double-tap logic:
  /// - Empty cell → pick login time, store as "HH:MM-"
  /// - Cell has "HH:MM-" (login only) → pick logout, calculate hours worked
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

      final value = '${_fmt12(loginTime.hour)}:'
          '${loginTime.minute.toString().padLeft(2, '0')}-';

      setState(() {
        row[emp] = value;
        ctrl.text = value;
        _cachedSummaries = null;
      });
    } else {
      // ── Evening: pick logout time, calculate hours worked ──
      final logoutTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 6, minute: 0),
        helpText: 'Select logout time',
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );
      if (logoutTime == null || !mounted) return;

      // Parse the stored login time
      final loginParts = current.replaceAll('-', '').split(':');
      final loginMins = (int.tryParse(loginParts[0]) ?? 0) * 60.0 +
          (int.tryParse(loginParts[1]) ?? 0);
      // Logout in 12h: if picked hour <= login hour, it's PM offset
      final logoutH = logoutTime.hour % 12;
      final logoutMins = logoutH * 60.0 + logoutTime.minute;

      double diff = logoutMins - loginMins;
      if (diff < 0) diff += 12 * 60;
      final workedH = (diff / 60).floor();
      final workedM = (diff % 60).round();

      final workedStr = workedM > 0
          ? '$workedH:${workedM.toString().padLeft(2, '0')}'
          : '$workedH';
      final value = '$current$workedStr';

      setState(() {
        row[emp] = value;
        ctrl.text = value;
        _cachedSummaries = null;
      });
    }
    _scheduleAnalysisUpdate();
  }

  /// Schedule an analysis refresh 600 ms after the last keystroke.
  void _scheduleAnalysisUpdate() {
    _analysisDebounce?.cancel();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Text('Attendance',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Row',
                    style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildTable() {
    const dateWidth = 110.0;
    const delWidth  = 28.0;
    const colWidth  = 160.0;
    const headerH   = 40.0;
    const rowH      = 36.0;
    final totalEmpW = _kEmployees.length * colWidth;

    return Column(
      children: [
        // ── Column headers ─────────────────────────────────────────────────
        Container(
          height: headerH,
          color: _kPrimary,
          child: Row(
            children: [
              // Fixed: del spacer + DATE label
              SizedBox(
                width: delWidth + dateWidth,
                child: Padding(
                  padding: EdgeInsets.only(left: delWidth + 10),
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
              // Scrollable employee name headers — driven only via _hScroll.jumpTo
              Expanded(
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalEmpW,
                    child: Row(
                      children: _kEmployees.map((e) => SizedBox(
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
            ],
          ),
        ),

        // ── Body: fixed date column LEFT | scrollable employee cells RIGHT ──
        // Listener wraps both columns so scroll works everywhere.
        // Normal wheel → vertical, Shift+wheel → horizontal.
        Expanded(
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons & kSecondaryMouseButton != 0) {
                _rightButtonHeld = true;
              }
            },
            onPointerUp: (event) {
              _rightButtonHeld = false;
            },
            onPointerCancel: (event) {
              _rightButtonHeld = false;
            },
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                // Right-click held + scroll → horizontal scroll
                if (_rightButtonHeld && _hScrollEmp.hasClients) {
                  _syncHTo(
                    (_hScrollEmp.offset + event.scrollDelta.dy)
                        .clamp(0.0, _hScrollEmp.position.maxScrollExtent),
                  );
                  return;
                }
                // Normal wheel (no horizontal delta) → vertical scroll
                if (event.scrollDelta.dx == 0 &&
                    event.scrollDelta.dy != 0 &&
                    !_isShiftHeld(event) &&
                    _vScroll.hasClients) {
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
                // LEFT: fixed date + delete column
                SizedBox(
                  width: delWidth + dateWidth,
                  child: ListView.builder(
                    controller: _vScroll,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rows.length,
                    itemExtent: rowH,
                  itemBuilder: (_, i) {
                    final row = _rows[i];
                    final isHoliday = _kEmployees.every(
                        (e) => _isHoliday(row[e] ?? ''));
                    return GestureDetector(
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
                        // Delete button
                        SizedBox(
                          width: delWidth,
                          child: Center(
                            child: InkWell(
                              onTap: () => _deleteRow(i),
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
                            child: TextField(
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
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    );
                  },
                ),
              ),

              // RIGHT: employee cells — h-scroll via SingleChildScrollView,
              // v-scroll synced from _vScroll via _onVScrollChange.
              Expanded(
                child: SingleChildScrollView(
                    controller: _hScrollEmp,
                    scrollDirection: Axis.horizontal,
                    // Default physics: handles drag + Shift+wheel (browser sends dx) natively.
                    // Vertical wheel is intercepted by the Listener above.
                    child: SizedBox(
                      width: totalEmpW,
                      child: ListView.builder(
                        controller: _vScroll2,
                        // NeverScrollable: driven only by _vScroll2.jumpTo (synced from _vScroll).
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rows.length,
                        itemExtent: rowH,
                        itemBuilder: (_, i) {
                          final row = _rows[i];
                          return SizedBox(
                            height: rowH,
                            child: Row(
                              children: _kEmployees.map((emp) {
                                final raw    = row[emp] ?? '';
                                final isLeave = _isLeave(raw);
                                final parsed  = _parseHours(raw);
                                Color? bg;
                                if (isLeave) {
                                  bg = const Color(0xFFFFF3CD);
                                } else if (!_isHoliday(raw) && parsed == null) {
                                  bg = const Color(0xFFFFEBEE);
                                }
                                return _TimeCellWithHoverClear(
                                  width: colWidth,
                                  bg: bg,
                                  hasValue: raw.isNotEmpty,
                                  onDoubleTap: () => _pickTime(i, emp),
                                  onClear: () {
                                    setState(() {
                                      row[emp] = '';
                                      _controllers['${i}_$emp']!.text = '';
                                      _cachedSummaries = null;
                                    });
                                    _scheduleAnalysisUpdate();
                                  },
                                  child: TextField(
                                    controller: _controllers['${i}_$emp']!,
                                    focusNode:  _focusNodes['${i}_$emp'],
                                    onChanged: (v) {
                                      if (_checkAsdf(v, _controllers['${i}_$emp']!, row, emp)) return;
                                      row[emp] = v;
                                      _scheduleAnalysisUpdate();
                                    },
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLeave
                                          ? Colors.orange[800]
                                          : Colors.grey[800],
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom horizontal scrollbar ─────────────────────────────────────
        Container(
          height: 14,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              const SizedBox(width: delWidth + dateWidth),
              Expanded(
                child: Scrollbar(
                  controller: _hScrollBar,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _hScrollBar,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: totalEmpW, height: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Time cell with hover X to clear ─────────────────────────────────────────

class _TimeCellWithHoverClear extends StatefulWidget {
  final double width;
  final Color? bg;
  final bool hasValue;
  final VoidCallback onDoubleTap;
  final VoidCallback onClear;
  final Widget child;

  const _TimeCellWithHoverClear({
    required this.width,
    required this.bg,
    required this.hasValue,
    required this.onDoubleTap,
    required this.onClear,
    required this.child,
  });

  @override
  State<_TimeCellWithHoverClear> createState() =>
      _TimeCellWithHoverClearState();
}

class _TimeCellWithHoverClearState extends State<_TimeCellWithHoverClear> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          width: widget.width,
          color: widget.bg,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              widget.child,
              if (_hovered && widget.hasValue)
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
      ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary)),
          const SizedBox(height: 12),
          // ── Stat cards 2-column grid ────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: summaries.map((s) => _StatCard(s)).toList(),
          ),
          const SizedBox(height: 20),
          // ── Bar chart ──────────────────────────────────────────────────
          const Text('Total Hours',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary)),
          const SizedBox(height: 10),
          ...summaries.map((s) => _BarRow(s, maxH)),
          const SizedBox(height: 12),
          Text(
            'Holidays (fully empty rows) excluded. '
            'Avg/day calculated only on days where logout was recorded.',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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

    return Container(
      // Less vertical padding — card content is compact, no need for tall spacing
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 6, 18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromARGB(255, 0, 94, 255)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Slightly smaller label — it's secondary info
          Text(s.name,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(255, 235, 243, 247),
                  letterSpacing: 0.5)),
          // 22→16: the big number was forcing the card to be tall
          RichText(
            text: TextSpan(
              style: const TextStyle(color: _kPrimary),
              children: [
                TextSpan(
                    text: '$hh',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                TextSpan(
                    text: 'h ${mm.toString().padLeft(2, '0')}m',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          // Merged avg/day into the same chip row — removes a whole row of height
          Row(
            children: [
              _Chip('${s.daysPresent}d', Colors.green),
              const SizedBox(width: 4),
              _Chip('${s.leaves}L', _kAccent),
              const SizedBox(width: 4),
              _Chip('avg ${_fmtHours(s.avgPerDay)}', Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              s.name[0] + s.name.substring(1).toLowerCase(),
              style: const TextStyle(fontSize: 11, color: _kPrimary),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                    height: 18,
                    decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(_fmtHours(s.totalHours),
                style: const TextStyle(fontSize: 11, color: _kPrimary),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
