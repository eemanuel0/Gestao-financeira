import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../utils/formatters.dart';

class SpendingLimitCard extends StatelessWidget {
  final double? limit;
  final double spent;
  final VoidCallback onEdit;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const SpendingLimitCard({
    super.key,
    required this.limit,
    required this.spent,
    required this.onEdit,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final value = limit;
    final hasError = errorMessage != null;
    final ready = !isLoading && !hasError;
    final hasLimit = value != null && value.isFinite && value > 0;
    // A barra só existe quando há um limite válido carregado.
    final ratio = hasLimit ? spent / value : 0.0;
    final color = hasLimit && spent > value
        ? AppColors.of(context).dashboardExpense
        : AppColors.of(context).neon;
    final label = ready && !hasLimit ? 'Definir limite' : 'Editar limite';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.of(context).fieldFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.of(context).outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Limite mensal',
                  style: GoogleFonts.poppins(
                    color: AppColors.of(context).dashboardText,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('edit-spending-limit'),
                onPressed: ready ? onEdit : null,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(label, style: GoogleFonts.poppins(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.of(context).neon,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isLoading
                    ? 'Carregando limite...'
                    : hasError
                    ? 'Limite indisponível'
                    : hasLimit
                    ? formatBRL(value)
                    : 'Não definido',
                style: GoogleFonts.poppins(
                  color: AppColors.of(context).dashboardText,
                  fontSize: isLoading || hasError ? 20 : 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (isLoading)
            LinearProgressIndicator(
              minHeight: 8,
              color: AppColors.of(context).neon,
              backgroundColor: AppColors.of(context).dashboardTrack,
            )
          else if (hasError) ...[
            Text(
              errorMessage!,
              style: GoogleFonts.poppins(
                color: AppColors.of(context).textSecondary,
                fontSize: 12,
              ),
            ),
            if (onRetry != null)
              TextButton.icon(
                key: const ValueKey('retry-spending-limit'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Tentar novamente', style: GoogleFonts.poppins()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.of(context).neon,
                ),
              ),
          ] else if (hasLimit)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
                      color: color,
                      backgroundColor: AppColors.of(context).dashboardTrack,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(ratio * 100).round()}%',
                  style: GoogleFonts.poppins(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            '${formatBRL(spent)} gastos',
            style: GoogleFonts.poppins(
              color: AppColors.of(context).textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
