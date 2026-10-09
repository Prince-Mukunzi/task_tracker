import 'package:hive/hive.dart';
import 'package:task_tracker/models/task.dart';

class TaskRepository {
  Box<Task> get _box => Hive.box<Task>('tasks');

  List<Task> getAllTasks() {
    return _box.values.toList();
  }

  Task? getTaskById(String id) {
    try {
      return _box.values.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveTask(Task task) async {
    await _box.put(task.id, task);
  }

  Future<void> updateTask(Task task) async {
    await _box.put(task.id, task);
  }

  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  Stream<BoxEvent> watchTasks() => _box.watch();
}
