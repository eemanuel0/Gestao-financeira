import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/services/finance_repository.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/formatters.dart';

Future<double?> showEditLimitSheet(
  BuildContext context, {
  double? currentLimit,
  Future<void> Function(double limit)? onSave,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.dashboardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _EditLimitSheet(currentLimit: currentLimit, onSave: onSave),
  );
}

class _EditLimitSheet extends StatefulWidget {
  final double? currentLimit;
  final Future<void> Function(double limit)? onSave;
  const _EditLimitSheet({this.currentLimit, this.onSave});

  @override
  State<_EditLimitSheet> createState() => _EditLimitSheetState();
}

class _EditLimitSheetState extends State<_EditLimitSheet> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.currentLimit;
    _controller = TextEditingController(
      text:
          value != null &&
              value.isFinite &&
              value > 0 &&
              value <= maxMoneyCents / 100
          ? formatBRL(value)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color),
    );

    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          // Mantém campo e botão acessíveis com o teclado aberto.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Editar limite mensal',
                  style: GoogleFonts.poppins(
                    color: AppColors.dashboardText,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey('spending-limit-input'),
                  controller: _controller,
                  enabled: !_saving,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    CurrencyInputFormatter(includeCurrencySymbol: true),
                  ],
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  cursorColor: AppColors.neon,
                  style: GoogleFonts.poppins(
                    color: AppColors.dashboardText,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Limite de gastos',
                    labelStyle: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    helperText:
                        'Você recebe um alerta ao ultrapassar esse valor.',
                    helperMaxLines: 2,
                    helperStyle: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    errorText: _error,
                    errorMaxLines: 4,
                    errorStyle: GoogleFonts.poppins(
                      color: AppColors.dashboardExpense,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    enabledBorder: border(AppColors.outline),
                    disabledBorder: border(AppColors.outline),
                    focusedBorder: border(AppColors.neon),
                    errorBorder: border(AppColors.dashboardExpense),
                    focusedErrorBorder: border(AppColors.dashboardExpense),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const ValueKey('save-spending-limit'),
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors.background,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _saving ? 'Salvando...' : 'Salvar limite',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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

  Future<void> _save() async {
    if (_saving) return;
    final cents = CurrencyInputFormatter.parseCents(_controller.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Informe um valor maior que zero');
      return;
    }
    FocusScope.of(context).unfocus();
    final limit = cents / 100;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // A folha só fecha depois que o banco confirma a gravação.
      await widget.onSave?.call(limit);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(limit);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FinanceException ? error.message : 'Não foi possível salvar o limite. Confira sua conexão e tente novamente.';
      });
    }
  }
}
