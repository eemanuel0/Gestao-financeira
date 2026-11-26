import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'screens/email_confirmed_screen.dart';
import 'utils/profile_image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // O Supabase pode limpar os parâmetros ao processar o link na inicialização.
    final emailConfirmation = kIsWeb ? _readEmailConfirmation(Uri.base) : null;
    // Abre o serviço antes de montar as telas, conforme o padrão do projeto.
    final database = await AppDatabase.instance.database;
    if (emailConfirmation == EmailConfirmationResult.confirmed) {
      try {
        await database.auth.signOut();
      } on AuthException {
        // O SDK encerra a sessão local antes de revogá-la no servidor.
        if (database.auth.currentSession != null) rethrow;
        debugPrint(
          'Não foi possível revogar a sessão de confirmação no Supabase.',
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
        emailConfirmation: emailConfirmation,
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

EmailConfirmationResult? _readEmailConfirmation(Uri uri) {
  final parameters = [uri.queryParameters, Uri.splitQueryString(uri.fragment)];
  if (parameters.any(
    (values) =>
        values.containsKey('error_code') || values['error'] == 'access_denied',
  )) {
    return EmailConfirmationResult.invalid;
  }
  if (parameters.any(
    (values) =>
        values['type'] == 'signup' ||
        values.containsKey('access_token') ||
        values.containsKey('code'),
  )) {
    return EmailConfirmationResult.confirmed;
  }
  return null;
}
