// Limite de um lançamento: R$ 99.999.999,99.
const int maxMoneyCents = 9999999999;

// Mantém a compatibilidade com os widgets antigos que recebem double.
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

// Formata centavos sem arredondamento de ponto flutuante.
String formatCentsBRL(int cents) {
  final absolute = cents.abs();
  final integer = (absolute ~/ 100).toString();
  final decimal = (absolute % 100).toString().padLeft(2, '0');
  final grouped = StringBuffer();

  for (var index = 0; index < integer.length; index++) {
    if (index > 0 && (integer.length - index) % 3 == 0) {
      grouped.write('.');
    }
    grouped.write(integer[index]);
  }

  final sign = cents < 0 ? '-' : '';
  return '${sign}R\$ $grouped,$decimal';
}

// Aceita números brasileiros; o formulário decide se zero é permitido.
int? parseBRLCents(String input) {
  final value = input.trim();
  final valid = RegExp(
    r'^(?:[0-9]+|[1-9][0-9]{0,2}(?:\.[0-9]{3})+)(?:,[0-9]{1,2})?$',
  );
  if (!valid.hasMatch(value)) return null;

  final parts = value.replaceAll('.', '').split(',');
  final reais = int.tryParse(parts[0]);
  final decimal = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  final cents = int.tryParse(decimal);
  if (reais == null || cents == null || reais > maxMoneyCents ~/ 100) {
    return null;
  }

  final total = reais * 100 + cents;
  return total <= maxMoneyCents ? total : null;
}
