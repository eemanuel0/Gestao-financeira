import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_colors.dart';
import 'models/app_user.dart';
import 'models/services/account_service.dart';
import 'models/services/finance_repository.dart';
import 'models/services/monthly_limit_repository.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(fontFamily: 'Poppins'),
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.neon,
      onPrimary: AppColors.background,
      secondary: AppColors.button,
      surface: AppColors.dashboardSurface,
      error: AppColors.dashboardExpense,
    ),
  );
}

class MyApp extends StatefulWidget {
  final AccountService accountService;
  final FinanceRepository repository;
  final MonthlyLimitRepository? monthlyLimitRepository;

  const MyApp({
    super.key,
    required this.accountService,
    required this.repository,
    this.monthlyLimitRepository,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AppUser?>? _subscription;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.accountService.currentUser;
    _subscription = widget.accountService.userChanges.listen(
      (user) {
        if (!mounted) return;
        // Remove formulários e telas antigas quando muda a conta autenticada.
        if (_user?.id != user?.id) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
        setState(() => _user = user);
      },
      onError: (Object error) {
        debugPrint('Falha ao atualizar a sessão: $error');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return MaterialApp(
      title: 'Finanças',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: user == null
          ? WelcomeScreen(accountService: widget.accountService)
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
