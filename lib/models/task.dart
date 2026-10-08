import 'package:hive/hive.dart';
import 'package:sla_tracker/models/enums.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime deadline;

  @HiveField(5)
  final String assignedTo; // team member id

  @HiveField(6)
  final Priority priority; // 'high', 'medium', 'low'

  @HiveField(7)
  final bool isCompleted;

  @HiveField(8, defaultValue: <String>[])
  final List<String> tags;

  @HiveField(9)
  final TaskStatus status;

  // Constructor
  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.deadline,
    required this.assignedTo,
    required this.priority,
    required this.isCompleted,
    this.tags = const [],
    this.status = TaskStatus.open,
  });

  // Copy method to create a new task with updated values
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? deadline,
    String? assignedTo,
    Priority? priority,
    bool? isCompleted,
    List<String>? tags,
    TaskStatus? status,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      assignedTo: assignedTo ?? this.assignedTo,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      tags: tags ?? this.tags,
      status: status ?? this.status,
    );
  }

  List<String> get assigneeIds =>
      assignedTo.split(',').where((s) => s.isNotEmpty).toList();

  SLAStatus get slaStatus {
    if (isCompleted) return SLAStatus.completed;

    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) return SLAStatus.overdue;
    if (difference.inHours < 24) return SLAStatus.atRisk;

    return SLAStatus.onTrack;
  }
}
