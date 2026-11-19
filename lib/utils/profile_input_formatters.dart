import 'package:flutter/services.dart';

// As 14 posições do CNPJ ocupam 18 caracteres quando pontuadas.
class CnpjInputFormatter extends TextInputFormatter {
  static const int maxCharacters = 14;
  static const int maxFormattedLength = 18;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_hasComposition(newValue)) return newValue;
    final characters = <int>[];
    final sourceEnds = <int>[];
    for (var index = 0; index < newValue.text.length; index++) {
      final code = newValue.text.codeUnitAt(index);
      final digit = code >= 48 && code <= 57;
      final upper = code >= 65 && code <= 90;
      final lower = code >= 97 && code <= 122;
      if ((characters.length < 12 && (digit || upper || lower)) ||
          (characters.length >= 12 && digit)) {
        characters.add(lower ? code - 32 : code);
        sourceEnds.add(index + 1);
      }
    }
    if (_fullCollapsed(oldValue, maxCharacters, _cnpjCharacterCount) &&
        characters.length > maxCharacters) {
      return oldValue;
    }
    final used = characters.take(maxCharacters).toList();
    final result = StringBuffer();
    for (var index = 0; index < used.length; index++) {
      if (index == 2 || index == 5) result.write('.');
      if (index == 8) result.write('/');
      if (index == 12) result.write('-');
      result.writeCharCode(used[index]);
    }
    final text = result.toString();
    int caret(int offset) {
      if (offset < 0) return text.length;
      final before = sourceEnds
          .take(maxCharacters)
          .where((end) => end <= offset)
          .length;
      if (before == 0) return 0;
      var seen = 0;
      for (var index = 0; index < text.length; index++) {
        if (_isAsciiAlphanumeric(text.codeUnitAt(index))) seen++;
        if (seen == before) return index + 1;
      }
      return text.length;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: caret(newValue.selection.baseOffset),
        extentOffset: caret(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}

// Conserva a apresentação já salva e limita os dígitos, incluindo DDD/DDI.
class PhoneInputFormatter extends TextInputFormatter {
  static const int maxDigits = 15;
  static const int maxFormattedLength = 32;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_hasComposition(newValue)) return newValue;
    if (_fullCollapsed(oldValue, maxDigits, _phoneDigitCount) &&
        _phoneDigitCount(newValue.text) > maxDigits) {
      return oldValue;
    }
    final result = StringBuffer();
    final sourceEnds = <int>[];
    var digits = 0;
    for (var index = 0; index < newValue.text.length; index++) {
      if (result.length >= maxFormattedLength) break;
      final code = newValue.text.codeUnitAt(index);
      final isDigit = code >= 48 && code <= 57;
      if (isDigit && digits < maxDigits) {
        result.writeCharCode(code);
        sourceEnds.add(index + 1);
        digits++;
      } else if (code == 43 && result.isEmpty) {
        result.write('+');
        sourceEnds.add(index + 1);
      } else if ((code == 40 ||
          code == 41 ||
          code == 46 ||
          code == 45 ||
          (code == 32 && result.isNotEmpty))) {
        result.writeCharCode(code);
        sourceEnds.add(index + 1);
      }
    }
    final text = result.toString();
    int caret(int offset) => offset < 0
        ? text.length
        : sourceEnds.where((end) => end <= offset).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: caret(newValue.selection.baseOffset),
        extentOffset: caret(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}

bool _hasComposition(TextEditingValue value) =>
    value.composing.isValid && !value.composing.isCollapsed;

bool _isAsciiAlphanumeric(int code) =>
    (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122);

int _cnpjCharacterCount(String text) =>
    text.codeUnits.where(_isAsciiAlphanumeric).length;

int _phoneDigitCount(String text) =>
    text.codeUnits.where((code) => code >= 48 && code <= 57).length;

bool _fullCollapsed(
  TextEditingValue oldValue,
  int limit,
  int Function(String) count,
) => oldValue.selection.isCollapsed && count(oldValue.text) >= limit;
