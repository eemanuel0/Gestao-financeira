import 'package:supabase_flutter/supabase_flutter.dart';

import 'family_group_repository.dart';
import 'finance_repository.dart';

class SupabaseFamilyGroupRepository implements FamilyGroupRepository {
  final SupabaseClient _client;

  SupabaseFamilyGroupRepository(this._client);

  @override
  Future<void> createGroup() async {
    await _call('create_family_group');
  }

  @override
  Future<void> joinGroup(String code) async {
    await _call('join_family_group', {'invite_code': code});
  }

  @override
  Future<String> createInvite() async {
    final code = await _call('create_family_invite');
    if (code is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
      return code;
    }
    throw const FinanceException('Não foi possível confirmar o convite.');
  }

  @override
  Future<List<FamilyMember>> loadMembers() async {
    final response = await _call('list_family_members');
    if (response is! List) {
      throw const FinanceException('Não foi possível carregar os membros.');
    }
    final members = <FamilyMember>[];
    for (final row in response) {
      if (row case {'user_id': final String id, 'name': final String name}) {
        members.add(FamilyMember(userId: id, name: name));
      } else {
        throw const FinanceException('Não foi possível carregar os membros.');
      }
    }
    return members;
  }

  @override
  Future<void> removeMember(String userId) async {
    await _call('remove_family_member', {'member_id': userId});
  }

  @override
  Future<void> leaveGroup() async {
    await _call('leave_family_group');
  }

  Future<dynamic> _call(String function, [Map<String, dynamic>? params]) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const FinanceException('Entre na sua conta para continuar.');
    }
    try {
      final response = await _client.rpc(function, params: params);
      if (_client.auth.currentUser?.id != userId) {
        throw const FinanceException('Sua sessão mudou. Entre novamente.');
      }
      return response;
    } on PostgrestException catch (error) {
      throw FinanceException(switch (error.code) {
        '22023' => 'Informe um código de convite válido.',
        'P0001' => 'Você já participa de um grupo familiar.',
        'P0002' => 'Este convite venceu ou já foi utilizado.',
        '42501' => 'Sua conta não tem acesso a esta ação.',
        _ => 'Não foi possível atualizar o grupo. Tente novamente.',
      });
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível atualizar o grupo. Confira sua conexão.',
      );
    }
  }
}
