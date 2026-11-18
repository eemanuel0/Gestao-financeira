import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';

// Cabeçalho compartilhado entre Início e Relatórios.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.savings_outlined, color: AppColors.neon, size: 32),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Finanças',
            style: GoogleFonts.poppins(
              color: AppColors.dashboardText,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // O seletor Pessoal continua apenas visual.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                color: AppColors.dashboardText,
                size: 20,
              ),
              const SizedBox(width: 7),
              Text(
                'Pessoal',
                style: GoogleFonts.poppins(
                  color: AppColors.dashboardText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.dashboardText,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
