import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/utils/formatters.dart';

void main() {
  group('formatCentsBRL', () {
    test('formata zero, centavos, milhares e saldo negativo', () {
      expect(formatCentsBRL(0), 'R\$ 0,00');
      expect(formatCentsBRL(1), 'R\$ 0,01');
      expect(formatCentsBRL(10), 'R\$ 0,10');
      expect(formatCentsBRL(392240), 'R\$ 3.922,40');
      expect(formatCentsBRL(-123456), '-R\$ 1.234,56');
      expect(formatCentsBRL(maxMoneyCents), 'R\$ 99.999.999,99');
    });
  });

  group('parseBRLCents', () {
    test('interpreta números brasileiros sem usar double', () {
      final examples = <String, int>{
        '1.234,56': 123456,
        '10': 1000,
        '10,5': 1050,
        '0,01': 1,
        '1.234': 123400,
        '4500,00': 450000,
        ' 42,99 ': 4299,
        '0': 0,
        '0,00': 0,
        '99.999.999,99': maxMoneyCents,
      };

      for (final entry in examples.entries) {
        expect(parseBRLCents(entry.key), entry.value, reason: entry.key);
      }
    });

    test('rejeita valores negativos, agrupamentos incorretos e excesso', () {
      const invalid = [
        '',
        ' ',
        '-1',
        '+1',
        'R\$ 10,00',
        '1.23',
        '1234.567',
        '1,234',
        '1,',
        ',50',
        '1 234,56',
        '1e3',
        'NaN',
        '100.000.000,00',
        '99999999999999999999999999999',
      ];

      for (final value in invalid) {
        expect(parseBRLCents(value), isNull, reason: value);
      }
    });

    test('preserva centavos ao converter texto formatado novamente', () {
      for (final cents in [1, 10, 29, 105, 99999, maxMoneyCents]) {
        final text = formatCentsBRL(cents).replaceFirst('R\$ ', '');
        expect(parseBRLCents(text), cents);
      }
    });
  });

  group('formatBRL compatível', () {
    test('mantém a saída usada pelos widgets existentes', () {
      expect(formatBRL(3922.40), 'R\$ 3.922,40');
      expect(formatBRL(0), 'R\$ 0,00');
      expect(formatBRL(-577.60), '-R\$ 577,60');
    });

    test('rejeita números não finitos', () {
      expect(() => formatBRL(double.nan), throwsArgumentError);
      expect(() => formatBRL(double.infinity), throwsArgumentError);
    });
  });
}
