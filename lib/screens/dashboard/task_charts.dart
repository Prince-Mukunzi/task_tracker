import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../models/task.dart';

/// Dashboard card with two charts:
///  1. Donut  – tasks by SLA status (on track / at risk / overdue / done)
///  2. Bars   – tasks by workflow status (open / in progress / ...)
class TaskCharts extends StatelessWidget {
  final List<Task> tasks;

  const TaskCharts({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final sla = <SLAStatus, int>{for (final s in SLAStatus.values) s: 0};
    final workflow = <TaskStatus, int>{for (final s in TaskStatus.values) s: 0};
    for (final t in tasks) {
      sla[t.slaStatus] = sla[t.slaStatus]! + 1;
      workflow[t.status] = workflow[t.status]! + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: AppTypography.headingSmall),
          const SizedBox(height: 16),
          _SlaDonut(counts: sla, total: tasks.length),
          const SizedBox(height: 24),
          Text('By status',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _StatusBars(counts: workflow),
        ],
      ),
    );
  }
}

String _slaLabel(SLAStatus s) {
  switch (s) {
    case SLAStatus.onTrack:
      return 'On track';
    case SLAStatus.atRisk:
      return 'At risk';
    case SLAStatus.overdue:
      return 'Overdue';
    case SLAStatus.completed:
      return 'Done';
  }
}

String _statusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.open:
      return 'Open';
    case TaskStatus.inProgress:
      return 'Active';
    case TaskStatus.inReview:
      return 'Review';
    case TaskStatus.blocked:
      return 'Blocked';
    case TaskStatus.done:
      return 'Done';
  }
}

class _SlaDonut extends StatelessWidget {
  final Map<SLAStatus, int> counts;
  final int total;

  const _SlaDonut({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList();

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 42,
                  startDegreeOffset: -90,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: AppColors.statusColor(e.key),
                        radius: 16,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total', style: AppTypography.headingLarge),
                  Text('tasks', style: AppTypography.labelSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              for (final s in SLAStatus.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.statusColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_slaLabel(s),
                            style: AppTypography.bodyMedium),
                      ),
                      Text('${counts[s]}',
                          style: AppTypography.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBars extends StatelessWidget {
  final Map<TaskStatus, int> counts;

  const _StatusBars({required this.counts});

  @override
  Widget build(BuildContext context) {
    final statuses = TaskStatus.values;
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: (maxCount + 1).toDouble(),
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= statuses.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_statusLabel(statuses[i]),
                        style: AppTypography.labelSmall),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < statuses.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[statuses[i]]!.toDouble(),
                    width: 22,
                    color: statuses[i] == TaskStatus.blocked
                        ? AppColors.overdue
                        : statuses[i] == TaskStatus.done
                            ? AppColors.onTrack
                            : AppColors.accentDim,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}