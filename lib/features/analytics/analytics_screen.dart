import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_colors.dart';

// ─── Delivery performance ─────────────────────────────────────────────────────

const _kPerfPalette = [
  Color(0xFF6366F1), // indigo
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEC4899), // pink
  Color(0xFF8B5CF6), // violet
  Color(0xFF06B6D4), // cyan
];

const _kGradeGreen   = Color(0xFF10B981);
const _kGradeAmber   = Color(0xFFF59E0B);
const _kGradeRed     = Color(0xFFEF4444);
const _kGradeNeutral = Color(0xFF6366F1);

Color _gradeColor(double? pct) {
  if (pct == null) return _kGradeNeutral;
  if (pct >= 75)   return _kGradeGreen;
  if (pct >= 50)   return _kGradeAmber;
  return _kGradeRed;
}

String _gradeLabel(double? pct) {
  if (pct == null) return 'No deadlines';
  if (pct >= 75)   return '🏆 Great';
  if (pct >= 50)   return '👍 Solid';
  return '💪 Improving';
}

class _PerfUser {
  final String userId, userName;
  final int    totalCompleted, onTime, late, early;
  final double? avgDrift, avgActualDays, avgPlannedDays;

  const _PerfUser({
    required this.userId,     required this.userName,
    required this.totalCompleted, required this.onTime,
    required this.late,       required this.early,
    this.avgDrift, this.avgActualDays, this.avgPlannedDays,
  });

  factory _PerfUser.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map<String, dynamic>?) ?? {};
    return _PerfUser(
      userId:         j['user_id']          as String? ?? '',
      userName:       j['user_name']         as String? ?? '',
      totalCompleted: s['total_completed']   as int?    ?? 0,
      onTime:         s['on_time']           as int?    ?? 0,
      late:           s['late']              as int?    ?? 0,
      early:          s['early']             as int?    ?? 0,
      avgDrift:       (s['avg_drift']        as num?)?.toDouble(),
      avgActualDays:  (s['avg_actual_days']  as num?)?.toDouble(),
      avgPlannedDays: (s['avg_planned_days'] as num?)?.toDouble(),
    );
  }

  double? get onTimePct {
    final d = onTime + late;
    return d == 0 ? null : onTime / d * 100;
  }
}

class _PerfTask {
  final String  taskId, title;
  final int?    plannedDays, actualDays, pausedDays;
  final double? drift;
  final String? completedAt, endDate;

  const _PerfTask({
    required this.taskId, required this.title,
    this.plannedDays, this.actualDays, this.pausedDays,
    this.drift, this.completedAt, this.endDate,
  });

  factory _PerfTask.fromJson(Map<String, dynamic> j) => _PerfTask(
    taskId:      j['task_id']      as String? ?? '',
    title:       j['title']        as String? ?? '',
    plannedDays: j['planned_days'] as int?,
    actualDays:  j['actual_days']  as int?,
    pausedDays:  j['paused_days']  as int?,
    drift:       (j['drift']       as num?)?.toDouble(),
    completedAt: j['completed_at'] as String?,
    endDate:     j['end_date']     as String?,
  );

  Color get driftColor {
    if (drift == null) return const Color(0xFF9CA3AF);
    if (drift! <= 0)   return _kGradeGreen;
    if (drift! <= 2)   return _kGradeAmber;
    return _kGradeRed;
  }

  String get driftLabel {
    if (drift == null) return '–';
    if (drift! == 0)   return 'On time';
    if (drift! < 0)    return '${(-drift!).toStringAsFixed(0)}d early';
    return '+${drift!.toStringAsFixed(0)}d';
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  // ── Delivery performance ───────────────────────────────────────────────────
  List<_PerfUser>               _perfUsers   = [];
  bool                          _perfLoading = true;
  String?                       _expandedUserId;
  final Map<String, List<_PerfTask>> _drillTasks   = {};
  final Set<String>             _drillLoading = {};

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _loadPerformance();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getAnalyticsDashboard();
      _data = res.data as Map<String, dynamic>;
    } catch (_) {
      _data = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPerformance() async {
    try {
      final res  = await _api.getTaskPerformance();
      final list = (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _perfUsers   = list.map(_PerfUser.fromJson).toList();
          _perfLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _perfUsers = []; _perfLoading = false; });
      }
    }
  }

  Future<void> _loadDrill(String userId) async {
    if (_drillTasks.containsKey(userId)) return;
    setState(() => _drillLoading.add(userId));
    try {
      final res   = await _api.getTaskPerformance(userId: userId);
      final data  = res.data as Map<String, dynamic>? ?? {};
      final tasks = (data['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _drillTasks[userId] = tasks.map(_PerfTask.fromJson).toList();
          _drillLoading.remove(userId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _drillTasks[userId] = [];
          _drillLoading.remove(userId);
        });
      }
    }
  }

  void _toggleExpand(String userId) {
    setState(() {
      if (_expandedUserId == userId) {
        _expandedUserId = null;
      } else {
        _expandedUserId = userId;
        _loadDrill(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load analytics', style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadAnalytics, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // ── Stat cards row ──────────────────────────────────────────────
          _buildStatCards(),
          const SizedBox(height: 24),

          // ── Charts row ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTasksByStatusChart()),
              const SizedBox(width: 24),
              Expanded(child: _buildTasksByPriorityChart()),
            ],
          ),
          const SizedBox(height: 24),

          // ── Tasks per person ─────────────────────────────────────────────
          _buildTasksPerPersonChart(),
          const SizedBox(height: 24),

          // ── Stagnant & Attendance overview ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStagnantCard()),
              const SizedBox(width: 24),
              Expanded(child: _buildAttendanceOverview()),
            ],
          ),
          const SizedBox(height: 32),

          // ── Team Delivery Performance ─────────────────────────────────────
          _buildDeliverySection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final tasksByStatus = _data!['tasks_by_status'] as Map<String, dynamic>? ?? {};
    final stagnant = _data!['stagnant_count'] as Map<String, dynamic>? ?? {};
    final avgDrift = _data!['avg_drift_days'];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(label: 'Total Tasks',
            value: '${_sumMap(tasksByStatus)}',
            color: AppColors.info),
        _StatCard(label: 'Completed',
            value: '${tasksByStatus['completed'] ?? 0}',
            color: AppColors.success),
        _StatCard(label: 'In Review',
            value: '${tasksByStatus['reviewer'] ?? 0}',
            color: AppColors.warning),
        _StatCard(label: 'Stagnant',
            value: '${(stagnant['stagnant'] ?? 0) + (stagnant['dead'] ?? 0)}',
            color: AppColors.error),
        _StatCard(label: 'Avg Drift',
            value: avgDrift != null ? '${avgDrift}d' : '0d',
            color: AppColors.healthAtRisk),
      ],
    );
  }

  int _sumMap(Map<String, dynamic> m) {
    int total = 0;
    for (final v in m.values) {
      if (v is int) total += v;
    }
    return total;
  }

  Widget _buildTasksByStatusChart() {
    final tasksByStatus = _data!['tasks_by_status'] as Map<String, dynamic>? ?? {};
    final sections = <PieChartSectionData>[];
    final colors = {
      'not_completed': AppColors.warning,
      'reviewer': AppColors.info,
      'completed': AppColors.success,
      'idea': Colors.purple,
      'archived': Colors.grey,
    };

    tasksByStatus.forEach((key, value) {
      final v = (value as int?) ?? 0;
      if (v > 0) {
        sections.add(PieChartSectionData(
          value: v.toDouble(),
          title: '$v',
          color: colors[key] ?? Colors.grey,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
    });

    return _ChartCard(
      title: 'Tasks by Status',
      child: sections.isEmpty
          ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: PieChart(PieChartData(
                      sections: sections,
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    )),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tasksByStatus.entries.where((e) => (e.value as int?) != null && (e.value as int) > 0).map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(
                            color: colors[e.key] ?? Colors.grey,
                            shape: BoxShape.circle,
                          )),
                          const SizedBox(width: 6),
                          Text('${_formatLabel(e.key)}: ${e.value}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTasksByPriorityChart() {
    final tasksByPriority = _data!['tasks_by_priority'] as Map<String, dynamic>? ?? {};
    final sections = <PieChartSectionData>[];
    final colors = {
      'high': AppColors.priorityHigh,
      'medium': AppColors.priorityMedium,
      'low': AppColors.priorityLow,
    };

    tasksByPriority.forEach((key, value) {
      final v = (value as int?) ?? 0;
      if (v > 0) {
        sections.add(PieChartSectionData(
          value: v.toDouble(),
          title: '$v',
          color: colors[key] ?? Colors.grey,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
    });

    return _ChartCard(
      title: 'Tasks by Priority',
      child: sections.isEmpty
          ? const Center(child: Text('No data', style: TextStyle(color: Colors.grey)))
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: PieChart(PieChartData(
                      sections: sections,
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    )),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tasksByPriority.entries.where((e) => (e.value as int?) != null && (e.value as int) > 0).map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(
                            color: colors[e.key] ?? Colors.grey,
                            shape: BoxShape.circle,
                          )),
                          const SizedBox(width: 6),
                          Text('${_formatLabel(e.key)}: ${e.value}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTasksPerPersonChart() {
    final tasksPerPerson = (_data!['tasks_per_person'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (tasksPerPerson.isEmpty) {
      return _ChartCard(title: 'Tasks per Person', child: const Center(child: Text('No data', style: TextStyle(color: Colors.grey))));
    }

    return _ChartCard(
      title: 'Tasks per Person',
      child: SizedBox(
        height: 250,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: tasksPerPerson.fold<double>(0, (max, p) {
            final total = (p['total'] as int?)?.toDouble() ?? 0;
            return total > max ? total : max;
          }) + 2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= tasksPerPerson.length) return const SizedBox.shrink();
                  final name = tasksPerPerson[i]['user_name'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(name, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          barGroups: List.generate(tasksPerPerson.length, (i) {
            final p = tasksPerPerson[i];
            final completed = (p['completed'] as int?)?.toDouble() ?? 0;
            final inProgress = ((p['in_progress'] as int?) ?? ((p['total'] as int? ?? 0) - (p['completed'] as int? ?? 0))).toDouble();
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: completed + inProgress,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                rodStackItems: [
                  BarChartRodStackItem(0, completed, AppColors.success),
                  BarChartRodStackItem(completed, completed + inProgress, AppColors.warning),
                ],
                color: Colors.transparent,
              ),
            ]);
          }),
        )),
      ),
    );
  }

  Widget _buildStagnantCard() {
    final stagnant = _data!['stagnant_count'] as Map<String, dynamic>? ?? {};
    return _ChartCard(
      title: 'Task Health',
      child: Column(
        children: [
          _HealthRow(label: 'At Risk', count: stagnant['at_risk'] as int? ?? 0, color: AppColors.healthAtRisk),
          _HealthRow(label: 'Stagnant', count: stagnant['stagnant'] as int? ?? 0, color: AppColors.healthStagnant),
          _HealthRow(label: 'Dead', count: stagnant['dead'] as int? ?? 0, color: AppColors.healthDead),
        ],
      ),
    );
  }

  Widget _buildAttendanceOverview() {
    final att = _data!['attendance_overview'] as Map<String, dynamic>? ?? {};
    final topPerformer = att['top_performer_this_month'] as Map<String, dynamic>?;
    final mostLeaves = att['most_leaves_this_month'] as Map<String, dynamic>?;

    return _ChartCard(
      title: 'Attendance Today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AttRow(label: 'Present', value: '${att['team_present_today'] ?? 0}', color: AppColors.success),
          _AttRow(label: 'On Leave', value: '${att['team_on_leave_today'] ?? 0}', color: AppColors.warning),
          _AttRow(label: 'Late', value: '${att['team_late_today'] ?? 0}', color: AppColors.error),
          _AttRow(label: 'Avg Hours', value: '${att['team_avg_hours_today'] ?? 0}h', color: AppColors.info),
          if (topPerformer != null) ...[
            const Divider(height: 20),
            Text('Top: ${topPerformer['user_name']} (${topPerformer['total_hours']}h)',
                style: const TextStyle(fontSize: 12, color: AppColors.success)),
          ],
          if (mostLeaves != null)
            Text('Most leaves: ${mostLeaves['user_name']} (${mostLeaves['total_leaves']})',
                style: const TextStyle(fontSize: 12, color: AppColors.error)),
        ],
      ),
    );
  }

  String _formatLabel(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  // ── Delivery Performance section ───────────────────────────────────────────

  Widget _buildDeliverySection() {
    if (_perfLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_perfUsers.isEmpty) return const SizedBox.shrink();

    final totalOT   = _perfUsers.fold(0, (s, u) => s + u.onTime);
    final totalLate = _perfUsers.fold(0, (s, u) => s + u.late);
    final teamPct   = (totalOT + totalLate) == 0
        ? null : totalOT / (totalOT + totalLate) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Team Delivery ⚡',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('How accurately tasks are being completed vs deadlines',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
            const Spacer(),
            if (teamPct != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        _gradeColor(teamPct).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gradeColor(teamPct).withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: _gradeColor(teamPct), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${teamPct.toStringAsFixed(0)}% team on-time',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _gradeColor(teamPct))),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // User cards
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _perfUsers.asMap().entries.map((e) {
            final user = e.value;
            return _UserPerfCard(
              user:         user,
              index:        e.key,
              color:        _kPerfPalette[e.key % _kPerfPalette.length],
              expanded:     _expandedUserId == user.userId,
              drillTasks:   _drillTasks[user.userId],
              drillLoading: _drillLoading.contains(user.userId),
              onToggle:     () => _toggleExpand(user.userId),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Reusable card wrapper ───────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _HealthRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: count > 0 ? color : Colors.grey)),
        ],
      ),
    );
  }
}

class _AttRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AttRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Delivery Performance Widgets ─────────────────────────────────────────────

const _kHeaderStyle = TextStyle(
  fontSize: 10, fontWeight: FontWeight.w700,
  color: Color(0xFFAAAAAA), letterSpacing: 0.5,
);

class _UserPerfCard extends StatefulWidget {
  final _PerfUser         user;
  final int               index;
  final Color             color;
  final bool              expanded;
  final List<_PerfTask>?  drillTasks;
  final bool              drillLoading;
  final VoidCallback      onToggle;

  const _UserPerfCard({
    required this.user,    required this.index,   required this.color,
    required this.expanded, this.drillTasks,
    required this.drillLoading, required this.onToggle,
  });

  @override
  State<_UserPerfCard> createState() => _UserPerfCardState();
}

class _UserPerfCardState extends State<_UserPerfCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    Future.delayed(
      Duration(milliseconds: 60 * widget.index),
      () { if (mounted) _enter.forward(); },
    );
  }

  @override
  void dispose() { _enter.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user     = widget.user;
    final pct      = user.onTimePct;
    final gradeClr = _gradeColor(pct);
    final initials = user.userName
        .split(' ').take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: 290,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      widget.color.withValues(alpha: 0.15),
                blurRadius: 18,
                offset:     const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coloured top strip — grade-based
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: gradeClr,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar + name + grade badge ──────────────────────
                    Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: widget.color.withValues(alpha: 0.15),
                        child: Text(initials,
                            style: TextStyle(
                                color:      widget.color,
                                fontWeight: FontWeight.bold,
                                fontSize:   14)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.userName,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: gradeClr.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_gradeLabel(pct),
                                  style: TextStyle(
                                      fontSize:   11,
                                      color:      gradeClr,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── Three stat tiles ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        _PerfStatTile(
                            value: '${user.totalCompleted}',
                            label: 'Tasks',
                            color: AppColors.info),
                        _PerfVertDivider(),
                        _PerfStatTile(
                            value: pct != null
                                ? '${pct.toStringAsFixed(0)}%' : '–',
                            label: 'On Time',
                            color: gradeClr),
                        _PerfVertDivider(),
                        _PerfStatTile(
                          value: user.avgDrift == null
                              ? '–'
                              : user.avgDrift! >= 0
                                  ? '+${user.avgDrift!.toStringAsFixed(1)}d'
                                  : '${user.avgDrift!.toStringAsFixed(1)}d',
                          label: 'Avg Drift',
                          color: user.avgDrift == null
                              ? Colors.grey
                              : user.avgDrift! <= 0
                                  ? _kGradeGreen
                                  : user.avgDrift! <= 2
                                      ? _kGradeAmber
                                      : _kGradeRed,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // ── Progress bar label ───────────────────────────────
                    Row(children: [
                      Text('On-time rate',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      const Spacer(),
                      Text(
                        pct != null
                            ? '${user.onTime} of ${user.onTime + user.late}'
                            : 'No deadlines',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const SizedBox(height: 6),

                    // ── Animated fill bar ────────────────────────────────
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (pct ?? 0) / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context2, v, child2) => Stack(children: [
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color:        Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(colors: [
                                gradeClr.withValues(alpha: 0.65),
                                gradeClr,
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── Expand / collapse toggle ─────────────────────────
                    InkWell(
                      onTap: widget.onToggle,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 2),
                        child: Row(children: [
                          AnimatedRotation(
                            turns:    widget.expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.expanded ? 'Hide tasks' : 'View tasks',
                            style: TextStyle(
                                fontSize:   12,
                                color:      Colors.grey[600],
                                fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),

                    // ── Drill-down (animated) ────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve:    Curves.easeInOut,
                      child:    widget.expanded
                          ? _buildDrillDown()
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrillDown() {
    if (widget.drillLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final tasks = widget.drillTasks ?? [];
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('No completed tasks',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        // Table header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(children: [
            const Expanded(child: Text('TASK',    style: _kHeaderStyle)),
            SizedBox(width: 42, child: Text('PLAN',   textAlign: TextAlign.center, style: _kHeaderStyle)),
            SizedBox(width: 48, child: Text('ACTUAL', textAlign: TextAlign.center, style: _kHeaderStyle)),
            SizedBox(width: 54, child: Text('DRIFT',  textAlign: TextAlign.right,  style: _kHeaderStyle)),
          ]),
        ),
        ...tasks.asMap().entries.map(
          (e) => _AnimatedTaskRow(task: e.value, index: e.key)),
      ],
    );
  }
}

// ── Animated task row ─────────────────────────────────────────────────────────

class _AnimatedTaskRow extends StatefulWidget {
  final _PerfTask task;
  final int       index;
  const _AnimatedTaskRow({required this.task, required this.index});

  @override
  State<_AnimatedTaskRow> createState() => _AnimatedTaskRowState();
}

class _AnimatedTaskRowState extends State<_AnimatedTaskRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(-0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(
      Duration(milliseconds: 30 * widget.index),
      () { if (mounted) _ctrl.forward(); },
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: widget.index.isEven
                ? Colors.transparent
                : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                  color: t.driftColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t.title,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 42,
              child: Text(
                t.plannedDays != null ? '${t.plannedDays}d' : '–',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
            SizedBox(
              width: 48,
              child: Text(
                t.actualDays != null ? '${t.actualDays}d' : '–',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              width: 54,
              child: Text(t.driftLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color:      t.driftColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Small stat tile inside the perf card ─────────────────────────────────────

class _PerfStatTile extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _PerfStatTile(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ]),
    );
  }
}

class _PerfVertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.grey.shade200);
}
