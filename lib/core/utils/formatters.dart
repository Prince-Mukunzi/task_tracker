import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../models/enums.dart';

String formatTimeLeft(Duration d) {
  if (d.isNegative) {
    final abs = d.abs();
    if (abs.inDays > 0) return '${abs.inDays}d overdue';
    if (abs.inHours > 0) return '${abs.inHours}h overdue';
    return '${abs.inMinutes}m overdue';
  }
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h left';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m left';
}

String formatCountdown(Duration d) {
  if (d.isNegative) {
    final abs = d.abs();
    if (abs.inDays > 0) return '${abs.inDays}d ${abs.inHours % 24}h overdue';
    if (abs.inHours > 0) return '${abs.inHours}h ${abs.inMinutes % 60}m overdue';
    return '${abs.inMinutes}m overdue';
  }
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h left';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m left';
  return '${d.inMinutes}m left';
}

String formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String formatDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, $hour:$minute $period';
}

String priorityLabel(Priority p) {
  switch (p) {
    case Priority.high: return 'High';
    case Priority.medium: return 'Medium';
    case Priority.low: return 'Low';
  }
}

String taskStatusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.open: return 'Open';
    case TaskStatus.inProgress: return 'In Progress';
    case TaskStatus.inReview: return 'In Review';
    case TaskStatus.blocked: return 'Blocked';
    case TaskStatus.done: return 'Done';
  }
}

Color taskStatusColor(TaskStatus s) {
  switch (s) {
    case TaskStatus.open: return AppColors.textSecondary;
    case TaskStatus.inProgress: return AppColors.atRisk;
    case TaskStatus.inReview: return const Color(0xFF64B5F6);
    case TaskStatus.blocked: return AppColors.overdue;
    case TaskStatus.done: return AppColors.onTrack;
  }
}

String slaStatusLabel(SLAStatus status) {
  switch (status) {
    case SLAStatus.onTrack: return 'On Track';
    case SLAStatus.atRisk: return 'At Risk';
    case SLAStatus.overdue: return 'Overdue';
    case SLAStatus.completed: return 'Completed';
  }
}

String initialsFrom(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.substring(0, trimmed.length < 2 ? trimmed.length : 2).toUpperCase();
}
