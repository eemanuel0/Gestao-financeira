import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_theme.dart';
import 'core/app_settings.dart';
import 'models/services/password_service.dart';
import 'models/app_user.dart';
import 'models/picked_profile_image.dart';
import 'models/services/account_service.dart';
import 'models/services/finance_repository.dart';
import 'models/services/financial_profile_repository.dart';
import 'models/services/monthly_limit_repository.dart';
import 'models/services/profile_details_repository.dart';
import 'screens/home_screen.dart';
import 'screens/financial_workspace.dart';
import 'screens/welcome_screen.dart';

// Mantém a chamada antiga buildAppTheme() compatível com as telas e testes.
ThemeData buildAppTheme([Brightness brightness = Brightness.dark]) =>
    createAppTheme(brightness);

class MyApp extends StatefulWidget {
  final AccountService accountService;
  final PasswordService? passwordService;
  final AppSettingsController? settings;
  final FinanceRepository repository;
  final MonthlyLimitRepository? monthlyLimitRepository;
  final FinancialProfileRepository? profileRepository;
  final FinanceRepository Function(String profileId)?
  financeRepositoryForProfile;
  final MonthlyLimitRepository Function(String profileId)?
  monthlyLimitRepositoryForProfile;
  final ProfileDetailsRepository? profileDetailsRepository;
  final Future<PickedProfileImage?> Function()? imagePicker;

  const MyApp({
    super.key,
    required this.accountService,
    this.passwordService,
    this.settings,
    required this.repository,
    this.monthlyLimitRepository,
    this.profileRepository,
    this.financeRepositoryForProfile,
    this.monthlyLimitRepositoryForProfile,
    this.profileDetailsRepository,
    this.imagePicker,
  }) : assert(
         (profileRepository == null &&
                 financeRepositoryForProfile == null &&
                 monthlyLimitRepositoryForProfile == null) ||
             (profileRepository != null &&
                 financeRepositoryForProfile != null &&
                 monthlyLimitRepositoryForProfile != null),
       );

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<AppUser?>? _subscription;
  AppUser? _user;
  late final AppSettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? AppSettingsController();
    _settings.addListener(_appearanceChanged);
    _user = widget.accountService.currentUser;
    _subscription = widget.accountService.userChanges.listen(
      (user) {
        if (!mounted) return;
        // Remove formulários e telas antigas quando muda a conta autenticada.
        if (_user?.id != user?.id) {
          // Remove avisos que podem conter valores da conta anterior.
          _messengerKey.currentState
            ?..clearSnackBars()
            ..removeCurrentSnackBar();
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
        setState(() => _user = user);
      },
      onError: (Object error) {
        debugPrint('Falha ao atualizar a sessão: $error');
      },
    );
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_appearanceChanged);
    if (widget.settings == null) _settings.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return MaterialApp(
      title: 'Finanças',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(),
      // Troca o tema preservando o estado e a navegação já abertos.
      themeMode: _settings.mode,
      builder: (context, child) => AppSettingsScope(
        controller: _settings,
        passwords: widget.passwordService,
        child: child!,
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: user == null
          ? WelcomeScreen(accountService: widget.accountService)
          : widget.profileRepository != null
          ? FinancialWorkspace(
              key: ValueKey(user.id),
              user: user,
              accountService: widget.accountService,
              profileRepository: widget.profileRepository!,
              financeRepositoryForProfile: widget.financeRepositoryForProfile!,
              monthlyLimitRepositoryForProfile:
                  widget.monthlyLimitRepositoryForProfile!,
              profileDetailsRepository: widget.profileDetailsRepository,
              imagePicker: widget.imagePicker,
            )
          : HomeScreen(
              key: ValueKey(user.id),
              user: user,
              accountService: widget.accountService,
              repository: widget.repository,
              monthlyLimitRepository: widget.monthlyLimitRepository,
            ),
    );
  }
}

// Evita uma tela branca se a configuração ou a inicialização falharem.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível iniciar o aplicativo.\n'
                'Tente novamente em alguns instantes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
