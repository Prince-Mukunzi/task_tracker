import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/task_repository.dart';
import '../models/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final tasksProvider = Provider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getAllTasks();
});
