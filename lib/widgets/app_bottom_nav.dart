import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // A altura inclui a parte do botão que sobe acima da barra.
    return SizedBox(
      height: 84 + bottomPadding,
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).dashboardSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: AppColors.of(context).outline),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _buildTab(
                      context,
                      index: 0,
                      label: 'Início',
                      icon: Icons.home,
                    ),
                    _buildTab(
                      context,
                      index: 1,
                      label: 'Relatórios',
                      icon: Icons.bar_chart,
                    ),
                    const SizedBox(width: 64),
                    _buildTab(
                      context,
                      index: 2,
                      label: 'Lançamentos',
                      icon: Icons.receipt_long_outlined,
                    ),
                    _buildTab(
                      context,
                      index: 3,
                      label: 'Perfil',
                      icon: Icons.person_outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                label: 'Adicionar lançamento',
                button: true,
                child: Material(
                  color: AppColors.of(context).neon,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('add-transaction'),
                    customBorder: const CircleBorder(),
                    onTap: onAddPressed,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.add,
                        color: AppColors.of(context).background,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selectedIndex == index;

    final color = isSelected
        ? AppColors.of(context).neon
        : AppColors.of(context).textSecondary;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        child: InkWell(
          onTap: () => onTabSelected(index),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                // Ajusta rótulos maiores em telas estreitas.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      color: color,
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
