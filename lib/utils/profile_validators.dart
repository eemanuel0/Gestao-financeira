// O formato não comprova que o CNPJ existe ou está ativo na Receita.
String normalizeCnpj(String value) =>
    value.replaceAll(RegExp(r'[\s./-]'), '').toUpperCase();

bool isValidCnpj(String value) {
  final unformatted = value.replaceAll(RegExp(r'[\s./-]'), '');
  if (!RegExp(r'^[A-Za-z0-9]{12}[0-9]{2}$').hasMatch(unformatted)) {
    return false;
  }
  final cnpj = normalizeCnpj(value);
  if (RegExp(r'^([0-9])\1{13}$').hasMatch(cnpj)) return false;
  final numbers = cnpj.codeUnits.map((code) => code - 48).toList();
  int digit(List<int> weights) {
    var sum = 0;
    for (var index = 0; index < weights.length; index++) {
      sum += numbers[index] * weights[index];
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  return numbers[12] == digit([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) &&
      numbers[13] == digit([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
}

String formatCnpj(String value) {
  final cnpj = normalizeCnpj(value);
  if (!RegExp(r'^[A-Z0-9]{12}[0-9]{2}$').hasMatch(cnpj)) return cnpj;
  return '${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.'
      '${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12)}';
}
