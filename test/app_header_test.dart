import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/widgets/app_header.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('um clique alterna o perfil e anuncia a seleção acessível', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var selected = 'personal';
      final selections = <String>[];
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AppHeader(
              selectedProfileId: selected,
              businessName: 'Loja da Ana',
              onProfileSelected: (value) {
                selections.add(value);
                setState(() => selected = value);
              },
            );
          },
        ),
      );
      final personal = find.byKey(const ValueKey('profile-personal'));
      final business = find.byKey(const ValueKey('profile-business'));
      expect(personal, findsOneWidget);
      expect(business, findsOneWidget);
      expect(find.text('Pessoal'), findsOneWidget);
      expect(find.text('Empresa'), findsOneWidget);
      expect(find.text('Loja da Ana'), findsNothing);
      expect(
        tester.getSemantics(personal),
        isSemantics(
          label: 'Pessoal',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      await tester.tap(business);
      await tester.pumpAndSettle();
      expect(selections, ['business']);
      expect(find.text('Loja da Ana'), findsOneWidget);
      expect(
        tester.getSemantics(business),
        isSemantics(
          label: 'Empresa',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(tester.getSemantics(personal), isSemantics(isSelected: false));

      await tester.tap(personal);
      await tester.pumpAndSettle();
      expect(selections, ['business', 'personal']);
      expect(find.text('Loja da Ana'), findsNothing);
      // A seleção atual não dispara outra troca de perfil.
      await tester.tap(personal);
      await tester.pump();
      expect(selections, ['business', 'personal']);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'sem callback e durante troca os dois segmentos ficam bloqueados',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester, const AppHeader());
        final personal = find.byKey(const ValueKey('profile-personal'));
        final business = find.byKey(const ValueKey('profile-business'));
        expect(
          tester.getSemantics(personal),
          isSemantics(
            hasEnabledState: true,
            isEnabled: false,
            isSelected: true,
            hasTapAction: false,
          ),
        );
        expect(
          tester.getSemantics(business),
          isSemantics(
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        await tester.tap(business, warnIfMissed: false);
        await tester.pump();
        expect(tester.getSemantics(personal), isSemantics(isSelected: true));

        final selections = <String>[];
        await _mount(
          tester,
          AppHeader(
            selectedProfileId: 'business',
            businessName: 'Empresa atual',
            isSwitchingProfile: true,
            onProfileSelected: selections.add,
          ),
          settle: false,
        );
        await tester.tap(personal, warnIfMissed: false);
        await tester.tap(business, warnIfMissed: false);
        await tester.pump();
        expect(selections, isEmpty);
        expect(
          tester.getSemantics(business),
          isSemantics(
            isSelected: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        expect(find.text('Empresa atual'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final width in [320.0, 360.0]) {
    testWidgets(
      'nome completo e segmentos cabem em $width com texto ampliado',
      (tester) async {
        final name = 'Empresa ${'A' * 52}';
        await _mount(
          tester,
          AppHeader(
            selectedProfileId: 'business',
            businessName: name,
            onProfileSelected: (_) {},
          ),
          width: width,
          textScale: 1.5,
        );
        expect(find.text('Finanças'), findsOneWidget);
        expect(find.text('Pessoal'), findsOneWidget);
        expect(find.text('Empresa'), findsOneWidget);
        expect(find.text(name), findsOneWidget);
        final nameParagraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(name), matching: find.byType(RichText)),
        );
        expect(nameParagraph.didExceedMaxLines, isFalse);
        expect(find.byKey(const ValueKey('profile-personal')), findsOneWidget);
        expect(find.byKey(const ValueKey('profile-business')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 720),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}
