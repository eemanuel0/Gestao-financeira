import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/utils/date_formatters.dart';

void main() {
  test('formata nomes em português e preserva o ano', () {
    expect(formatMonthYear(DateTime(2026, 1, 31)), 'Janeiro de 2026');
    expect(formatMonthYear(DateTime(2024, 3, 1)), 'Março de 2024');
    expect(formatMonthYear(DateTime(2026, 11, 16)), 'Novembro de 2026');
    expect(formatMonthYear(DateTime(2025, 12, 31)), 'Dezembro de 2025');
  });
}
