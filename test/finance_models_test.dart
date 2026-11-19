import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/finance_summary.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/financial_profile.dart';

FinanceTransaction transaction({
  String id = 'transaction-1',
  String userId = 'user-1',
  String profileId = FinancialProfile.personalId,
  TransactionType type = TransactionType.expense,
  int amountCents = 100,
  TransactionCategory category = TransactionCategory.food,
  String description = 'Mercado',
  DateTime? occurredOn,
}) {
  return FinanceTransaction(
    id: id,
    userId: userId,
    profileId: profileId,
    type: type,
    amountCents: amountCents,
    category: category,
    description: description,
    occurredOn: occurredOn ?? DateTime(2026, 11, 16),
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
      expect(json['profile_id'], FinancialProfile.personalId);
      expect(json['occurred_on'], '2026-11-16');
      expect(json['created_at'], '2026-11-16T12:00:00.000Z');
      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.profileId, original.profileId);
      expect(restored.type, original.type);
      expect(restored.amountCents, original.amountCents);
      expect(restored.category, original.category);
      expect(restored.description, original.description);
      expect(restored.occurredOn, original.occurredOn);
      expect(restored.createdAt, original.createdAt);
    });

    test(
      'dados legados pertencem ao pessoal e perfis inválidos são rejeitados',
      () {
        final legacy = transaction().toJson()..remove('profile_id');
        expect(
          FinanceTransaction.fromJson(legacy).profileId,
          FinancialProfile.personalId,
        );
        final business = transaction(profileId: FinancialProfile.businessId);
        expect(
          FinanceTransaction.fromJson(business.toJson()).profileId,
          FinancialProfile.businessId,
        );
        for (final value in [null, '', '   ', 42, ' personal ']) {
          expect(
            () => FinanceTransaction.fromJson({...legacy, 'profile_id': value}),
            throwsFormatException,
          );
        }
        expect(() => transaction(profileId: ''), throwsArgumentError);
      },
    );

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

  group('FinancialProfile', () {
    FinancialProfile profile(
      String id, {
      String userId = 'user-1',
      String name = 'Empresa',
    }) {
      return FinancialProfile(
        id: id,
        userId: userId,
        name: name,
        kind: id == FinancialProfile.personalId
            ? FinancialProfileKind.personal
            : FinancialProfileKind.business,
      );
    }

    test(
      'preserva nome personalizado e seleciona perfil em lista imutável',
      () {
        final business = profile(
          FinancialProfile.businessId,
          name: '  Minha loja  ',
        );
        final state = FinancialProfileState(
          profiles: [
            profile(FinancialProfile.personalId, name: 'Pessoal'),
            business,
          ],
          activeProfileId: FinancialProfile.businessId,
        );
        expect(state.activeProfile.name, 'Minha loja');
        expect(FinancialProfile.fromJson(business.toJson()).name, 'Minha loja');
        expect(state.profiles.clear, throwsUnsupportedError);
      },
    );

    test('rejeita dono misturado, seleção inexistente e IDs repetidos', () {
      final personal = profile(FinancialProfile.personalId);
      final business = profile(FinancialProfile.businessId);
      for (final entries in [
        [personal, personal, business],
        [personal, profile(FinancialProfile.businessId, userId: 'user-2')],
        [personal],
      ]) {
        expect(
          () => FinancialProfileState(
            profiles: entries,
            activeProfileId: FinancialProfile.personalId,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => FinancialProfileState(
          profiles: [personal, business],
          activeProfileId: 'missing',
        ),
        throwsArgumentError,
      );
    });

    test('valida nome e compatibilidade entre ID pessoal e tipo', () {
      expect(
        () => profile(FinancialProfile.businessId, name: ' '),
        throwsArgumentError,
      );
      expect(
        () => profile(
          FinancialProfile.businessId,
          name: List.filled(61, 'a').join(),
        ),
        throwsArgumentError,
      );
      expect(
        () => FinancialProfile.fromJson({
          'id': 'personal',
          'user_id': 'user-1',
          'name': 'Pessoal',
          'kind': 'business',
        }),
        throwsFormatException,
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
      expect(summary.expenseTotals, isEmpty);
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
      expect(summary.expenseTotals, {
        TransactionCategory.food: 3000,
        TransactionCategory.housing: 1000,
      });
      expect(summary.expenseTotals.keys, [
        TransactionCategory.food,
        TransactionCategory.housing,
      ]);
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
      expect(summary.expenseTotals, isEmpty);
    });

    test('despesas podem produzir saldo negativo sem perder centavos', () {
      final summary = FinanceSummary.fromTransactions([
        transaction(id: 'expense-1', amountCents: 10),
        transaction(id: 'expense-2', amountCents: 20),
      ]);
      expect(summary.balanceCents, -30);
      expect(summary.expenseCents, 30);
      expect(summary.expenseTotals, {TransactionCategory.food: 30});
      expect(summary.categories.single.percentage, 100);
    });

    test('uma despesa de R\$ 200 gera somente os gastos registrados', () {
      final summary = FinanceSummary.fromTransactions([
        transaction(amountCents: 20000),
        transaction(
          id: 'income-1',
          type: TransactionType.income,
          amountCents: 100000,
          category: TransactionCategory.salary,
        ),
      ]);
      expect(summary.expenseCents, 20000);
      expect(summary.expenseTotals, {TransactionCategory.food: 20000});
      expect(summary.categories.single.name, TransactionCategory.food.label);
      expect(summary.categories.single.percentage, 100);
    });

    test('filtra o mês, o ano e o proprietário pela data do lançamento', () {
      final transactions = [
        transaction(id: 'november-2026', amountCents: 20000),
        transaction(
          id: 'income-2026',
          type: TransactionType.income,
          amountCents: 50000,
          category: TransactionCategory.salary,
        ),
        transaction(
          id: 'october-2026',
          amountCents: 5000,
          occurredOn: DateTime(2026, 10, 31),
        ),
        transaction(
          id: 'november-2025',
          amountCents: 7000,
          occurredOn: DateTime(2025, 11, 16),
        ),
        transaction(id: 'other-user', userId: 'user-2', amountCents: 80000),
        transaction(
          id: 'business-expense',
          profileId: FinancialProfile.businessId,
          amountCents: 3000,
        ),
        transaction(
          id: 'business-income',
          profileId: FinancialProfile.businessId,
          type: TransactionType.income,
          category: TransactionCategory.services,
          amountCents: 100000,
        ),
      ];
      final november = FinanceSummary.forMonth(
        transactions,
        userId: 'user-1',
        month: DateTime(2026, 11, 30, 23, 59),
      );
      expect(november.expenseCents, 20000);
      expect(november.incomeCents, 50000);
      expect(november.expenseTotals, {TransactionCategory.food: 20000});
      final business = FinanceSummary.forMonth(
        transactions,
        userId: 'user-1',
        month: DateTime(2026, 11),
        profileId: FinancialProfile.businessId,
      );
      expect(business.expenseCents, 3000);
      expect(business.incomeCents, 100000);
      expect(business.balanceCents, 97000);

      final october = FinanceSummary.forMonth(
        transactions,
        userId: 'user-1',
        month: DateTime(2026, 10),
      );
      expect(october.expenseCents, 5000);
      expect(october.incomeCents, 0);
      final previousYear = FinanceSummary.forMonth(
        transactions,
        userId: 'user-1',
        month: DateTime(2025, 11),
      );
      expect(previousYear.expenseCents, 7000);
    });

    test('mantém o total de todo o histórico usado pela Home', () {
      final transactions = [
        transaction(amountCents: 20000),
        transaction(
          id: 'october',
          amountCents: 5000,
          occurredOn: DateTime(2026, 10),
        ),
      ];
      expect(FinanceSummary.fromTransactions(transactions).expenseCents, 25000);
      expect(
        FinanceSummary.forMonth(
          transactions,
          userId: 'user-1',
          month: DateTime(2026, 11),
        ).expenseCents,
        20000,
      );
    });

    test('um mês sem dados não recebe valores nem categorias de exemplo', () {
      final summary = FinanceSummary.forMonth(
        [transaction(amountCents: 20000)],
        userId: 'user-1',
        month: DateTime(2026, 12),
      );
      expect(summary.expenseCents, 0);
      expect(summary.incomeCents, 0);
      expect(summary.balanceCents, 0);
      expect(summary.expenseTotals, isEmpty);
      expect(summary.categories, isEmpty);
    });

    test('totais por categoria são imutáveis e ordenados por valor', () {
      final summary = FinanceSummary.fromTransactions([
        transaction(amountCents: 10),
        transaction(
          id: 'housing',
          amountCents: 20,
          category: TransactionCategory.housing,
        ),
        transaction(
          id: 'transport',
          amountCents: 20,
          category: TransactionCategory.transport,
        ),
      ]);
      expect(summary.expenseTotals.keys, [
        TransactionCategory.housing,
        TransactionCategory.transport,
        TransactionCategory.food,
      ]);
      expect(
        () => summary.expenseTotals[TransactionCategory.food] = 999,
        throwsUnsupportedError,
      );
      expect(summary.expenseTotals.clear, throwsUnsupportedError);
      expect(summary.categories.clear, throwsUnsupportedError);
    });
  });
}
