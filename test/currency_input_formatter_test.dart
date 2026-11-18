import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/utils/currency_input_formatter.dart';
import 'package:gestao_financeira/utils/formatters.dart';

void main() {
  test('digita centavos e agrupa os milhares sem símbolos no controller', () {
    final formatter = CurrencyInputFormatter();
    for (final entry in {
      '1': '0,01',
      '12': '0,12',
      '123': '1,23',
      '123456': '1.234,56',
      '1.234,56': '1.234,56',
      '000': '0,00',
    }.entries) {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: entry.key),
      );
      expect(result.text, entry.value);
      expect(result.selection.baseOffset, result.text.length);
    }
  });

  test('prefixo e exclusão usam o mesmo valor em centavos', () {
    final formatter = CurrencyInputFormatter(includeCurrencySymbol: true);
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '123456'),
    );
    expect(result.text, 'R\$ 1.234,56');
    expect(CurrencyInputFormatter.parseCents(result.text), 123456);
    expect(
      formatter
          .formatEditUpdate(result, const TextEditingValue(text: 'R\$ 1.234,5'))
          .text,
      'R\$ 123,45',
    );
    expect(
      formatter.formatEditUpdate(result, const TextEditingValue(text: 'R\$ ')),
      TextEditingValue.empty,
    );
  });

  test('preserva composição IME e rejeita valores acima do limite', () {
    final formatter = CurrencyInputFormatter();
    const composing = TextEditingValue(
      text: '123',
      composing: TextRange(start: 0, end: 3),
    );
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, composing),
      composing,
    );
    final maximum = formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: '$maxMoneyCents'),
    );
    expect(maximum.text, '99.999.999,99');
    expect(
      formatter.formatEditUpdate(
        maximum,
        TextEditingValue(text: '${maxMoneyCents}0'),
      ),
      maximum,
    );
    expect(
      formatter.formatEditUpdate(maximum, TextEditingValue(text: '9' * 100)),
      maximum,
    );
  });

  test('parse aceita prefixo e mantém inválidos como null', () {
    expect(CurrencyInputFormatter.parseCents('R\$ 1.234,56'), 123456);
    expect(CurrencyInputFormatter.parseCents('  R\$ 0,00  '), 0);
    expect(CurrencyInputFormatter.parseCents('250,00'), 25000);
    for (final value in ['', 'R\$ ', '-1,00', 'abc', 'R\$ R\$ 1,00', '1.23']) {
      expect(CurrencyInputFormatter.parseCents(value), isNull);
    }
  });
}
