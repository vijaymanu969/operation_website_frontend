import 'dart:async';
import 'dart:ui' show ImageFilter, PointerDeviceKind;
import 'dart:math' show min;
import '../../core/socket/socket_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/user_role.dart';
import '../../shared/widgets/select_option_field.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kPrimary    = Color(0xFF1A1A2E);
const _kAccent     = Color(0xFFE94560);
const _kBorder     = Color(0xFFE8ECF3);
const _kBg         = Color(0xFFF7F8FA);
const _kSurface    = Colors.white;
const _kMuted      = Color(0xFF9CA3AF);

// Column status colors
const _kTodo       = Color(0xFF6366F1); // indigo
const _kInProgress = Color(0xFFF59E0B); // amber
const _kDone       = Color(0xFF10B981); // emerald

// Priority colors
const _kHigh       = Color(0xFFEF4444); // red
const _kMedium     = Color(0xFFF59E0B); // amber
const _kLow        = Color(0xFF3B82F6); // blue

// ─── Priority enum ────────────────────────────────────────────────────────────

enum Priority { urgent, high, medium, low }

extension PriorityX on Priority {
  String get label => switch (this) {
    Priority.urgent => 'Urgent',
    Priority.high   => 'High',
    Priority.medium => 'Medium',
    Priority.low    => 'Low',
  };
  Color get color => switch (this) {
    Priority.urgent => Color(0xFF7C3AED),
    Priority.high   => _kHigh,
    Priority.medium => _kMedium,
    Priority.low    => _kLow,
  };
  String get apiValue => switch (this) {
    Priority.urgent => 'urgent',
    Priority.high   => 'high',
    Priority.medium => 'medium',
    Priority.low    => 'low',
  };
}

// ─── Model ────────────────────────────────────────────────────────────────────

class TaskItem extends AppFlowyGroupItem {
  String?  backendId;     // UUID from backend
  String   title;
  String   description;
  // Multi-assignee / multi-reviewer
  List<String> personIds;
  List<String> assigneeNames;
  List<String> reviewerIds;
  List<String> reviewerNames;
  Priority priority;
  String   status;        // not_completed, reviewer, completed
  DateTime? date;         // start / due date
  DateTime? endDate;      // optional range end date
  List<String>  typeIds;
  List<Map<String, dynamic>> types; // [{id, name, color}]
  List<Map<String, dynamic>> commentsList; // full comment objects from API
  bool     isDone;
  String?  columnGroup;
  String?  createdBy;   // UUID of creator — used to gate "Move to Idea"
  int      sortOrder;
  // Pause/drift fields
  bool     isPaused;
  Map<String, dynamic>? pendingPauseRequest; // non-null = pending approval
  int?     plannedDays;
  int?     pausedDays;
  int?     actualDays;
  int?     drift;
  String?  health;
  // Deadline fields
  bool     isOverdue;
  int      daysOverdue;
  int?     daysUntilDue;

  TaskItem({
    this.backendId,
    required this.title,
    this.description = '',
    List<String>? personIds,
    List<String>? assigneeNames,
    List<String>? reviewerIds,
    List<String>? reviewerNames,
    this.priority    = Priority.medium,
    this.status      = 'not_completed',
    this.date,
    this.endDate,
    List<String>? typeIds,
    List<Map<String, dynamic>>? types,
    List<Map<String, dynamic>>? commentsList,
    this.isDone      = false,
    this.columnGroup,
    this.createdBy,
    this.sortOrder   = 0,
    this.isPaused            = false,
    this.pendingPauseRequest,
    this.plannedDays,
    this.pausedDays,
    this.actualDays,
    this.drift,
    this.health,
    this.isOverdue    = false,
    this.daysOverdue  = 0,
    this.daysUntilDue,
  }) : personIds     = personIds     ?? [],
       assigneeNames = assigneeNames ?? [],
       reviewerIds   = reviewerIds   ?? [],
       reviewerNames = reviewerNames ?? [],
       typeIds       = typeIds       ?? [],
       types         = types         ?? [],
       commentsList  = commentsList  ?? [];

  // ─── Compat getters (other code reads these) ────────────────────────────
  String get assignee     => assigneeNames.join(', ');
  String? get personId    => personIds.isEmpty ? null : personIds.first;
  String? get reviewerId  => reviewerIds.isEmpty ? null : reviewerIds.first;
  String? get reviewerName=> reviewerNames.isEmpty ? null : reviewerNames.join(', ');
  String  get type        => types.isEmpty ? '' : types.first['name'] as String? ?? '';

  // For backward compat with comments displayed as strings
  List<String> get comments => commentsList.map((c) => c['text'] as String? ?? '').toList();

  @override
  String get id => backendId ?? title;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final typesList = (json['types'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final commentsRaw = (json['comments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = json['status'] as String? ?? 'not_completed';

    // Multi-assignee / multi-reviewer arrays from backend
    final assignees = (json['assignees'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final reviewers = (json['reviewers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Fall back to single-id legacy fields if arrays are empty
    final personIds = assignees.isNotEmpty
        ? assignees.map((a) => a['id'] as String).toList()
        : (json['person_id'] != null ? [json['person_id'] as String] : <String>[]);
    final assigneeNames = assignees.isNotEmpty
        ? assignees.map((a) => a['name'] as String).toList()
        : (json['person_name'] != null ? [json['person_name'] as String] : <String>[]);
    final reviewerIds = reviewers.isNotEmpty
        ? reviewers.map((r) => r['id'] as String).toList()
        : (json['reviewer_id'] != null ? [json['reviewer_id'] as String] : <String>[]);
    final reviewerNames = reviewers.isNotEmpty
        ? reviewers.map((r) => r['name'] as String).toList()
        : (json['reviewer_name'] != null ? [json['reviewer_name'] as String] : <String>[]);

    return TaskItem(
      backendId:     json['id'] as String?,
      title:         json['title'] as String? ?? '',
      description:   json['description'] as String? ?? '',
      personIds:     personIds,
      assigneeNames: assigneeNames,
      reviewerIds:   reviewerIds,
      reviewerNames: reviewerNames,
      priority:      _parsePriority(json['priority'] as String?),
      status:        status,
      date:          _parseDate(json['date']),
      endDate:       _parseDate(json['end_date']),
      typeIds:       typesList.map((t) => t['id'] as String).toList(),
      types:         typesList,
      commentsList: commentsRaw,
      isDone:       status == 'completed',
      columnGroup:  json['column_group'] as String?,
      createdBy:    json['created_by'] as String?,
      sortOrder:    json['sort_order'] as int? ?? 0,
      isPaused:            json['is_paused'] as bool? ?? false,
      pendingPauseRequest: json['pending_pause_request'] as Map<String, dynamic>?,
      plannedDays:  json['planned_days'] as int?,
      pausedDays:   json['paused_days'] as int?,
      actualDays:   json['actual_days'] as int?,
      drift:        json['drift'] as int?,
      health:       json['health'] as String?,
      isOverdue:    json['is_overdue']    as bool? ?? false,
      daysOverdue:  json['days_overdue']  as int?  ?? 0,
      daysUntilDue: json['days_until_due'] as int?,
    );
  }

  static Priority _parsePriority(String? p) => switch (p) {
    'urgent' => Priority.urgent,
    'high'   => Priority.high,
    'low'    => Priority.low,
    _        => Priority.medium,
  };

  static DateTime? _parseDate(dynamic d) {
    if (d == null) return null;
    final parsed = DateTime.tryParse(d.toString());
    if (parsed == null) return null;
    // Convert UTC timestamps to local time before stripping the time component.
    // Without this, "2026-04-28T18:30:00Z" (= Apr 29 midnight IST) would display
    // as Apr 28 because .day on a UTC DateTime returns the UTC calendar day.
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Map column_group from backend to board group ID
  static String columnToGroup(String? col) => switch (col) {
    'in_progress' => 'in_progress',
    'done'        => 'done',
    _             => 'todo',
  };

  /// Map board group ID back to backend column_group
  static String groupToColumn(String groupId) => switch (groupId) {
    'in_progress' => 'in_progress',
    'done'        => 'done',
    _             => 'todo',
  };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final AppFlowyBoardController       _boardCtrl;
  late final AppFlowyBoardScrollController _scrollCtrl;
  TaskItem? _selectedTask;
  // Buffers socket task:updated events that arrive while the detail modal is open.
  // Flushed to the board when the modal closes.
  final Map<String, Map<String, dynamic>> _pendingTaskUpdates = {};
  bool _loadingTasks = true;

  // Cached tasks for local operations (pin) without extra API calls
  List<TaskItem> _loadedTasks = [];
  // IDs of pinned tasks — pinned tasks float to top of each column
  final Set<String> _pinnedIds = {};

  // Users loaded from API (for assignee / reviewer dropdowns in new task dialog)
  List<Map<String, dynamic>> _users = [];

  // Task types from backend
  List<SelectOption> _taskTypeOpts = [];

  // ── Filters (all stored as API param values / UUIDs) ─────────────────────
  String?   _filterPerson;    // person_id UUID
  String?   _filterReviewer;  // reviewer_id UUID
  String?   _filterType;      // type_id UUID
  Priority? _filterPriority;
  String?   _filterStatus;    // 'not_completed' | 'reviewer' | 'completed' | 'idea'
  String?   _filterHealth;    // 'active' | 'at_risk' | 'stagnant' | 'dead'
  bool      _filterOverdue = false;

  bool get _hasActiveFilter =>
      _filterPerson != null || _filterReviewer != null ||
      _filterType != null || _filterPriority != null ||
      _filterStatus != null || _filterHealth != null ||
      _filterOverdue;

  // ── Mobile tab: 0 = Tasks, 1 = Analytics (only used on narrow screens) ─────
  int _mobileTab = 0;

  // ── Profile panel (admin: selected person) ───────────────────────────────
  String?               _profileUserId;
  Map<String, dynamic>? _profileData;
  bool                  _profileLoading = false;

  // ── Self-profile panel (worker / intern: always shown) ───────────────────
  Map<String, dynamic>? _myProfileData;
  bool                  _myProfileLoading = false;

  Future<void> _loadProfile(String userId) async {
    setState(() {
      _profileUserId  = userId;
      _profileData    = null;
      _profileLoading = true;
    });
    try {
      final res = await _api.getUserSummary(userId);
      if (mounted) setState(() => _profileData = res.data as Map<String, dynamic>);
    } catch (_) {
      if (mounted) setState(() => _profileData = null);
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  void _clearProfile() {
    setState(() {
      _profileUserId  = null;
      _profileData    = null;
      _profileLoading = false;
    });
  }

  Future<void> _loadMyProfile() async {
    setState(() => _myProfileLoading = true);
    try {
      final res = await _api.getMyUserSummary();
      if (mounted) setState(() => _myProfileData = res.data as Map<String, dynamic>);
    } catch (_) {
      if (mounted) setState(() => _myProfileData = null);
    } finally {
      if (mounted) setState(() => _myProfileLoading = false);
    }
  }

  // ── Bulk select ──────────────────────────────────────────────────────────
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleCard(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Delete $count task${count == 1 ? '' : 's'}?',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete $count selected task${count == 1 ? '' : 's'}. This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteTasks(_selectedIds.toList());
      setState(() {
        _selectMode = false;
        _selectedIds.clear();
      });
      _loadTasks();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete tasks')),
        );
      }
    }
  }

  ApiClient     get _api    => context.read<ApiClient>();
  SocketService get _socket => context.read<SocketService>();

  StreamSubscription<Map<String, dynamic>>? _taskCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _taskUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _taskDeletedSub;
  StreamSubscription<Map<String, dynamic>>? _taskStatusSub;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = AppFlowyBoardScrollController();
    _boardCtrl  = AppFlowyBoardController(
      onMoveGroup:            (_, _, _, _) {},
      onMoveGroupItem:        (_, _, _)    {},
      onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
        _onTaskMovedToGroup(fromGroupId, fromIndex, toGroupId, toIndex);
      },
    );
    _loadTasks();
    _loadTaskTypes();
    _loadUsers();
    _taskCreatedSub = _socket.onTaskCreated.listen(_onTaskCreated);
    _taskUpdatedSub = _socket.onTaskUpdated.listen(_onTaskUpdated);
    _taskDeletedSub = _socket.onTaskDeleted.listen(_onTaskDeleted);
    _taskStatusSub  = _socket.onTaskStatusChanged.listen(_onTaskUpdated);

    // Workers / interns always see their own analytics panel on the right.
    if (!_isAdminUser(context)) _loadMyProfile();
  }

  Future<void> _loadUsers() async {
    try {
      // GET /users/directory — lightweight list, returns only active users with
      // id/name/color/role. Works for any authenticated user (not just admins).
      final res = await _api.getUserDirectory();
      final list = (res.data as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _users = list);
      debugPrint('[Tasks] Loaded ${list.length} users from /users/directory');
    } catch (e) {
      debugPrint('[Tasks] _loadUsers failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _loadTaskTypes() async {
    try {
      final res = await _api.getTaskTypes();
      final types = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _taskTypeOpts = types.map((t) => SelectOption(
          id:    t['id'] as String,
          name:  t['name'] as String,
          color: _colorFromString(t['color'] as String? ?? 'gray'),
        )).toList();
      });
    } catch (_) {}
  }

  static SelectOptionColor _colorFromString(String c) => switch (c) {
    'purple' => SelectOptionColor.purple,
    'pink'   => SelectOptionColor.pink,
    'blue'   => SelectOptionColor.blue,
    'green'  => SelectOptionColor.green,
    'orange' => SelectOptionColor.orange,
    'red'    => SelectOptionColor.pink,
    'yellow' => SelectOptionColor.orange,
    _        => SelectOptionColor.gray,
  };

  static String _stringFromColor(SelectOptionColor c) => switch (c) {
    SelectOptionColor.purple => 'purple',
    SelectOptionColor.pink   => 'pink',
    SelectOptionColor.blue   => 'blue',
    SelectOptionColor.green  => 'green',
    SelectOptionColor.orange => 'orange',
    SelectOptionColor.gray   => 'gray',
  };

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      // Person and Captain are two distinct filters — person_ids matches
      // assignees only, reviewer_ids matches captains only. Do NOT merge.
      final filters = <String, dynamic>{};
      if (_filterPerson   != null) filters['person_ids']   = _filterPerson;
      if (_filterReviewer != null) filters['reviewer_ids'] = _filterReviewer;
      if (_filterType     != null) filters['type_ids']     = _filterType;
      if (_filterPriority != null) filters['priorities']   = _filterPriority!.apiValue;
      if (_filterStatus   != null) filters['statuses']     = _filterStatus;
      if (_filterHealth   != null) filters['healths']      = _filterHealth;
      if (_filterOverdue)          filters['overdue']      = 'true';

      final res = await _api.getTasks(filters: filters.isEmpty ? null : filters);
      final tasks = (res.data as List)
          .map((j) => TaskItem.fromJson(j as Map<String, dynamic>))
          .toList();

      _loadedTasks = tasks;
      _rebuildBoard(tasks);
    } catch (_) {
      // If API fails, show empty board
      for (final g in _boardCtrl.groupDatas.toList()) {
        _boardCtrl.removeGroup(g.id);
      }
      _boardCtrl.addGroup(AppFlowyGroupData(id: 'todo',        name: 'To Do',       items: []));
      _boardCtrl.addGroup(AppFlowyGroupData(id: 'in_progress', name: 'In Progress', items: []));
      _boardCtrl.addGroup(AppFlowyGroupData(id: 'done',        name: 'Done',        items: []));
      _boardCtrl.addGroup(AppFlowyGroupData(id: 'idea',        name: 'Ideas',       items: []));
    }
    if (mounted) setState(() => _loadingTasks = false);
  }

  void _rebuildBoard(List<TaskItem> tasks) {
    final todoItems       = <AppFlowyGroupItem>[];
    final inProgressItems = <AppFlowyGroupItem>[];
    final doneItems       = <AppFlowyGroupItem>[];
    final ideaItems       = <AppFlowyGroupItem>[];

    final today = DateTime.now();
    for (final task in tasks) {
      if (task.status == 'idea' || task.status == 'archived') {
        ideaItems.add(task);
      } else if (task.status == 'completed') {
        doneItems.add(task);
      } else if (task.date != null &&
          !task.date!.isAfter(DateTime(today.year, today.month, today.day))) {
        inProgressItems.add(task);
      } else {
        final group = TaskItem.columnToGroup(task.columnGroup);
        switch (group) {
          case 'in_progress': inProgressItems.add(task);
          case 'done':        doneItems.add(task);
          default:            todoItems.add(task);
        }
      }
    }

    int pinSort(AppFlowyGroupItem a, AppFlowyGroupItem b) {
      final ta = a as TaskItem;
      final tb = b as TaskItem;
      final ap = _pinnedIds.contains(ta.backendId) ? 0 : 1;
      final bp = _pinnedIds.contains(tb.backendId) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return ta.sortOrder.compareTo(tb.sortOrder);
    }

    todoItems.sort(pinSort);
    inProgressItems.sort(pinSort);
    doneItems.sort(pinSort);
    ideaItems.sort(pinSort);

    for (final g in _boardCtrl.groupDatas.toList()) {
      _boardCtrl.removeGroup(g.id);
    }
    _boardCtrl.addGroup(AppFlowyGroupData(id: 'todo',        name: 'To Do',       items: todoItems));
    _boardCtrl.addGroup(AppFlowyGroupData(id: 'in_progress', name: 'In Progress', items: inProgressItems));
    _boardCtrl.addGroup(AppFlowyGroupData(id: 'done',        name: 'Done',        items: doneItems));
    _boardCtrl.addGroup(AppFlowyGroupData(id: 'idea',        name: 'Ideas',       items: ideaItems));
  }

  void _togglePin(String taskId) {
    setState(() {
      if (_pinnedIds.contains(taskId)) {
        _pinnedIds.remove(taskId);
      } else {
        _pinnedIds.add(taskId);
      }
    });
    _rebuildBoard(_loadedTasks);
  }

  /// Called when a card is dragged to a different column
  void _onTaskMovedToGroup(String fromGroupId, int fromIndex, String toGroupId, int toIndex) {
    // Build reorder payload for all items in the target group
    final group = _boardCtrl.getGroupController(toGroupId);
    if (group == null) return;
    final reorderPayload = <Map<String, dynamic>>[];
    for (var i = 0; i < group.items.length; i++) {
      final item = group.items[i] as TaskItem;
      if (item.backendId != null) {
        reorderPayload.add({
          'id': item.backendId,
          'column_group': TaskItem.groupToColumn(toGroupId),
          'sort_order': i,
        });
      }
    }
    if (reorderPayload.isNotEmpty) {
      _api.reorderTasks(reorderPayload);
    }
  }

  @override
  void dispose() {
    _taskCreatedSub?.cancel();
    _taskUpdatedSub?.cancel();
    _taskDeletedSub?.cancel();
    _taskStatusSub?.cancel();
    _boardCtrl.dispose();
    super.dispose();
  }

  // ── Surgical real-time board updates ──────────────────────────────────────

  /// Determine which board column a task belongs to.
  String _groupForTask(TaskItem task) {
    final today = DateTime.now();
    if (task.status == 'idea' || task.status == 'archived') return 'idea';
    if (task.status == 'completed') return 'done';
    if (task.date != null &&
        !task.date!.isAfter(DateTime(today.year, today.month, today.day))) {
      return 'in_progress';
    }
    return TaskItem.columnToGroup(task.columnGroup);
  }

  /// Remove a task from whatever column it's currently in.
  void _removeTaskFromBoard(String taskId) {
    for (final group in _boardCtrl.groupDatas) {
      for (final item in group.items) {
        if ((item as TaskItem).backendId == taskId) {
          _boardCtrl.removeGroupItem(group.id, item.id);
          return;
        }
      }
    }
  }

  void _onTaskCreated(Map<String, dynamic> data) {
    final taskJson = data['task'] as Map<String, dynamic>?;
    if (taskJson == null || !mounted) return;
    final task = TaskItem.fromJson(taskJson);
    // Avoid duplicates (we may have just created it locally)
    _removeTaskFromBoard(task.id);
    _boardCtrl.addGroupItem(_groupForTask(task), task);
    if (mounted) setState(() {});
  }

  void _onTaskUpdated(Map<String, dynamic> data) {
    final taskJson = data['task'] as Map<String, dynamic>?;
    if (taskJson == null || !mounted) return;
    final task = TaskItem.fromJson(taskJson);
    // If the detail modal for this task is currently open, buffer the update
    // and apply it once the modal closes instead of updating mid-view.
    if (_selectedTask != null && _selectedTask!.id == task.id) {
      _pendingTaskUpdates[task.id] = taskJson;
      return;
    }
    _removeTaskFromBoard(task.id);
    _boardCtrl.addGroupItem(_groupForTask(task), task);
    if (mounted) setState(() {});
  }

  void _onTaskDeleted(Map<String, dynamic> data) {
    final taskId = data['task_id'] as String?;
    if (taskId == null || !mounted) return;
    _removeTaskFromBoard(taskId);
    if (mounted) setState(() {});
  }

  Color _columnColor(String id) => switch (id) {
    'todo'        => _kTodo,
    'in_progress' => _kInProgress,
    'done'        => _kDone,
    'idea'        => const Color(0xFF8B5CF6), // violet
    _             => _kMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopBar(
          onAddTask:       _showAddTaskDialog,
          onStagnant:      _isAdminUser(context) ? _showStagnantPanel : null,
          onRequests:      _isAdminUser(context) ? _showRequestsPanel : null,
          onSelectToggle:  _toggleSelectMode,
          selectMode:      _selectMode,
        ),
        // ── Filter bar ──────────────────────────────────────────────────
        _TaskFilterBar(
          showPerson:     _isAdminUser(context),
          filterPerson:   _filterPerson,
          filterReviewer: _filterReviewer,
          filterType:     _filterType,
          filterPriority: _filterPriority,
          filterStatus:   _filterStatus,
          filterHealth:   _filterHealth,
          users:          _users,
          taskTypes:      _taskTypeOpts,
          hasActive:      _hasActiveFilter,
          onPersonChanged: (v) {
            setState(() => _filterPerson = v);
            _loadTasks();
            if (_isAdminUser(context)) {
              if (v != null && v != _profileUserId) {
                _loadProfile(v);   // only fetch when the selected person changes
              } else if (v == null) {
                _clearProfile();
              }
            }
          },
          onReviewerChanged: (v) { setState(() => _filterReviewer = v); _loadTasks(); },
          onTypeChanged:     (v) { setState(() => _filterType     = v); _loadTasks(); },
          onPriorityChanged: (v) { setState(() => _filterPriority = v); _loadTasks(); },
          onStatusChanged:   (v) { setState(() => _filterStatus   = v); _loadTasks(); },
          onHealthChanged:   (v) { setState(() => _filterHealth   = v); _loadTasks(); },
          onClearAll: () {
            setState(() {
              _filterPerson   = null;
              _filterReviewer = null;
              _filterType     = null;
              _filterPriority = null;
              _filterStatus   = null;
              _filterHealth   = null;
              _filterOverdue  = false;
            });
            _clearProfile();
            _loadTasks();
          },
        ),
        // ── Bulk-action bar (shown in select mode) ──────────────────────────
        if (_selectMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(children: [
              Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _selectedIds.isEmpty ? null : _bulkDelete,
                icon:  const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('Delete', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kBorder,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize:   Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Expanded(child: _buildBoardArea(context)),
      ],
    );
  }

  // ── Board area (responsive) ─────────────────────────────────────────────────

  Widget _buildKanbanBoard() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        thumbVisibility: true,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: AppFlowyBoard(
          controller:            _boardCtrl,
          boardScrollController: _scrollCtrl,
          cardBuilder: (context, group, groupItem) {
            final item   = groupItem as TaskItem;
            final cardId = item.backendId ?? item.id;
            if (_selectMode) {
              return AppFlowyGroupCard(
                key: ValueKey(item.id),
                child: GestureDetector(
                  onTap: () => _toggleCard(cardId),
                  child: Stack(children: [
                    _TaskCard(
                      item:        item,
                      isSelected:  _selectedIds.contains(cardId),
                      isPinned:    _pinnedIds.contains(cardId),
                      onTap:       () => _toggleCard(cardId),
                      onPinToggle: () => _togglePin(cardId),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: IgnorePointer(
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: _selectedIds.contains(cardId) ? _kAccent : Colors.white,
                            border: Border.all(
                              color: _selectedIds.contains(cardId) ? _kAccent : _kBorder,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _selectedIds.contains(cardId)
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }
            return AppFlowyGroupCard(
              key: ValueKey(item.id),
              child: _TaskCard(
                item:        item,
                isSelected:  _selectedTask?.id == item.id,
                isPinned:    _pinnedIds.contains(item.backendId ?? item.id),
                onTap:       () => _showTaskDetailModal(item),
                onPinToggle: () => _togglePin(item.backendId ?? item.id),
              ),
            );
          },
          headerBuilder: (context, groupData) => _ColumnHeader(
            groupData:   groupData,
            accentColor: _columnColor(groupData.id),
          ),
          footerBuilder: (_, _) => const SizedBox.shrink(),
          groupConstraints: const BoxConstraints.tightFor(width: 300),
          config: AppFlowyBoardConfig(
            groupBackgroundColor: _kBg,
            stretchGroupHeight:  false,
            groupMargin:         const EdgeInsets.only(right: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardArea(BuildContext context) {
    if (_loadingTasks) return const Center(child: CircularProgressIndicator());

    final isAdmin  = _isAdminUser(context);
    final hasPanel = _profileUserId != null || !isAdmin;
    final isMobile = MediaQuery.of(context).size.width < 700;

    // Board widget — shared between mobile and desktop
    final board = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _buildKanbanBoard(),
    );

    // Profile panel widget — shared between mobile and desktop
    Widget? panel;
    if (_profileUserId != null) {
      panel = _UserProfilePanel(
        loading:      _profileLoading,
        data:         _profileData,
        onClose: () {
          setState(() {
            _filterPerson  = null;
            _filterOverdue = false;
            _mobileTab     = 0;
          });
          _clearProfile();
          _loadTasks();
        },
        onOverdueTap: () {
          setState(() => _filterOverdue = true);
          _loadTasks();
        },
      );
    } else if (!isAdmin) {
      panel = _UserProfilePanel(
        loading:      _myProfileLoading,
        data:         _myProfileData,
        showClose:    false,
        onClose:      () {},
        onOverdueTap: () {
          setState(() => _filterOverdue = true);
          _loadTasks();
        },
      );
    }

    // ── Desktop: side-by-side ────────────────────────────────────────────────
    if (!isMobile || !hasPanel || panel == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: board),
          if (panel != null) panel,
        ],
      );
    }

    // ── Mobile: tab toggle ───────────────────────────────────────────────────
    return Column(
      children: [
        // Toggle bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color:        _kBg,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _kBorder),
            ),
            child: Row(children: [
              _MobileTab(
                label: 'Tasks',
                icon:  Icons.view_kanban_outlined,
                active: _mobileTab == 0,
                onTap:  () => setState(() => _mobileTab = 0),
              ),
              _MobileTab(
                label: 'Analytics',
                icon:  Icons.bar_chart_rounded,
                active: _mobileTab == 1,
                onTap:  () => setState(() => _mobileTab = 1),
              ),
            ]),
          ),
        ),
        // Content
        Expanded(
          child: _mobileTab == 0 ? board : panel,
        ),
      ],
    );
  }

  // ── Task detail modal ───────────────────────────────────────────────────────

  void _showTaskDetailModal(TaskItem item) {
    setState(() => _selectedTask = item);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          // Blur layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const SizedBox.expand(),
          ),
          // Modal card
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width:       min(860.0, MediaQuery.of(ctx).size.width * 0.9),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.84,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color:        _kSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color:      Colors.black26,
                      blurRadius: 40,
                      offset:     Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _TaskDetailPanel(
                    item:          item,
                    onClose:       () => Navigator.of(ctx).pop(),
                    onChanged:     () => setState(() {}),
                    onDeleted:     () {
                      Navigator.of(ctx).pop();
                      _loadTasks();
                    },
                    typeOptions:   _taskTypeOpts,
                    users:         _users,
                    currentUserId: (context.read<AuthBloc>().state is AuthAuthenticated)
                        ? (context.read<AuthBloc>().state as AuthAuthenticated).user.id
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      final closedId = _selectedTask?.id;
      setState(() => _selectedTask = null);
      // If any socket updates arrived while the modal was open, discard the
      // buffered JSON and do one fresh fetch instead — avoids applying the
      // same change twice (onChanged already mutated the item in-place).
      if (closedId != null && _pendingTaskUpdates.containsKey(closedId)) {
        _pendingTaskUpdates.remove(closedId);
        _loadTasks();
      }
    });
  }

  // ── Add task dialog ─────────────────────────────────────────────────────────

  bool _isAdminUser(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return false;
    final role = state.user.role;
    return role == UserRole.superAdmin || role == UserRole.admin;
  }

  void _showRequestsPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width:       600,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            margin:      const EdgeInsets.all(32),
            decoration:  BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 12))],
            ),
            child: _RequestsPanel(
              api:     _api,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _showStagnantPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width:       560,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            margin:      const EdgeInsets.all(32),
            decoration:  BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 12))],
            ),
            child: _StagnantPanel(
              api:     _api,
              onClose: () => Navigator.of(ctx).pop(),
              onTaskTap: (task) {
                Navigator.of(ctx).pop();
                _showTaskDetailModal(task);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog() async {
    // Always refresh users + types when dialog opens so dropdowns are current
    await _loadUsers();
    if (_taskTypeOpts.isEmpty) {
      await _loadTaskTypes();
    }
    if (!mounted) return;
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users available. Check your connection.')),
      );
      return;
    }
    final titleCtrl    = TextEditingController();
    final descCtrl     = TextEditingController();
    String   selectedGroup    = 'todo';
    String   selectedType     = 'Task';
    Priority selectedPriority = Priority.medium;
    DateTime? selectedDate;
    DateTime? selectedEndDate;
    bool      showCalendar    = false;

    final dialogTypeOpts = List<SelectOption>.from(_taskTypeOpts);
    List<String> selectedTypeIds = [];

    // Build SelectOption lists for people dropdowns (from /users API)
    // Each user's color comes from the backend (ops_users.color).
    final personOpts = _users.map((u) => SelectOption(
      id:    u['id'] as String,
      name:  u['name'] as String,
      color: _colorFromString(u['color'] as String? ?? 'gray'),
    )).toList();
    final reviewerOpts = _users.map((u) => SelectOption(
      id:    u['id'] as String,
      name:  u['name'] as String,
      color: _colorFromString(u['color'] as String? ?? 'gray'),
    )).toList();
    List<String> selectedPersonIds   = [];
    List<String> selectedReviewerIds = [];
    String? _errTitle;
    String? _errDate;
    String? _errPerson;
    String? _errReviewer;
    const border   = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide:   BorderSide(color: _kBorder),
    );
    const focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide:   BorderSide(color: _kAccent),
    );

    InputDecoration fieldDeco(String label) => InputDecoration(
      labelText:     label,
      labelStyle:    const TextStyle(fontSize: 13, color: _kMuted),
      border:        border,
      enabledBorder: border,
      focusedBorder: focusBorder,
      isDense:       true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

   
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _kSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding:    const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding:  const EdgeInsets.fromLTRB(20, 16, 20, 20),
          // No actionsPadding — buttons are removed
          title: const Text('New Task',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kPrimary)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus:  true,
                    style:      const TextStyle(fontSize: 13),
                    onChanged:  (_) { if (_errTitle != null) setDlg(() => _errTitle = null); },
                    decoration: fieldDeco('Title *').copyWith(
                      enabledBorder: _errTitle != null
                          ? const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                              borderSide:   BorderSide(color: Colors.red),
                            )
                          : null,
                    ),
                  ),
                  if (_errTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(_errTitle!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines:   3,
                    style:      const TextStyle(fontSize: 13),
                    decoration: fieldDeco('Description'),
                  ),
                  const SizedBox(height: 12),
                  // Person (assignee)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border:       Border.all(color: _errPerson != null ? 
                      Colors.red : _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectOptionField(
                      label:           'Person *',
                      options:         personOpts,
                      selectedOptions: selectedPersonIds,
                      onOptionSelected: (id) {
                        setDlg(() {
                          if (selectedPersonIds.contains(id)) {
                            selectedPersonIds.remove(id);
                          } else {
                            selectedPersonIds.add(id);
                            _errPerson = null;
                          }
                        });
                      },
                      // People come from /users — not creatable/editable here
                      onOptionCreated:      (_) {},
                      onOptionRenamed:      (_, _) {},
                      onOptionColorChanged: (_, _) {},
                    ),
                  ),
                  if (_errPerson != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(_errPerson!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                  const SizedBox(height: 12),
                  // Reviewer (captain)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border:       Border.all(color: _errReviewer != null ?
                      Colors.red : _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectOptionField(
                      label:           'Reviewer *',
                      options:         reviewerOpts,
                      selectedOptions: selectedReviewerIds,
                      onOptionSelected: (id) {
                        setDlg(() {
                          if (selectedReviewerIds.contains(id)) {
                            selectedReviewerIds.remove(id);
                          } else {
                            selectedReviewerIds.add(id);
                            _errReviewer = null;
                          }
                        });
                      },
                      onOptionCreated:      (_) {},
                      onOptionRenamed:      (_, _) {},
                      onOptionColorChanged: (_, _) {},
                    ),
                  ),
                  if (_errReviewer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(_errReviewer!, style: const TextStyle
                      (fontSize: 11, color: Colors.red)),
                  ),
                  const SizedBox(height: 12),
                  // Priority dropdown
                  DropdownButtonFormField<Priority>(
                    initialValue: selectedPriority,
                    style:     const TextStyle(fontSize: 13, color: _kPrimary),
                    decoration: fieldDeco('Priority'),
                    items: Priority.values.map((p) => DropdownMenuItem(
                      value: p,
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: p.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(p.label, style: const TextStyle(fontSize: 13)),
                      ]),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDlg(() => selectedPriority = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Type — SelectOptionField
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border:       Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectOptionField(
                      label:           'Type',
                      options:         dialogTypeOpts,
                      selectedOptions: selectedTypeIds,
                      onOptionSelected: (id) {
                        setDlg(() {
                          if (selectedTypeIds.contains(id)) {
                            selectedTypeIds.remove(id);
                          } else {
                            selectedTypeIds.add(id);
                          }
                          final opt = dialogTypeOpts.firstWhere(
                              (o) => o.id == id,
                              orElse: () => dialogTypeOpts.first);
                          selectedType = opt.name;
                        });
                      },
                      onOptionCreated: (name) async {
                        // Call POST /tasks/types to get a real UUID
                        const _autoColors = ['blue', 'purple', 'green', 'orange', 'pink', 'red'];
                        final autoColor = _autoColors[dialogTypeOpts.length % _autoColors.length];
                        try {
                          final res = await _api.createTaskType({
                            'name':  name,
                            'color': autoColor,
                          });
                          final data = res.data as Map<String, dynamic>;
                          final newId = data['id'] as String;
                          final newOpt = SelectOption(
                            id:    newId,
                            name:  data['name'] as String? ?? name,
                            color: _colorFromString(data['color'] as String? ?? 'gray'),
                          );
                          setDlg(() {
                            dialogTypeOpts.add(newOpt);
                            selectedTypeIds.add(newId);
                            selectedType = newOpt.name;
                          });
                          // Keep parent list in sync so next "New Task" shows it
                          if (mounted) setState(() => _taskTypeOpts.add(newOpt));
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to create type: $e')),
                            );
                          }
                        }
                      },
                      onOptionRenamed: (id, name) async {
                        try {
                          await _api.updateTaskType(id, {'name': name});
                          setDlg(() {
                            final i = dialogTypeOpts.indexWhere((o) => o.id == id);
                            if (i != -1) {
                              if (selectedType == dialogTypeOpts[i].name) selectedType = name;
                              dialogTypeOpts[i] = dialogTypeOpts[i].copyWith(name: name);
                            }
                          });
                          if (mounted) {
                            setState(() {
                              final i = _taskTypeOpts.indexWhere((o) => o.id == id);
                              if (i != -1) _taskTypeOpts[i] = _taskTypeOpts[i].copyWith(name: name);
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to rename type: $e')),
                            );
                          }
                        }
                      },
                      onOptionColorChanged: (id, color) async {
                        try {
                          await _api.updateTaskType(id, {'color': _stringFromColor(color)});
                          setDlg(() {
                            final i = dialogTypeOpts.indexWhere((o) => o.id == id);
                            if (i != -1) dialogTypeOpts[i] = dialogTypeOpts[i].copyWith(color: color);
                          });
                          if (mounted) {
                            setState(() {
                              final i = _taskTypeOpts.indexWhere((o) => o.id == id);
                              if (i != -1) _taskTypeOpts[i] = _taskTypeOpts[i].copyWith(color: color);
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update type color: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroup,
                    style:     const TextStyle(fontSize: 13, color: _kPrimary),
                    decoration: fieldDeco('Status'),
                    items: const [
                      DropdownMenuItem(value: 'todo',        child: Text('To Do',       style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'in_progress', child: Text('In Progress', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'done',        child: Text('Done',        style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlg(() => selectedGroup = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Due date — TapRegion closes the calendar on outside tap
                  TapRegion(
                    onTapOutside: (_) {
                      if (showCalendar) setDlg(() => showCalendar = false);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setDlg(() => showCalendar = !showCalendar),
                          child: InputDecorator(
                            decoration: fieldDeco('Date *').copyWith(
                              enabledBorder: _errDate != null
                                  ? const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                      borderSide:   BorderSide(color: Colors.red),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDate == null
                                      ? 'Pick a date'
                                      : selectedEndDate != null
                                          ? '${_fmtDate(selectedDate!)}  →  ${_fmtDate(selectedEndDate!)}'
                                          : _fmtDateLong(selectedDate!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selectedDate == null
                                        ? _kMuted
                                        : _kPrimary,
                                  ),
                                ),
                                Icon(
                                  showCalendar
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.calendar_today_outlined,
                                  size: 14,
                                  color: _kMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Inline calendar — no auto-close, TapRegion dismisses it
                        if (showCalendar)
                          _InlineDatePicker(
                            selected:       selectedDate,
                            endDate:        selectedEndDate,
                            onSelect: (d) => setDlg(() {
                              selectedDate    = d;
                              selectedEndDate = null;
                              _errDate        = null;
                            }),
                            onEndSelect:    (d) => setDlg(() => selectedEndDate = d),
                            onEndDateClear: ()  => setDlg(() => selectedEndDate = null),
                          ),
                      ],
                    ),
                  ),
                  if (_errDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(_errDate!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          titleCtrl.dispose();
                          descCtrl.dispose();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Cancel', style: TextStyle(color: _kMuted)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final eTitle    = titleCtrl.text.trim().isEmpty ? 'Title is required' : null;
                          final eDate     = selectedDate == null ? 'Date is required' : null;
                          final ePerson   = selectedPersonIds.isEmpty ? 'At least one assignee is required' : null;
                          final eReviewer = selectedReviewerIds.isEmpty ? 'At least one reviewer is required' : null;
                          if (eTitle != null || eDate != null || ePerson != null || eReviewer != null) {
                            setDlg(() {
                              _errTitle    = eTitle;
                              _errDate     = eDate;
                              _errPerson   = ePerson;
                              _errReviewer = eReviewer;
                            });
                            return;
                          }
                          try {
                            final data = <String, dynamic>{
                              'title':        titleCtrl.text.trim(),
                              'description':  descCtrl.text.trim(),
                              'priority':     selectedPriority.apiValue,
                              'column_group': TaskItem.groupToColumn(selectedGroup),
                              'date':         selectedDate!.toIso8601String().split('T').first,
                              'person_ids':   selectedPersonIds,
                              'reviewer_ids': selectedReviewerIds,
                            };
                            if (selectedEndDate != null) {
                              data['end_date'] = selectedEndDate!.toIso8601String().split('T').first;
                            }
                            if (selectedTypeIds.isNotEmpty) {
                              data['type_ids'] = selectedTypeIds;
                            }
                            await _api.createTask(data);
                            titleCtrl.dispose();
                            descCtrl.dispose();
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await _loadTasks();
                          } on DioException catch (e) {
                            final backendMsg = e.response?.data is Map
                                ? (e.response!.data as Map)['error']?.toString()
                                : null;
                            final msg = backendMsg ?? 'Failed to create task (${e.response?.statusCode ?? 'network error'})';
                            debugPrint('[Tasks] createTask failed: $msg | full response: ${e.response?.data}');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to create task: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Create Task', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable: Mobile tab toggle pill ────────────────────────────────────────

class _MobileTab extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       active;
  final VoidCallback onTap;

  const _MobileTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color:        active ? _kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14,
                  color: active ? Colors.white : _kMuted),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      active ? Colors.white : _kMuted,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable: Top bar ────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback  onAddTask;
  final VoidCallback? onStagnant;
  final VoidCallback? onRequests;
  final VoidCallback  onSelectToggle;
  final bool          selectMode;
  const _TopBar({
    required this.onAddTask,
    required this.onSelectToggle,
    required this.selectMode,
    this.onStagnant,
    this.onRequests,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Text('Tasks',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary)),
          const SizedBox(width: 8),
          // Buttons scroll horizontally on narrow screens instead of overflowing
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // keeps rightmost buttons (New Task) always visible
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRequests != null) ...[
                    OutlinedButton.icon(
                      onPressed: onRequests,
                      icon:  const Icon(Icons.inbox_rounded, size: 14),
                      label: const Text('Requests', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize:   Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (onStagnant != null) ...[
                    OutlinedButton.icon(
                      onPressed: onStagnant,
                      icon:  const Icon(Icons.warning_amber_rounded, size: 14),
                      label: const Text('Stagnant', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF97316),
                        side: const BorderSide(color: Color(0xFFF97316)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize:   Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Select / Cancel button
                  OutlinedButton.icon(
                    onPressed: onSelectToggle,
                    icon:  Icon(selectMode ? Icons.close : Icons.checklist_rounded, size: 14),
                    label: Text(selectMode ? 'Cancel' : 'Select',
                        style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kMuted,
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize:   Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onAddTask,
                    icon:  const Icon(Icons.add, size: 16),
                    label: const Text('New Task', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize:     Size.zero,
                      tapTargetSize:   MaterialTapTargetSize.shrinkWrap,
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

// ─── Reusable: Filter bar ────────────────────────────────────────────────────

class _TaskFilterBar extends StatelessWidget {
  final String?   filterPerson;
  final String?   filterReviewer;
  final String?   filterType;
  final Priority? filterPriority;
  final String?   filterStatus;
  final String?   filterHealth;
  final bool      showPerson;
  final List<Map<String, dynamic>> users;
  final List<SelectOption>         taskTypes;
  final bool      hasActive;
  final ValueChanged<String?>   onPersonChanged;
  final ValueChanged<String?>   onReviewerChanged;
  final ValueChanged<String?>   onTypeChanged;
  final ValueChanged<Priority?> onPriorityChanged;
  final ValueChanged<String?>   onStatusChanged;
  final ValueChanged<String?>   onHealthChanged;
  final VoidCallback            onClearAll;

  const _TaskFilterBar({
    required this.filterPerson,
    required this.filterReviewer,
    required this.filterType,
    required this.filterPriority,
    required this.filterStatus,
    required this.filterHealth,
    required this.showPerson,
    required this.users,
    required this.taskTypes,
    required this.hasActive,
    required this.onPersonChanged,
    required this.onReviewerChanged,
    required this.onTypeChanged,
    required this.onPriorityChanged,
    required this.onStatusChanged,
    required this.onHealthChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final userItems = users
        .map((u) => MapEntry(u['id'] as String, u['name'] as String))
        .toList();
    final typeItems = taskTypes
        .map((t) => MapEntry(t.id, t.name))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const Icon(Icons.filter_list_rounded, size: 15, color: _kMuted),
          const SizedBox(width: 6),
          const Text('Filter',
              style: TextStyle(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),

          // Person (assignee) — admin only
          if (showPerson) ...[
            _FilterDropdown<String>(
              label:    'Person',
              value:    filterPerson,
              items:    userItems,
              onChanged: onPersonChanged,
            ),
            const SizedBox(width: 6),
          ],

          // Reviewer
          _FilterDropdown<String>(
            label:    'Reviewer',
            value:    filterReviewer,
            items:    userItems,
            onChanged: onReviewerChanged,
          ),
          const SizedBox(width: 6),

          // Type
          _FilterDropdown<String>(
            label:    'Type',
            value:    filterType,
            items:    typeItems,
            onChanged: onTypeChanged,
          ),
          const SizedBox(width: 6),

          // Priority
          _FilterDropdown<Priority>(
            label: 'Priority',
            value: filterPriority,
            items: Priority.values.map((p) => MapEntry(p, p.label)).toList(),
            onChanged: onPriorityChanged,
          ),
          const SizedBox(width: 6),

          // Status
          _FilterDropdown<String>(
            label: 'Status',
            value: filterStatus,
            items: const [
              MapEntry('not_completed', 'Not Completed'),
              MapEntry('reviewer',      'In Review'),
              MapEntry('completed',     'Completed'),
              MapEntry('idea',          'Idea'),
            ],
            onChanged: onStatusChanged,
          ),
          const SizedBox(width: 6),

          // Health
          _FilterDropdown<String>(
            label: 'Health',
            value: filterHealth,
            items: const [
              MapEntry('active',   'Active'),
              MapEntry('at_risk',  'At Risk'),
              MapEntry('stagnant', 'Stagnant'),
              MapEntry('dead',     'Dead'),
            ],
            onChanged: onHealthChanged,
          ),

          // Clear all
          if (hasActive) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onClearAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        _kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close, size: 11, color: _kAccent),
                  const SizedBox(width: 3),
                  Text('Clear',
                      style: TextStyle(fontSize: 11, color: _kAccent, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Single filter dropdown chip ─────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T?     value;
  final List<MapEntry<T, String>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive   = value != null;
    final displayLbl = isActive
        ? items.firstWhere((e) => e.key == value, orElse: () => items.first).value
        : label;

    return PopupMenuButton<T?>(
      onSelected: (v) => onChanged(v),
      tooltip: label,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (_) => [
        // "All" option to clear — onTap is needed because PopupMenuButton.onSelected
        // silently skips null values; onTap fires unconditionally.
        PopupMenuItem<T?>(
          value: null,
          height: 32,
          onTap: () => onChanged(null),
          child: Text('All',
              style: TextStyle(
                  fontSize: 12,
                  color: !isActive ? _kAccent : _kPrimary,
                  fontWeight: !isActive ? FontWeight.w600 : FontWeight.normal)),
        ),
        const PopupMenuDivider(height: 1),
        ...items.map((e) => PopupMenuItem<T?>(
          value: e.key,
          height: 32,
          child: Text(e.value,
              style: TextStyle(
                  fontSize: 12,
                  color: e.key == value ? _kAccent : _kPrimary,
                  fontWeight: e.key == value ? FontWeight.w600 : FontWeight.normal)),
        )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        isActive ? _kPrimary : _kSurface,
          borderRadius: BorderRadius.circular(4),
          border:       Border.all(color: isActive ? _kPrimary : _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(displayLbl,
              style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w500,
                  color:      isActive ? Colors.white : _kPrimary)),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 13, color: isActive ? Colors.white : _kMuted),
        ]),
      ),
    );
  }
}

// ─── Reusable: Column header ──────────────────────────────────────────────────
// Colored top-border accent makes the status immediately scannable.

class _ColumnHeader extends StatelessWidget {
  final AppFlowyGroupData groupData;
  final Color accentColor;

  const _ColumnHeader({required this.groupData, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        // 3px top border per column — TailAdmin Kanban style
        border: Border(
          top:    BorderSide(color: accentColor, width: 3),
          bottom: const BorderSide(color: _kBorder),
        ),
      ),
      child: AppFlowyGroupHeader(
        height: 44,
        margin: EdgeInsets.zero,
        title: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                groupData.headerData.groupName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kPrimary),
              ),
              const SizedBox(width: 8),
              // Count pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:        accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${groupData.items.length}',
                  style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      accentColor),
                ),
              ),
            ],
          ),
        ),
        addIcon: const SizedBox.shrink(),
      ),
    );
  }
}

// ─── Reusable: Priority badge ─────────────────────────────────────────────────
// Pill badge — colored bg at low opacity so it's visible but not loud.

class _PriorityBadge extends StatelessWidget {
  final Priority priority;
  const _PriorityBadge(this.priority);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        priority.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w600,
            color:      priority.color),
      ),
    );
  }
}

// ─── Reusable: Type badge ─────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        _kBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
      ),
      child: Text(type,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: _kMuted)),
    );
  }
}

// ─── Reusable: Assignee avatar ────────────────────────────────────────────────

class _AssigneeAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const _AssigneeAvatar(this.name, {this.radius = 11});

  // Generate a consistent color from the name so each person has their own.
  Color get _color {
    const palette = [
      Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF0EA5E9),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius:          radius,
      backgroundColor: _color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            fontSize:   radius * 0.8,
            fontWeight: FontWeight.w600,
            color:      Colors.white),
      ),
    );
  }
}

// ─── Reusable: Meta chip (date / comment count) ───────────────────────────────

class _HealthDot extends StatelessWidget {
  final String health;
  const _HealthDot(this.health);

  static Color _color(String h) => switch (h) {
    'active'   => Color(0xFF10B981),
    'at_risk'  => Color(0xFFF59E0B),
    'stagnant' => Color(0xFFF97316),
    'dead'     => Color(0xFFEF4444),
    _          => Color(0xFF9CA3AF),
  };

  static String _label(String h) => switch (h) {
    'active'   => 'Active',
    'at_risk'  => 'At Risk',
    'stagnant' => 'Stagnant',
    'dead'     => 'Dead',
    _          => h,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(health);
    return Tooltip(
      message: _label(health),
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  final TaskItem item;
  const _DeadlineChip({required this.item});

  static String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (item.isOverdue) {
      final label = item.daysOverdue == 1 ? '1d late' : '${item.daysOverdue}d late';
      return _colored(Icons.warning_amber_rounded, label, const Color(0xFFEF4444));
    }
    if (item.daysUntilDue == 0) {
      return _colored(Icons.today_rounded, 'Due today', const Color(0xFFF59E0B));
    }
    if (item.daysUntilDue == 1) {
      return _colored(Icons.today_rounded, 'Due tmrw',  const Color(0xFFF97316));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.calendar_today_outlined, size: 11, color: _kMuted),
      const SizedBox(width: 3),
      Text(_fmt(item.date!), style: const TextStyle(fontSize: 11, color: _kMuted)),
    ]);
  }

  Widget _colored(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: _kMuted),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11, color: _kMuted)),
      ],
    );
  }
}

// ─── Reusable: Task card ──────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskItem   item;
  final bool       isSelected;
  final bool       isPinned;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;

  const _TaskCard({
    required this.item,
    required this.isSelected,
    required this.isPinned,
    required this.onTap,
    required this.onPinToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isPaused
              ? const Color(0xFFFFFBEB)
              : item.isOverdue
                  ? const Color(0xFFFFF5F5)
                  : _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? _kAccent
                : item.isPaused
                    ? const Color(0xFFF59E0B)
                    : item.isOverdue
                        ? const Color(0xFFEF4444)
                        : _kBorder,
            width: isSelected || item.isPaused || item.isOverdue ? 1.5 : 1,
          ),
          boxShadow: item.isPaused || item.isOverdue ? [] : [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: priority badge + type badge + health dot ───────────
            Row(
              children: [
                _PriorityBadge(item.priority),
                const SizedBox(width: 6),
                Flexible(child: _TypeBadge(item.type)),
                const SizedBox(width: 6),
                const Spacer(),
                if (item.isPaused) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                      border:       Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Icon(Icons.pause_rounded,
                        size: 11, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (item.health != null && item.status == 'not_completed' && !item.isPaused) ...[
                  _HealthDot(item.health!),
                  const SizedBox(width: 6),
                ],
                if (item.isDone)
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: _kDone),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onPinToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 13,
                    color: isPinned ? _kAccent : _kMuted.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Row 2: title ──────────────────────────────────────────────
            Text(
              item.title,
              style: TextStyle(
                fontSize:        13,
                fontWeight:      FontWeight.w600,
                color:           item.isDone || item.isPaused ? _kMuted : _kPrimary,
                decoration:      item.isDone ? TextDecoration.lineThrough : null,
                decorationColor: _kMuted,
              ),
            ),
            // ── Row 3: description (optional) ─────────────────────────────
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.description,
                style: const TextStyle(fontSize: 11, color: _kMuted, height: 1.5),
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 10),
            // ── Assignees row ─────────────────────────────────────────────
            if (item.assigneeNames.isNotEmpty)
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 12, color: _kMuted),
                const SizedBox(width: 5),
                ...item.assigneeNames.take(4).expand((name) => [
                  _AssigneeAvatar(name, radius: 10),
                  const SizedBox(width: 4),
                ]),
                Flexible(
                  child: Text(
                    item.assigneeNames.join(', '),
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),

            // ── Reviewers row ────────────────────────────────────────────
            if (item.reviewerNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.shield_outlined, size: 12, color: _kMuted),
                const SizedBox(width: 5),
                ...item.reviewerNames.take(4).expand((name) => [
                  _AssigneeAvatar(name, radius: 10),
                  const SizedBox(width: 4),
                ]),
                Flexible(
                  child: Text(
                    item.reviewerNames.join(', '),
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],

            // ── Dates + comments row ─────────────────────────────────────
            const SizedBox(height: 6),
            Row(children: [
              if (item.date != null) _DeadlineChip(item: item),
              if (item.date != null && item.endDate != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('–', style: TextStyle(fontSize: 10, color: _kMuted)),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_outlined, size: 11, color: _kMuted),
                  const SizedBox(width: 3),
                  Text(_fmtDate(item.endDate!),
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                ]),
              ],
              const Spacer(),
              if (item.comments.isNotEmpty)
                _MetaChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  text: '${item.comments.length}',
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable: Panel section label + icon ─────────────────────────────────────

class _PanelRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Widget   child;
  const _PanelRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: _kMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: _kMuted)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ─── Reusable: Comment bubble ─────────────────────────────────────────────────

class _ActivityLogEntry extends StatelessWidget {
  final String text;
  const _ActivityLogEntry({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE8ECF3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(text,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ),
        const Expanded(child: Divider(color: Color(0xFFE8ECF3))),
      ]),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final String text;
  final String? author;
  const _CommentBubble({required this.text, this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:        _kBg,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (author != null && author!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(author!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kMuted)),
            ),
          Text(text,
              style: const TextStyle(fontSize: 12, color: _kPrimary, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Task detail panel ────────────────────────────────────────────────────────

class _TaskDetailPanel extends StatefulWidget {
  final TaskItem     item;
  final VoidCallback onClose;
  final VoidCallback onChanged;
  final VoidCallback? onDeleted;
  final List<SelectOption> typeOptions;
  final List<Map<String, dynamic>> users;
  final String? currentUserId;

  const _TaskDetailPanel({
    super.key,
    required this.item,
    required this.onClose,
    required this.onChanged,
    this.onDeleted,
    this.typeOptions    = const [],
    this.users          = const [],
    this.currentUserId,
  });

  @override
  State<_TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends State<_TaskDetailPanel> {
  late final _titleCtrl   = TextEditingController(text: widget.item.title);
  late final _descCtrl    = TextEditingController(text: widget.item.description);
  final _commentCtrl      = TextEditingController();
  final _dateRowKey       = GlobalKey();
  OverlayEntry? _dateOverlay;
  // Snapshot of date values taken when the picker opens — used to skip the
  // save if the user closes without actually changing anything.
  DateTime? _pickerOpenDate;
  DateTime? _pickerOpenEndDate;
  bool _dateDirty = false;
  Timer? _debounce;
  Timer? _personDebounce;
  Timer? _reviewerDebounce;

  late final List<SelectOption> _typeOpts = List<SelectOption>.from(widget.typeOptions);

  // Build SelectOption list for the user pickers (Person / Captain) using
  // the same color mapping the New Task dialog uses.
  List<SelectOption> get _userOpts => widget.users.map((u) => SelectOption(
        id:    u['id'] as String,
        name:  u['name'] as String,
        color: _userColor(u['color'] as String? ?? 'gray'),
      )).toList();

  static SelectOptionColor _userColor(String c) => switch (c) {
    'purple' => SelectOptionColor.purple,
    'pink'   => SelectOptionColor.pink,
    'blue'   => SelectOptionColor.blue,
    'green'  => SelectOptionColor.green,
    'orange' => SelectOptionColor.orange,
    'red'    => SelectOptionColor.pink,
    'yellow' => SelectOptionColor.orange,
    _        => SelectOptionColor.gray,
  };

  // Comments loaded from API
  List<Map<String, dynamic>> _comments    = [];
  bool                       _loadingComments = false;
  bool                       _postingComment  = false;

  // Cached so _closeDateOverlay can fire during dispose() without touching
  // a deactivated context (which would throw _dependents.isEmpty assertion).
  late final ApiClient _panelApi;

  @override
  void initState() {
    super.initState();
    _panelApi = context.read<ApiClient>();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final id = widget.item.backendId;
    if (id == null) return;
    setState(() => _loadingComments = true);
    try {
      final res = await _panelApi.getTaskComments(id);
      if (mounted) {
        setState(() {
          _comments = (res.data as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // keep empty on error
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _personDebounce?.cancel();
    _reviewerDebounce?.cancel();
    _closeDateOverlay();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // Save immediately. After the update, re-sync the in-memory TaskItem from
  // the server's response so the UI always reflects the persisted truth
  // (e.g. multi-assignee/multi-type arrays the backend may dedupe or reorder).
  Future<void> _saveField(Map<String, dynamic> data) async {
    final id = widget.item.backendId;
    if (id == null) return;
    try {
      final res = await _panelApi.updateTask(id, data);
      if (!mounted) return;
      final json = res.data;
      if (json is Map<String, dynamic>) {
        _syncFromJson(json);
      }
    } catch (_) {
      // silent — user sees their change; they can retry if needed
    }
  }

  /// Patch the existing TaskItem with fresh server data without replacing
  /// the instance (the parent kanban references the same object).
  void _syncFromJson(Map<String, dynamic> json) {
    final fresh = TaskItem.fromJson(json);
    setState(() {
      final item = widget.item;
      item.title          = fresh.title;
      item.description    = fresh.description;
      item.personIds      = fresh.personIds;
      item.assigneeNames  = fresh.assigneeNames;
      item.reviewerIds    = fresh.reviewerIds;
      item.reviewerNames  = fresh.reviewerNames;
      item.priority       = fresh.priority;
      item.status         = fresh.status;
      item.date           = fresh.date;
      item.endDate        = fresh.endDate;
      item.typeIds        = fresh.typeIds;
      item.types          = fresh.types;
      item.isDone         = fresh.isDone;
      item.columnGroup    = fresh.columnGroup;
      item.isPaused       = fresh.isPaused;
      item.pendingPauseRequest = fresh.pendingPauseRequest;
    });
    widget.onChanged();
  }

  // Save after 600 ms of inactivity (for text fields)
  void _saveLater(Map<String, dynamic> data) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _saveField(data));
  }

  Future<void> _confirmDelete() async {
    final id = widget.item.backendId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Delete task?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${widget.item.title}"? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _panelApi.deleteTasks([id]);
      widget.onDeleted?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete task')),
        );
      }
    }
  }

  // Build the status action widget:
  //   not_completed → "Submit for Review" button (assignee only)
  //   reviewer      → captain sees "Mark as Complete" button; assignee sees "In Review" pill
  //   completed     → green completed pill
  Widget _buildStatusAction(TaskItem item) {
    final isReviewer = widget.currentUserId != null &&
        item.reviewerIds.contains(widget.currentUserId);

    switch (item.status) {
      case 'reviewer':
        if (isReviewer) {
          // Captain sees "Mark as Complete" button
          return Material(
            color:        _kDone,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _markComplete,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Mark as Complete',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
          );
        }
        // Assignee sees "In Review" pill
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        const Color(0xFFFFF7E8),
            borderRadius: BorderRadius.circular(4),
            border:       Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFF59E0B)),
            SizedBox(width: 4),
            Text('In Review',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
          ]),
        );

      case 'completed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        const Color(0xFFE8FFF0),
            borderRadius: BorderRadius.circular(4),
            border:       Border.all(color: _kDone),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.check_circle_rounded, size: 12, color: _kDone),
            SizedBox(width: 4),
            Text('Completed',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kDone)),
          ]),
        );

      default:
        // not_completed → show Submit button (assignee)
        return Material(
          color:        _kAccent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _submitForReview,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.send_rounded, size: 12, color: Colors.white),
                SizedBox(width: 6),
                Text('Submit for Review',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        );
    }
  }

  Future<void> _submitForReview() async {
    final item = widget.item;
    final api = _panelApi;
    final messenger = ScaffoldMessenger.of(context);

    // Optimistic update
    setState(() => item.status = 'reviewer');
    try {
      await api.changeTaskStatus(item.id, 'reviewer');
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => item.status = 'not_completed');
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to submit for review')),
      );
    }
  }

  Future<void> _markComplete() async {
    final item  = widget.item;
    final api   = _panelApi;
    final messenger = ScaffoldMessenger.of(context);

    // Optimistic update
    setState(() {
      item.status = 'completed';
      item.isDone = true;
    });
    try {
      await api.changeTaskStatus(item.id, 'completed');
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item.status = 'reviewer';
        item.isDone = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to mark task as complete')),
      );
    }
  }

  Widget _buildPauseResumeButton(TaskItem item) {
    if (item.isPaused) {
      return Material(
        color:        const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _resumeTask,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
              SizedBox(width: 6),
              Text('Resume', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      );
    }
    final req            = item.pendingPauseRequest;
    final currentUserId  = widget.currentUserId;
    final isReviewer     = item.reviewerId != null && item.reviewerId == currentUserId;

    if (req != null) {
      if (isReviewer) {
        // Reviewer sees Approve / Deny buttons
        final reqId = req['id'] as String;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton(
            onPressed: () => _reviewPauseRequest(reqId, 'denied'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAccent,
              side: const BorderSide(color: _kAccent),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Deny Pause', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => _reviewPauseRequest(reqId, 'approved'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Approve Pause', style: TextStyle(fontSize: 11)),
          ),
        ]);
      }
      // Assignee — show locked "Pause Requested" pill
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFF59E0B)),
          SizedBox(width: 6),
          Text('Pause Requested',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
        ]),
      );
    }
    // No pending request — show Pause button for assignee
    return Material(
      color:        const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _showPauseDialog,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.pause_rounded, size: 12, color: Color(0xFF6B7280)),
            SizedBox(width: 6),
            Text('Pause', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ]),
        ),
      ),
    );
  }

  Future<void> _reviewPauseRequest(String requestId, String status) async {
    final item = widget.item;
    try {
      await _panelApi.reviewPauseRequest(requestId, status);
      setState(() {
        item.pendingPauseRequest = null;
        if (status == 'approved') item.isPaused = true;
      });
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $status pause request')),
      );
    }
  }

  Future<void> _showPauseDialog() async {
    String selectedReason = 'blocked';
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Pause Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reason', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'priority_shift', child: Text('Priority Shift', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'blocked',        child: Text('Blocked',        style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'need_info',      child: Text('Need Info',      style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'other',          child: Text('Other',          style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) { if (v != null) setDlg(() => selectedReason = v); },
              ),
              const SizedBox(height: 12),
              const Text('Note (optional)', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. waiting for design files…',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pause')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = _panelApi;
    final item = widget.item;
    final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
    noteCtrl.dispose();
    setState(() => item.pendingPauseRequest = {'id': '', 'reason': selectedReason});
    try {
      final res = await api.pauseTask(item.backendId!, selectedReason, note: note);
      // Update with real request id from response if available
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() => item.pendingPauseRequest = data);
      }
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pause request sent — waiting for reviewer approval')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => item.pendingPauseRequest = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send pause request')));
    }
  }

  Future<void> _resumeTask() async {
    final api = _panelApi;
    final item = widget.item;
    setState(() => item.isPaused = false);
    try {
      await api.resumeTask(item.backendId!);
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => item.isPaused = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resume task')));
    }
  }

  Widget _buildMoveToIdeaButton(TaskItem item) {
    return Material(
      color:        const Color(0xFFF5F3FF),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showMoveToIdeaDialog(item),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lightbulb_outline_rounded, size: 12, color: Color(0xFF8B5CF6)),
            SizedBox(width: 6),
            Text('Move to Idea',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
          ]),
        ),
      ),
    );
  }

  Future<void> _showMoveToIdeaDialog(TaskItem item) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Idea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Explain why this task should move to the idea stage. A reviewer will approve or deny your request.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text('Reason', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Less relevant after the pivot…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send Request')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }
    try {
      final res = await _panelApi.requestIdeaMove(item.backendId!, reason);
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      final used      = data['moves_used_this_month'] as int? ?? 0;
      final remaining = data['moves_remaining'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent — $used/3 moves used this month, $remaining remaining')),
      );
    } catch (e) {
      if (!mounted) return;
      // Extract the backend's actual error message from {error: "..."}
      String msg = 'Failed to send idea request';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] is String) {
          msg = data['error'] as String;
        } else if (e.response?.statusCode == 403) {
          msg = 'You do not have permission to move this task to ideas';
        } else if (e.response?.statusCode == 429) {
          msg = 'Monthly idea-move quota exceeded (3/3)';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _openDateOverlay() {
    final item = widget.item;
    if (_dateOverlay != null) { _closeDateOverlay(); return; }
    // Snapshot the current dates so we can skip the save if nothing changes.
    _pickerOpenDate    = item.date;
    _pickerOpenEndDate = item.endDate;
    final rb = _dateRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos  = rb.localToGlobal(Offset.zero);
    final size = rb.size;

    _dateOverlay = OverlayEntry(builder: (_) => _DatePickerOverlay(
      anchorPos:   Offset(pos.dx, pos.dy + size.height + 4),
      anchorRight: pos.dx + size.width,
      selected:    item.date,
      endDate:     item.endDate,
      onClose:     _closeDateOverlay,
      onSelect: (d) {
        setState(() { item.date = d; item.endDate = null; _dateDirty = true; });
        widget.onChanged();
        _dateOverlay?.markNeedsBuild();
      },
      onEndSelect: (d) {
        setState(() { item.endDate = d; _dateDirty = true; });
        widget.onChanged();
        _dateOverlay?.markNeedsBuild();
      },
      onEndDateClear: () {
        setState(() { item.endDate = null; _dateDirty = true; });
        widget.onChanged();
        _dateOverlay?.markNeedsBuild();
      },
    ));
    Overlay.of(context).insert(_dateOverlay!);
    setState(() {}); // update arrow icon
  }

  void _closeDateOverlay() {
    _dateOverlay?.remove();
    _dateOverlay?.dispose();
    _dateOverlay = null;
    // Save exactly once when the picker closes — covers both explicit close
    // (tap outside / X) and modal dismiss (dispose → _closeDateOverlay).
    if (_dateDirty) {
      _dateDirty = false;
      final item = widget.item;
      final dateChanged   = item.date    != _pickerOpenDate;
      final endDateChanged = item.endDate != _pickerOpenEndDate;
      if (dateChanged || endDateChanged) {
        final id = item.backendId;
        if (id != null) {
          _panelApi.updateTask(id, {
            'date':     item.date?.toIso8601String().substring(0, 10),
            'end_date': item.endDate?.toIso8601String().substring(0, 10),
          });
        }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Column(
      mainAxisSize:        MainAxisSize.min,
      crossAxisAlignment:  CrossAxisAlignment.start,
      children: [
        // ── Header button row (delete only) ──────────────────────────────
        if (widget.item.backendId != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap:        _confirmDelete,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width:  28, height: 28,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                ),
              ),
            ),
          ),

        // ── Body ────────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title (editable, header size) ──────────────────────────
                TextField(
                  controller: _titleCtrl,
                  style:      const TextStyle(
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      _kPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText:  'Untitled',
                    hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                        color: Color(0xFFD1D5DB)),
                    border:    InputBorder.none,
                    isDense:   true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    item.title = v;
                    widget.onChanged();
                    _saveLater({'title': v});
                  },
                ),
                const SizedBox(height: 4),

                // ── Description (editable, normal size) ────────────────────
                TextField(
                  controller: _descCtrl,
                  maxLines:   null,
                  style:      const TextStyle(
                    fontSize: 13,
                    height:   1.5,
                    color:    Color(0xFF4B5563),
                  ),
                  decoration: const InputDecoration(
                    hintText:  'Add a description…',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
                    border:    InputBorder.none,
                    isDense:   true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    item.description = v;
                    widget.onChanged();
                    _saveLater({'description': v});
                  },
                ),

                const Divider(height: 28, color: _kBorder),

                // ── Status row: shows current state + submit-for-review button ───
                _PanelRow(
                  icon:  Icons.check_circle_outline_rounded,
                  label: 'Status',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildStatusAction(item),
                      if (item.status != 'completed' && item.status != 'idea' &&
                          (item.isPaused || item.pendingPauseRequest != null ||
                           item.personId == widget.currentUserId ||
                           item.reviewerId == widget.currentUserId))
                        _buildPauseResumeButton(item),
                      if (item.status == 'not_completed' &&
                          item.createdBy != null &&
                          item.createdBy == widget.currentUserId)
                        _buildMoveToIdeaButton(item),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Priority ───────────────────────────────────────────────
                _PanelRow(
                  icon:  Icons.flag_outlined,
                  label: 'Priority',
                  child: DropdownButton<Priority>(
                    value:      item.priority,
                    isDense:    true,
                    underline:  const SizedBox(),
                    style:      const TextStyle(fontSize: 12, color: _kPrimary),
                    items: Priority.values.map((p) => DropdownMenuItem(
                      value: p,
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: p.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(p.label, style: const TextStyle(fontSize: 12)),
                      ]),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null && v != item.priority) {
                        setState(() => item.priority = v);
                        widget.onChanged();
                        _saveField({'priority': v.apiValue});
                      }
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Due date ───────────────────────────────────────────────
                KeyedSubtree(
                  key: _dateRowKey,
                  child: _PanelRow(
                    icon:  Icons.calendar_today_outlined,
                    label: 'Date',
                    child: GestureDetector(
                      onTap: _openDateOverlay,
                      child: Row(children: [
                        Text(
                          item.date == null
                              ? 'Set date'
                              : item.endDate != null
                                  ? '${_fmtDate(item.date!)}  →  ${_fmtDate(item.endDate!)}'
                                  : _fmtDate(item.date!),
                          style: TextStyle(
                              fontSize: 12,
                              color: item.date == null ? _kMuted : _kPrimary),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _dateOverlay != null
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 14, color: _kMuted,
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Person (Assignee) — multi-select ──────────────────────
                SelectOptionField(
                  label:           'Person',
                  options:         _userOpts,
                  selectedOptions: item.personIds,
                  onOptionSelected: (id) {
                    setState(() {
                      if (item.personIds.contains(id)) {
                        final idx = item.personIds.indexOf(id);
                        item.personIds.removeAt(idx);
                        if (idx < item.assigneeNames.length) {
                          item.assigneeNames.removeAt(idx);
                        }
                      } else {
                        final u = widget.users.firstWhere(
                          (x) => x['id'] == id,
                          orElse: () => const {},
                        );
                        item.personIds.add(id);
                        item.assigneeNames.add((u['name'] as String?) ?? '');
                      }
                    });
                    // Debounce: wait for user to finish selecting before
                    // sending. One API call = one task_updated socket broadcast.
                    _personDebounce?.cancel();
                    _personDebounce = Timer(const Duration(milliseconds: 600), () {
                      _saveField({'person_ids': List.from(item.personIds)});
                    });
                  },
                  onOptionCreated: (_) {},
                ),
                const SizedBox(height: 14),

                // ── Reviewer (Captain) — multi-select ─────────────────────
                SelectOptionField(
                  label:           'Captain',
                  options:         _userOpts,
                  selectedOptions: item.reviewerIds,
                  onOptionSelected: (id) {
                    setState(() {
                      if (item.reviewerIds.contains(id)) {
                        final idx = item.reviewerIds.indexOf(id);
                        item.reviewerIds.removeAt(idx);
                        if (idx < item.reviewerNames.length) {
                          item.reviewerNames.removeAt(idx);
                        }
                      } else {
                        final u = widget.users.firstWhere(
                          (x) => x['id'] == id,
                          orElse: () => const {},
                        );
                        item.reviewerIds.add(id);
                        item.reviewerNames.add((u['name'] as String?) ?? '');
                      }
                    });
                    _reviewerDebounce?.cancel();
                    _reviewerDebounce = Timer(const Duration(milliseconds: 600), () {
                      _saveField({'reviewer_ids': List.from(item.reviewerIds)});
                    });
                  },
                  onOptionCreated: (_) {},
                ),
                const SizedBox(height: 14),

                // ── Type — multi-select ───────────────────────────────────
                SelectOptionField(
                  label:           'Type',
                  options:         _typeOpts,
                  selectedOptions: item.typeIds,
                  onOptionSelected: (id) {
                    setState(() {
                      if (item.typeIds.contains(id)) {
                        // Toggle off
                        item.typeIds.remove(id);
                        item.types.removeWhere((t) => t['id'] == id);
                      } else {
                        // Toggle on
                        final opt = _typeOpts.firstWhere(
                          (o) => o.id == id,
                          orElse: () => _typeOpts.first,
                        );
                        item.typeIds.add(id);
                        item.types.add({
                          'id':    opt.id,
                          'name':  opt.name,
                        });
                      }
                    });
                    widget.onChanged();
                    _saveField({'type_ids': item.typeIds});
                  },
                  onOptionCreated: (name) async {
                    // Persist new type to backend, then assign it to this task
                    try {
                      final res = await _panelApi.createTaskType({
                        'name':  name,
                        'color': 'gray',
                      });
                      if (!mounted) return;
                      final created = res.data as Map<String, dynamic>;
                      final newOpt = SelectOption(
                        id:    created['id'] as String,
                        name:  created['name'] as String,
                        color: SelectOptionColor.gray,
                      );
                      setState(() {
                        _typeOpts.add(newOpt);
                        item.typeIds.add(newOpt.id);
                        item.types.add({
                          'id':    newOpt.id,
                          'name':  newOpt.name,
                          'color': 'gray',
                        });
                      });
                      widget.onChanged();
                      _saveField({'type_ids': item.typeIds});
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to create type')),
                        );
                      }
                    }
                  },
                  onOptionRenamed: (id, name) {
                    setState(() {
                      final i = _typeOpts.indexWhere((o) => o.id == id);
                      if (i != -1) {
                        _typeOpts[i] = _typeOpts[i].copyWith(name: name);
                      }
                      for (final t in item.types) {
                        if (t['id'] == id) t['name'] = name;
                      }
                    });
                    widget.onChanged();
                  },
                  onOptionColorChanged: (id, color) {
                    setState(() {
                      final i = _typeOpts.indexWhere((o) => o.id == id);
                      if (i != -1) _typeOpts[i] = _typeOpts[i].copyWith(color: color);
                    });
                  },
                ),

                const Divider(height: 28, color: _kBorder),

                // ── Comments ───────────────────────────────────────────────
                Row(children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 14, color: _kMuted),
                  const SizedBox(width: 6),
                  const Text('Comments',
                      style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color:      _kPrimary)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color:        _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: _kBorder),
                    ),
                    child: Text('${_comments.length}',
                        style: const TextStyle(fontSize: 10, color: _kMuted)),
                  ),
                ]),
                const SizedBox(height: 10),
                if (_loadingComments)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ))
                else if (_comments.isEmpty)
                  const Text('No comments yet',
                      style: TextStyle(fontSize: 12, color: _kMuted))
                else
                  ..._comments.map((c) {
                    final isSystem = c['is_system'] as bool? ?? false;
                    if (isSystem) {
                      return _ActivityLogEntry(text: c['text'] as String? ?? '');
                    }
                    return _CommentBubble(
                      text:   c['text'] as String? ?? '',
                      author: c['user_name'] as String?,
                    );
                  }),
                const SizedBox(height: 10),
                // Add comment
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style:      const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText:  'Add a comment…',
                        hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                        isDense:   true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _kBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _kBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _kAccent)),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _postingComment ? null : _addComment,
                    child: Container(
                      width:  32, height: 32,
                      decoration: BoxDecoration(
                        color:        _postingComment ? _kMuted : _kAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _postingComment
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              size: 14, color: Colors.white),
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

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _postingComment) return;
    final backendId = widget.item.backendId;
    if (backendId == null) return;

    setState(() => _postingComment = true);
    _commentCtrl.clear();
    try {
      final res = await _panelApi.addTaskComment(backendId, text);
      final comment = res.data as Map<String, dynamic>;
      if (mounted) setState(() => _comments.add(comment));
    } catch (_) {
      // restore text so user can retry
      if (mounted) {
        _commentCtrl.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }
}

// ─── Shared date formatter ────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

String _fmtDateLong(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

// ─── Pending requests panel (pause + idea) ────────────────────────────────────

class _RequestsPanel extends StatefulWidget {
  final ApiClient    api;
  final VoidCallback onClose;
  const _RequestsPanel({required this.api, required this.onClose});

  @override
  State<_RequestsPanel> createState() => _RequestsPanelState();
}

class _RequestsPanelState extends State<_RequestsPanel> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _loadingPause = true;
  bool _loadingIdea  = true;
  List<Map<String, dynamic>> _pauseRequests = [];
  List<Map<String, dynamic>> _ideaRequests  = [];

  @override
  void initState() {
    super.initState();
    _loadPause();
    _loadIdea();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadPause() async {
    setState(() => _loadingPause = true);
    try {
      final res = await widget.api.getPauseRequests(status: 'pending');
      _pauseRequests = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) { _pauseRequests = []; }
    if (mounted) setState(() => _loadingPause = false);
  }

  Future<void> _loadIdea() async {
    setState(() => _loadingIdea = true);
    try {
      final res = await widget.api.getIdeaRequests(status: 'pending');
      _ideaRequests = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) { _ideaRequests = []; }
    if (mounted) setState(() => _loadingIdea = false);
  }

  Future<void> _reviewPause(String id, String status) async {
    try {
      await widget.api.reviewPauseRequest(id, status);
      _loadPause();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $status pause request')),
        );
      }
    }
  }

  Future<void> _reviewIdea(String id, String status) async {
    try {
      await widget.api.reviewIdeaRequest(id, status);
      _loadIdea();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $status idea request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
          child: Row(children: [
            const Icon(Icons.inbox_rounded, size: 16, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            const Text('Pending Requests',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kPrimary)),
            const Spacer(),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, size: 16, color: _kMuted),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ]),
        ),
        TabBar(
          controller: _tab,
          labelStyle:         const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          indicatorColor: const Color(0xFF6366F1),
          labelColor:     const Color(0xFF6366F1),
          unselectedLabelColor: _kMuted,
          tabs: const [Tab(text: 'Pause'), Tab(text: 'Idea Move')],
        ),
        const Divider(height: 1, color: _kBorder),
        Flexible(
          child: TabBarView(
            controller: _tab,
            children: [
              _requestList(
                loading:  _loadingPause,
                items:    _pauseRequests,
                titleKey: 'task_title',
                subtitleBuilder: (r) =>
                    'By ${r['requested_by_name'] ?? ''} — ${r['reason'] ?? ''}',
                onApprove: (id) => _reviewPause(id, 'approved'),
                onDeny:    (id) => _reviewPause(id, 'denied'),
              ),
              _requestList(
                loading:  _loadingIdea,
                items:    _ideaRequests,
                titleKey: 'task_title',
                subtitleBuilder: (r) =>
                    'By ${r['requested_by_name'] ?? ''} — ${r['reason'] ?? ''}',
                onApprove: (id) => _reviewIdea(id, 'approved'),
                onDeny:    (id) => _reviewIdea(id, 'denied'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _requestList({
    required bool loading,
    required List<Map<String, dynamic>> items,
    required String titleKey,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required void Function(String) onApprove,
    required void Function(String) onDeny,
  }) {
    if (loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    if (items.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No pending requests', style: TextStyle(fontSize: 13, color: _kMuted)),
      ));
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: _kBorder),
      itemBuilder: (_, i) {
        final r  = items[i];
        final id = r['id'] as String;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r[titleKey] as String? ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitleBuilder(r),
                      style: const TextStyle(fontSize: 11, color: _kMuted),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => onDeny(id),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kAccent,
                side: const BorderSide(color: _kAccent),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Deny', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => onApprove(id),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 12)),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Stagnant tasks panel ─────────────────────────────────────────────────────

class _StagnantPanel extends StatefulWidget {
  final ApiClient                        api;
  final VoidCallback                     onClose;
  final void Function(TaskItem task)     onTaskTap;
  const _StagnantPanel({required this.api, required this.onClose, required this.onTaskTap});

  @override
  State<_StagnantPanel> createState() => _StagnantPanelState();
}

class _StagnantPanelState extends State<_StagnantPanel> {
  bool   _loading = true;
  String _filter  = '';   // '' | 'at_risk' | 'stagnant' | 'dead'
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res  = await widget.api.getStagnantTasks(health: _filter.isEmpty ? null : _filter);
      _tasks = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      _tasks = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _healthColor(String? h) => switch (h) {
    'at_risk'  => const Color(0xFFF59E0B),
    'stagnant' => const Color(0xFFF97316),
    'dead'     => const Color(0xFFEF4444),
    _          => const Color(0xFF9CA3AF),
  };

  String _healthLabel(String? h) => switch (h) {
    'at_risk'  => 'At Risk',
    'stagnant' => 'Stagnant',
    'dead'     => 'Dead',
    _          => h ?? '',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF97316)),
            const SizedBox(width: 8),
            const Text('Stagnant Tasks',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kPrimary)),
            const Spacer(),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, size: 16, color: _kMuted),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ]),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            for (final f in [('', 'All'), ('at_risk', 'At Risk'), ('stagnant', 'Stagnant'), ('dead', 'Dead')])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(f.$2, style: const TextStyle(fontSize: 11)),
                  selected: _filter == f.$1,
                  onSelected: (_) { setState(() => _filter = f.$1); _load(); },
                  selectedColor: _filter == f.$1 ? const Color(0xFFF97316) : null,
                  labelStyle: TextStyle(
                    color: _filter == f.$1 ? Colors.white : _kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ]),
        ),
        const Divider(height: 1, color: _kBorder),
        // List
        Flexible(
          child: _loading
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              : _tasks.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No stagnant tasks 🎉',
                          style: TextStyle(fontSize: 13, color: _kMuted)),
                    ))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _tasks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: _kBorder),
                      itemBuilder: (_, i) {
                        final t = _tasks[i];
                        final health   = t['health'] as String?;
                        final days     = t['days_inactive'] as int? ?? 0;
                        final assignees = (t['assignees'] as List?)
                            ?.cast<Map<String, dynamic>>()
                            .map((a) => a['name'] as String)
                            .join(', ') ?? '';
                        final color = _healthColor(health);
                        return ListTile(
                          dense: true,
                          onTap: () {
                            final item = TaskItem.fromJson(t);
                            widget.onTaskTap(item);
                          },
                          title: Text(t['title'] as String? ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary)),
                          subtitle: assignees.isNotEmpty
                              ? Text(assignees, style: const TextStyle(fontSize: 11, color: _kMuted))
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_healthLabel(health),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                              ),
                              const SizedBox(height: 2),
                              Text('$days days',
                                  style: const TextStyle(fontSize: 10, color: _kMuted)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── Date picker overlay ──────────────────────────────────────────────────────
// Positioned below the due-date row as a floating card (same pattern as
// SelectOptionField dropdown). Barrier tap closes it.

class _DatePickerOverlay extends StatelessWidget {
  final Offset              anchorPos;
  final double              anchorRight;
  final DateTime?           selected;
  final DateTime?           endDate;
  final VoidCallback        onClose;
  final ValueChanged<DateTime>  onSelect;
  final ValueChanged<DateTime>? onEndSelect;
  final VoidCallback?           onEndDateClear;

  const _DatePickerOverlay({
    required this.anchorPos,
    required this.anchorRight,
    required this.onClose,
    required this.onSelect,
    this.selected,
    this.endDate,
    this.onEndSelect,
    this.onEndDateClear,
  });

  @override
  Widget build(BuildContext context) {
    const popupW  = 280.0;
    final screenW = MediaQuery.of(context).size.width;
    double left   = anchorPos.dx;
    if (left + popupW > screenW - 8) {
      left = anchorRight - popupW;
    }
    left = left.clamp(8.0, screenW - popupW - 8);

    // Clamp vertically so the calendar doesn't go off the bottom
    final screenH = MediaQuery.of(context).size.height;
    const calH    = 320.0;
    final top     = (anchorPos.dy + calH > screenH - 8)
        ? screenH - calH - 8
        : anchorPos.dy;

    return Stack(children: [
      // Barrier
      Positioned.fill(
        child: GestureDetector(
          onTap:    onClose,
          behavior: HitTestBehavior.opaque,
        ),
      ),
      // Calendar card
      Positioned(
        left: left,
        top:  top,
        child: GestureDetector(
          onTap:    () {},
          behavior: HitTestBehavior.opaque,
          child: Material(
            color:        Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: popupW,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color:      Colors.black12,
                    blurRadius: 8,
                    offset:     Offset(0, 4),
                  ),
                ],
              ),
              child: _InlineDatePicker(
                selected:       selected,
                endDate:        endDate,
                onSelect:       onSelect,
                onEndSelect:    onEndSelect,
                onEndDateClear: onEndDateClear,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── Inline date picker ───────────────────────────────────────────────────────
// Shown inside the detail panel when the due-date row is tapped.
// Matches the calendar UI in the screenshot: date display pill, month nav,
// day grid with a blue circle for the selected day, and an End date toggle.

class _InlineDatePicker extends StatefulWidget {
  final DateTime?               selected;       // start / single date
  final DateTime?               endDate;        // range end (null = single-date mode)
  final ValueChanged<DateTime>  onSelect;       // start date chosen
  final ValueChanged<DateTime>? onEndSelect;    // end date chosen
  final VoidCallback?           onEndDateClear; // end date tapped again → clear it

  const _InlineDatePicker({
    this.selected,
    this.endDate,
    required this.onSelect,
    this.onEndSelect,
    this.onEndDateClear,
  });

  @override
  State<_InlineDatePicker> createState() => _InlineDatePickerState();
}

class _InlineDatePickerState extends State<_InlineDatePicker> {
  late DateTime _viewing; // first day of the month being shown

  @override
  void initState() {
    super.initState();
    final base = widget.selected ?? DateTime.now();
    _viewing = DateTime(base.year, base.month);
  }

  void _prev() => setState(
      () => _viewing = DateTime(_viewing.year, _viewing.month - 1));
  void _next() => setState(
      () => _viewing = DateTime(_viewing.year, _viewing.month + 1));

  @override
  Widget build(BuildContext context) {
    final today    = DateTime.now();
    final selected = widget.selected;
    final endDate  = widget.endDate;

    // ── Build flat list of 42 date cells (6 weeks × 7 days) ─────────────────
    // Dart weekday: Mon=1 … Sun=7. We want Sun=0 … Sat=6, so (weekday % 7).
    final firstDay    = DateTime(_viewing.year, _viewing.month);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(_viewing.year, _viewing.month + 1, 0).day;
    final prevTotal   = DateTime(_viewing.year, _viewing.month, 0).day;

    final cells = <({DateTime date, bool current})>[];
    // Previous month tail
    for (int i = startOffset - 1; i >= 0; i--) {
      cells.add((
        date:    DateTime(_viewing.year, _viewing.month - 1, prevTotal - i),
        current: false,
      ));
    }
    // Current month
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add((date: DateTime(_viewing.year, _viewing.month, d), current: true));
    }
    // Next month head
    var nextDay = 1;
    while (cells.length < 42) {
      cells.add((
        date:    DateTime(_viewing.year, _viewing.month + 1, nextDay++),
        current: false,
      ));
    }

    const monthNames = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    const dayLabels = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              children: [
                // ── Selected date display pill (like the text input in screenshot)
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color:        _kBg,
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: _kBorder),
                  ),
                  child: Text(
                    selected == null ? 'No date selected' : _fmtDateLong(selected),
                    style: const TextStyle(fontSize: 13, color: _kPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                // ── Month / year + nav arrows ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${monthNames[_viewing.month - 1]} ${_viewing.year}',
                      style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      _kPrimary),
                    ),
                    Row(children: [
                      _CalNavBtn(icon: Icons.chevron_left,  onTap: _prev),
                      const SizedBox(width: 4),
                      _CalNavBtn(icon: Icons.chevron_right, onTap: _next),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Day-of-week header row ────────────────────────────────────
                Row(
                  children: dayLabels.map((label) => Expanded(
                    child: Center(
                      child: Text(label,
                          style: const TextStyle(
                              fontSize:   11,
                              fontWeight: FontWeight.w500,
                              color:      _kMuted)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 4),
                // ── 6 week rows ───────────────────────────────────────────────
                ...List.generate(6, (row) {
                  final week = cells.sublist(row * 7, row * 7 + 7);
                  // Skip 6th row if it's all next-month overflow
                  if (row == 5 && week.every((c) => !c.current)) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    children: week.map((cell) {
                      final d = cell.date;

                      final isStart = selected != null &&
                          d.year == selected.year &&
                          d.month == selected.month &&
                          d.day   == selected.day;

                      final isEnd = endDate != null &&
                          d.year  == endDate.year &&
                          d.month == endDate.month &&
                          d.day   == endDate.day;

                      final isInRange = selected != null &&
                          endDate  != null &&
                          d.isAfter(selected) &&
                          d.isBefore(endDate);

                      final isHighlighted = isStart || isEnd;

                      final isToday = d.year  == today.year &&
                          d.month == today.month &&
                          d.day   == today.day;

                      // Tap logic (no toggle needed):
                      //  • No start → set start
                      //  • Has start, no end, different date → set end
                      //  • Has start, no end, same as start → do nothing (single-date locked)
                      //  • Has end, tap end again → clear end
                      //  • Has end, tap other date → set new end
                      void onTap() {
                        if (selected == null) {
                          widget.onSelect(d);
                        } else if (endDate == null) {
                          if (!isStart) widget.onEndSelect?.call(d);
                        } else if (isEnd) {
                          widget.onEndDateClear?.call();
                        } else {
                          widget.onEndSelect?.call(d);
                        }
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: onTap,
                          child: Container(
                            height: 34,
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            // Range bar: light blue full-width background for
                            // interior days, connecting start → end visually.
                            color: isInRange
                                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                : null,
                            child: Center(
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isHighlighted
                                      ? const Color(0xFF2563EB)
                                      : null,
                                  border: isToday && !isHighlighted
                                      ? Border.all(
                                          color: const Color(0xFF2563EB),
                                          width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontSize:   12,
                                      fontWeight: isHighlighted
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isHighlighted
                                          ? Colors.white
                                          : isInRange
                                              ? const Color(0xFF1D4ED8)
                                              : cell.current
                                                  ? _kPrimary
                                                  : _kMuted.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          // Hint: tap a second date to set end; tap end date again to clear it
          if (endDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                'Tap the end date again to remove it',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Calendar nav button (< >) ────────────────────────────────────────────────

class _CalNavBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _CalNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  28, height: 28,
        decoration: BoxDecoration(
          color:        _kBg,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: _kBorder),
        ),
        child: Icon(icon, size: 16, color: _kPrimary),
      ),
    );
  }
}

// ─── User profile panel (right of kanban, admin only) ────────────────────────

class _UserProfilePanel extends StatelessWidget {
  final bool                  loading;
  final Map<String, dynamic>? data;
  final VoidCallback          onClose;
  final bool                  showClose;
  final VoidCallback?         onOverdueTap;

  const _UserProfilePanel({
    required this.loading,
    required this.data,
    required this.onClose,
    this.showClose    = true,
    this.onOverdueTap,
  });

  Color _gradeColor(double pct) {
    if (pct >= 75) return const Color(0xFF10B981);
    if (pct >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          : data == null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: _kMuted, size: 32),
                    const SizedBox(height: 8),
                    const Text('Failed to load profile',
                        style: TextStyle(fontSize: 12, color: _kMuted)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: onClose, child: const Text('Close')),
                  ]),
                )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final d = data!;
    final name       = d['user_name']             as String? ?? '–';
    final role       = d['role']                  as String? ?? '';
    final workload   = d['workload']              as Map<String, dynamic>? ?? {};
    final perf       = d['performance']           as Map<String, dynamic>? ?? {};
    final health     = d['health_breakdown']      as Map<String, dynamic>? ?? {};
    final recent     = (d['recent_completed']     as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pauseCount = d['pause_count_this_month'] as int?    ?? 0;
    final compRate   = (d['completion_rate']      as num?)?.toDouble() ?? 0;
    final totalAssigned = workload['total_assigned'] as int? ?? 0;
    final completed     = workload['completed']     as int? ?? 0;

    final avgDrift = (perf['avg_drift'] as num?)?.toDouble();
    final driftClr = avgDrift == null
        ? _kMuted
        : avgDrift <= 0
            ? const Color(0xFF10B981)
            : avgDrift <= 2
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);
    final driftLbl = avgDrift == null
        ? '–'
        : avgDrift == 0
            ? '0d'
            : avgDrift < 0
                ? '${avgDrift.toStringAsFixed(1)}d'
                : '+${avgDrift.toStringAsFixed(1)}d';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: name + close ────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _kPrimary),
                      overflow: TextOverflow.ellipsis),
                  if (role.isNotEmpty)
                    Text(role,
                        style: const TextStyle(fontSize: 11, color: _kMuted)),
                ],
              ),
            ),
            if (showClose)
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color:        _kBg,
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: _kBorder),
                  ),
                  child: const Icon(Icons.close, size: 12, color: _kMuted),
                ),
              ),
          ]),
          const SizedBox(height: 14),

          // ── Workload chips ──────────────────────────────────────────────
          Wrap(spacing: 6, runSpacing: 6, children: [
            _profileChip('${workload['not_completed'] ?? 0} Active',  const Color(0xFF6366F1)),
            _profileChip('${workload['in_review'] ?? 0} Review',      const Color(0xFFF59E0B)),
            _profileChip('${workload['completed'] ?? 0} Done',        const Color(0xFF10B981)),
            _profileChip('${workload['paused'] ?? 0} Paused',         const Color(0xFF9CA3AF)),
            if ((workload['idea'] as int? ?? 0) > 0)
              _profileChip('${workload['idea']} Ideas', const Color(0xFF8B5CF6)),
          ]),

          // ── Deadline warnings ───────────────────────────────────────────
          Builder(builder: (_) {
            final dl       = d['deadline_summary'] as Map<String, dynamic>?;
            final overdue  = dl?['overdue']  as int? ?? 0;
            final dueSoon  = dl?['due_soon'] as int? ?? 0;
            if (overdue == 0 && dueSoon == 0) return const SizedBox(height: 16);
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(spacing: 8, children: [
                if (overdue > 0)
                  _deadlineBadge(
                    icon:  Icons.warning_amber_rounded,
                    label: '$overdue Overdue',
                    color: const Color(0xFFEF4444),
                    onTap: onOverdueTap,
                  ),
                if (dueSoon > 0)
                  _deadlineBadge(
                    icon:  Icons.schedule_rounded,
                    label: '$dueSoon Due soon',
                    color: const Color(0xFFF59E0B),
                    onTap: null, // no backend filter yet
                  ),
              ]),
            );
          }),
          const SizedBox(height: 16),

          // ── Donut + completion rate ─────────────────────────────────────
          Center(
            child: SizedBox(
              width: 110, height: 110,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 110, height: 110,
                  child: CircularProgressIndicator(
                    value:           compRate / 100,
                    strokeWidth:     10,
                    backgroundColor: _kBorder,
                    color:           _gradeColor(compRate),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${compRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _gradeColor(compRate))),
                  Text('$completed/$totalAssigned done',
                      style: const TextStyle(fontSize: 10, color: _kMuted)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Performance charts ──────────────────────────────────────────
          const Text('PERFORMANCE',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _buildPerfBars(
            avgActual:  (perf['avg_actual_days']  as num?)?.toDouble(),
            avgPlanned: (perf['avg_planned_days'] as num?)?.toDouble(),
            driftLbl:   driftLbl,
            driftClr:   driftClr,
          ),
          const SizedBox(height: 14),
          _buildTimingChart(
            onTime: perf['on_time'] as int? ?? 0,
            late:   perf['late']    as int? ?? 0,
            early:  perf['early']   as int? ?? 0,
          ),
          const SizedBox(height: 16),

          // ── Active task health ──────────────────────────────────────────
          const Text('ACTIVE TASK HEALTH',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _buildHealthBars(health),
          const SizedBox(height: 14),

          // ── Pause discipline ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: pauseCount > 2
                  ? const Color(0xFFFFF7E8)
                  : _kBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: pauseCount > 2
                      ? const Color(0xFFF97316)
                      : _kBorder),
            ),
            child: Row(children: [
              Icon(Icons.pause_circle_outline_rounded,
                  size: 14,
                  color: pauseCount > 2
                      ? const Color(0xFFF97316)
                      : _kMuted),
              const SizedBox(width: 6),
              const Text('Paused this month: ',
                  style: TextStyle(fontSize: 11, color: _kPrimary)),
              Text('$pauseCount',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: pauseCount > 2
                          ? const Color(0xFFF97316)
                          : _kPrimary)),
            ]),
          ),

          if (recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('RECENT COMPLETED',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kMuted, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...recent.take(5).map((t) {
              final drift = (t['drift'] as num?)?.toDouble();
              final dClr  = drift == null
                  ? _kMuted
                  : drift <= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444);
              final dLbl = drift == null
                  ? '–'
                  : drift == 0
                      ? 'On time'
                      : drift < 0
                          ? '${drift.toStringAsFixed(0)}d early'
                          : '+${drift.toStringAsFixed(0)}d';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(width: 5, height: 5,
                      decoration: BoxDecoration(color: dClr, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t['title'] as String? ?? '–',
                        style: const TextStyle(fontSize: 11, color: _kPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${t['actual_days'] ?? '–'}d',
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                  const SizedBox(width: 8),
                  Text(dLbl,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: dClr)),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _deadlineBadge({
    required IconData      icon,
    required String        label,
    required Color         color,
    required VoidCallback? onTap,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w700,
                color:      color)),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 11, color: color),
        ],
      ]),
    );
    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }

  Widget _profileChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Performance: Planned vs Actual bars + drift ─────────────────────────

  Widget _buildPerfBars({
    required double? avgActual,
    required double? avgPlanned,
    required String  driftLbl,
    required Color   driftClr,
  }) {
    final maxVal = [avgActual ?? 0.0, avgPlanned ?? 0.0, 0.1]
        .reduce((a, b) => a > b ? a : b);
    final overBudget = avgActual != null && avgPlanned != null && avgActual > avgPlanned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _horizBar('Planned', avgPlanned, maxVal, const Color(0xFF6366F1)),
        const SizedBox(height: 8),
        _horizBar('Actual',  avgActual,  maxVal,
            overBudget ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Avg drift ',
              style: TextStyle(fontSize: 11, color: _kMuted)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        driftClr.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(driftLbl,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: driftClr)),
          ),
        ]),
      ],
    );
  }

  Widget _horizBar(String label, double? value, double maxVal, Color color) {
    final pct = (value == null || maxVal == 0)
        ? 0.0
        : (value / maxVal).clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(
        width: 50,
        child: Text(label, style: const TextStyle(fontSize: 10, color: _kMuted)),
      ),
      Expanded(
        child: LayoutBuilder(builder: (_, c) => Stack(children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(4)),
          ),
          Container(
            height: 8,
            width: c.maxWidth * pct,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4)),
          ),
        ])),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 36,
        child: Text(
          value != null ? '${value.toStringAsFixed(1)}d' : '–',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color),
          textAlign: TextAlign.right,
        ),
      ),
    ]);
  }

  // ── Timing donut: On Time / Late / Early ─────────────────────────────────

  Widget _buildTimingChart({
    required int onTime,
    required int late,
    required int early,
  }) {
    final total = onTime + late + early;
    if (total == 0) return const SizedBox.shrink();
    final td = total.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('COMPLETION TIMING',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _kMuted, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 90, height: 90,
            child: PieChart(PieChartData(
              sectionsSpace:      2,
              centerSpaceRadius:  26,
              sections: [
                if (onTime > 0) PieChartSectionData(
                    value: onTime.toDouble(),
                    color: const Color(0xFF10B981),
                    title: '', radius: 20),
                if (late > 0)   PieChartSectionData(
                    value: late.toDouble(),
                    color: const Color(0xFFEF4444),
                    title: '', radius: 20),
                if (early > 0)  PieChartSectionData(
                    value: early.toDouble(),
                    color: const Color(0xFF3B82F6),
                    title: '', radius: 20),
              ],
            )),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _timingRow('On time', onTime, td, const Color(0xFF10B981)),
              const SizedBox(height: 6),
              _timingRow('Late',    late,   td, const Color(0xFFEF4444)),
              const SizedBox(height: 6),
              _timingRow('Early',   early,  td, const Color(0xFF3B82F6)),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _timingRow(String label, int count, double total, Color color) {
    final pct = '${(count / total * 100).toStringAsFixed(0)}%';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$label ', style: const TextStyle(fontSize: 11, color: _kMuted)),
      Text('$count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      Text(' ($pct)',
          style: const TextStyle(fontSize: 10, color: _kMuted)),
    ]);
  }

  // ── Health: mini horizontal bars ─────────────────────────────────────────

  Widget _buildHealthBars(Map<String, dynamic> health) {
    final items = [
      ('Active',   health['active']   as int? ?? 0, const Color(0xFF10B981)),
      ('At Risk',  health['at_risk']  as int? ?? 0, const Color(0xFFF59E0B)),
      ('Stagnant', health['stagnant'] as int? ?? 0, const Color(0xFFF97316)),
      ('Dead',     health['dead']     as int? ?? 0, const Color(0xFFEF4444)),
    ];
    final maxCount = items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Column(
      children: items.map((item) {
        final (label, count, color) = item;
        final pct = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            SizedBox(
              width: 58,
              child: Text(label,
                  style: const TextStyle(fontSize: 10, color: _kMuted)),
            ),
            Expanded(
              child: LayoutBuilder(builder: (_, c) => Stack(children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                      color: _kBorder, borderRadius: BorderRadius.circular(4)),
                ),
                Container(
                  height: 7,
                  width: c.maxWidth * pct,
                  decoration: BoxDecoration(
                      color: count > 0 ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ])),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 16,
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: count > 0 ? color : _kMuted),
                  textAlign: TextAlign.right),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

