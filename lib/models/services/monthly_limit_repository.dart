import '../monthly_limit.dart';

abstract interface class MonthlyLimitRepository {
  // Ausência é diferente de falha de conexão ou de configuração do banco.
  Future<MonthlyLimit?> loadForMonth(DateTime month);

  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  });
}
