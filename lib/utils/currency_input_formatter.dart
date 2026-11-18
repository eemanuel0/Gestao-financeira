import 'package:flutter/services.dart';

import 'formatters.dart';

// Os dígitos são centavos: 123456 vira 1.234,56.
class CurrencyInputFormatter extends TextInputFormatter {
  final bool includeCurrencySymbol;

  CurrencyInputFormatter({this.includeCurrencySymbol = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Aguarda o teclado terminar a composição do texto.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    final cents = int.tryParse(digits);

    if (cents == null || cents > maxMoneyCents) {
      return oldValue;
    }

    final currency = formatCentsBRL(cents);
    final text = includeCurrencySymbol
        ? currency
        : currency.replaceFirst('R\$ ', '');

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // Converte o texto formatado para centavos.
  static int? parseCents(String value) {
    final number = value.replaceFirst(RegExp(r'^\s*R\$\s*'), '');
    return parseBRLCents(number);
  }
}
