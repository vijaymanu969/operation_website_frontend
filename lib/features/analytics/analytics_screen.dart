import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
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
