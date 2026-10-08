import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/team_member_repository.dart';
import '../models/team_member.dart';

final teamMemberRepositoryProvider = Provider<TeamMemberRepository>((ref) {
  return TeamMemberRepository();
});

// Returns the full list of team members from local storage.
// Seeding now happens in main.dart so we don't need to do it here.
final teamMembersProvider = Provider<List<TeamMember>>((ref) {
  final repo = ref.watch(teamMemberRepositoryProvider);
  return repo.getAllMembers();
});

// Holds the currently logged-in user. Set during onboarding
// or restored from Hive in the AppGate.
final currentUserProvider = StateProvider<TeamMember?>((ref) => null);
