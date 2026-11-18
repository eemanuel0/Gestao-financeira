import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/widgets/edit_transaction_description_sheet.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('preenche o texto real e valida sem truncar colagem longa', (
    tester,
  ) async {
    String? saved;
    String? returned;
    var calls = 0;
    await _mount(
      tester,
      onSave: (value) async {
        calls++;
        saved = value;
      },
      onResult: (value) => returned = value,
    );
    final field = find.byKey(const ValueKey('transaction-description-input'));
    final save = find.byKey(const ValueKey('save-transaction-description'));
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Mercado da semana',
    );
    expect(find.text('Editar descrição'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.enterText(field, '   ');
    await _tap(tester, save);
    expect(find.text('Informe uma descrição.'), findsOneWidget);
    expect(calls, 0);

    final longDescription = 'a' * 121;
    await tester.enterText(field, longDescription);
    await _tap(tester, save);
    expect(tester.widget<TextField>(field).controller!.text, longDescription);
    expect(find.text('Use até 120 caracteres.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(field, '  Conta de luz  ');
    await _tap(tester, save);
    expect(saved, 'Conta de luz');
    expect(returned, 'Conta de luz');
    expect(calls, 1);
    expect(field, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aguarda gravação, bloqueia duplicação e permite repetir após falhas',
    (tester) async {
      var finished = false;
      String? returned;
      var calls = 0;
      var pending = Completer<void>();
      await _mount(
        tester,
        onSave: (_) {
          calls++;
          return pending.future;
        },
        onResult: (value) {
          returned = value;
          finished = true;
        },
      );
      final field = find.byKey(const ValueKey('transaction-description-input'));
      final save = find.byKey(const ValueKey('save-transaction-description'));
      final cancel = find.byKey(
        const ValueKey('cancel-transaction-description'),
      );
      await tester.enterText(field, 'Compra corrigida');
      await _tap(tester, save);
      expect(find.text('Salvando...'), findsOneWidget);
      expect(finished, isFalse);
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      expect(tester.widget<TextButton>(cancel).onPressed, isNull);
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.drag(find.text('Editar descrição'), const Offset(0, 250));
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      expect(finished, isFalse);

      pending.completeError(
        const FinanceException('Não foi possível atualizar no banco.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível atualizar no banco.'), findsOneWidget);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Compra corrigida',
      );
      expect(tester.widget<TextField>(field).enabled, isTrue);
      expect(finished, isFalse);

      pending = Completer<void>();
      await _tap(tester, save);
      pending.completeError(StateError('falha interna'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Não foi possível alterar a descrição. Confira sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Compra corrigida',
      );
      expect(finished, isFalse);

      pending = Completer<void>();
      await _tap(tester, save);
      pending.complete();
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(returned, 'Compra corrigida');
      expect(finished, isTrue);
      expect(field, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final useBack in [false, true]) {
    testWidgets(
      '${useBack ? 'voltar' : 'cancelar'} não salva o texto alterado',
      (tester) async {
        var calls = 0;
        var finished = false;
        String? returned = 'ainda não retornou';
        await _mount(
          tester,
          onSave: (_) async => calls++,
          onResult: (value) {
            returned = value;
            finished = true;
          },
        );
        await tester.enterText(
          find.byKey(const ValueKey('transaction-description-input')),
          'Não salvar',
        );
        if (useBack) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await _tap(
            tester,
            find.byKey(const ValueKey('cancel-transaction-description')),
          );
        }
        expect(calls, 0);
        expect(returned, isNull);
        expect(finished, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _mount(
  WidgetTester tester, {
  required Future<void> Function(String) onSave,
  required ValueChanged<String?> onResult,
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
                    await showEditTransactionDescriptionSheet(
                      context,
                      currentDescription: 'Mercado da semana',
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
