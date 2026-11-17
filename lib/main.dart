import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_database.dart';
import 'models/services/supabase_account_service.dart';
import 'models/services/supabase_finance_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Abre o serviço antes de montar as telas, conforme o padrão do projeto.
    final database = await AppDatabase.instance.database;
    runApp(
      MyApp(
        accountService: SupabaseAccountService(database),
        repository: SupabaseFinanceRepository(database),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Falha ao iniciar Finanças: $error\n$stackTrace');
    runApp(const StartupFailureApp());
  }
}
