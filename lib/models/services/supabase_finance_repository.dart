import 'package:supabase_flutter/supabase_flutter.dart';

import '../finance_transaction.dart';
import 'finance_repository.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  final SupabaseClient _client;
  static const int _pageSize = 500;

  SupabaseFinanceRepository(this._client);

  // Reconsulta a nuvem sem depender da ativação do Supabase Realtime.
  @override
  Stream<void> get changes =>
      Stream<void>.periodic(const Duration(seconds: 30), (_) {});

  @override
  Future<List<FinanceTransaction>> loadTransactions() async {
    final userId = _requireUserId();
    final result = <FinanceTransaction>[];
    var offset = 0;

    try {
      while (true) {
        _checkSession(userId);
        final page = await _client
            .from('transactions')
            .select()
            .eq('user_id', userId)
            .order('occurred_on', ascending: false)
            .order('created_at', ascending: false)
            .order('id')
            .range(offset, offset + _pageSize - 1);
        _checkSession(userId);

        for (final row in page) {
          final transaction = FinanceTransaction.fromJson(row);
          if (transaction.userId != userId) {
            throw const FinanceException(
              'Não foi possível carregar seus dados.',
            );
          }
          result.add(transaction);
        }
        if (page.length < _pageSize) break;
        offset += _pageSize;
      }
      return List.unmodifiable(result);
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível carregar seus lançamentos. Tente novamente.',
      );
    }
  }

  @override
  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  }) async {
    final userId = _requireUserId();
    try {
      // Usa a mesma validação dos registros lidos, antes de enviar à nuvem.
      final transaction = FinanceTransaction(
        id: 'pending',
        userId: userId,
        type: type,
        amountCents: amountCents,
        category: category,
        description: description.trim(),
        occurredOn: occurredOn,
        createdAt: DateTime.now().toUtc(),
      );
      final payload = transaction.toJson()
        ..remove('id')
        ..remove('created_at');

      _checkSession(userId);
      await _client.from('transactions').insert(payload);
      _checkSession(userId);
    } on FinanceException {
      rethrow;
    } on ArgumentError {
      throw const FinanceException('Confira os dados do lançamento.');
    } catch (_) {
      throw const FinanceException(
        'Não foi possível salvar o lançamento. Confira sua conexão.',
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
}
