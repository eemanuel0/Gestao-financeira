import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../widgets/glow_background.dart';

enum EmailConfirmationResult { confirmed, invalid }

class EmailConfirmedScreen extends StatelessWidget {
  final EmailConfirmationResult result;
  final VoidCallback onLogin;

  const EmailConfirmedScreen({
    super.key,
    required this.result,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final confirmed = result == EmailConfirmationResult.confirmed;

    return Scaffold(
      backgroundColor: colors.background,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      confirmed
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 56,
                      color: confirmed ? colors.neon : colors.dashboardExpense,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      confirmed
                          ? 'E-mail confirmado!'
                          : 'Link inválido ou expirado.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.dashboardText,
                      ),
                    ),
                    if (confirmed) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Já pode fazer login.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onLogin,
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
