import 'package:flutter/material.dart';
import 'package:appflowy_board/appflowy_board.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kPrimary   = Color(0xFF1A1A2E);
const _kAccent    = Color(0xFFE94560);
const _kBorder    = Color(0xFFE8ECF3);
const _kBg        = Color(0xFFF7F8FA);

// ─── Model ────────────────────────────────────────────────────────────────────

class TaskItem extends AppFlowyGroupItem {
  String title;
  String description;
  String assignee;
  Color priorityColor;
  DateTime? date;
  String type;
  List<String> comments;
  bool isDone;

  TaskItem({
    required this.title,
    this.description = '',
    this.assignee = '',
    this.priorityColor = Colors.grey,
    this.date,
    this.type = 'Task',
    List<String>? comments,
    this.isDone = false,
  }) : comments = comments ?? [];

  @override
  String get id => title;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final AppFlowyBoardController _boardController;
  late final AppFlowyBoardScrollController _scrollController;
  TaskItem? _selectedTask;

  @override
  void initState() {
    super.initState();
    _scrollController = AppFlowyBoardScrollController();
    _boardController = AppFlowyBoardController(
      onMoveGroup: (_, _, _, _) {},
      onMoveGroupItem: (_, _, _) {},
      onMoveGroupItemToGroup: (_, _, _, _) {},
    );
    _initBoard();
  }

  void _initBoard() {
    _boardController.addGroup(AppFlowyGroupData(
      id: 'todo',
      name: 'To Do',
      items: <AppFlowyGroupItem>[
        TaskItem(
          title: 'Design landing page',
          description: 'Create mockups for the new landing page',
          assignee: 'Alice',
          priorityColor: Colors.orange,
          type: 'Design',
          date: DateTime.now().add(const Duration(days: 3)),
        ),
        TaskItem(
          title: 'Set up CI/CD pipeline',
          description: 'Configure GitHub Actions for auto-deploy',
          assignee: 'Bob',
          priorityColor: _kAccent,
          type: 'DevOps',
          date: DateTime.now().add(const Duration(days: 7)),
        ),
        TaskItem(
          title: 'Write API documentation',
          description: 'Document all REST endpoints',
          assignee: 'Charlie',
          priorityColor: Colors.blue,
          type: 'Docs',
          date: DateTime.now().add(const Duration(days: 5)),
        ),
      ],
    ));

    _boardController.addGroup(AppFlowyGroupData(
      id: 'in_progress',
      name: 'In Progress',
      items: <AppFlowyGroupItem>[
        TaskItem(
          title: 'Build auth flow',
          description: 'Implement GoTrue login/logout',
          assignee: 'Bob',
          priorityColor: _kAccent,
          type: 'Feature',
          date: DateTime.now().add(const Duration(days: 2)),
        ),
        TaskItem(
          title: 'Dashboard layout',
          description: 'Role-based dashboard screens',
          assignee: 'Alice',
          priorityColor: Colors.orange,
          type: 'Feature',
          date: DateTime.now().add(const Duration(days: 1)),
        ),
      ],
    ));

    _boardController.addGroup(AppFlowyGroupData(
      id: 'done',
      name: 'Done',
      items: <AppFlowyGroupItem>[
        TaskItem(
          title: 'Project scaffolding',
          description: 'Flutter web project initialized',
          assignee: 'Bob',
          priorityColor: Colors.green,
          type: 'Setup',
          isDone: true,
        ),
        TaskItem(
          title: 'Vercel deployment config',
          description: 'vercel.json added and tested',
          assignee: 'Charlie',
          priorityColor: Colors.green,
          type: 'DevOps',
          isDone: true,
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Text(
                'Tasks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddTaskDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Task', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Board + Detail Panel ─────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kanban board fills all remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 0, bottom: 16),
                  child: AppFlowyBoard(
                    controller: _boardController,
                    boardScrollController: _scrollController,
                    cardBuilder: (context, group, groupItem) {
                      final item = groupItem as TaskItem;
                      return AppFlowyGroupCard(
                        key: ValueKey(item.id),
                        child: _TaskCard(
                          item: item,
                          isSelected: _selectedTask?.id == item.id,
                          onTap: () => setState(() {
                            _selectedTask =
                                _selectedTask?.id == item.id ? null : item;
                          }),
                        ),
                      );
                    },
                    headerBuilder: (context, groupData) => _ColumnHeader(
                      groupData: groupData,
                      color: _groupColor(groupData.id),
                    ),
                    footerBuilder: (context, groupData) =>
                        AppFlowyGroupFooter(
                      height: 36,
                      icon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              'Add task',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 260px columns, 12px gap between them
                    groupConstraints:
                        const BoxConstraints.tightFor(width: 260),
                    config: AppFlowyBoardConfig(
                      groupBackgroundColor: _kBg,
                      stretchGroupHeight: false,
                      groupMargin: const EdgeInsets.only(right: 12),
                    ),
                  ),
                ),
              ),
              // Detail panel — AnimatedContainer slides in from the right
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                width: _selectedTask != null ? 360 : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: _kBorder),
                  ),
                ),
                child: _selectedTask != null
                    ? _TaskDetailPanel(
                        key: ValueKey(_selectedTask!.id),
                        item: _selectedTask!,
                        onClose: () =>
                            setState(() => _selectedTask = null),
                        onChanged: () => setState(() {}),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _groupColor(String id) {
    switch (id) {
      case 'todo':        return Colors.blue;
      case 'in_progress': return Colors.orange;
      case 'done':        return Colors.green;
      default:            return Colors.grey;
    }
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController  = TextEditingController();
    String selectedGroup  = 'todo';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Task'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) =>
                    DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  decoration: const InputDecoration(
                      labelText: 'Column', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'todo',        child: Text('To Do')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'done',        child: Text('Done')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedGroup = v);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                _boardController
                    .getGroupController(selectedGroup)
                    ?.add(TaskItem(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      priorityColor: Colors.blue,
                    ));
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _kAccent),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─── Column Header ────────────────────────────────────────────────────────────

class _ColumnHeader extends StatelessWidget {
  final AppFlowyGroupData groupData;
  final Color color;

  const _ColumnHeader({required this.groupData, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: AppFlowyGroupHeader(
        height: 36,
        margin: EdgeInsets.zero,
        addIcon: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () {},
            child: Icon(Icons.add, size: 16, color: Colors.grey[400]),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colored dot
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              // Status name
              Text(
                groupData.headerData.groupName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              // Count pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${groupData.items.length}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Task Card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskItem item;
  final bool isSelected;
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
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _kAccent : _kBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: item.priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                      color: item.isDone ? Colors.grey[400] : Colors.grey[900],
                    ),
                  ),
                ),
                if (item.isDone)
                  const Icon(Icons.check_circle, size: 13, color: Colors.green),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                item.description,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.assignee.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: _kPrimary,
                        child: Text(
                          item.assignee[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.assignee,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                if (item.date != null)
                  Text(
                    _fmt(item.date!),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Task Detail Panel ────────────────────────────────────────────────────────

class _TaskDetailPanel extends StatefulWidget {
  final TaskItem item;
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
  final _commentController = TextEditingController();

  static const _types = [
    'Task', 'Feature', 'Bug', 'Design', 'Docs', 'DevOps', 'Setup'
  ];
  static const _statuses = ['To Do', 'In Progress', 'Done'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: item.priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF0F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Done
                  _PanelRow(
                    icon: Icons.check_circle_outline,
                    label: 'Done',
                    child: Transform.scale(
                      scale: 0.85,
                      alignment: Alignment.centerLeft,
                      child: Checkbox(
                        value: item.isDone,
                        activeColor: Colors.green,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) {
                          setState(() => item.isDone = v ?? false);
                          widget.onChanged();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status
                  _PanelRow(
                    icon: Icons.circle_outlined,
                    label: 'Status',
                    child: DropdownButton<String>(
                      value: _statuses.firstWhere(
                        (s) => s.toLowerCase().replaceAll(' ', '_') ==
                            item.type.toLowerCase().replaceAll(' ', '_'),
                        orElse: () => 'To Do',
                      ),
                      isDense: true,
                      underline: const SizedBox(),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black87),
                      items: _statuses
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => item.type = v);
                          widget.onChanged();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Assigned person
                  _PanelRow(
                    icon: Icons.person_outline,
                    label: 'Person',
                    child: item.assignee.isEmpty
                        ? Text('Unassigned',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[400]))
                        : Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: _kPrimary,
                                child: Text(
                                  item.assignee[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(item.assignee,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Due date
                  _PanelRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Due date',
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: item.date ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => item.date = picked);
                          widget.onChanged();
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            item.date == null
                                ? 'Set date'
                                : '${item.date!.month.toString().padLeft(2, '0')}/'
                                    '${item.date!.day.toString().padLeft(2, '0')}/'
                                    '${item.date!.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.date == null
                                  ? Colors.grey[400]
                                  : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 11, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Priority / Type
                  _PanelRow(
                    icon: Icons.label_outline,
                    label: 'Type',
                    child: DropdownButton<String>(
                      value: _types.contains(item.type) ? item.type : 'Task',
                      isDense: true,
                      underline: const SizedBox(),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black87),
                      items: _types
                          .map((t) =>
                              DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => item.type = v);
                          widget.onChanged();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  _PanelSection(
                    icon: Icons.notes,
                    label: 'Description',
                    child: Text(
                      item.description.isEmpty
                          ? 'No description'
                          : item.description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: item.description.isEmpty
                            ? Colors.grey[400]
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                  const Divider(height: 24, color: _kBorder),
                  // Comments header
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'Comments',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF0F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.comments.length}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (item.comments.isEmpty)
                    Text('No comments yet',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ...item.comments.map((c) => _CommentBubble(text: c)),
                  const SizedBox(height: 10),
                  // Add comment input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Add a comment…',
                            hintStyle: TextStyle(
                                fontSize: 12, color: Colors.grey[400]),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  const BorderSide(color: _kBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  const BorderSide(color: _kBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  const BorderSide(color: _kAccent),
                            ),
                          ),
                          onSubmitted: (_) => _addComment(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _addComment,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.send,
                              size: 14, color: Colors.white),
                        ),
                      ),
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

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.item.comments.add(text);
      _commentController.clear();
    });
    widget.onChanged();
  }
}

// ─── Panel helpers ────────────────────────────────────────────────────────────

class _PanelRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _PanelRow(
      {required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _PanelSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _PanelSection(
      {required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
            padding: const EdgeInsets.only(left: 22), child: child),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final String text;
  const _CommentBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
