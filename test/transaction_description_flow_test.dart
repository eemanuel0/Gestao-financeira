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
import 'package:gestao_financeira/widgets/balance_card.dart';
import 'package:gestao_financeira/widgets/category_totals_table.dart';
import 'package:gestao_financeira/widgets/spending_limit_card.dart';
import 'package:gestao_financeira/widgets/summary_card.dart';

const _ana = AppUser(id: 'user-a', email: 'ana@teste.com', name: 'Ana Silva');
const _bia = AppUser(id: 'user-b', email: 'bia@teste.com', name: 'Bia Souza');

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('edita receita e despesa, persiste e preserva todos os totais', (
    tester,
  ) async {
    final accounts = _Accounts();
    final repository = _Transactions(accounts);
    final originals = {
      for (final row in repository.rows[_ana.id]!) row.id: row.toJson(),
    };
    await _mount(tester, accounts, repository);
    _expectHomeTotals(tester);
    await _tab(tester, 'Lançamentos');

    await _openEditor(tester, 'expense-1');
    expect(_description(tester), 'Mercado original');
    await _writeDescription(tester, '  Supermercado atualizado  ');
    await _save(tester);
    expect(
      find.byKey(const ValueKey('transaction-description-input')),
      findsNothing,
    );
    expect(find.text('Supermercado atualizado'), findsOneWidget);
    expect(find.text('Mercado original'), findsNothing);

    await _openEditor(tester, 'income-1');
    expect(_description(tester), 'Receita original');
    await _writeDescription(tester, 'Salário atualizado');
    await _save(tester);
    expect(find.text('Salário atualizado'), findsOneWidget);

    for (final row in repository.rows[_ana.id]!) {
      final before = Map<String, dynamic>.of(originals[row.id]!)
        ..remove('description');
      expect(row.toJson()..remove('description'), before);
    }
    expect(repository.rows[_ana.id]!.map((row) => row.description), [
      'Salário atualizado',
      'Supermercado atualizado',
    ]);

    // Recarrega a fonte persistida em vez de depender apenas do texto local.
    final loadsBefore = repository.loadCalls;
    repository.notifyChanges();
    await tester.pumpAndSettle();
    expect(repository.loadCalls, greaterThan(loadsBefore));
    expect(find.text('Supermercado atualizado'), findsOneWidget);
    expect(find.text('Salário atualizado'), findsOneWidget);

    await _tab(tester, 'Início');
    _expectHomeTotals(tester);
    await _tab(tester, 'Relatórios');
    final spending = tester.widget<SpendingLimitCard>(
      find.byType(SpendingLimitCard),
    );
    expect(spending.spent, 200);
    expect(find.text('R\$ 200,00 gastos'), findsOneWidget);
    final categories = tester
        .widget<CategoryTotalsTable>(find.byType(CategoryTotalsTable))
        .categories;
    expect(categories.single.name, 'Alimentação');
    expect(categories.single.total, 200);
    expect(repository.updateCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'erro mantém o registro antigo e o novo texto para tentar de novo',
    (tester) async {
      final accounts = _Accounts();
      final repository = _Transactions(accounts)
        ..updateError = const FinanceException('Sem conexão. Tente novamente.');
      await _mount(tester, accounts, repository);
      await _tab(tester, 'Lançamentos');
      await _openEditor(tester, 'expense-1');
      await _writeDescription(tester, 'Descrição mantida no editor');
      await _save(tester);

      expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('transaction-description-input')),
        findsOneWidget,
      );
      expect(_description(tester), 'Descrição mantida no editor');
      expect(repository.rows[_ana.id]!.last.description, 'Mercado original');
      expect(repository.rows[_ana.id]!.last.amountCents, 20000);

      repository.updateError = null;
      await _save(tester);
      expect(
        find.byKey(const ValueKey('transaction-description-input')),
        findsNothing,
      );
      expect(find.text('Descrição mantida no editor'), findsOneWidget);
      expect(repository.rows[_ana.id]!.length, 2);
      await _tab(tester, 'Início');
      _expectHomeTotals(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resposta de edição da conta anterior não aparece na nova conta',
    (tester) async {
      final accounts = _Accounts();
      final gate = Completer<void>();
      final repository = _Transactions(accounts)..updateGate = gate;
      await _mount(tester, accounts, repository);
      await _tab(tester, 'Lançamentos');
      await _openEditor(tester, 'expense-1');
      await _writeDescription(tester, 'Resposta atrasada da Ana');
      final save = find.byKey(const ValueKey('save-transaction-description'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(repository.updateCalls, 1);

      accounts.switchTo(_bia);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('transaction-description-input')),
        findsNothing,
      );
      expect(find.text('Olá, Bia'), findsOneWidget);
      expect(
        tester.widget<BalanceCard>(find.byType(BalanceCard)).balanceCents,
        0,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Resposta atrasada da Ana', skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Mercado original', skipOffstage: false), findsNothing);
      expect(find.text('Receita original', skipOffstage: false), findsNothing);
      expect(
        tester.widget<BalanceCard>(find.byType(BalanceCard)).balanceCents,
        0,
      );
      expect(repository.rows[_bia.id], isNull);
      await _tab(tester, 'Lançamentos');
      expect(find.byTooltip('Editar descrição'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('consulta anterior à edição não restaura o nome antigo', (
    tester,
  ) async {
    final accounts = _Accounts();
    final repository = _Transactions(accounts);
    await _mount(tester, accounts, repository);
    await _tab(tester, 'Lançamentos');
    await _openEditor(tester, 'expense-1');
    final oldRows = List<FinanceTransaction>.of(repository.rows[_ana.id]!);
    final pending = Completer<List<FinanceTransaction>>();
    repository.nextLoad = pending;
    repository.notifyChanges();
    await tester.pump();
    await _writeDescription(tester, 'Nome confirmado pelo banco');
    await _save(tester);
    expect(find.text('Nome confirmado pelo banco'), findsOneWidget);
    pending.complete(oldRows);
    await tester.pumpAndSettle();
    expect(find.text('Nome confirmado pelo banco'), findsOneWidget);
    expect(find.text('Mercado original'), findsNothing);
    await _tab(tester, 'Início');
    _expectHomeTotals(tester);
    expect(tester.takeException(), isNull);
  });

  for (final recovers in [true, false]) {
    testWidgets(
      'edição confirmada após falha de leitura preserva estado ${recovers ? 'recuperado' : 'de erro'}',
      (tester) async {
        final accounts = _Accounts();
        final repository = _Transactions(accounts);
        await _mount(tester, accounts, repository);
        await _tab(tester, 'Lançamentos');
        await _openEditor(tester, 'expense-1');
        await _writeDescription(tester, 'Descrição realmente salva');
        repository.loadError = const FinanceException(
          'Falha ao atualizar os lançamentos.',
        );
        repository.notifyChanges();
        await tester.pumpAndSettle();
        if (recovers) repository.loadError = null;
        await _save(tester);
        expect(
          find.byKey(const ValueKey('transaction-description-input')),
          findsNothing,
        );
        expect(
          repository.rows[_ana.id]!.last.description,
          'Descrição realmente salva',
        );
        expect(
          find.text('Nenhum lançamento ainda. Toque no + para adicionar.'),
          findsNothing,
        );
        if (!recovers) {
          expect(
            find.text('Falha ao atualizar os lançamentos.'),
            findsOneWidget,
          );
          expect(
            find.text(
              'Descrição salva. Atualize os dados para conferir seus lançamentos.',
            ),
            findsOneWidget,
          );
          repository.loadError = null;
          repository.notifyChanges();
          await tester.pumpAndSettle();
        }
        expect(find.text('Descrição realmente salva'), findsOneWidget);
        expect(find.text('Receita original'), findsOneWidget);
        await _tab(tester, 'Início');
        _expectHomeTotals(tester);
        expect(repository.updateCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Accounts accounts,
  _Transactions repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 720);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await accounts.close();
    await repository.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MyApp(
      accountService: accounts,
      repository: repository,
      monthlyLimitRepository: _NoLimits(accounts),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) =>
    _tap(tester, find.text(label).last);

Future<void> _openEditor(WidgetTester tester, String id) =>
    _tap(tester, find.byKey(ValueKey('edit-transaction-$id')));

Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('save-transaction-description')));

Future<void> _writeDescription(WidgetTester tester, String text) async {
  final field = find.byKey(const ValueKey('transaction-description-input'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

String _description(WidgetTester tester) => tester
    .widget<TextField>(
      find.byKey(const ValueKey('transaction-description-input')),
    )
    .controller!
    .text;

void _expectHomeTotals(WidgetTester tester) {
  expect(
    tester.widget<BalanceCard>(find.byType(BalanceCard)).balanceCents,
    30000,
  );
  final cards = tester.widgetList<SummaryCard>(find.byType(SummaryCard));
  expect(
    cards.singleWhere((card) => card.title == 'Receitas').amountCents,
    50000,
  );
  expect(
    cards.singleWhere((card) => card.title == 'Despesas').amountCents,
    20000,
  );
}

class _Accounts implements AccountService {
  final _changes = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _currentUser = _ana;
  @override
  AppUser? get currentUser => _currentUser;
  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  void switchTo(AppUser? user) {
    _currentUser = user;
    _changes.add(user);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => switchTo(email == _bia.email ? _bia : _ana);
  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async => false;
  @override
  Future<void> signOut() async => switchTo(null);
  Future<void> close() => _changes.close();
}

class _Transactions implements FinanceRepository {
  final _Accounts accounts;
  final rows = <String, List<FinanceTransaction>>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  FinanceException? updateError;
  FinanceException? loadError;
  Completer<List<FinanceTransaction>>? nextLoad;
  Completer<void>? updateGate;
  int updateCalls = 0;
  int loadCalls = 0;

  _Transactions(this.accounts) {
    final now = DateTime.now();
    rows[_ana.id] = [
      FinanceTransaction(
        id: 'income-1',
        userId: _ana.id,
        type: TransactionType.income,
        amountCents: 50000,
        category: TransactionCategory.salary,
        description: 'Receita original',
        occurredOn: now,
        createdAt: now.toUtc(),
      ),
      FinanceTransaction(
        id: 'expense-1',
        userId: _ana.id,
        type: TransactionType.expense,
        amountCents: 20000,
        category: TransactionCategory.food,
        description: 'Mercado original',
        occurredOn: now,
        createdAt: now.toUtc(),
      ),
    ];
  }

  @override
  Stream<void> get changes => _changes.stream;
  void notifyChanges() => _changes.add(null);
  @override
  Future<List<FinanceTransaction>> loadTransactions() async {
    loadCalls++;
    final pending = nextLoad;
    nextLoad = null;
    if (pending != null) return pending.future;
    final error = loadError;
    if (error != null) throw error;
    return List.of(rows[accounts.currentUser!.id] ?? []);
  }

  @override
  Future<FinanceTransaction> updateTransactionDescription({
    required String transactionId,
    required String description,
  }) async {
    updateCalls++;
    final userId = accounts.currentUser!.id;
    final owned = rows[userId] ?? [];
    final index = owned.indexWhere((row) => row.id == transactionId);
    if (index < 0) throw const FinanceException('Lançamento não encontrado.');
    final original = owned[index];
    await updateGate?.future;
    final error = updateError;
    if (error != null) throw error;
    // Uma requisição já enviada pode terminar depois de mudar a sessão.
    final updated = FinanceTransaction.fromJson({
      ...original.toJson(),
      'description': description.trim(),
    });
    owned[index] = updated;
    return updated;
  }

  @override
  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  }) async {
    throw UnimplementedError('Este teste cobre somente a edição.');
  }

  Future<void> close() => _changes.close();
}

class _NoLimits implements MonthlyLimitRepository {
  final _Accounts accounts;
  _NoLimits(this.accounts);
  @override
  Future<MonthlyLimit?> loadForMonth(DateTime month) async => null;
  @override
  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  }) async => MonthlyLimit(
    userId: accounts.currentUser!.id,
    month: month,
    limitCents: limitCents,
  );
}
