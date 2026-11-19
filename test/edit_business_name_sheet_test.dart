import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/widgets/edit_business_name_sheet.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('valida nome vazio e longo sem truncar e salva o texto aparado', (
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
    final field = find.byKey(const ValueKey('business-name-input'));
    final save = find.byKey(const ValueKey('save-business-name'));
    expect(tester.widget<TextField>(field).controller!.text, 'Comércio da Ana');
    expect(find.text('Editar nome da empresa'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.enterText(field, '   ');
    await _tap(tester, save);
    expect(find.text('Informe o nome da empresa.'), findsOneWidget);
    expect(calls, 0);
    final longName = 'a' * 61;
    await tester.enterText(field, longName);
    await _tap(tester, save);
    expect(tester.widget<TextField>(field).controller!.text, longName);
    expect(find.text('Use até 60 caracteres.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(field, '  Comércio Silva  ');
    await _tap(tester, save);
    expect(saved, 'Comércio Silva');
    expect(returned, 'Comércio Silva');
    expect(calls, 1);
    expect(field, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'espera o servidor, bloqueia duplicação e mantém nome após falhas',
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
        width: 360,
      );
      final field = find.byKey(const ValueKey('business-name-input'));
      final save = find.byKey(const ValueKey('save-business-name'));
      final cancel = find.byKey(const ValueKey('cancel-business-name'));
      await tester.enterText(field, 'Nova Empresa');
      await _tap(tester, save, settle: false);
      expect(find.text('Salvando...'), findsOneWidget);
      expect(finished, isFalse);
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      expect(tester.widget<TextButton>(cancel).onPressed, isNull);
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.drag(
        find.text('Editar nome da empresa'),
        const Offset(0, 250),
      );
      await tester.pump();
      expect(field, findsOneWidget);
      expect(finished, isFalse);

      pending.completeError(
        const FinanceException('Não foi possível atualizar a empresa.'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível atualizar a empresa.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, 'Nova Empresa');
      expect(tester.widget<TextField>(field).enabled, isTrue);
      expect(finished, isFalse);
      pending = Completer<void>();
      await _tap(tester, save, settle: false);
      pending.completeError(StateError('falha interna'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Não foi possível alterar o nome da empresa. Confira sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, 'Nova Empresa');
      expect(finished, isFalse);
      pending = Completer<void>();
      await _tap(tester, save, settle: false);
      pending.complete();
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(returned, 'Nova Empresa');
      expect(finished, isTrue);
      expect(field, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final useBack in [false, true]) {
    testWidgets('${useBack ? 'voltar' : 'cancelar'} não grava a alteração', (
      tester,
    ) async {
      var calls = 0;
      var finished = false;
      String? returned = 'pendente';
      await _mount(
        tester,
        onSave: (_) async => calls++,
        onResult: (value) {
          returned = value;
          finished = true;
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('business-name-input')),
        'Não salvar',
      );
      if (useBack) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        await _tap(tester, find.byKey(const ValueKey('cancel-business-name')));
      }
      expect(calls, 0);
      expect(returned, isNull);
      expect(finished, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _mount(
  WidgetTester tester, {
  required Future<void> Function(String) onSave,
  required ValueChanged<String?> onResult,
  double width = 320,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 720);
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
                    await showEditBusinessNameSheet(
                      context,
                      currentName: 'Comércio da Ana',
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
    await tester.pump(const Duration(milliseconds: 300));
  }
}
