import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/core/app_theme.dart';
import 'package:gestao_financeira/widgets/limit_alert_banner.dart';
import 'package:gestao_financeira/widgets/spending_limit_card.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: createAppTheme(Brightness.dark),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('excesso mostra 112% e barra vermelha limitada a 100%', (
    tester,
  ) async {
    var edited = false;
    await mount(
      tester,
      SpendingLimitCard(limit: 1500, spent: 1680, onEdit: () => edited = true),
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 1);
    expect(progress.color, createAppTheme(Brightness.dark).colorScheme.error);
    expect(find.text('112%'), findsOneWidget);
    expect(find.text('R\$ 1.680,00 gastos'), findsOneWidget);
    await tester.tap(find.text('Editar limite'));
    expect(edited, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'igual ao limite continua verde e limite zero não divide por zero',
    (tester) async {
      await mount(
        tester,
        SpendingLimitCard(limit: 1500, spent: 1500, onEdit: () {}),
      );
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 1);
      expect(
        progress.color,
        createAppTheme(Brightness.dark).colorScheme.primary,
      );
      await mount(
        tester,
        SpendingLimitCard(limit: 0, spent: 100, onEdit: () {}),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Não definido'), findsOneWidget);
      expect(find.text('Definir limite'), findsOneWidget);
      expect(find.text('R\$ 100,00 gastos'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('limite não definido mostra o gasto real sem inventar valores', (
    tester,
  ) async {
    var edited = false;
    await mount(
      tester,
      SpendingLimitCard(limit: null, spent: 200, onEdit: () => edited = true),
    );
    expect(find.text('Não definido'), findsOneWidget);
    expect(find.text('R\$ 200,00 gastos'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('R\$ 0,00'), findsNothing);
    await tester.tap(find.text('Definir limite'));
    expect(edited, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carregamento e falha são diferentes de limite ausente', (
    tester,
  ) async {
    await mount(
      tester,
      SpendingLimitCard(
        limit: null,
        spent: 200,
        isLoading: true,
        onEdit: () {},
      ),
      settle: false,
    );
    expect(find.text('Carregando limite...'), findsOneWidget);
    expect(find.text('Não definido'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('edit-spending-limit')))
          .onPressed,
      isNull,
    );

    var retried = false;
    await mount(
      tester,
      SpendingLimitCard(
        limit: null,
        spent: 200,
        errorMessage: 'Sem conexão com o banco.',
        onEdit: () {},
        onRetry: () => retried = true,
      ),
    );
    expect(find.text('Limite indisponível'), findsOneWidget);
    expect(find.text('Sem conexão com o banco.'), findsOneWidget);
    expect(find.text('Não definido'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('R\$ 200,00 gastos'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mesmo banner alterna excesso e valor restante em largura de 360',
    (tester) async {
      await mount(tester, const LimitAlertBanner(limit: 1500, spent: 1680));
      expect(find.text('Limite ultrapassado'), findsOneWidget);
      expect(
        find.text('Você gastou R\$ 180,00 acima do limite.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mount(tester, const LimitAlertBanner(limit: 1500, spent: 1050));
      expect(find.text('Dentro do limite'), findsOneWidget);
      expect(find.text('Ainda restam R\$ 450,00 neste mês.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
