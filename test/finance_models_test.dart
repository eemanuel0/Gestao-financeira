import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/finance_summary.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';

FinanceTransaction transaction({
  String id = 'transaction-1',
  TransactionType type = TransactionType.expense,
  int amountCents = 100,
  TransactionCategory category = TransactionCategory.food,
  String description = 'Mercado',
}) {
  return FinanceTransaction(
    id: id,
    userId: 'user-1',
    type: type,
    amountCents: amountCents,
    category: category,
    description: description,
    occurredOn: DateTime(2026, 11, 16),
    createdAt: DateTime.utc(2026, 11, 16, 12),
  );
}

void main() {
  group('FinanceTransaction', () {
    test('preserva centavos e datas no contrato do banco', () {
      final original = transaction(amountCents: 123456);
      final json = original.toJson();
      final restored = FinanceTransaction.fromJson(json);

      expect(json['amount_cents'], 123456);
      expect(json['occurred_on'], '2026-11-16');
      expect(json['created_at'], '2026-11-16T12:00:00.000Z');
      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.type, original.type);
      expect(restored.amountCents, original.amountCents);
      expect(restored.category, original.category);
      expect(restored.description, original.description);
      expect(restored.occurredOn, original.occurredOn);
      expect(restored.createdAt, original.createdAt);
    });

    test('exige valor positivo dentro do limite', () {
      for (final cents in [0, -1, FinanceTransaction.maxAmountCents + 1]) {
        expect(() => transaction(amountCents: cents), throwsArgumentError);
      }
      expect(
        transaction(amountCents: FinanceTransaction.maxAmountCents).amountCents,
        FinanceTransaction.maxAmountCents,
      );
    });

    test('exige descrição e categoria compatível com o tipo', () {
      expect(() => transaction(description: '  '), throwsArgumentError);
      expect(
        () => transaction(description: List.filled(121, 'a').join()),
        throwsArgumentError,
      );
      expect(
        () => transaction(category: TransactionCategory.salary),
        throwsArgumentError,
      );
      expect(
        () => transaction(type: TransactionType.income),
        throwsArgumentError,
      );
      expect(() => transaction(id: ''), throwsArgumentError);
    });

    test('rejeita dados do banco com tipo, categoria ou valor inválidos', () {
      final valid = transaction().toJson();
      for (final invalid in [
        {...valid, 'type': 'invalid'},
        {...valid, 'category': 'invalid'},
        {...valid, 'amount_cents': 1.5},
        {...valid, 'occurred_on': 'sem-data'},
        {...valid, 'user_id': null},
      ]) {
        expect(
          () => FinanceTransaction.fromJson(invalid),
          throwsFormatException,
        );
      }
    });

    test('separa categorias de receita e despesa', () {
      expect(TransactionCategory.allowedFor(TransactionType.income), [
        TransactionCategory.salary,
        TransactionCategory.services,
        TransactionCategory.other,
      ]);
      expect(
        TransactionCategory.allowedFor(TransactionType.expense),
        containsAll([
          TransactionCategory.food,
          TransactionCategory.housing,
          TransactionCategory.transport,
          TransactionCategory.health,
          TransactionCategory.leisure,
          TransactionCategory.other,
        ]),
      );
      expect(
        TransactionCategory.allowedFor(TransactionType.expense),
        isNot(contains(TransactionCategory.salary)),
      );
    });
  });

  group('FinanceSummary', () {
    test('uma conta sem lançamentos começa zerada e sem categorias', () {
      final summary = FinanceSummary.fromTransactions([]);
      expect(summary.incomeCents, 0);
      expect(summary.expenseCents, 0);
      expect(summary.balanceCents, 0);
      expect(summary.categories, isEmpty);
    });

    test('soma em centavos e calcula categorias somente pelas despesas', () {
      final summary = FinanceSummary.fromTransactions([
        transaction(
          id: 'income-1',
          type: TransactionType.income,
          amountCents: 10000,
          category: TransactionCategory.salary,
        ),
        transaction(id: 'food-1', amountCents: 1000),
        transaction(id: 'food-2', amountCents: 2000),
        transaction(
          id: 'housing-1',
          amountCents: 1000,
          category: TransactionCategory.housing,
        ),
      ]);

      expect(summary.incomeCents, 10000);
      expect(summary.expenseCents, 4000);
      expect(summary.balanceCents, 6000);
      expect(summary.categories.length, 2);
      expect(summary.categories[0].name, 'Alimentação');
      expect(summary.categories[0].percentage, 75);
      expect(summary.categories[1].name, 'Moradia');
      expect(summary.categories[1].percentage, 25);
    });

    test('receitas sozinhas não criam categorias de gastos', () {
      final summary = FinanceSummary.fromTransactions([
        transaction(
          type: TransactionType.income,
          category: TransactionCategory.services,
          amountCents: 29,
        ),
      ]);
      expect(summary.balanceCents, 29);
      expect(summary.categories, isEmpty);
    });

    test('despesas podem produzir saldo negativo sem perder centavos', () {
      final summary = FinanceSummary.fromTransactions([
        transaction(id: 'expense-1', amountCents: 10),
        transaction(id: 'expense-2', amountCents: 20),
      ]);
      expect(summary.balanceCents, -30);
      expect(summary.categories.single.percentage, 100);
    });
  });
}
