import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/models/app_user.dart';
import 'package:gestao_financeira/models/business_profile_data.dart';
import 'package:gestao_financeira/models/financial_profile.dart';
import 'package:gestao_financeira/utils/profile_input_formatters.dart';
import 'package:gestao_financeira/utils/profile_validators.dart';
import 'package:gestao_financeira/widgets/edit_profile_sheet.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('CNPJ digitado e colado mantém somente as 14 posições permitidas', () {
    final formatter = CnpjInputFormatter();
    var value = TextEditingValue.empty;
    for (final character in '00000000e08g12'.split('')) {
      value = formatter.formatEditUpdate(value, _value(value.text + character));
    }
    expect(value.text, '00.000.000/E08G-12');
    expect(isValidCnpj(value.text), isTrue);
    final extra = formatter.formatEditUpdate(value, _value('${value.text}9'));
    expect(extra.text, value.text);
    expect(normalizeCnpj(extra.text), hasLength(14));

    for (final pasted in [
      '00000000e08g129876',
      '00.000.000/e08g-129876',
      '11.222.333/0001-81999',
    ]) {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _value(pasted),
      );
      expect(normalizeCnpj(result.text), hasLength(14));
      expect(result.text, hasLength(18));
      expect(isValidCnpj(result.text), isTrue);
    }
  });

  test('CNPJ bloqueia letras nos DVs e não expande caracteres não ASCII', () {
    final formatter = CnpjInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      _value('AB12CD34EF56AZ'),
    );
    expect(normalizeCnpj(result.text), 'AB12CD34EF56');
    final digits = formatter.formatEditUpdate(
      result,
      _value('${result.text}12'),
    );
    expect(normalizeCnpj(digits.text), 'AB12CD34EF5612');
    final unicode = formatter.formatEditUpdate(
      TextEditingValue.empty,
      _value('00.000.000/ß08G-12'),
    );
    expect(unicode.text.contains('ß'), isFalse);
    expect(unicode.text.contains('SS'), isFalse);
  });

  test(
    'CNPJ permite apagar perto da máscara e rejeita inserção em campo cheio',
    () {
      final formatter = CnpjInputFormatter();
      final old = _value('11.222.333/0001-81')
          .copyWith(selection: const TextSelection.collapsed(offset: 3));
      final removeDot = formatter.formatEditUpdate(
        old,
        _value('11222.333/0001-81')
            .copyWith(selection: const TextSelection.collapsed(offset: 2)),
      );
      expect(removeDot.text, old.text);
      expect(removeDot.selection.baseOffset, 2);
      final deleteDigit = formatter.formatEditUpdate(
        removeDot,
        _value('1.222.333/0001-81')
            .copyWith(selection: const TextSelection.collapsed(offset: 1)),
      );
      expect(normalizeCnpj(deleteDigit.text), hasLength(13));
      expect(deleteDigit.selection.baseOffset, 1);
      final middle = old.copyWith(
        selection: const TextSelection.collapsed(offset: 6),
      );
      expect(
        formatter.formatEditUpdate(middle, _value('11.2229.333/0001-81')),
        middle,
      );
    },
  );

  test('telefone conserva DDD/DDI e bloqueia o 16º dígito', () {
    final formatter = PhoneInputFormatter();
    const formatted = '+55 (71) 99999-1234';
    final preserved = formatter.formatEditUpdate(
      TextEditingValue.empty,
      _value(formatted),
    );
    expect(preserved.text, formatted);

    var value = TextEditingValue.empty;
    for (final character in '+123456789012345'.split('')) {
      value = formatter.formatEditUpdate(value, _value(value.text + character));
    }
    expect(value.text, '+123456789012345');
    expect(
      formatter.formatEditUpdate(value, _value('${value.text}6')).text,
      value.text,
    );
    final pasted = formatter.formatEditUpdate(
      TextEditingValue.empty,
      _value(' +55 (71) 99999-123456789abc+'),
    );
    expect(pasted.text, '+55 (71) 99999-123456');
    expect(_digits(pasted.text), hasLength(15));
    expect(pasted.text, isNot(contains('abc')));
    expect(pasted.text.split('+'), hasLength(2));
  });

  test(
    'telefone também limita a apresentação e mantém o cursor após filtrar',
    () {
      final formatter = PhoneInputFormatter();
      final padding = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _value('12345678${' ' * 80}'),
      );
      expect(padding.text.length, lessThanOrEqualTo(32));
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _value('12x34')
            .copyWith(selection: const TextSelection.collapsed(offset: 3)),
      );
      expect(result.text, '1234');
      expect(result.selection.baseOffset, 2);
    },
  );

  test('composição do teclado não é reescrita antes de ser concluída', () {
    final value = _value('00000000e')
        .copyWith(composing: const TextRange(start: 8, end: 9));
    expect(
      CnpjInputFormatter().formatEditUpdate(TextEditingValue.empty, value),
      value,
    );
    expect(
      PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, value),
      value,
    );
  });

  testWidgets('campos limitam a digitação e a colagem antes de salvar', (
    tester,
  ) async {
    BusinessProfileData? saved;
    var calls = 0;
    await _mount(
      tester,
      onSave: (data) async {
        calls++;
        saved = data;
      },
    );
    final cnpj = find.byKey(const ValueKey('business-cnpj-input'));
    final phone = find.byKey(const ValueKey('business-phone-input'));
    await _enter(tester, cnpj, '00000000e08g1299999');
    expect(_text(tester, cnpj), '00.000.000/E08G-12');
    await _enter(tester, cnpj, '${_text(tester, cnpj)}9');
    expect(_text(tester, cnpj), '00.000.000/E08G-12');
    await _enter(tester, phone, '+55 (71) 99999-123456789');
    expect(_digits(_text(tester, phone)), hasLength(15));
    await _enter(tester, phone, '${_text(tester, phone)}9');
    expect(_digits(_text(tester, phone)), hasLength(15));
    expect(calls, 0);
    final save = find.byKey(const ValueKey('save-profile'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(saved!.cnpj, '00000000E08G12');
    expect(_digits(saved!.contactPhone!), hasLength(15));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dados já salvos permanecem completos ao abrir e salvar o editor',
    (tester) async {
      BusinessProfileData? saved;
      await _mount(
        tester,
        cnpj: '00000000E08G12',
        phone: '+55 (71) 99999-1234',
        onSave: (data) async => saved = data,
      );
      final cnpj = find.byKey(const ValueKey('business-cnpj-input'));
      final phone = find.byKey(const ValueKey('business-phone-input'));
      expect(_text(tester, cnpj), '00.000.000/E08G-12');
      expect(_text(tester, phone), '+55 (71) 99999-1234');
      final save = find.byKey(const ValueKey('save-profile'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved!.cnpj, '00000000E08G12');
      expect(saved!.contactPhone, '+55 (71) 99999-1234');
      expect(tester.takeException(), isNull);
    },
  );
}

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

String _digits(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<TextFormField>(finder).controller!.text;

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _mount(
  WidgetTester tester, {
  String? cnpj,
  String? phone,
  required Future<void> Function(BusinessProfileData) onSave,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 900);
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
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showEditProfileSheet(
                context,
                user: const AppUser(
                  id: 'user-a',
                  email: 'ana@teste.com',
                  name: 'Ana',
                ),
                financialProfile: FinancialProfile(
                  id: 'business',
                  userId: 'user-a',
                  name: 'Empresa',
                  kind: FinancialProfileKind.business,
                  cnpj: cnpj,
                  contactPhone: phone,
                ),
                onSaveBusiness: onSave,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
