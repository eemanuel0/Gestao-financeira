import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/services/account_service.dart';
import '../widgets/glow_background.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AccountService accountService;

  const RegisterScreen({super.key, required this.accountService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GlowBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Voltar',
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.dashboardText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.savings_outlined,
                                size: 40,
                                color: AppColors.neon,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Finanças',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dashboardText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Crie sua conta',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dashboardText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'É rápido e gratuito.',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Cada cadastro é enviado ao serviço de autenticação.
                        _buildField(
                          fieldKey: const ValueKey('register-name'),
                          controller: _nameController,
                          icon: Icons.person_outline,
                          label: 'Nome',
                          keyboardType: TextInputType.name,
                          autofillHints: const [AutofillHints.name],
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Informe seu nome.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          fieldKey: const ValueKey('register-email'),
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          label: 'E-mail',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          fieldKey: const ValueKey('register-password'),
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          label: 'Senha',
                          obscure: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Crie uma senha.';
                            }
                            return value.length < 8
                                ? 'Use uma senha com pelo menos 8 caracteres.'
                                : null;
                          },
                          suffix: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          fieldKey: const ValueKey('register-confirm-password'),
                          controller: _confirmController,
                          icon: Icons.lock_outline,
                          label: 'Confirmar senha',
                          obscure: _obscureConfirm,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirme sua senha.';
                            }
                            return value != _passwordController.text
                                ? 'As senhas precisam ser iguais.'
                                : null;
                          },
                          suffix: IconButton(
                            tooltip: _obscureConfirm
                                ? 'Mostrar confirmação de senha'
                                : 'Ocultar confirmação de senha',
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const ValueKey('register-submit'),
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.button,
                              foregroundColor: AppColors.background,
                              minimumSize: const Size.fromHeight(56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.background,
                                    ),
                                  )
                                : Text(
                                    'Cadastrar',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Já tem uma conta?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: _isSubmitting ? null : _openLogin,
                                child: Text(
                                  'Entrar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.button,
                                  ),
                                ),
                              ),
                            ],
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

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      final needsConfirmation = await widget.accountService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // A raiz abre a Home quando existir uma sessão autenticada.
      if (needsConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confira seu e-mail para confirmar a conta. Depois, entre com sua senha.',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        _openLogin();
      }
    } on AccountException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Não foi possível cadastrar sua conta. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(accountService: widget.accountService),
      ),
    );
  }

  Widget _buildField({
    required Key fieldKey,
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color),
    );

    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: !_isSubmitting,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 15, color: AppColors.dashboardText),
      cursorColor: AppColors.neon,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontSize: 15,
          color: AppColors.textSecondary,
        ),
        errorStyle: GoogleFonts.poppins(color: AppColors.dashboardExpense),
        errorMaxLines: 2,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        suffixIcon: suffix,
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
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
        ? null
        : 'Informe um e-mail válido.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }
}
