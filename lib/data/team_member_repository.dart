import 'package:hive_flutter/hive_flutter.dart';

import '../models/team_member.dart';

class TeamMemberRepository {
  Box<TeamMember> get _box => Hive.box<TeamMember>('teamMembers');

  List<TeamMember> getAllMembers() {
    return _box.values.toList();
  }

  TeamMember? getMemberById(String id) {
    try {
      return _box.values.firstWhere((member) => member.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMember(TeamMember member) async {
    await _box.put(member.id, member);
  }

  Future<void> deleteMember(String id) async {
    await _box.delete(id);
  }

  // Seed some initial team members so the app isn't empty on first launch
  Future<void> seedIfEmpty() async {
    if (_box.isNotEmpty) return; // Already has data — don't overwrite

    final initialMembers = [
      TeamMember(
        id: 'member_1',
        name: 'Mukunzi',
        role: 'Product Lead',
        avatarInitials: 'MK',
      ),
      TeamMember(
        id: 'member_2',
        name: 'Aline',
        role: 'Frontend Dev',
        avatarInitials: 'AL',
      ),
      TeamMember(
        id: 'member_3',
        name: 'David',
        role: 'Backend Dev',
        avatarInitials: 'DV',
      ),
    ];

    for (final member in initialMembers) {
      await saveMember(member);
    }
  }
}
