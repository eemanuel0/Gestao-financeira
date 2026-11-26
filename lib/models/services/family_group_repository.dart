class FamilyMember {
  final String userId;
  final String name;

  const FamilyMember({required this.userId, required this.name});
}

abstract interface class FamilyGroupRepository {
  Future<void> createGroup();
  Future<void> joinGroup(String code);
  Future<String> createInvite();
  Future<List<FamilyMember>> loadMembers();
  Future<void> removeMember(String userId);
  Future<void> leaveGroup();
}
