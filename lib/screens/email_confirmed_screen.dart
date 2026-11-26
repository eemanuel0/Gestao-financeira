import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/services/account_service.dart';
import '../widgets/glow_background.dart';
import 'login_screen.dart';

class EmailConfirmedScreen extends StatelessWidget {
  final AccountService accountService;
  final bool isError;

  const EmailConfirmedScreen({
    super.key,
    required this.accountService,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = isError ? colors.dashboardExpense : colors.neon;

    return Scaffold(
      backgroundColor: colors.background,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 88,
                      color: accent,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      isError
                          ? 'Link inválido ou expirado.'
                          : 'E-mail confirmado!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colors.dashboardText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isError
                          ? 'Volte para o login para continuar.'
                          : 'Já pode fazer login.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('email-confirmed-login'),
                        onPressed: () {
                          Navigator.of(context).pushReplacement<void, void>(
                            MaterialPageRoute<void>(
                              builder: (_) => LoginScreen(
                                accountService: accountService,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.button,
                          foregroundColor: colors.background,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Ir para o login',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
