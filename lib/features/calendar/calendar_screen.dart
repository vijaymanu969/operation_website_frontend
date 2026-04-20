import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';

// ─── Design tokens (reused from clients screen) ──────────────────────────────
const _kPrimary = Color(0xFF414099);
const _kBorder  = Color(0xFFE5E7EB);
const _kBg      = Color(0xFFF9FAFB);
const _kSurface = Colors.white;
const _kMuted   = Color(0xFF6B7280);
const _kText    = Color(0xFF1A1A1A);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFEF4444);
const _kBlue    = Color(0xFF3B82F6);

// ─── View modes ──────────────────────────────────────────────────────────────
enum _View { month, week, agenda }

extension on _View {
  String get label => switch (this) {
    _View.month  => 'Month',
    _View.week   => 'Week',
    _View.agenda => 'Agenda',
  };
}

// ─── Event model ─────────────────────────────────────────────────────────────
class _Event {
  final String  type;        // meeting | task
  final dynamic id;
  final DateTime date;       // local date (midnight)
  final String? time;        // HH:MM or null
  final String  title;
  final String  status;
  final String? clientId;
  final String? clientName;
  final Map<String, dynamic> meta;

  _Event({
    required this.type,
    required this.id,
    required this.date,
    required this.time,
    required this.title,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.meta,
  });

  factory _Event.fromJson(Map j) {
    final dateStr = j['date'] as String;
    final parts = dateStr.split('-');
    return _Event(
      type:       j['type']   as String,
      id:         j['id'],
      date:       DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      time:       j['time']   as String?,
      title:      j['title']  as String? ?? '',
      status:     j['status'] as String? ?? '',
      clientId:   j['client_id']?.toString(),
      clientName: j['client_name'] as String?,
      meta:       (j['meta'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Color get color => switch (type) {
    'meeting' => _kBlue,
    'task'    => _kAmber,
    _         => _kMuted,
  };
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime  _viewing    = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  _View     _view       = _View.month;

  bool _showMeetings = true;
  bool _showTasks    = true;
  bool _onlyMine     = false;

  List<_Event> _events = [];
  bool _loading = true;
  String? _error;

  late final ApiClient _api = context.read<ApiClient>();

  String? get _myUserId {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.id : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final range = _rangeFor(_view, _viewing);
    try {
      final types = <String>[];
      if (_showMeetings) types.add('meeting');
      if (_showTasks)    types.add('task');
      if (types.isEmpty) {
        setState(() { _events = []; _loading = false; });
        return;
      }
      final res = await _api.getClientsCalendar(
        start: _fmtApi(range.start),
        end:   _fmtApi(range.end),
        types: types,
      );
      final list = ((res.data['data']?['events'] as List?) ?? [])
          .map((e) => _Event.fromJson(e as Map))
          .toList();
      if (!mounted) return;
      setState(() { _events = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  _DateRange _rangeFor(_View v, DateTime anchor) {
    if (v == _View.week) {
      // Week starts Sunday
      final start = anchor.subtract(Duration(days: anchor.weekday % 7));
      return _DateRange(start, start.add(const Duration(days: 6)));
    }
    if (v == _View.agenda) {
      // Next 30 days
      final start = DateTime.now();
      return _DateRange(DateTime(start.year, start.month, start.day), start.add(const Duration(days: 30)));
    }
    // Month
    return _DateRange(
      DateTime(anchor.year, anchor.month, 1),
      DateTime(anchor.year, anchor.month + 1, 0),
    );
  }

  List<_Event> get _filtered => _events.where((e) {
    if (!_onlyMine) return true;
    if (_myUserId == null) return true;
    if (e.type == 'task')    return e.meta['assigned_to']?.toString() == _myUserId;
    if (e.type == 'meeting') {
      // Backend doesn't give structured attendees; do a name/id check in free-text
      final attendees = (e.meta['attendees'] as String?)?.toLowerCase() ?? '';
      return attendees.contains(_myUserId!.toLowerCase());
    }
    return true;
  }).toList();

  Map<DateTime, List<_Event>> get _byDate {
    final map = <DateTime, List<_Event>>{};
    for (final e in _filtered) {
      map.putIfAbsent(e.date, () => []).add(e);
    }
    return map;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    final dayEvents = _selectedDay == null ? <_Event>[] : (_byDate[_selectedDay!] ?? []);

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopBar(
          title:     _headerTitle(),
          view:      _view,
          onViewChange: (v) {
            setState(() { _view = v; _selectedDay = null; });
            _load();
          },
          onPrev: () { _navigate(-1); },
          onNext: () { _navigate(1);  },
          onToday: () {
            setState(() {
              _viewing = DateTime(DateTime.now().year, DateTime.now().month);
              _selectedDay = null;
            });
            _load();
          },
        ),
        _FilterBar(
          showMeetings: _showMeetings,
          showTasks:    _showTasks,
          onlyMine:     _onlyMine,
          onMeetings:   (v) { setState(() => _showMeetings = v); _load(); },
          onTasks:      (v) { setState(() => _showTasks = v);    _load(); },
          onMine:       (v) => setState(() => _onlyMine = v),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, size: 40, color: _kRed),
                        const SizedBox(height: 12),
                        Text('Failed to load calendar', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _kMuted)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, style: FilledButton.styleFrom(backgroundColor: _kPrimary), child: const Text('Retry')),
                      ]),
                    ))
                  : switch (_view) {
                      _View.month  => _MonthGrid(
                        viewing:     _viewing,
                        selected:    _selectedDay,
                        byDate:      _byDate,
                        onPickDay:   (d) => setState(() => _selectedDay = d),
                      ),
                      _View.week   => _WeekView(
                        start:     _rangeFor(_View.week, _viewing).start,
                        byDate:    _byDate,
                        onOpen:    _openEvent,
                      ),
                      _View.agenda => _AgendaList(
                        events:    _filtered,
                        onOpen:    _openEvent,
                      ),
                    },
        ),
      ],
    );

    if (isMobile || _view != _View.month) return main;

    // Desktop month view: side drawer for selected day
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: main),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _selectedDay != null ? 360 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(color: _kSurface, border: Border(left: BorderSide(color: _kBorder))),
          child: _selectedDay != null
              ? _DayDrawer(
                  date:     _selectedDay!,
                  events:   dayEvents,
                  onClose:  () => setState(() => _selectedDay = null),
                  onOpen:   _openEvent,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _navigate(int delta) {
    setState(() {
      if (_view == _View.week) {
        _viewing = _viewing.add(Duration(days: 7 * delta));
      } else if (_view == _View.month) {
        _viewing = DateTime(_viewing.year, _viewing.month + delta);
      }
      _selectedDay = null;
    });
    _load();
  }

  String _headerTitle() {
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    if (_view == _View.week) {
      final r = _rangeFor(_View.week, _viewing);
      return '${_shortDate(r.start)} – ${_shortDate(r.end)}';
    }
    if (_view == _View.agenda) return 'Next 30 days';
    return '${months[_viewing.month - 1]} ${_viewing.year}';
  }

  void _openEvent(_Event e) {
    showDialog(
      context: context,
      builder: (ctx) => _EventDialog(event: e, onClose: () => Navigator.of(ctx).pop()),
    );
  }

  static String _shortDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  static String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  _DateRange(this.start, this.end);
}

// ─── Top bar ─────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String            title;
  final _View             view;
  final ValueChanged<_View> onViewChange;
  final VoidCallback      onPrev;
  final VoidCallback      onNext;
  final VoidCallback      onToday;

  const _TopBar({
    required this.title,
    required this.view,
    required this.onViewChange,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Wrap(
        spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Calendar',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kText)),
          if (view != _View.agenda) ...[
            _NavBtn(icon: Icons.chevron_left,  onTap: onPrev),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
            _NavBtn(icon: Icons.chevron_right, onTap: onNext),
            OutlinedButton(
              onPressed: onToday,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary, side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
          ] else
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
          // View toggle
          Container(
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final v in _View.values)
                GestureDetector(
                  onTap: () => onViewChange(v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:        view == v ? _kPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(v.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: view == v ? Colors.white : _kText,
                        )),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Icon(icon, size: 16, color: _kMuted),
    ),
  );
}

// ─── Filter bar ──────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final bool showMeetings;
  final bool showTasks;
  final bool onlyMine;
  final ValueChanged<bool> onMeetings;
  final ValueChanged<bool> onTasks;
  final ValueChanged<bool> onMine;

  const _FilterBar({
    required this.showMeetings,
    required this.showTasks,
    required this.onlyMine,
    required this.onMeetings,
    required this.onTasks,
    required this.onMine,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        _TypeChip(label: 'Meetings', active: showMeetings, dot: _kBlue,  onTap: () => onMeetings(!showMeetings)),
        _TypeChip(label: 'Tasks',    active: showTasks,    dot: _kAmber, onTap: () => onTasks(!showTasks)),
        const SizedBox(width: 8),
        _TypeChip(label: 'Only mine', active: onlyMine, onTap: () => onMine(!onlyMine)),
      ]),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final Color?       dot;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.active, required this.onTap, this.dot});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _kPrimary : _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? _kPrimary : _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot != null) ...[
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: active ? Colors.white : dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : _kText)),
      ]),
    ),
  );
}

// ─── Month grid ──────────────────────────────────────────────────────────────
class _MonthGrid extends StatelessWidget {
  final DateTime                        viewing;
  final DateTime?                       selected;
  final Map<DateTime, List<_Event>>     byDate;
  final ValueChanged<DateTime>          onPickDay;

  const _MonthGrid({
    required this.viewing,
    required this.selected,
    required this.byDate,
    required this.onPickDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay    = DateTime(viewing.year, viewing.month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(viewing.year, viewing.month + 1, 0).day;
    final prevTotal   = DateTime(viewing.year, viewing.month, 0).day;
    final today       = DateTime.now();

    final cells = <({DateTime date, bool current})>[];
    for (int i = startOffset - 1; i >= 0; i--) {
      cells.add((date: DateTime(viewing.year, viewing.month - 1, prevTotal - i), current: false));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add((date: DateTime(viewing.year, viewing.month, d), current: true));
    }
    var nextDay = 1;
    while (cells.length % 7 != 0) {
      cells.add((date: DateTime(viewing.year, viewing.month + 1, nextDay++), current: false));
    }

    const dayLabels = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

    return Column(children: [
      // Day-of-week header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Row(children: dayLabels.map((l) => Expanded(
          child: Center(child: Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted))),
        )).toList()),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (_, constraints) {
              final rows = (cells.length / 7).ceil();
              final cellW = constraints.maxWidth / 7;
              final cellH = constraints.maxHeight / rows;
              return Column(
                children: List.generate(rows, (row) {
                  final week = cells.sublist(row * 7, (row * 7 + 7).clamp(0, cells.length));
                  return SizedBox(
                    height: cellH,
                    child: Row(children: week.map((c) {
                      final events = byDate[c.date] ?? const <_Event>[];
                      final isToday = c.date.year == today.year && c.date.month == today.month && c.date.day == today.day;
                      final isSelected = selected != null && c.date == selected;
                      return SizedBox(
                        width: cellW,
                        child: _DayCell(
                          date:       c.date,
                          current:    c.current,
                          events:     events,
                          isToday:    isToday,
                          isSelected: isSelected,
                          onTap:      () => onPickDay(c.date),
                        ),
                      );
                    }).toList()),
                  );
                }),
              );
            }),
          ),
        ),
      ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime       date;
  final bool           current;
  final bool           isToday;
  final bool           isSelected;
  final List<_Event>   events;
  final VoidCallback   onTap;

  const _DayCell({
    required this.date,
    required this.current,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary.withValues(alpha: 0.06) : null,
          border: const Border(right: BorderSide(color: _kBorder), bottom: BorderSide(color: _kBorder)),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 22, height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? _kPrimary : null,
                  shape: BoxShape.circle,
                ),
                child: Text('${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? Colors.white : (current ? _kText : _kMuted.withValues(alpha: 0.5)),
                    )),
              ),
            ]),
            const SizedBox(height: 4),
            ...events.take(3).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(children: [
                  Container(width: 5, height: 5, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      e.time != null ? '${e.time} ${e.title}' : e.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: e.color, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
            )),
            if (events.length > 3)
              Text('+${events.length - 3} more',
                  style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Day drawer (desktop, month view) ────────────────────────────────────────
class _DayDrawer extends StatelessWidget {
  final DateTime      date;
  final List<_Event>  events;
  final VoidCallback  onClose;
  final ValueChanged<_Event> onOpen;

  const _DayDrawer({
    required this.date,
    required this.events,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder))),
        child: Row(children: [
          Expanded(
            child: Text(_longDate(date),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kText),
                overflow: TextOverflow.ellipsis),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _kBorder)),
              child: const Icon(Icons.close, size: 14, color: _kMuted),
            ),
          ),
        ]),
      ),
      Expanded(
        child: events.isEmpty
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_busy, size: 32, color: _kMuted),
                  SizedBox(height: 8),
                  Text('No events on this day', style: TextStyle(fontSize: 13, color: _kMuted)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _EventCard(event: events[i], onTap: () => onOpen(events[i])),
              ),
      ),
    ]);
  }

  static String _longDate(DateTime d) {
    const days   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday % 7]}, ${months[d.month - 1]} ${d.day}';
  }
}

// ─── Event card ──────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final _Event      event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          Container(width: 4, color: event.color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: event.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(event.type.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: event.color, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    if (event.time != null)
                      Text(event.time!, style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 6),
                  Text(event.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (event.clientName != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.business_outlined, size: 12, color: _kMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(event.clientName!,
                            style: const TextStyle(fontSize: 11, color: _kMuted),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  if (event.type == 'task' && event.meta['assigned_to_name'] != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 12, color: _kMuted),
                      const SizedBox(width: 4),
                      Text(event.meta['assigned_to_name'].toString(),
                          style: const TextStyle(fontSize: 11, color: _kMuted)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Event dialog ────────────────────────────────────────────────────────────
class _EventDialog extends StatelessWidget {
  final _Event       event;
  final VoidCallback onClose;
  const _EventDialog({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final meetingLink = event.meta['meeting_link'] as String?;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: event.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(event.type.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: event.color, letterSpacing: 0.5)),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose),
          ]),
          const SizedBox(height: 8),
          Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 12),
          _row(Icons.calendar_today_outlined, _longDate(event.date) + (event.time != null ? ' · ${event.time}' : '')),
          if (event.clientName != null) _row(Icons.business_outlined, event.clientName!),
          if (event.status.isNotEmpty)  _row(Icons.flag_outlined, event.status),
          if (event.type == 'meeting' && event.meta['duration_minutes'] != null)
            _row(Icons.timer_outlined, '${event.meta['duration_minutes']} min'),
          if (event.type == 'meeting' && event.meta['location'] != null && (event.meta['location'] as String).isNotEmpty)
            _row(Icons.location_on_outlined, event.meta['location'] as String),
          if (event.type == 'task' && event.meta['assigned_to_name'] != null)
            _row(Icons.person_outline, event.meta['assigned_to_name'].toString()),
          if (event.type == 'task' && event.meta['substage'] != null)
            _row(Icons.layers_outlined, 'Substage: ${event.meta['substage']}'),
          if (meetingLink != null && meetingLink.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(meetingLink);
                  if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.video_call_outlined, size: 16),
                label: const Text('Join meeting', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 14, color: _kMuted)),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
    ]),
  );

  static String _longDate(DateTime d) {
    const days   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${days[d.weekday % 7]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─── Week view ───────────────────────────────────────────────────────────────
class _WeekView extends StatelessWidget {
  final DateTime                        start;
  final Map<DateTime, List<_Event>>     byDate;
  final ValueChanged<_Event>            onOpen;

  const _WeekView({required this.start, required this.byDate, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: 7,
      itemBuilder: (_, i) {
        final d = start.add(Duration(days: i));
        final dayKey = DateTime(d.year, d.month, d.day);
        final events = byDate[dayKey] ?? const <_Event>[];
        final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 28, height: 28, alignment: Alignment.center,
                  decoration: BoxDecoration(color: isToday ? _kPrimary : null, shape: BoxShape.circle),
                  child: Text('${d.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isToday ? Colors.white : _kText)),
                ),
                const SizedBox(width: 10),
                Text(_weekdayLabel(d), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
                const Spacer(),
                if (events.isNotEmpty)
                  Text('${events.length} event${events.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
              ]),
              const SizedBox(height: 8),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No events', style: TextStyle(fontSize: 12, color: _kMuted)),
                )
              else
                ...events.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _EventCard(event: e, onTap: () => onOpen(e)),
                )),
            ]),
          ),
        );
      },
    );
  }

  static String _weekdayLabel(DateTime d) {
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    return days[d.weekday % 7];
  }
}

// ─── Agenda list ─────────────────────────────────────────────────────────────
class _AgendaList extends StatelessWidget {
  final List<_Event>          events;
  final ValueChanged<_Event>  onOpen;
  const _AgendaList({required this.events, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_available_outlined, size: 40, color: _kMuted),
          SizedBox(height: 12),
          Text('No upcoming events in the next 30 days.', style: TextStyle(fontSize: 13, color: _kMuted)),
        ]),
      );
    }
    final sorted = [...events]..sort((a, b) {
      final d = a.date.compareTo(b.date);
      if (d != 0) return d;
      return (a.time ?? '').compareTo(b.time ?? '');
    });
    // Group by date
    final groups = <DateTime, List<_Event>>{};
    for (final e in sorted) {
      groups.putIfAbsent(e.date, () => []).add(e);
    }
    final keys = groups.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final d = keys[i];
        final list = groups[d]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_longDate(d).toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5)),
            ),
            ...list.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EventCard(event: e, onTap: () => onOpen(e)),
            )),
          ]),
        );
      },
    );
  }

  static String _longDate(DateTime d) {
    const days   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday % 7]}, ${months[d.month - 1]} ${d.day}';
  }
}
