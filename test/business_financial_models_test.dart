import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/finance_summary.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';

void main() {
  test('Pessoal mantém salário como entrada e despesas pessoais', () {
    expect(TransactionCategory.allowedFor(TransactionType.income), [
      TransactionCategory.salary,
      TransactionCategory.services,
      TransactionCategory.other,
    ]);
    expect(TransactionCategory.allowedFor(TransactionType.expense), [
      TransactionCategory.food,
      TransactionCategory.housing,
      TransactionCategory.transport,
      TransactionCategory.health,
      TransactionCategory.leisure,
      TransactionCategory.other,
    ]);
    expect(TransactionType.income.labelForProfile('personal'), 'Receita');
    expect(TransactionType.expense.labelForProfile('personal'), 'Despesa');
  });

  test('Empresa oferece vendas e serviços; salários da equipe são saída', () {
    for (final profileId in ['business', 'segunda-empresa']) {
      expect(
        TransactionCategory.allowedFor(
          TransactionType.income,
          profileId: profileId,
        ),
        [
          TransactionCategory.sales,
          TransactionCategory.services,
          TransactionCategory.other,
        ],
      );
      expect(
        TransactionCategory.allowedFor(
          TransactionType.expense,
          profileId: profileId,
        ),
        [
          TransactionCategory.suppliers,
          TransactionCategory.payroll,
          TransactionCategory.businessRent,
          TransactionCategory.utilities,
          TransactionCategory.taxes,
          TransactionCategory.transport,
          TransactionCategory.other,
        ],
      );
      expect(TransactionType.income.labelForProfile(profileId), 'Entrada');
      expect(TransactionType.expense.labelForProfile(profileId), 'Saída');
    }
    final payroll = _transaction(
      profileId: 'business',
      type: TransactionType.expense,
      category: TransactionCategory.payroll,
      amountCents: 250001,
    );
    expect(payroll.toJson()['category'], 'payroll');
    expect(payroll.amountCents, 250001);
    expect(
      () => _transaction(
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.payroll,
      ),
      throwsArgumentError,
    );
    expect(
      () => _transaction(
        profileId: 'business',
        type: TransactionType.expense,
        category: TransactionCategory.salary,
      ),
      throwsArgumentError,
    );
  });

  test('categorias novas da empresa são rejeitadas no perfil pessoal', () {
    for (final category in [
      TransactionCategory.sales,
      TransactionCategory.suppliers,
      TransactionCategory.payroll,
      TransactionCategory.businessRent,
      TransactionCategory.utilities,
      TransactionCategory.taxes,
    ]) {
      expect(
        () => _transaction(
          category: category,
          type: category == TransactionCategory.sales
              ? TransactionType.income
              : TransactionType.expense,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'histórico empresarial mantém as categorias antigas sem reclassificar',
    () {
      for (final category in [
        TransactionCategory.salary,
        TransactionCategory.food,
        TransactionCategory.housing,
        TransactionCategory.health,
        TransactionCategory.leisure,
      ]) {
        final type = category == TransactionCategory.salary
            ? TransactionType.income
            : TransactionType.expense;
        final oldRow = {
          'id': 'registro-anterior',
          'user_id': 'user-a',
          'profile_id': 'business',
          'type': type.name,
          'amount_cents': 12345,
          'category': category.name,
          'description': 'Registro anterior',
          'occurred_on': '2026-11-01',
          'created_at': '2026-11-01T09:30:00.000Z',
        };
        final transaction = FinanceTransaction.fromJson(oldRow);
        expect(transaction.toJson(), oldRow);
        expect(
          TransactionCategory.allowedFor(type, profileId: 'business'),
          isNot(contains(category)),
        );
      }
    },
  );

  test('novas categorias empresariais preservam o contrato do banco', () {
    const expected = {
      TransactionCategory.sales: 'sales',
      TransactionCategory.suppliers: 'suppliers',
      TransactionCategory.payroll: 'payroll',
      TransactionCategory.businessRent: 'businessRent',
      TransactionCategory.utilities: 'utilities',
      TransactionCategory.taxes: 'taxes',
    };
    for (final entry in expected.entries) {
      final transaction = _transaction(
        profileId: 'business',
        category: entry.key,
        type: entry.key == TransactionCategory.sales
            ? TransactionType.income
            : TransactionType.expense,
      );
      expect(transaction.toJson()['category'], entry.value);
      expect(
        FinanceTransaction.fromJson(transaction.toJson()).category,
        entry.key,
      );
    }
  });

  test('faturamento mensal soma somente vendas e serviços daquele perfil', () {
    final november = DateTime(2026, 11);
    final rows = [
      _transaction(
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.sales,
        amountCents: 12010,
      ),
      _transaction(
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.services,
        amountCents: 3490,
      ),
      _transaction(
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.other,
        amountCents: 50000,
      ),
      _transaction(
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.salary,
        amountCents: 1000,
      ),
      _transaction(
        profileId: 'business',
        type: TransactionType.expense,
        category: TransactionCategory.payroll,
        amountCents: 20000,
      ),
      _transaction(
        type: TransactionType.income,
        category: TransactionCategory.services,
        amountCents: 80000,
      ),
      _transaction(
        userId: 'user-b',
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.sales,
        amountCents: 99999,
      ),
      _transaction(
        profileId: 'business',
        type: TransactionType.income,
        category: TransactionCategory.sales,
        amountCents: 100000,
        occurredOn: DateTime(2026, 12),
      ),
    ];
    final summary = FinanceSummary.forMonth(
      rows,
      userId: 'user-a',
      profileId: 'business',
      month: november,
    );
    expect(summary.revenueCents, 15500);
    expect(summary.incomeCents, 66500);
    expect(summary.expenseCents, 20000);
    expect(summary.balanceCents, 46500);
    expect(summary.expenseTotals, {TransactionCategory.payroll: 20000});
    final emptyMonth = FinanceSummary.forMonth(
      rows,
      userId: 'user-a',
      profileId: 'business',
      month: DateTime(2026, 10),
    );
    expect(emptyMonth.revenueCents, 0);
    expect(emptyMonth.incomeCents, 0);
  });

  test(
    'faturamento mantém centavos exatos sem confundir entrada com saldo',
    () {
      final summary = FinanceSummary.fromTransactions([
        _transaction(
          profileId: 'business',
          type: TransactionType.income,
          category: TransactionCategory.sales,
          amountCents: 10,
        ),
        _transaction(
          profileId: 'business',
          type: TransactionType.income,
          category: TransactionCategory.services,
          amountCents: 20,
        ),
        _transaction(
          profileId: 'business',
          type: TransactionType.income,
          category: TransactionCategory.other,
          amountCents: 100,
        ),
        _transaction(
          profileId: 'business',
          type: TransactionType.expense,
          category: TransactionCategory.suppliers,
          amountCents: 200,
        ),
      ]);
      expect(summary.revenueCents, 30);
      expect(summary.incomeCents, 130);
      expect(summary.balanceCents, -70);
    },
  );
}

FinanceTransaction _transaction({
  String userId = 'user-a',
  String profileId = 'personal',
  TransactionType type = TransactionType.expense,
  TransactionCategory category = TransactionCategory.food,
  int amountCents = 100,
  DateTime? occurredOn,
}) => FinanceTransaction(
  id: 'registro',
  userId: userId,
  profileId: profileId,
  type: type,
  amountCents: amountCents,
  category: category,
  description: 'Registro real do teste',
  occurredOn: occurredOn ?? DateTime(2026, 11, 1),
  createdAt: DateTime.utc(2026, 11, 1, 9, 30),
);
