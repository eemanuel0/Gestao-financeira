import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gestao_financeira/models/category_total.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/monthly_limit.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/monthly_limit_repository.dart';
import 'package:gestao_financeira/screens/reports_screen.dart';
import 'package:gestao_financeira/utils/date_formatters.dart';
import 'package:gestao_financeira/widgets/category_totals_table.dart';
import 'package:gestao_financeira/widgets/month_selector.dart';
import 'package:gestao_financeira/widgets/spending_limit_card.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('totais com larguras diferentes ficam alinhados à direita', (
    tester,
  ) async {
    await _mount(
      tester,
      const CategoryTotalsTable(
        categories: [
          CategoryTotal(name: 'Curto', icon: Icons.home, total: 1),
          CategoryTotal(name: 'Longo', icon: Icons.home, total: 1000000),
        ],
      ),
    );
    final headerRight = tester.getTopRight(find.text('Total gasto')).dx;
    expect(
      tester.getTopRight(find.text('R\$ 1,00')).dx,
      closeTo(headerRight, 0.5),
    );
    expect(
      tester.getTopRight(find.text('R\$ 1.000.000,00')).dx,
      closeTo(headerRight, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filtra despesas pelo dono e mês e consulta o limite de cada mês',
    (tester) async {
      final now = _currentMonth;
      final previous = DateTime(now.year, now.month - 1);
      final budget = _Budget()
        ..put(now, 15000)
        ..put(previous, 10000);
      await _mount(
        tester,
        ReportsScreen(
          userId: 'user-a',
          transactions: _transactions(now),
          limitRepository: budget,
        ),
      );
      expect(_card(tester).spent, 200);
      expect(_card(tester).limit, 150);
      expect(find.text('133%'), findsOneWidget);
      expect(find.text('R\$ 200,00 gastos'), findsOneWidget);
      expect(_table(tester).categories.single.name, 'Alimentação');
      expect(_table(tester).categories.single.total, 200);

      await _selectMonth(tester, previous);
      expect(find.text(formatMonthYear(previous)), findsOneWidget);
      expect(_card(tester).spent, 80);
      expect(_card(tester).limit, 100);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('R\$ 80,00 gastos'), findsOneWidget);
      expect(find.text('133%'), findsNothing);
      expect(find.text('R\$ 150,00'), findsNothing);
      expect(_table(tester).categories.single.name, 'Moradia');
      expect(_table(tester).categories.single.total, 80);
      expect(budget.loadedMonths, [
        MonthlyLimit.formatMonth(now),
        MonthlyLimit.formatMonth(previous),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ausência não inventa limite e grava o valor escolhido para o mês',
    (tester) async {
      final now = _currentMonth;
      final previous = DateTime(now.year, now.month - 1);
      final budget = _Budget();
      await _mount(
        tester,
        ReportsScreen(
          userId: 'user-a',
          transactions: _transactions(now),
          limitRepository: budget,
        ),
      );
      expect(find.text('Não definido'), findsOneWidget);
      expect(_card(tester).limit, isNull);
      expect(_card(tester).spent, 200);
      expect(find.text('R\$ 1.500,00'), findsNothing);
      await _tap(tester, find.text('Definir limite'));
      final field = find.byKey(const ValueKey('spending-limit-input'));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, '15000');
      await _tap(tester, find.byKey(const ValueKey('save-spending-limit')));
      expect(budget.saved.single.monthKey, MonthlyLimit.formatMonth(now));
      expect(budget.saved.single.userId, 'user-a');
      expect(budget.saved.single.limitCents, 15000);
      expect(_card(tester).spent, 200);
      expect(_card(tester).limit, 150);
      expect(find.text('133%'), findsOneWidget);
      expect(
        find.text('Você gastou R\$ 50,00 acima do limite.'),
        findsOneWidget,
      );

      // O limite de um mês não é copiado para o mês anterior.
      await _selectMonth(tester, previous);
      expect(_card(tester).limit, isNull);
      expect(_card(tester).spent, 80);
      expect(find.text('Não definido'), findsOneWidget);
      expect(find.text('133%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resposta atrasada do mês anterior da consulta é descartada', (
    tester,
  ) async {
    final now = _currentMonth;
    final previous = DateTime(now.year, now.month - 1);
    final oldRequest = Completer<MonthlyLimit?>();
    final budget = _Budget()
      ..pending[MonthlyLimit.formatMonth(now)] = oldRequest.future
      ..put(previous, 10000);
    await _mount(
      tester,
      ReportsScreen(
        userId: 'user-a',
        transactions: _transactions(now),
        limitRepository: budget,
      ),
      settle: false,
    );
    expect(find.text('Carregando limite...'), findsOneWidget);
    await _selectMonth(tester, previous, pendingBeforeSelection: true);
    expect(_card(tester).limit, 100);
    expect(_card(tester).spent, 80);

    oldRequest.complete(
      MonthlyLimit(userId: 'user-a', month: now, limitCents: 15000),
    );
    await tester.pumpAndSettle();
    expect(_card(tester).limit, 100);
    expect(_card(tester).spent, 80);
    expect(
      tester.widget<MonthSelector>(find.byType(MonthSelector)).selectedMonth,
      previous,
    );
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('133%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falha do limite não se passa por ausência e preserva gastos reais',
    (tester) async {
      final now = _currentMonth;
      final budget = _Budget()
        ..loadFailure = const FinanceException('Sem conexão com o limite.');
      await _mount(
        tester,
        ReportsScreen(
          userId: 'user-a',
          transactions: _transactions(now),
          limitRepository: budget,
        ),
      );
      expect(find.text('Limite indisponível'), findsOneWidget);
      expect(find.text('Sem conexão com o limite.'), findsOneWidget);
      expect(find.text('Não definido'), findsNothing);
      expect(_card(tester).spent, 200);
      expect(find.text('R\$ 200,00 gastos'), findsOneWidget);
      expect(_table(tester).categories.single.total, 200);

      budget.loadFailure = null;
      await _tap(tester, find.byKey(const ValueKey('retry-spending-limit')));
      expect(find.text('Não definido'), findsOneWidget);
      expect(find.text('Limite indisponível'), findsNothing);
      expect(_card(tester).spent, 200);
      expect(budget.loadedMonths.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'falha dos lançamentos não apresenta zero nem categorias fictícias',
    (tester) async {
      var refreshed = false;
      await _mount(
        tester,
        ReportsScreen(
          userId: 'user-a',
          transactions: const [],
          limitRepository: _Budget(),
          loadError: 'Não foi possível carregar seus lançamentos.',
          onRefresh: () async => refreshed = true,
        ),
      );
      expect(
        find.text('Não foi possível carregar seus lançamentos.'),
        findsOneWidget,
      );
      expect(find.byType(SpendingLimitCard), findsNothing);
      expect(find.byType(CategoryTotalsTable), findsNothing);
      expect(find.text('R\$ 0,00'), findsNothing);
      expect(find.text('Você ainda não tem despesas neste mês.'), findsNothing);
      expect(find.text('Alimentação'), findsNothing);
      expect(find.text('Moradia'), findsNothing);
      await _tap(tester, find.text('Tentar novamente'));
      expect(refreshed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

DateTime get _currentMonth => MonthlyLimit.normalizeMonth(DateTime.now());

List<FinanceTransaction> _transactions(DateTime month) => [
  _transaction(
    'a-current-expense',
    'user-a',
    month,
    TransactionType.expense,
    TransactionCategory.food,
    20000,
  ),
  _transaction(
    'a-previous-expense',
    'user-a',
    DateTime(month.year, month.month - 1),
    TransactionType.expense,
    TransactionCategory.housing,
    8000,
  ),
  _transaction(
    'a-current-income',
    'user-a',
    month,
    TransactionType.income,
    TransactionCategory.salary,
    99900,
  ),
  _transaction(
    'b-current-expense',
    'user-b',
    month,
    TransactionType.expense,
    TransactionCategory.food,
    50000,
  ),
];

FinanceTransaction _transaction(
  String id,
  String userId,
  DateTime month,
  TransactionType type,
  TransactionCategory category,
  int amountCents,
) => FinanceTransaction(
  id: id,
  userId: userId,
  type: type,
  amountCents: amountCents,
  category: category,
  description: id,
  occurredOn: DateTime(month.year, month.month, 2),
  createdAt: DateTime(month.year, month.month, 2),
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: child is CategoryTotalsTable
                ? const EdgeInsets.all(16)
                : EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _selectMonth(
  WidgetTester tester,
  DateTime month, {
  bool pendingBeforeSelection = false,
}) async {
  await _tap(
    tester,
    find.byKey(const ValueKey('month-selector')),
    settle: !pendingBeforeSelection,
  );
  final key =
      'month-option-${month.year}-${month.month.toString().padLeft(2, '0')}';
  await _tap(tester, find.byKey(ValueKey(key)));
}

SpendingLimitCard _card(WidgetTester tester) =>
    tester.widget<SpendingLimitCard>(find.byType(SpendingLimitCard));
CategoryTotalsTable _table(WidgetTester tester) =>
    tester.widget<CategoryTotalsTable>(find.byType(CategoryTotalsTable));

class _Budget implements MonthlyLimitRepository {
  final values = <String, MonthlyLimit>{};
  final pending = <String, Future<MonthlyLimit?>>{};
  final loadedMonths = <String>[];
  final saved = <MonthlyLimit>[];
  FinanceException? loadFailure;

  void put(DateTime month, int cents) {
    final value = MonthlyLimit(
      userId: 'user-a',
      month: month,
      limitCents: cents,
    );
    values[value.monthKey] = value;
  }

  @override
  Future<MonthlyLimit?> loadForMonth(DateTime month) async {
    final key = MonthlyLimit.formatMonth(month);
    loadedMonths.add(key);
    final error = loadFailure;
    if (error != null) throw error;
    final delayed = pending[key];
    if (delayed != null) return delayed;
    return values[key];
  }

  @override
  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  }) async {
    final value = MonthlyLimit(
      userId: 'user-a',
      month: month,
      limitCents: limitCents,
    );
    values[value.monthKey] = value;
    saved.add(value);
    return value;
  }
}
