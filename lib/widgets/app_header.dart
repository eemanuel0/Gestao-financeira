import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/financial_profile.dart';

// O perfil escolhido pertence à sessão e é controlado pela tela principal.
class AppHeader extends StatelessWidget {
  final String selectedProfileId;
  final ValueChanged<String>? onProfileSelected;
  final bool isSwitchingProfile;
  final String? businessName;
  final bool showFamily;

  const AppHeader({
    super.key,
    this.selectedProfileId = FinancialProfile.personalId,
    this.onProfileSelected,
    this.isSwitchingProfile = false,
    this.businessName,
    this.showFamily = false,
  });

  @override
  Widget build(BuildContext context) {
    final isBusiness = FinancialProfile.isBusinessId(selectedProfileId);
    final name = businessName?.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcons =
            constraints.maxWidth >= 320 &&
            MediaQuery.textScalerOf(context).scale(12) <= 14;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Em fontes maiores, o seletor pode ir para a próxima linha.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      color: AppColors.of(context).neon,
                      size: 32,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Finanças',
                      style: GoogleFonts.poppins(
                        color: AppColors.of(context).dashboardText,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).fieldFill,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.of(context).outline),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      _segment(
                        context,
                        id: FinancialProfile.personalId,
                        label: 'Pessoal',
                        icon: Icons.person_outline,
                        selected:
                            selectedProfileId == FinancialProfile.personalId,
                        showIcon: showIcons,
                      ),
                      _segment(
                        context,
                        id: FinancialProfile.businessId,
                        label: 'Empresa',
                        icon: Icons.storefront_outlined,
                        selected: isBusiness,
                        showIcon: showIcons,
                      ),
                      if (showFamily)
                        _segment(
                          context,
                          id: FinancialProfile.familyId,
                          label: 'Familiar',
                          icon: Icons.groups_outlined,
                          selected:
                              selectedProfileId == FinancialProfile.familyId,
                          showIcon: showIcons,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isBusiness && name != null && name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Empresa ativa: $name',
                child: ExcludeSemantics(
                  child: Text(
                    name,
                    key: const ValueKey('active-business-name'),
                    style: GoogleFonts.poppins(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _segment(
    BuildContext context, {
    required String id,
    required String label,
    required IconData icon,
    required bool selected,
    required bool showIcon,
  }) {
    final enabled = onProfileSelected != null && !isSwitchingProfile;
    final color = selected
        ? AppColors.of(context).neon
        : AppColors.of(context).textSecondary;
    void select() {
      if (enabled && !selected) onProfileSelected!(id);
    }

    return Semantics(
      key: ValueKey('profile-$id'),
      container: true,
      label: label,
      button: true,
      selected: selected,
      enabled: enabled,
      onTap: enabled ? select : null,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? AppColors.of(context).neon.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: enabled ? select : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.poppins(color: color, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
