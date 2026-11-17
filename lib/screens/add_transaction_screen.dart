import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/finance_transaction.dart';
import '../models/services/finance_repository.dart';
import '../utils/formatters.dart';

// O formulário devolve os dados; a tela anterior faz a gravação.
class NewTransactionData {
  final TransactionType type;
  final int amountCents;
  final TransactionCategory category;
  final String description;
  final DateTime occurredOn;

  const NewTransactionData({
    required this.type,
    required this.amountCents,
    required this.category,
    required this.description,
    required this.occurredOn,
  });
}

class AddTransactionScreen extends StatefulWidget {
  final TransactionType? initialType;
  final Future<void> Function(NewTransactionData data)? onSave;

  const AddTransactionScreen({super.key, this.initialType, this.onSave});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType? _type;
  TransactionCategory? _category;
  DateTime _occurredOn = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == null
        ? <TransactionCategory>[]
        : TransactionCategory.allowedFor(_type!);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.dashboardText,
          title: Text(
            'Novo lançamento',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Informe os dados da sua receita ou despesa.',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // A escolha do tipo define as categorias disponíveis.
                        DropdownButtonFormField<TransactionType>(
                          key: const ValueKey('transaction-type'),
                          initialValue: _type,
                          isExpanded: true,
                          dropdownColor: AppColors.dashboardSurface,
                          style: _fieldStyle,
                          decoration: _decoration('Tipo', Icons.swap_vert),
                          hint: Text('Selecione', style: _hintStyle),
                          items: TransactionType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.label, style: _fieldStyle),
                            );
                          }).toList(),
                          onChanged: (type) {
                            if (type == _type) return;
                            setState(() {
                              _type = type;
                              _category = null;
                            });
                          },
                          validator: (type) {
                            return type == null ? 'Selecione o tipo.' : null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // O valor só é convertido para centavos ao validar.
                        TextFormField(
                          key: const ValueKey('transaction-amount'),
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          style: _fieldStyle,
                          cursorColor: AppColors.neon,
                          decoration:
                              _decoration(
                                'Valor',
                                Icons.payments_outlined,
                              ).copyWith(
                                prefixText: 'R\$ ',
                                prefixStyle: _fieldStyle,
                                hintText: 'Digite o valor',
                                helperText: 'Use vírgula nos centavos: 125,50',
                                helperStyle: _hintStyle,
                                helperMaxLines: 2,
                              ),
                          validator: (value) {
                            final cents = parseBRLCents(value ?? '');
                            if (cents == null) {
                              return 'Informe um valor válido, como 125,50.';
                            }
                            if (cents <= 0) {
                              return 'O valor deve ser maior que zero.';
                            }
                            if (cents > FinanceTransaction.maxAmountCents) {
                              return 'O valor ultrapassa o limite permitido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        DropdownButtonFormField<TransactionCategory>(
                          // Recria a seleção quando o tipo é alterado.
                          key: ValueKey('transaction-category-${_type?.name}'),
                          initialValue: _category,
                          isExpanded: true,
                          dropdownColor: AppColors.dashboardSurface,
                          style: _fieldStyle,
                          decoration: _decoration(
                            'Categoria',
                            Icons.category_outlined,
                          ),
                          hint: Text(
                            _type == null
                                ? 'Escolha o tipo primeiro'
                                : 'Selecione',
                            style: _hintStyle,
                          ),
                          items: categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category.label, style: _fieldStyle),
                            );
                          }).toList(),
                          onChanged: _type == null
                              ? null
                              : (category) {
                                  setState(() => _category = category);
                                },
                          validator: (category) {
                            return category == null
                                ? 'Selecione a categoria.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 18),

                        TextFormField(
                          key: const ValueKey('transaction-description'),
                          controller: _descriptionController,
                          style: _fieldStyle,
                          cursorColor: AppColors.neon,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 120,
                          decoration: _decoration(
                            'Descrição',
                            Icons.notes_outlined,
                          ).copyWith(hintText: 'Descreva este lançamento'),
                          validator: (value) {
                            final description = value?.trim() ?? '';
                            if (description.isEmpty) {
                              return 'Informe a descrição.';
                            }
                            if (description.length > 120) {
                              return 'Use até 120 caracteres.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // O calendário usa o idioma configurado no aplicativo.
                        Semantics(
                          button: true,
                          label: 'Escolher data do lançamento',
                          child: InkWell(
                            key: const ValueKey('transaction-date'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: _decoration(
                                'Data do lançamento',
                                Icons.calendar_today_outlined,
                              ),
                              child: Text(_formattedDate, style: _fieldStyle),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        ElevatedButton(
                          key: const ValueKey('submit-transaction'),
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.button,
                            foregroundColor: AppColors.background,
                            minimumSize: const Size.fromHeight(54),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Salvando...' : 'Adicionar',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _fieldStyle =>
      GoogleFonts.poppins(color: AppColors.dashboardText, fontSize: 14);

  TextStyle get _hintStyle =>
      GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12);

  InputDecoration _decoration(String label, IconData icon) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: _hintStyle,
      hintStyle: _hintStyle,
      errorStyle: GoogleFonts.poppins(color: AppColors.dashboardExpense),
      errorMaxLines: 3,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      border: border(AppColors.outline),
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.neon),
      errorBorder: border(AppColors.dashboardExpense),
      focusedErrorBorder: border(AppColors.dashboardExpense),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  String get _formattedDate {
    final day = _occurredOn.day.toString().padLeft(2, '0');
    final month = _occurredOn.month.toString().padLeft(2, '0');
    return '$day/$month/${_occurredOn.year}';
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredOn,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10, 12, 31),
      helpText: 'Data do lançamento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selected == null || !mounted) return;
    setState(() => _occurredOn = selected);
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final data = NewTransactionData(
      type: _type!,
      amountCents: parseBRLCents(_amountController.text)!,
      category: _category!,
      description: _descriptionController.text.trim(),
      occurredOn: DateTime(
        _occurredOn.year,
        _occurredOn.month,
        _occurredOn.day,
      ),
    );
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(data);
      if (!mounted) return;
      // Libera a saída antes de fechar a tela após a gravação.
      setState(() => _saving = false);
      Navigator.of(context).pop(data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FinanceException ? error.message : 'Não foi possível salvar. Confira sua conexão e tente novamente.',
          ),
        ),
      );
    }
  }
}
