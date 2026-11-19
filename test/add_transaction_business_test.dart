import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/screens/add_transaction_screen.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'Empresa cadastra salários da equipe como saída com valor exato',
    (tester) async {
      NewTransactionData? saved;
      await _mount(
        tester,
        profileId: 'business',
        initialType: TransactionType.expense,
        onSave: (data) async => saved = data,
      );
      expect(find.text('Saída'), findsOneWidget);
      await _selectCategory(
        tester,
        TransactionType.expense,
        'Salários da equipe',
      );
      await _fillAndSubmit(tester, '250001', 'Pagamento da equipe');
      expect(saved!.type, TransactionType.expense);
      expect(saved!.category, TransactionCategory.payroll);
      expect(saved!.amountCents, 250001);
      expect(saved!.description, 'Pagamento da equipe');
      expect(find.text('Abrir lançamento'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Empresa cadastra vendas como entrada e não oferece salário pessoal',
    (tester) async {
      NewTransactionData? saved;
      await _mount(
        tester,
        profileId: 'business',
        initialType: TransactionType.income,
        onSave: (data) async => saved = data,
      );
      expect(find.text('Entrada'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('transaction-category-income')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Salário'), findsNothing);
      await tester.tap(find.text('Vendas').last);
      await tester.pumpAndSettle();
      await _fillAndSubmit(tester, '12345', 'Venda recebida');
      expect(saved!.type, TransactionType.income);
      expect(saved!.category, TransactionCategory.sales);
      expect(saved!.amountCents, 12345);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pessoal continua cadastrando salário como receita', (
    tester,
  ) async {
    NewTransactionData? saved;
    await _mount(
      tester,
      initialType: TransactionType.income,
      onSave: (data) async => saved = data,
    );
    expect(find.text('Receita'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-category-income')));
    await tester.pumpAndSettle();
    expect(find.text('Vendas'), findsNothing);
    await tester.tap(find.text('Salário').last);
    await tester.pumpAndSettle();
    await _fillAndSubmit(tester, '10000', 'Meu salário');
    expect(saved!.type, TransactionType.income);
    expect(saved!.category, TransactionCategory.salary);
    expect(saved!.amountCents, 10000);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mudança de perfil limpa categoria incompatível sem perder o valor',
    (tester) async {
      late StateSetter update;
      var profileId = 'business';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AddTransactionScreen(
                key: const ValueKey('same-form'),
                profileId: profileId,
                initialType: TransactionType.expense,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _selectCategory(
        tester,
        TransactionType.expense,
        'Salários da equipe',
      );
      final value = find.byKey(const ValueKey('transaction-amount'));
      await tester.enterText(value, '250001');
      update(() => profileId = 'personal');
      await tester.pumpAndSettle();
      expect(find.text('Despesa'), findsOneWidget);
      expect(find.text('Salários da equipe'), findsNothing);
      expect(tester.widget<TextFormField>(value).controller!.text, '2.500,01');
      await tester.tap(
        find.byKey(const ValueKey('transaction-category-expense')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alimentação'), findsOneWidget);
      expect(find.text('Fornecedores'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester, {
  String profileId = 'personal',
  required TransactionType initialType,
  required Future<void> Function(NewTransactionData data) onSave,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddTransactionScreen(
                    profileId: profileId,
                    initialType: initialType,
                    onSave: onSave,
                  ),
                ),
              ),
              child: const Text('Abrir lançamento'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir lançamento'));
  await tester.pumpAndSettle();
}

Future<void> _selectCategory(
  WidgetTester tester,
  TransactionType type,
  String label,
) async {
  final dropdown = find.byKey(ValueKey('transaction-category-${type.name}'));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(
  WidgetTester tester,
  String amount,
  String description,
) async {
  final value = find.byKey(const ValueKey('transaction-amount'));
  await tester.ensureVisible(value);
  await tester.enterText(value, amount);
  final field = find.byKey(const ValueKey('transaction-description'));
  await tester.ensureVisible(field);
  await tester.enterText(field, description);
  final button = find.byKey(const ValueKey('submit-transaction'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
