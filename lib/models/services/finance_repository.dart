import '../finance_transaction.dart';

// O usuário vem da sessão autenticada, nunca de um campo do formulário.
abstract interface class FinanceRepository {
  Future<List<FinanceTransaction>> loadTransactions();

  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  });

  // A Home escuta mudanças de outro dispositivo e recarrega os dados.
  Stream<void> get changes;
}

class FinanceException implements Exception {
  final String message;
  const FinanceException(this.message);

  @override
  String toString() => message;
}
