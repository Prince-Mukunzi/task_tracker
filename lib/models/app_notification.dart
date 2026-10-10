
enum NotificationType {
  taskCreated,
  taskUpdated,
  taskCompleted,
  atRisk,
  overdue,
  mention,
}


class AppNotification {
  final int? id;
  final String title;
  final String body;
  final NotificationType type;
  final String? taskId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    this.taskId,
    this.isRead = false,
    required this.createdAt,
  });


  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'task_id': taskId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, Object?> map) {
    return AppNotification(
      id: map['id'] as int?,
      title: map['title'] as String,
      body: map['body'] as String,
      type: _typeFromName(map['type'] as String),
      taskId: map['task_id'] as String?,
      isRead: (map['is_read'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }


  static NotificationType _typeFromName(String name) {
    return NotificationType.values.firstWhere(
          (type) => type.name == name,
      orElse: () => NotificationType.taskUpdated,
    );
  }
}
