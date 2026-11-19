import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/app_settings.dart';
import 'models/services/supabase_password_service.dart';

import 'core/app_database.dart';
import 'models/services/supabase_account_service.dart';
import 'models/services/supabase_finance_repository.dart';
import 'models/services/supabase_financial_profile_repository.dart';
import 'models/services/supabase_monthly_limit_repository.dart';
import 'models/services/supabase_profile_details_repository.dart';
import 'utils/profile_image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Abre o serviço antes de montar as telas, conforme o padrão do projeto.
    final database = await AppDatabase.instance.database;
    final settings = await AppSettingsController.load();
    final config = AppConfig.fromEnvironment();
    final passwords = SupabasePasswordService(
      database,
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    runApp(
      MyApp(
        passwordService: passwords,
        settings: settings,
        accountService: SupabaseAccountService(database),
        repository: SupabaseFinanceRepository(database),
        monthlyLimitRepository: SupabaseMonthlyLimitRepository(database),
        profileRepository: SupabaseFinancialProfileRepository(database),
        financeRepositoryForProfile: (profileId) =>
            SupabaseFinanceRepository(database, profileId: profileId),
        monthlyLimitRepositoryForProfile: (profileId) =>
            SupabaseMonthlyLimitRepository(database, profileId: profileId),
        profileDetailsRepository: SupabaseProfileDetailsRepository(database),
        imagePicker: pickProfileImage,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Falha ao iniciar Finanças: $error\n$stackTrace');
    runApp(const StartupFailureApp());
  }
}
