import 'dart:convert';
import 'package:hive/hive.dart';

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorInitials;
  final String content;
  final DateTime createdAt;
  final List<String> mentions;

  Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorInitials,
    required this.content,
    required this.createdAt,
    this.mentions = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorInitials': authorInitials,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'mentions': mentions,
      };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        authorInitials: json['authorInitials'] as String? ?? '',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        mentions: (json['mentions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class CommentRepository {
  Box<String> get _box => Hive.box<String>('task_comments');

  List<Comment> getComments(String taskId) {
    final raw = _box.get(taskId);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addComment(String taskId, Comment comment) async {
    final existing = getComments(taskId);
    existing.add(comment);
    await _box.put(
      taskId,
      jsonEncode(existing.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> deleteComment(String taskId, String commentId) async {
    final existing = getComments(taskId);
    existing.removeWhere((c) => c.id == commentId);
    await _box.put(
      taskId,
      jsonEncode(existing.map((c) => c.toJson()).toList()),
    );
  }
}
