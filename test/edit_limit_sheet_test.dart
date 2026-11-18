import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/widgets/edit_limit_sheet.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('pré-preenche, valida zero/vazio e salva com teclado aberto', (
    tester,
  ) async {
    double? returned;
    var finished = false;
    await _mount(tester, 2500, (value) {
      returned = value;
      finished = true;
    });
    final field = find.byKey(const ValueKey('spending-limit-input'));
    final save = find.byKey(const ValueKey('save-spending-limit'));
    expect(tester.widget<TextField>(field).controller!.text, 'R\$ 2.500,00');
    expect(find.text('Editar limite mensal'), findsOneWidget);
    expect(
      find.text('Você recebe um alerta ao ultrapassar esse valor.'),
      findsOneWidget,
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.enterText(field, '0');
    await _tap(tester, save);
    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    expect(finished, isFalse);
    expect(field, findsOneWidget);

    await tester.enterText(field, '');
    await _tap(tester, save);
    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    expect(finished, isFalse);

    await tester.enterText(field, '123456');
    expect(tester.widget<TextField>(field).controller!.text, 'R\$ 1.234,56');
    await _tap(tester, save);
    expect(finished, isTrue);
    expect(returned, closeTo(1234.56, 0.00001));
    expect(field, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entrada inválida pode ser corrigida sem fechar a folha', (
    tester,
  ) async {
    double? returned;
    await _mount(tester, double.nan, (value) => returned = value);
    final field = find.byKey(const ValueKey('spending-limit-input'));
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    await tester.enterText(field, 'abc');
    await _tap(tester, find.byKey(const ValueKey('save-spending-limit')));
    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    expect(returned, isNull);
    await tester.enterText(field, '1');
    await _tap(tester, find.byKey(const ValueKey('save-spending-limit')));
    expect(returned, 0.01);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar devolve null sem criar um limite', (tester) async {
    var finished = false;
    double? returned = 100;
    await _mount(tester, 0, (value) {
      returned = value;
      finished = true;
    });
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(returned, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conta sem limite abre vazia e só grava o valor informado', (
    tester,
  ) async {
    double? returned;
    double? saved;
    var calls = 0;
    await _mount(
      tester,
      null,
      (value) => returned = value,
      onSave: (value) async {
        calls++;
        saved = value;
      },
    );
    final field = find.byKey(const ValueKey('spending-limit-input'));
    final save = find.byKey(const ValueKey('save-spending-limit'));
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.text('R\$ 0,00'), findsNothing);
    expect(calls, 0);
    await _tap(tester, save);
    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(field, '20000');
    await _tap(tester, save);
    expect(saved, 200);
    expect(returned, 200);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'espera o banco, bloqueia duplicação e preserva texto nas falhas',
    (tester) async {
      double? returned;
      var finished = false;
      var calls = 0;
      var pending = Completer<void>();
      await _mount(
        tester,
        null,
        (value) {
          returned = value;
          finished = true;
        },
        onSave: (_) {
          calls++;
          return pending.future;
        },
      );
      final field = find.byKey(const ValueKey('spending-limit-input'));
      final save = find.byKey(const ValueKey('save-spending-limit'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.enterText(field, '80000');
      await _tap(tester, save);
      expect(find.text('Salvando...'), findsOneWidget);
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      expect(finished, isFalse);
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);

      pending.completeError(
        const FinanceException('Não foi possível gravar no banco.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível gravar no banco.'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'R\$ 800,00');
      expect(tester.widget<TextField>(field).enabled, isTrue);
      expect(finished, isFalse);

      // Uma falha inesperada também mantém o valor e permite tentar de novo.
      pending = Completer<void>();
      await _tap(tester, save);
      pending.completeError(StateError('falha interna'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Não foi possível salvar o limite. Confira sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, 'R\$ 800,00');
      expect(finished, isFalse);

      pending = Completer<void>();
      await _tap(tester, save);
      expect(calls, 3);
      pending.complete();
      await tester.pumpAndSettle();
      expect(returned, 800);
      expect(finished, isTrue);
      expect(field, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  double? limit,
  ValueChanged<double?> onResult, {
  Future<void> Function(double)? onSave,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 720);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () async {
                  onResult(
                    await showEditLimitSheet(
                      context,
                      currentLimit: limit,
                      onSave: onSave,
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Abrir'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
