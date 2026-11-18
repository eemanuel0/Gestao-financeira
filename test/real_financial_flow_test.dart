import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/app.dart';
import 'package:gestao_financeira/models/app_user.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/monthly_limit.dart';
import 'package:gestao_financeira/models/services/account_service.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/monthly_limit_repository.dart';
import 'package:gestao_financeira/screens/add_transaction_screen.dart';
import 'package:gestao_financeira/utils/date_formatters.dart';
import 'package:gestao_financeira/widgets/balance_card.dart';
import 'package:gestao_financeira/widgets/category_totals_table.dart';
import 'package:gestao_financeira/widgets/limit_alert_banner.dart';
import 'package:gestao_financeira/widgets/spending_limit_card.dart';
import 'package:gestao_financeira/widgets/summary_card.dart';

const _ana = AppUser(id: 'user-a', email: 'ana@teste.com', name: 'Ana Silva');
const _bia = AppUser(id: 'user-b', email: 'bia@teste.com', name: 'Bia Souza');
const _password = 'senha1234';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('despesa real, limite e mês permanecem isolados por conta', (
    tester,
  ) async {
    final accounts = _FakeAccountService(_ana);
    final finances = _FakeFinanceRepo(accounts);
    final budgets = _FakeBudgetRepo(accounts);
    final now = DateTime.now();
    await _mount(tester, accounts, finances, budgets);

    expect(_balance(tester), 0);
    expect(_summary(tester, 'Despesas'), 0);
    await _addTransaction(
      tester,
      type: TransactionType.expense,
      amountCents: 20000,
      description: 'Compra da Ana',
    );
    expect(_balance(tester), -20000);
    expect(_summary(tester, 'Despesas'), 20000);
    expect(finances.rows[_ana.id]!.single.amountCents, 20000);

    await _tab(tester, 'Relatórios');
    expect(_spending(tester).spent, 200);
    expect(_spending(tester).limit, isNull);
    expect(find.text('R\$ 200,00 gastos'), findsOneWidget);
    expect(find.text('Não definido'), findsOneWidget);
    final table = tester.widget<CategoryTotalsTable>(
      find.byType(CategoryTotalsTable),
    );
    expect(table.categories.single.name, 'Alimentação');
    expect(table.categories.single.total, 200);
    expect(
      find.descendant(
        of: find.byType(CategoryTotalsTable),
        matching: find.text('R\$ 200,00'),
      ),
      findsOneWidget,
    );
    expect(find.text('R\$ 1.500,00'), findsNothing);
    expect(find.text('R\$ 1.680,00 gastos'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('edit-spending-limit')));
    final limitInput = find.byKey(const ValueKey('spending-limit-input'));
    expect(tester.widget<TextField>(limitInput).controller!.text, isEmpty);
    await _enter(tester, 'spending-limit-input', '15000');
    expect(tester.widget<TextField>(limitInput).controller!.text, 'R\$ 150,00');
    await _tap(tester, find.byKey(const ValueKey('save-spending-limit')));
    expect(_spending(tester).limit, 150);
    expect(find.text('133%'), findsOneWidget);
    expect(find.text('Você gastou R\$ 50,00 acima do limite.'), findsOneWidget);
    expect(
      budgets.records[(_ana.id, MonthlyLimit.formatMonth(now))]!.limitCents,
      15000,
    );

    await _selectMonth(tester, DateTime(now.year, now.month - 1));
    expect(_spending(tester).spent, 0);
    expect(_spending(tester).limit, isNull);
    expect(find.text('R\$ 0,00 gastos'), findsOneWidget);
    expect(find.text('Não definido'), findsOneWidget);
    expect(find.byType(CategoryTotalsTable), findsNothing);
    expect(find.byType(LimitAlertBanner), findsNothing);

    await _selectMonth(tester, now);
    expect(_spending(tester).spent, 200);
    expect(_spending(tester).limit, 150);
    expect(find.text('133%'), findsOneWidget);

    await _logout(tester);
    await _login(tester, _bia);
    expect(_balance(tester), 0);
    expect(_summary(tester, 'Despesas'), 0);
    expect(find.text('Compra da Ana', skipOffstage: false), findsNothing);
    await _tab(tester, 'Relatórios');
    expect(_spending(tester).spent, 0);
    expect(_spending(tester).limit, isNull);
    expect(find.text('Não definido'), findsOneWidget);
    expect(find.byType(CategoryTotalsTable), findsNothing);
    expect(find.byType(LimitAlertBanner), findsNothing);

    await _logout(tester);
    await _login(tester, _ana);
    expect(_balance(tester), -20000);
    await _tab(tester, 'Relatórios');
    expect(_spending(tester).spent, 200);
    expect(_spending(tester).limit, 150);
    expect(find.text('133%'), findsOneWidget);
    expect(budgets.records.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('receita não vira gasto e centavos exatos geram alerta real', (
    tester,
  ) async {
    final accounts = _FakeAccountService(_ana);
    final finances = _FakeFinanceRepo(accounts);
    final budgets = _FakeBudgetRepo(accounts);
    final now = DateTime.now();
    await budgets.saveForMonth(month: now, limitCents: 20);
    await _mount(tester, accounts, finances, budgets);

    await _addTransaction(
      tester,
      type: TransactionType.income,
      amountCents: 5000,
      description: 'Receita da Ana',
    );
    expect(_summary(tester, 'Receitas'), 5000);
    expect(_summary(tester, 'Despesas'), 0);
    await _addTransaction(
      tester,
      type: TransactionType.expense,
      amountCents: 10,
      description: 'Primeiro gasto',
    );
    expect(_summary(tester, 'Despesas'), 10);
    await _addTransaction(
      tester,
      type: TransactionType.expense,
      amountCents: 20,
      description: 'Segundo gasto',
    );
    expect(_summary(tester, 'Despesas'), 30);
    expect(_balance(tester), 4970);
    expect(finances.rows[_ana.id]!.map((row) => row.amountCents), [
      5000,
      10,
      20,
    ]);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(
          'Limite de ${formatMonthYear(now)} ultrapassado em R\$ 0,10.',
        ),
      ),
      findsOneWidget,
    );

    await _tab(tester, 'Relatórios');
    expect(_spending(tester).spent, 0.30);
    expect(_spending(tester).limit, 0.20);
    expect(find.text('R\$ 0,30 gastos'), findsOneWidget);
    final categories = tester
        .widget<CategoryTotalsTable>(find.byType(CategoryTotalsTable))
        .categories;
    expect(categories.single.name, 'Alimentação');
    expect(categories.single.total, 0.30);
    expect(find.text('150%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falha ao consultar limite não duplica nem desfaz a despesa salva',
    (tester) async {
      final accounts = _FakeAccountService(_ana);
      final finances = _FakeFinanceRepo(accounts);
      final budgets = _FakeBudgetRepo(accounts)
        ..loadError = const FinanceException('Tabela de limites indisponível.');
      await _mount(tester, accounts, finances, budgets);

      await _addTransaction(
        tester,
        type: TransactionType.expense,
        amountCents: 20000,
        description: 'Despesa sem tabela de limites',
      );

      expect(finances.rows[_ana.id]!.length, 1);
      expect(finances.rows[_ana.id]!.single.amountCents, 20000);
      expect(_summary(tester, 'Despesas'), 20000);
      expect(_balance(tester), -20000);
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(find.byKey(const ValueKey('transaction-amount')), findsNothing);
      expect(
        find.text(
          'Lançamento salvo. Não foi possível verificar o limite agora.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Não foi possível salvar o lançamento. Confira sua conexão.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  _FakeAccountService accounts,
  _FakeFinanceRepo finances,
  _FakeBudgetRepo budgets,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 720);
  addTearDown(() async {
    // Desmontar primeiro cancela a atualização periódica dos relatórios.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await accounts.close();
    await finances.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MyApp(
      accountService: accounts,
      repository: finances,
      monthlyLimitRepository: budgets,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tab(WidgetTester tester, String label) =>
    _tap(tester, find.text(label).last);

Future<void> _logout(WidgetTester tester) async {
  await _tab(tester, 'Perfil');
  await _tap(tester, find.byKey(const ValueKey('sign-out')));
}

Future<void> _login(WidgetTester tester, AppUser user) async {
  await _tap(tester, find.byKey(const ValueKey('welcome-login')));
  await _enter(tester, 'login-email', user.email);
  await _enter(tester, 'login-password', _password);
  await _tap(tester, find.byKey(const ValueKey('login-submit')));
}

Future<void> _selectMonth(WidgetTester tester, DateTime month) async {
  await _tap(tester, find.byKey(const ValueKey('month-selector')));
  await _tap(
    tester,
    find.byKey(
      ValueKey(
        'month-option-${month.year}-${month.month.toString().padLeft(2, '0')}',
      ),
    ),
  );
}

Future<void> _addTransaction(
  WidgetTester tester, {
  required TransactionType type,
  required int amountCents,
  required String description,
}) async {
  await _tap(tester, find.byKey(const ValueKey('add-transaction')));
  await _tap(tester, find.byKey(const ValueKey('transaction-type')));
  await _tap(tester, find.text(type.label).last);
  await _enter(tester, 'transaction-amount', amountCents.toString());
  await _tap(tester, find.byKey(ValueKey('transaction-category-${type.name}')));
  final category = type == TransactionType.income
      ? TransactionCategory.salary
      : TransactionCategory.food;
  await _tap(tester, find.text(category.label).last);
  await _enter(tester, 'transaction-description', description);
  await _tap(tester, find.byKey(const ValueKey('submit-transaction')));
}

int _balance(WidgetTester tester) =>
    tester.widget<BalanceCard>(find.byType(BalanceCard)).balanceCents;

int _summary(WidgetTester tester, String title) => tester
    .widgetList<SummaryCard>(find.byType(SummaryCard))
    .singleWhere((card) => card.title == title)
    .amountCents;

SpendingLimitCard _spending(WidgetTester tester) =>
    tester.widget<SpendingLimitCard>(find.byType(SpendingLimitCard));

class _FakeAccountService implements AccountService {
  final _changes = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _currentUser;
  _FakeAccountService(AppUser initialUser) : _currentUser = initialUser;

  @override
  AppUser? get currentUser => _currentUser;
  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final user = email == _ana.email
        ? _ana
        : email == _bia.email
        ? _bia
        : null;
    if (user == null || password != _password) {
      throw const AccountException('E-mail ou senha inválidos.');
    }
    _currentUser = user;
    _changes.add(user);
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Cadastro não participa destes fluxos.');
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

class _FakeFinanceRepo implements FinanceRepository {
  final _FakeAccountService accounts;
  final rows = <String, List<FinanceTransaction>>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  int _nextId = 0;
  _FakeFinanceRepo(this.accounts);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<FinanceTransaction>> loadTransactions() async {
    final userId = accounts.currentUser!.id;
    return List.of(rows[userId] ?? []);
  }

  @override
  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  }) async {
    final userId = accounts.currentUser!.id;
    rows
        .putIfAbsent(userId, () => [])
        .add(
          FinanceTransaction(
            id: 'transaction-${++_nextId}',
            userId: userId,
            type: type,
            amountCents: amountCents,
            category: category,
            description: description,
            occurredOn: occurredOn,
            createdAt: DateTime.now().toUtc(),
          ),
        );
    _changes.add(null);
  }

  @override
  Future<FinanceTransaction> updateTransactionDescription({
    required String transactionId,
    required String description,
  }) async {
    final user = accounts.currentUser;
    if (user == null) {
      throw const FinanceException('Entre na sua conta para continuar.');
    }
    final transactions = rows[user.id] ?? [];
    final index = transactions.indexWhere(
      (row) => row.id == transactionId && row.userId == user.id,
    );
    if (index < 0) {
      throw const FinanceException('Lançamento não encontrado nesta conta.');
    }
    final original = transactions[index];
    final updated = FinanceTransaction(
      id: original.id,
      userId: original.userId,
      type: original.type,
      amountCents: original.amountCents,
      category: original.category,
      description: description.trim(),
      occurredOn: original.occurredOn,
      createdAt: original.createdAt,
    );
    transactions[index] = updated;
    _changes.add(null);
    return updated;
  }

  Future<void> close() => _changes.close();
}

class _FakeBudgetRepo implements MonthlyLimitRepository {
  final _FakeAccountService accounts;
  final records = <(String, String), MonthlyLimit>{};
  FinanceException? loadError;
  _FakeBudgetRepo(this.accounts);

  @override
  Future<MonthlyLimit?> loadForMonth(DateTime month) async {
    final error = loadError;
    if (error != null) throw error;
    return records[(accounts.currentUser!.id, MonthlyLimit.formatMonth(month))];
  }

  @override
  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  }) async {
    final userId = accounts.currentUser!.id;
    final limit = MonthlyLimit(
      userId: userId,
      month: month,
      limitCents: limitCents,
    );
    records[(userId, limit.monthKey)] = limit;
    return limit;
  }
}
