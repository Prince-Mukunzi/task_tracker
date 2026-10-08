import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/comment_repository.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

final commentsProvider =
    Provider.family<List<Comment>, String>((ref, taskId) {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.getComments(taskId);
});
