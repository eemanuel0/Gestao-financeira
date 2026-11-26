import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/email_confirmation.dart';
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

  // Captura o retorno antes que o Supabase processe os parâmetros da URL.
  final emailConfirmationStatus =
      emailConfirmationStatusFromUri(Uri.base);

  try {
    // Abre o serviço antes de montar as telas, conforme o padrão do projeto.
    final database = await AppDatabase.instance.open(
      detectSessionInUri:
          emailConfirmationStatus == EmailConfirmationStatus.none,
    );

    // O link confirma o e-mail, mas não deve manter o usuário conectado.
    if (emailConfirmationStatus != EmailConfirmationStatus.none) {
      try {
        await database.auth.signOut();
      } catch (error, stackTrace) {
        debugPrint(
          'Não foi possível encerrar a sessão do link: $error\n$stackTrace',
        );
      }
    }

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
        emailConfirmationStatus: emailConfirmationStatus,
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
