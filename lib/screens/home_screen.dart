import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/category_spending.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/balance_card.dart';
import '../widgets/category_item.dart';
import '../widgets/summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Dados fixos usados enquanto não existe integração.
  static const List<CategorySpending> _categories = [
    CategorySpending(
      name: 'Alimentação',
      icon: Icons.restaurant,
      percentage: 42,
    ),
    CategorySpending(
      name: 'Moradia',
      icon: Icons.home_outlined,
      percentage: 24,
    ),
    CategorySpending(
      name: 'Transporte',
      icon: Icons.directions_car_outlined,
      percentage: 12,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: SafeArea(
        bottom: false,
        // Preserva o saldo oculto e a rolagem ao trocar de aba.
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboard(),
            _buildComingSoon(),
            _buildComingSoon(),
            _buildComingSoon(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // Evita esticar demais o conteúdo no navegador.
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),

              // Saudação.
              Text(
                'Olá, Emanuel',
                style: GoogleFonts.poppins(
                  color: AppColors.dashboardText,
                  fontSize: 25,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aqui está o resumo das suas finanças.',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),

              // Card principal.
              const BalanceCard(balance: 3922.40),
              const SizedBox(height: 14),

              // Cards de receitas e despesas.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Receitas',
                      amount: 4500,
                      icon: Icons.arrow_upward,
                      accentColor: AppColors.neon,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SummaryCard(
                      title: 'Despesas',
                      amount: 577.60,
                      icon: Icons.arrow_downward,
                      accentColor: AppColors.dashboardExpense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Gastos separados por categoria.
              Text(
                'Gastos por categoria',
                style: GoogleFonts.poppins(
                  color: AppColors.dashboardText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < _categories.length; index++) ...[
                CategoryItem(category: _categories[index]),
                if (index < _categories.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Seletor de conta apenas visual.
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

  Widget _buildComingSoon() {
    return Center(
      child: Text(
        'Em breve',
        style: GoogleFonts.poppins(
          color: AppColors.textSecondary,
          fontSize: 18,
        ),
      ),
    );
  }
}
