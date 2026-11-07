import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../widgets/glow_background.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GlowBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Ícone neon do cofrinho
                Icon(
                  Icons.savings_outlined,
                  size: 150,
                  color: AppColors.neon,
                  shadows: [
                    Shadow(
                      color: AppColors.neon.withOpacity(0.6),
                      blurRadius: 9,
                    ),
                    Shadow(
                      color: AppColors.neon.withOpacity(0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Título
                Text(
                  'Finanças',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtítulo
                Text(
                  'Controle seu dinheiro de forma\nsimples e inteligente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),

                const Spacer(flex: 3),

                // Botão Entrar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Abre a tela de login
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Entrar',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botão Criar conta
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.04),
                      side: const BorderSide(color: AppColors.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Criar conta',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot({required bool active}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.neon : AppColors.dotInactive,
      ),
    );
  }
}
