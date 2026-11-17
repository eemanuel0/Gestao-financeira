// Converte números para o formato brasileiro: R$ 3.922,40.
String formatBRL(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      'value',
      'O valor precisa ser um número finito.',
    );
  }

  final parts = value.abs().toStringAsFixed(2).split('.');
  final integerPart = parts[0];
  final decimalPart = parts[1];
  final formattedInteger = StringBuffer();

  // Insere o ponto a cada grupo de três números.
  for (var index = 0; index < integerPart.length; index++) {
    if (index > 0 && (integerPart.length - index) % 3 == 0) {
      formattedInteger.write('.');
    }

    formattedInteger.write(integerPart[index]);
  }

  final sign = value < 0 ? '-' : '';

  return '${sign}R\$ $formattedInteger,$decimalPart';
}
