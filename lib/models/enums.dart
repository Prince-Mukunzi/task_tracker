import 'package:hive/hive.dart';

part 'enums.g.dart';

@HiveType(typeId: 2)
enum Priority {
  @HiveField(0)
  high,

  @HiveField(1)
  medium,

  @HiveField(2)
  low,
}

@HiveType(typeId: 3)
enum TaskStatus {
  @HiveField(0)
  open,

  @HiveField(1)
  inProgress,

  @HiveField(2)
  inReview,

  @HiveField(3)
  blocked,

  @HiveField(4)
  done,
}

enum SLAStatus { onTrack, atRisk, overdue, completed }
