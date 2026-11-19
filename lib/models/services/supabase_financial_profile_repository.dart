import 'package:supabase_flutter/supabase_flutter.dart';

import '../financial_profile.dart';
import 'finance_repository.dart';
import 'financial_profile_repository.dart';
import 'supabase_profile_details_repository.dart';

class SupabaseFinancialProfileRepository implements FinancialProfileRepository {
  final SupabaseClient _client;

  SupabaseFinancialProfileRepository(this._client);

  @override
  Future<FinancialProfileState> loadProfiles() async {
    final userId = _requireUserId();
    try {
      _checkSession(userId);
      final response = await _client.rpc('ensure_financial_profiles');
      _checkSession(userId);
      if (response is! Map<String, dynamic> ||
          response['profiles'] is! List ||
          response['active_profile_id'] is! String) {
        throw const FormatException('Seleção de perfis inválida.');
      }
      final profiles = (response['profiles'] as List).map((row) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Dados do perfil inválidos.');
        }
        final profile = FinancialProfile.fromJson(row);
        if (profile.userId != userId) {
          throw const FinanceException(
            'Não foi possível carregar seus perfis.',
          );
        }
        return profile;
      }).toList();
      final state = FinancialProfileState(
        profiles: profiles,
        activeProfileId: response['active_profile_id'] as String,
      );
      final resolved = await Future.wait(
        state.profiles.map(
          (profile) => SupabaseProfileDetailsRepository.resolveAvatarUrl(
            _client,
            profile,
          ),
        ),
      );
      _checkSession(userId);
      return FinancialProfileState(
        profiles: resolved,
        activeProfileId: state.activeProfileId,
      );
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível carregar seus perfis. Tente novamente.',
      );
    }
  }

  @override
  Future<void> selectProfile(String profileId) async {
    final userId = _requireUserId();
    _validateId(profileId);
    try {
      _checkSession(userId);
      // O RPC de carregamento já garantiu a preferência desta conta.
      final row = await _client
          .from('financial_profile_preferences')
          .update({'active_profile_id': profileId})
          .eq('user_id', userId)
          .select('user_id,active_profile_id')
          .single();
      _checkSession(userId);
      if (row['user_id'] != userId || row['active_profile_id'] != profileId) {
        throw const FinanceException('Não foi possível confirmar o perfil.');
      }
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível trocar de perfil. Tente novamente.',
      );
    }
  }

  @override
  Future<FinancialProfile> renameBusiness({
    required String profileId,
    required String name,
  }) async {
    final userId = _requireUserId();
    _validateId(profileId);
    final normalizedName = name.trim();
    if (profileId == FinancialProfile.personalId ||
        normalizedName.isEmpty ||
        normalizedName.length > 60) {
      throw const FinanceException(
        'Informe um nome de empresa entre 1 e 60 caracteres.',
      );
    }
    try {
      _checkSession(userId);
      final row = await _client
          .from('financial_profiles')
          .update({'name': normalizedName})
          .eq('user_id', userId)
          .eq('id', profileId)
          .eq('kind', FinancialProfileKind.business.name)
          .select()
          .single();
      _checkSession(userId);
      final profile = FinancialProfile.fromJson(row);
      if (profile.userId != userId ||
          profile.id != profileId ||
          profile.kind != FinancialProfileKind.business ||
          row['name'] != normalizedName) {
        throw const FinanceException(
          'Não foi possível confirmar o nome da empresa.',
        );
      }
      final resolved = await SupabaseProfileDetailsRepository.resolveAvatarUrl(
        _client,
        profile,
      );
      _checkSession(userId);
      return resolved;
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível alterar o nome da empresa. Tente novamente.',
      );
    }
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const FinanceException('Entre na sua conta para continuar.');
    }
    return user.id;
  }

  void _checkSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const FinanceException('Sua sessão mudou. Entre novamente.');
    }
  }

  void _validateId(String profileId) {
    if (profileId.trim().isEmpty || profileId != profileId.trim()) {
      throw const FinanceException('Escolha um perfil válido.');
    }
  }
}
