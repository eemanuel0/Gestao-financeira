import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/utils/date_formatters.dart';
import 'package:gestao_financeira/widgets/app_header.dart';
import 'package:gestao_financeira/widgets/month_selector.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('retorna o mês escolhido sem alterar o valor controlado', (
    tester,
  ) async {
    _setSize(tester, const Size(360, 640));
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, 15);
    final previous = DateTime(now.year, now.month - 1);
    final changes = <DateTime>[];
    await tester.pumpWidget(_app(initial, changes.add));

    expect(changes, isEmpty);
    expect(find.text('Finanças'), findsOneWidget);
    expect(find.text('Pessoal'), findsOneWidget);
    expect(find.text(formatMonthYear(initial)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('month-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Selecione o mês'), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      final month = DateTime(now.year, now.month - index);
      expect(find.byKey(_monthKey(month)), findsOneWidget);
    }
    expect(
      find.byKey(_monthKey(DateTime(now.year, now.month - 6))),
      findsNothing,
    );
    await tester.tap(find.byKey(_monthKey(previous)));
    await tester.pumpAndSettle();

    expect(changes, [previous]);
    expect(find.text(formatMonthYear(initial)), findsOneWidget);
    expect(find.text('Selecione o mês'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('month-selector')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(changes, [previous]);
  });

  testWidgets('permite escolher o sexto mês em uma tela baixa', (tester) async {
    _setSize(tester, const Size(360, 400));
    final now = DateTime.now();
    final oldest = DateTime(now.year, now.month - 5);
    DateTime? chosen;
    await tester.pumpWidget(_app(now, (month) => chosen = month));
    await tester.tap(find.byKey(const ValueKey('month-selector')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(_monthKey(oldest)),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(_monthKey(oldest)));
    await tester.pumpAndSettle();

    expect(chosen, oldest);
    expect(tester.takeException(), isNull);
  });
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ValueKey<String> _monthKey(DateTime date) => ValueKey(
  'month-option-${date.year}-${date.month.toString().padLeft(2, '0')}',
);

Widget _app(DateTime month, ValueChanged<DateTime> onChanged) => MaterialApp(
  home: Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const AppHeader(),
            const SizedBox(height: 20),
            MonthSelector(selectedMonth: month, onChanged: onChanged),
          ],
        ),
      ),
    ),
  ),
);
