import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../utils/formatters.dart';

class LimitAlertBanner extends StatelessWidget {
  final double limit;
  final double spent;

  const LimitAlertBanner({super.key, required this.limit, required this.spent});

  @override
  Widget build(BuildContext context) {
    final exceeded = spent > limit;
    final color = exceeded ? AppColors.dashboardExpense : AppColors.neon;

    final border = exceeded
        ? AppColors.limitExceededBorder
        : AppColors.limitWithinBorder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exceeded
            ? AppColors.limitExceededBackground
            : AppColors.limitWithinBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            exceeded ? Icons.notifications_none : Icons.check_circle_outline,
            color: color,
            size: 26,
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 44, color: border),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exceeded ? 'Limite ultrapassado' : 'Dentro do limite',
                  style: GoogleFonts.poppins(
                    color: AppColors.dashboardText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),

                // O mesmo widget calcula as duas mensagens.
                Text(
                  exceeded
                      ? 'Você gastou ${formatBRL(spent - limit)} acima do limite.'
                      : 'Ainda restam ${formatBRL(limit - spent)} neste mês.',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
