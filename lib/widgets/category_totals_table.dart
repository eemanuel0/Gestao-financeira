import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/category_total.dart';
import '../utils/formatters.dart';

class CategoryTotalsTable extends StatelessWidget {
  final List<CategoryTotal> categories;

  const CategoryTotalsTable({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.of(context).fieldFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.of(context).outline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Expanded(child: _text(context, 'Categoria', bold: true)),
                _text(context, 'Total gasto', bold: true),
              ],
            ),
          ),
          _divider(context),
          for (var index = 0; index < categories.length; index++) ...[
            _buildRow(context, categories[index]),
            if (index < categories.length - 1) _divider(context),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, CategoryTotal category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.of(context).fieldFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              category.icon,
              color: AppColors.of(context).dashboardText,
              size: 25,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _text(context, category.name)),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: _text(context, formatBRL(category.total)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: AppColors.of(context).outline);

  Widget _text(BuildContext context, String value, {bool bold = false}) => Text(
    value,
    style: GoogleFonts.poppins(
      color: AppColors.of(context).dashboardText,
      fontSize: 13,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}
