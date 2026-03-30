import 'dart:ui' show ImageFilter;
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:appflowy_board/appflowy_board.dart';
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

enum Priority { high, medium, low }

extension PriorityX on Priority {
  String get label => switch (this) {
    Priority.high   => 'High',
    Priority.medium => 'Medium',
    Priority.low    => 'Low',
  };
  Color get color => switch (this) {
    Priority.high   => _kHigh,
    Priority.medium => _kMedium,
    Priority.low    => _kLow,
  };
}

// ─── Model ────────────────────────────────────────────────────────────────────

class TaskItem extends AppFlowyGroupItem {
  String   title;
  String   description;
  String   assignee;
  Priority priority;
  DateTime? date;    // start / due date
  DateTime? endDate; // optional range end date
  String   type;
  List<String> comments;
  bool     isDone;

  TaskItem({
    required this.title,
    this.description = '',
    this.assignee    = '',
    this.priority    = Priority.medium,
    this.date,
    this.endDate,
    this.type        = 'Task',
    List<String>? comments,
    this.isDone      = false,
  }) : comments = comments ?? [];

  @override
  String get id => title;
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

  @override
  void initState() {
    super.initState();
    _scrollCtrl = AppFlowyBoardScrollController();
    _boardCtrl  = AppFlowyBoardController(
      onMoveGroup:            (_, _, _, _) {},
      onMoveGroupItem:        (_, _, _)    {},
      onMoveGroupItemToGroup: (_, _, _, _) {},
    );
    _initBoard();
  }

  void _initBoard() {
    _boardCtrl.addGroup(AppFlowyGroupData(
      id: 'todo', name: 'To Do',
      items: <AppFlowyGroupItem>[
        TaskItem(
          title:       'Design landing page',
          description: 'Create wireframes and high-fidelity mockups for the new marketing landing page',
          assignee:    'Alice',
          priority:    Priority.high,
          type:        'Design',
          date:        DateTime.now().add(const Duration(days: 3)),
        ),
        TaskItem(
          title:       'Set up CI/CD pipeline',
          description: 'Configure GitHub Actions for automated testing and deployment',
          assignee:    'Bob',
          priority:    Priority.medium,
          type:        'DevOps',
          date:        DateTime.now().add(const Duration(days: 7)),
        ),
        TaskItem(
          title:       'Write API documentation',
          description: 'Document all REST endpoints with examples and error codes',
          assignee:    'Charlie',
          priority:    Priority.low,
          type:        'Docs',
          date:        DateTime.now().add(const Duration(days: 5)),
        ),
      ],
    ));

    _boardCtrl.addGroup(AppFlowyGroupData(
      id: 'in_progress', name: 'In Progress',
      items: <AppFlowyGroupItem>[
        TaskItem(
          title:       'Build auth flow',
          description: 'Implement GoTrue login, logout and session refresh',
          assignee:    'Bob',
          priority:    Priority.high,
          type:        'Feature',
          date:        DateTime.now().add(const Duration(days: 2)),
          comments:    ['Blocked on GoTrue config', 'Unblocked — proceeding'],
        ),
        TaskItem(
          title:       'Dashboard layout',
          description: 'Role-based dashboard screens for CEO, directors and staff',
          assignee:    'Alice',
          priority:    Priority.medium,
          type:        'Feature',
          date:        DateTime.now().add(const Duration(days: 1)),
          comments:    ['Draft ready for review'],
        ),
      ],
    ));

    _boardCtrl.addGroup(AppFlowyGroupData(
      id: 'done', name: 'Done',
      items: <AppFlowyGroupItem>[
        TaskItem(
          title:       'Project scaffolding',
          description: 'Flutter web project initialized with router and theme',
          assignee:    'Bob',
          priority:    Priority.low,
          type:        'Setup',
          isDone:      true,
        ),
        TaskItem(
          title:       'Vercel deployment config',
          description: 'vercel.json configured, preview deployments verified',
          assignee:    'Charlie',
          priority:    Priority.low,
          type:        'DevOps',
          isDone:      true,
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _boardCtrl.dispose();
    super.dispose();
  }

  Color _columnColor(String id) => switch (id) {
    'todo'        => _kTodo,
    'in_progress' => _kInProgress,
    'done'        => _kDone,
    _             => _kMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopBar(onAddTask: _showAddTaskDialog),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Kanban board ────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: AppFlowyBoard(
                    controller:             _boardCtrl,
                    boardScrollController:  _scrollCtrl,
                    cardBuilder: (context, group, groupItem) {
                      final item = groupItem as TaskItem;
                      return AppFlowyGroupCard(
                        key: ValueKey(item.id),
                        child: _TaskCard(
                          item:       item,
                          isSelected: _selectedTask?.id == item.id,
                          onTap:      () => _showTaskDetailModal(item),
                        ),
                      );
                    },
                    headerBuilder: (context, groupData) => _ColumnHeader(
                      groupData: groupData,
                      accentColor: _columnColor(groupData.id),
                    ),
                    footerBuilder: (context, groupData) =>
                        AppFlowyGroupFooter(
                      height: 40,
                      icon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(children: [
                          Icon(Icons.add, size: 14, color: _kMuted),
                          const SizedBox(width: 6),
                          Text('Add task',
                              style: TextStyle(fontSize: 12, color: _kMuted)),
                        ]),
                      ),
                    ),
                    groupConstraints: const BoxConstraints.tightFor(width: 272),
                    config: AppFlowyBoardConfig(
                      // Column bg slightly off-white so cards (pure white) pop
                      groupBackgroundColor: _kBg,
                      stretchGroupHeight:  false,
                      groupMargin:         const EdgeInsets.only(right: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                    item:      item,
                    onClose:   () => Navigator.of(ctx).pop(),
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).then((_) => setState(() => _selectedTask = null));
  }

  // ── Add task dialog ─────────────────────────────────────────────────────────

  void _showAddTaskDialog() {
    final titleCtrl    = TextEditingController();
    final descCtrl     = TextEditingController();
    final assigneeCtrl = TextEditingController();
    String   selectedGroup    = 'todo';
    String   selectedType     = 'Task';
    Priority selectedPriority = Priority.medium;
    DateTime? selectedDate;
    DateTime? selectedEndDate;
    bool      endDateEnabled  = false;
    bool      showCalendar    = false;

    final dialogTypeOpts = <SelectOption>[
      SelectOption(id: '1', name: 'prompt',         color: SelectOptionColor.purple),
      SelectOption(id: '2', name: 'whatsapp agent', color: SelectOptionColor.pink),
      SelectOption(id: '3', name: 'frontend',       color: SelectOptionColor.blue),
      SelectOption(id: '4', name: 'Backend',        color: SelectOptionColor.green),
      SelectOption(id: '5', name: 'Agent',          color: SelectOptionColor.orange),
    ];
    List<String> selectedTypeIds = [];
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

    // barrierDismissible: true — tapping outside closes the dialog.
    // .then() fires after close and saves the card if a title was entered.
    showDialog<void>(
      context: context,
      barrierDismissible: true,
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
                    decoration: fieldDeco('Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines:   3,
                    style:      const TextStyle(fontSize: 13),
                    decoration: fieldDeco('Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: assigneeCtrl,
                    style:      const TextStyle(fontSize: 13),
                    decoration: fieldDeco('Assignee'),
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
                            selectedTypeIds
                              ..clear()
                              ..add(id);
                          }
                          final opt = dialogTypeOpts.firstWhere(
                              (o) => o.id == id,
                              orElse: () => dialogTypeOpts.first);
                          selectedType = opt.name;
                        });
                      },
                      onOptionCreated: (name) {
                        setDlg(() {
                          final newId = '${DateTime.now().millisecondsSinceEpoch}';
                          dialogTypeOpts.add(SelectOption(
                            id:    newId,
                            name:  name,
                            color: SelectOptionColor.gray,
                          ));
                          selectedTypeIds
                            ..clear()
                            ..add(newId);
                          selectedType = name;
                        });
                      },
                      onOptionDeleted: (id) {
                        setDlg(() {
                          final removed = dialogTypeOpts.firstWhere(
                              (o) => o.id == id,
                              orElse: () => SelectOption(id: '', name: '', color: SelectOptionColor.gray));
                          if (selectedType == removed.name) selectedType = '';
                          selectedTypeIds.remove(id);
                          dialogTypeOpts.removeWhere((o) => o.id == id);
                        });
                      },
                      onOptionRenamed: (id, name) {
                        setDlg(() {
                          final i = dialogTypeOpts.indexWhere((o) => o.id == id);
                          if (i != -1) {
                            if (selectedType == dialogTypeOpts[i].name) selectedType = name;
                            dialogTypeOpts[i] = dialogTypeOpts[i].copyWith(name: name);
                          }
                        });
                      },
                      onOptionColorChanged: (id, color) {
                        setDlg(() {
                          final i = dialogTypeOpts.indexWhere((o) => o.id == id);
                          if (i != -1) dialogTypeOpts[i] = dialogTypeOpts[i].copyWith(color: color);
                        });
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
                            decoration: fieldDeco('Due Date'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDate == null
                                      ? 'Pick a date'
                                      : (endDateEnabled && selectedEndDate != null)
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
                            endDateEnabled: endDateEnabled,
                            onSelect: (d) => setDlg(() {
                              selectedDate    = d;
                              selectedEndDate = null;
                            }),
                            onEndSelect: (d) =>
                                setDlg(() => selectedEndDate = d),
                            onEndDateToggle: (v) => setDlg(() {
                              endDateEnabled  = v;
                              if (!v) selectedEndDate = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                  // Hint at the bottom of the form — no buttons
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      color:  _kBg,
                      border: Border(top: BorderSide(color: _kBorder)),
                    ),
                    child: const Text(
                      'Click outside to save  ·  Leave title empty to discard',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: _kMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      // Fires when dialog is dismissed (barrier tap, back button, etc.)
      if (!mounted) return;
      final title = titleCtrl.text.trim();
      if (title.isNotEmpty) {
        // Add the card to the board locally.
        // TODO: replace with backend API call once endpoints are provided.
        _boardCtrl
            .getGroupController(selectedGroup)
            ?.add(TaskItem(
              title:       title,
              description: descCtrl.text.trim(),
              assignee:    assigneeCtrl.text.trim(),
              priority:    selectedPriority,
              type:        selectedType,
              date:        selectedDate,
              endDate:     selectedEndDate,
            ));
      }
      // Dispose text controllers created for this dialog session.
      titleCtrl.dispose();
      descCtrl.dispose();
      assigneeCtrl.dispose();
    });
  }
}

// ─── Reusable: Top bar ────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onAddTask;
  const _TopBar({required this.onAddTask});

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
          const Spacer(),
          // Add task button
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
        addIcon: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Icon(Icons.add, size: 16, color: _kMuted),
        ),
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
  final VoidCallback onTap;

  const _TaskCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        _kSurface,          // pure white card
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _kAccent : _kBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
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
            // ── Row 1: priority badge + type badge ────────────────────────
            Row(
              children: [
                _PriorityBadge(item.priority),
                const SizedBox(width: 6),
                _TypeBadge(item.type),
                const Spacer(),
                if (item.isDone)
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: _kDone),
              ],
            ),
            const SizedBox(height: 10),
            // ── Row 2: title ──────────────────────────────────────────────
            Text(
              item.title,
              style: TextStyle(
                fontSize:      13,
                fontWeight:    FontWeight.w600,
                color:         item.isDone ? _kMuted : _kPrimary,
                decoration:    item.isDone ? TextDecoration.lineThrough : null,
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
            // ── Row 4: assignee + meta chips ──────────────────────────────
            Row(
              children: [
                if (item.assignee.isNotEmpty) ...[
                  _AssigneeAvatar(item.assignee),
                  const SizedBox(width: 5),
                  Text(item.assignee,
                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                ],
                const Spacer(),
                if (item.comments.isNotEmpty) ...[
                  _MetaChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: '${item.comments.length}',
                  ),
                  const SizedBox(width: 8),
                ],
                if (item.date != null)
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    text: _fmtDate(item.date!),
                  ),
              ],
            ),
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

class _CommentBubble extends StatelessWidget {
  final String text;
  const _CommentBubble({required this.text});

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
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: _kPrimary, height: 1.4)),
    );
  }
}

// ─── Task detail panel ────────────────────────────────────────────────────────

class _TaskDetailPanel extends StatefulWidget {
  final TaskItem     item;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const _TaskDetailPanel({
    super.key,
    required this.item,
    required this.onClose,
    required this.onChanged,
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
  bool _endDateEnabled    = false;

  final List<SelectOption> _typeOpts = [
    SelectOption(id: '1', name: 'prompt',         color: SelectOptionColor.purple),
    SelectOption(id: '2', name: 'whatsapp agent', color: SelectOptionColor.pink),
    SelectOption(id: '3', name: 'frontend',       color: SelectOptionColor.blue),
    SelectOption(id: '4', name: 'Backend',        color: SelectOptionColor.green),
    SelectOption(id: '5', name: 'Agent',          color: SelectOptionColor.orange),
  ];

  @override
  void dispose() {
    _closeDateOverlay();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _openDateOverlay() {
    final item = widget.item;
    if (_dateOverlay != null) { _closeDateOverlay(); return; }
    final rb = _dateRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos  = rb.localToGlobal(Offset.zero);
    final size = rb.size;

    _dateOverlay = OverlayEntry(builder: (_) => _DatePickerOverlay(
      anchorPos:      Offset(pos.dx, pos.dy + size.height + 4),
      anchorRight:    pos.dx + size.width,
      selected:       item.date,
      endDate:        item.endDate,
      endDateEnabled: _endDateEnabled,
      onClose:        _closeDateOverlay,
      onSelect: (d) {
        setState(() { item.date = d; item.endDate = null; });
        widget.onChanged();
        _dateOverlay?.markNeedsBuild();
      },
      onEndSelect: (d) {
        setState(() => item.endDate = d);
        widget.onChanged();
        _dateOverlay?.markNeedsBuild();
      },
      onEndDateToggle: (v) {
        setState(() { _endDateEnabled = v; if (!v) item.endDate = null; });
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Column(
      mainAxisSize:        MainAxisSize.min,
      crossAxisAlignment:  CrossAxisAlignment.start,
      children: [
        // ── Close button row ──────────────────────────────────────────────
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: InkWell(
              onTap:        widget.onClose,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width:  28, height: 28,
                decoration: BoxDecoration(
                  color:        _kBg,
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(color: _kBorder),
                ),
                child: Icon(Icons.close, size: 14, color: _kMuted),
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
                  },
                ),

                const Divider(height: 28, color: _kBorder),

                // ── Done checkbox ──────────────────────────────────────────
                _PanelRow(
                  icon:  Icons.check_circle_outline_rounded,
                  label: 'Done',
                  child: Transform.scale(
                    scale:     0.8,
                    alignment: Alignment.centerLeft,
                    child: Checkbox(
                      value:       item.isDone,
                      activeColor: _kDone,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        setState(() => item.isDone = v ?? false);
                        widget.onChanged();
                      },
                    ),
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
                      if (v != null) {
                        setState(() => item.priority = v);
                        widget.onChanged();
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
                    label: 'Due date',
                    child: GestureDetector(
                      onTap: _openDateOverlay,
                      child: Row(children: [
                        Text(
                          item.date == null
                              ? 'Set date'
                              : (_endDateEnabled && item.endDate != null)
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

                // ── Person (Assignee) ──────────────────────────────────────
                _PanelRow(
                  icon:  Icons.person_outline_rounded,
                  label: 'Person',
                  child: item.assignee.isEmpty
                      ? const Text('Unassigned',
                          style: TextStyle(fontSize: 12, color: _kMuted))
                      : Row(children: [
                          _AssigneeAvatar(item.assignee, radius: 12),
                          const SizedBox(width: 8),
                          Text(item.assignee,
                              style: const TextStyle(
                                  fontSize: 12, color: _kPrimary)),
                        ]),
                ),
                const SizedBox(height: 14),

                // ── Type ───────────────────────────────────────────────────
                SelectOptionField(
                  label:           'Type',
                  options:         _typeOpts,
                  selectedOptions: item.type.isEmpty
                      ? []
                      : [_typeOpts.firstWhere(
                            (o) => o.name.toLowerCase() == item.type.toLowerCase(),
                            orElse: () => _typeOpts.first,
                          ).id],
                  onOptionSelected: (id) {
                    final opt = _typeOpts.firstWhere((o) => o.id == id, orElse: () => _typeOpts.first);
                    setState(() => item.type = opt.name);
                    widget.onChanged();
                  },
                  onOptionCreated: (name) {
                    setState(() {
                      _typeOpts.add(SelectOption(
                        id:    name.toLowerCase().replaceAll(' ', '_'),
                        name:  name,
                        color: SelectOptionColor.gray,
                      ));
                      item.type = name;
                    });
                    widget.onChanged();
                  },
                  onOptionDeleted: (id) {
                    setState(() {
                      final removed = _typeOpts.firstWhere((o) => o.id == id,
                          orElse: () => SelectOption(id: '', name: '', color: SelectOptionColor.gray));
                      if (item.type == removed.name) item.type = '';
                      _typeOpts.removeWhere((o) => o.id == id);
                    });
                    widget.onChanged();
                  },
                  onOptionRenamed: (id, name) {
                    setState(() {
                      final i = _typeOpts.indexWhere((o) => o.id == id);
                      if (i != -1) {
                        if (item.type == _typeOpts[i].name) item.type = name;
                        _typeOpts[i] = _typeOpts[i].copyWith(name: name);
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
                    child: Text('${item.comments.length}',
                        style: const TextStyle(fontSize: 10, color: _kMuted)),
                  ),
                ]),
                const SizedBox(height: 10),
                if (item.comments.isEmpty)
                  const Text('No comments yet',
                      style: TextStyle(fontSize: 12, color: _kMuted))
                else
                  ...item.comments.map((c) => _CommentBubble(text: c)),
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
                    onTap: _addComment,
                    child: Container(
                      width:  32, height: 32,
                      decoration: BoxDecoration(
                        color:        _kAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.send_rounded,
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

  void _addComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.item.comments.add(text);
      _commentCtrl.clear();
    });
    widget.onChanged();
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

// ─── Date picker overlay ──────────────────────────────────────────────────────
// Positioned below the due-date row as a floating card (same pattern as
// SelectOptionField dropdown). Barrier tap closes it.

class _DatePickerOverlay extends StatelessWidget {
  final Offset              anchorPos;
  final double              anchorRight;
  final DateTime?           selected;
  final DateTime?           endDate;
  final bool                endDateEnabled;
  final VoidCallback        onClose;
  final ValueChanged<DateTime>  onSelect;
  final ValueChanged<DateTime>? onEndSelect;
  final ValueChanged<bool>      onEndDateToggle;

  const _DatePickerOverlay({
    required this.anchorPos,
    required this.anchorRight,
    required this.endDateEnabled,
    required this.onClose,
    required this.onSelect,
    required this.onEndDateToggle,
    this.selected,
    this.endDate,
    this.onEndSelect,
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
                endDateEnabled: endDateEnabled,
                onSelect:       onSelect,
                onEndSelect:    onEndSelect,
                onEndDateToggle: onEndDateToggle,
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
  final DateTime?               endDate;        // range end (null when disabled)
  final bool                    endDateEnabled;
  final ValueChanged<DateTime>  onSelect;       // fires when start date tapped
  final ValueChanged<DateTime>? onEndSelect;    // fires when end date tapped
  final ValueChanged<bool>      onEndDateToggle;

  const _InlineDatePicker({
    this.selected,
    this.endDate,
    this.endDateEnabled  = false,
    required this.onSelect,
    this.onEndSelect,
    required this.onEndDateToggle,
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

                      final isEnd = widget.endDateEnabled &&
                          endDate != null &&
                          d.year  == endDate.year &&
                          d.month == endDate.month &&
                          d.day   == endDate.day;

                      // A day is "in range" only when end-date mode is on AND
                      // both dates are picked AND this day falls between them.
                      final isInRange = widget.endDateEnabled &&
                          selected != null &&
                          endDate  != null &&
                          d.isAfter(selected) &&
                          d.isBefore(endDate);

                      final isHighlighted = isStart || isEnd;

                      final isToday = d.year  == today.year &&
                          d.month == today.month &&
                          d.day   == today.day;

                      // Tap logic:
                      //  • End-date OFF → always set start date
                      //  • End-date ON  → if no start, or tapped ≤ start → set start
                      //                   if tapped > start → set end
                      void onTap() {
                        if (!widget.endDateEnabled) {
                          widget.onSelect(d);
                        } else if (selected == null ||
                            !d.isAfter(selected)) {
                          widget.onSelect(d); // set/reset start
                        } else {
                          widget.onEndSelect?.call(d); // set end
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
          // ── End date toggle — functional ──────────────────────────────────────
          const Divider(height: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: _kMuted),
              const SizedBox(width: 8),
              const Text('End date',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              const Spacer(),
              Switch(
                value:       widget.endDateEnabled,
                activeThumbColor: const Color(0xFF2563EB),
                onChanged:   (v) => widget.onEndDateToggle(v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
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
