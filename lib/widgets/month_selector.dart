import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../utils/date_formatters.dart';

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Selecionar mês',
      child: Material(
        color: AppColors.of(context).fieldFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.of(context).outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('month-selector'),
          onTap: () => _selectMonth(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.of(context).dashboardText,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatMonthYear(selectedMonth),
                    style: GoogleFonts.poppins(
                      color: AppColors.of(context).dashboardText,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.of(context).dashboardText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - index),
    );
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.of(context).dashboardSurface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Selecione o mês',
                  style: GoogleFonts.poppins(
                    color: AppColors.of(context).dashboardText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  children: [
                    for (final month in months)
                      ListTile(
                        key: ValueKey(
                          'month-option-${month.year}-${month.month.toString().padLeft(2, '0')}',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        selected:
                            month.year == selectedMonth.year &&
                            month.month == selectedMonth.month,
                        selectedTileColor: AppColors.of(context).neon
                            .withValues(alpha: 0.08),
                        title: Text(
                          formatMonthYear(month),
                          style: GoogleFonts.poppins(
                            color: AppColors.of(context).dashboardText,
                            fontSize: 13,
                          ),
                        ),
                        trailing:
                            month.year == selectedMonth.year &&
                                month.month == selectedMonth.month
                            ? Icon(
                                Icons.check,
                                color: AppColors.of(context).neon,
                              )
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(month),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // O pai controla o mês e decide como usar a escolha.
    if (context.mounted && selected != null) onChanged(selected);
  }
}
