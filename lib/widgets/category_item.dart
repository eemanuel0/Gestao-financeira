import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/category_spending.dart';

class CategoryItem extends StatelessWidget {
  final CategorySpending category;

  const CategoryItem({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ícone dentro do quadrado arredondado.
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.of(context).fieldFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            category.icon,
            color: AppColors.of(context).dashboardText,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: GoogleFonts.poppins(
                        color: AppColors.of(context).dashboardText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${category.percentage.toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              // Converte o percentual para a escala de 0 a 1.
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: category.percentage / 100,
                  minHeight: 8,
                  color: AppColors.of(context).neon,
                  backgroundColor: AppColors.of(context).dashboardTrack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
