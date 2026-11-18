import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/services/finance_repository.dart';

Future<String?> showEditTransactionDescriptionSheet(
  BuildContext context, {
  required String currentDescription,
  required Future<void> Function(String description) onSave,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.dashboardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _DescriptionSheet(
      currentDescription: currentDescription,
      onSave: onSave,
    ),
  );
}

class _DescriptionSheet extends StatefulWidget {
  final String currentDescription;
  final Future<void> Function(String description) onSave;

  const _DescriptionSheet({
    required this.currentDescription,
    required this.onSave,
  });

  @override
  State<_DescriptionSheet> createState() => _DescriptionSheetState();
}

class _DescriptionSheetState extends State<_DescriptionSheet> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentDescription);
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
                  'Editar descrição',
                  style: GoogleFonts.poppins(
                    color: AppColors.dashboardText,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey('transaction-description-input'),
                  controller: _controller,
                  enabled: !_saving,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 120,
                  // A validação avisa sobre o excesso sem cortar a colagem.
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  cursorColor: AppColors.neon,
                  style: GoogleFonts.poppins(
                    color: AppColors.dashboardText,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    labelStyle: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                    ),
                    errorText: _error,
                    errorMaxLines: 4,
                    errorStyle: GoogleFonts.poppins(
                      color: AppColors.dashboardExpense,
                    ),
                    counterStyle: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: border(AppColors.outline),
                    disabledBorder: border(AppColors.outline),
                    focusedBorder: border(AppColors.neon),
                    errorBorder: border(AppColors.dashboardExpense),
                    focusedErrorBorder: border(AppColors.dashboardExpense),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const ValueKey('save-transaction-description'),
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
                      _saving ? 'Salvando...' : 'Salvar alteração',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  key: const ValueKey('cancel-transaction-description'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
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
    final description = _controller.text.trim();
    if (description.isEmpty || description.length > 120) {
      setState(
        () => _error = description.isEmpty
            ? 'Informe uma descrição.'
            : 'Use até 120 caracteres.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // O texto só muda na lista depois da confirmação do servidor.
      await widget.onSave(description);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(description);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FinanceException ? error.message : 'Não foi possível alterar a descrição. Confira sua conexão e tente novamente.';
      });
    }
  }
}
