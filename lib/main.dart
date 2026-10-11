import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/team_member_repository.dart';
import 'models/enums.dart';
import 'models/task.dart';
import 'models/team_member.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive and register adapters for local storage
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TeamMemberAdapter());
  Hive.registerAdapter(PriorityAdapter());
  Hive.registerAdapter(TaskStatusAdapter());

  await Hive.openBox<Task>('tasks');
  await Hive.openBox<TeamMember>('teamMembers');
  await Hive.openBox<String>('task_comments');

  // Pre-populate team members if the box is empty
  final teamRepo = TeamMemberRepository();
  await teamRepo.seedIfEmpty();

  runApp(const ProviderScope(child: SlaTrackerApp()));
}
