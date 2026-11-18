import '../utils/formatters.dart';

class MonthlyLimit {
  final String userId;
  final DateTime month;
  final int limitCents;

  MonthlyLimit({
    required this.userId,
    required DateTime month,
    required this.limitCents,
  }) : month = normalizeMonth(month) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('O limite precisa de um usuário.');
    }
    if (limitCents <= 0 || limitCents > maxMoneyCents) {
      throw ArgumentError.value(limitCents, 'limitCents', 'Limite inválido.');
    }
  }

  String get monthKey => formatMonth(month);

  // Cada mês é identificado pela data civil do seu primeiro dia.
  static DateTime normalizeMonth(DateTime value) {
    if (value.year < 1 || value.year > 9999) {
      throw ArgumentError.value(value, 'month', 'Mês inválido.');
    }
    return DateTime(value.year, value.month);
  }

  static String formatMonth(DateTime value) {
    final normalized = normalizeMonth(value);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-01';
  }

  factory MonthlyLimit.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final month = json['month'];
    final limit = json['limit_cents'];
    if (userId is! String || month is! String || limit is! int) {
      throw const FormatException('Dados do limite mensal inválidos.');
    }
    final match = RegExp(r'^([0-9]{4})-(0[1-9]|1[0-2])-01$').firstMatch(month);
    if (match == null || int.parse(match[1]!) == 0) {
      throw const FormatException('O mês precisa usar o primeiro dia.');
    }
    try {
      return MonthlyLimit(
        userId: userId,
        month: DateTime(int.parse(match[1]!), int.parse(match[2]!)),
        limitCents: limit,
      );
    } on ArgumentError {
      throw const FormatException('Dados do limite mensal inválidos.');
    }
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'month': monthKey,
    'limit_cents': limitCents,
  };
}
