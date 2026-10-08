import 'package:hive/hive.dart';

part 'team_member.g.dart';

@HiveType(typeId: 1)
class TeamMember {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String role;

  @HiveField(3)
  final String avatarInitials;

  @HiveField(4, defaultValue: '')
  final String email;

  TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarInitials,
    this.email = '',
  });

  TeamMember copyWith({
    String? id,
    String? name,
    String? role,
    String? avatarInitials,
    String? email,
  }) {
    return TeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      email: email ?? this.email,
    );
  }
}
