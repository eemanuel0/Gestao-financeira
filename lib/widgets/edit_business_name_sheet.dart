import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/services/finance_repository.dart';

Future<String?> showEditBusinessNameSheet(
  BuildContext context, {
  required String currentName,
  required Future<void> Function(String name) onSave,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.of(context).dashboardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _BusinessNameSheet(currentName: currentName, onSave: onSave),
  );
}

class _BusinessNameSheet extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String name) onSave;

  const _BusinessNameSheet({required this.currentName, required this.onSave});

  @override
  State<_BusinessNameSheet> createState() => _BusinessNameSheetState();
}

class _BusinessNameSheetState extends State<_BusinessNameSheet> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
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
                      color: AppColors.of(context).outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Editar nome da empresa',
                  style: GoogleFonts.poppins(
                    color: AppColors.of(context).dashboardText,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey('business-name-input'),
                  controller: _controller,
                  enabled: !_saving,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 60,
                  // A validação avisa sobre o excesso sem cortar a colagem.
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  cursorColor: AppColors.of(context).neon,
                  style: GoogleFonts.poppins(
                    color: AppColors.of(context).dashboardText,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nome da empresa',
                    labelStyle: GoogleFonts.poppins(
                      color: AppColors.of(context).textSecondary,
                    ),
                    errorText: _error,
                    errorMaxLines: 4,
                    errorStyle: GoogleFonts.poppins(
                      color: AppColors.of(context).dashboardExpense,
                    ),
                    counterStyle: GoogleFonts.poppins(
                      color: AppColors.of(context).textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.of(context).fieldFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: border(AppColors.of(context).outline),
                    disabledBorder: border(AppColors.of(context).outline),
                    focusedBorder: border(AppColors.of(context).neon),
                    errorBorder: border(AppColors.of(context).dashboardExpense),
                    focusedErrorBorder: border(
                      AppColors.of(context).dashboardExpense,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const ValueKey('save-business-name'),
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).button,
                      foregroundColor: AppColors.of(context).background,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _saving ? 'Salvando...' : 'Salvar nome',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  key: const ValueKey('cancel-business-name'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: AppColors.of(context).textSecondary,
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
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(
        () => _error = name.isEmpty
            ? 'Informe o nome da empresa.'
            : 'Use até 60 caracteres.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // O cabeçalho só muda após a confirmação do servidor.
      await widget.onSave(name);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FinanceException ? error.message : 'Não foi possível alterar o nome da empresa. Confira sua conexão e tente novamente.';
      });
    }
  }
}
