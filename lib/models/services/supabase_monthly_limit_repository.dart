import 'package:supabase_flutter/supabase_flutter.dart';

import '../monthly_limit.dart';
import '../financial_profile.dart';
import 'finance_repository.dart';
import 'monthly_limit_repository.dart';

class SupabaseMonthlyLimitRepository implements MonthlyLimitRepository {
  final SupabaseClient _client;
  final String profileId;

  SupabaseMonthlyLimitRepository(
    this._client, {
    this.profileId = FinancialProfile.personalId,
  }) {
    if (profileId.trim().isEmpty || profileId != profileId.trim()) {
      throw ArgumentError('O repositório precisa de um perfil válido.');
    }
  }

  @override
  Future<MonthlyLimit?> loadForMonth(DateTime month) async {
    final userId = _requireUserId();
    try {
      final monthKey = MonthlyLimit.formatMonth(month);
      _checkSession(userId);
      final row = await _client
          .from('monthly_limits')
          .select('user_id,profile_id,month,limit_cents')
          .eq('user_id', userId)
          .eq('profile_id', profileId)
          .eq('month', monthKey)
          .maybeSingle();
      _checkSession(userId);
      if (row == null) return null;
      return _validateResponse(row, userId, monthKey);
    } on FinanceException {
      rethrow;
    } on ArgumentError {
      throw const FinanceException('Confira o mês do limite.');
    } catch (_) {
      throw const FinanceException(
        'Não foi possível carregar o limite mensal. Tente novamente.',
      );
    }
  }

  @override
  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  }) async {
    final userId = _requireUserId();
    try {
      final limit = MonthlyLimit(
        userId: userId,
        profileId: profileId,
        month: month,
        limitCents: limitCents,
      );
      _checkSession(userId);
      // A chave composta mantém apenas um limite para cada usuário e mês.
      final row = await _client
          .from('monthly_limits')
          .upsert(limit.toJson(), onConflict: 'user_id,profile_id,month')
          .select('user_id,profile_id,month,limit_cents')
          .single();
      _checkSession(userId);
      return _validateResponse(
        row,
        userId,
        limit.monthKey,
        expectedCents: limitCents,
      );
    } on FinanceException {
      rethrow;
    } on ArgumentError {
      throw const FinanceException(
        'Informe um limite mensal válido e positivo.',
      );
    } catch (_) {
      throw const FinanceException(
        'Não foi possível salvar o limite mensal. Tente novamente.',
      );
    }
  }

  MonthlyLimit _validateResponse(
    Map<String, dynamic> row,
    String userId,
    String monthKey, {
    int? expectedCents,
  }) {
    final limit = MonthlyLimit.fromJson(row);
    if (limit.userId != userId ||
        limit.profileId != profileId ||
        limit.monthKey != monthKey ||
        (expectedCents != null && limit.limitCents != expectedCents)) {
      throw const FinanceException('Não foi possível confirmar seu limite.');
    }
    return limit;
  }

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const FinanceException('Entre na sua conta para continuar.');
    }
    return user.id;
  }

  void _checkSession(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const FinanceException('Sua sessão mudou. Entre novamente.');
    }
  }
}
