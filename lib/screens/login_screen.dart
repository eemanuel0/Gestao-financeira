import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../models/services/account_service.dart';
import '../widgets/glow_background.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AccountService accountService;

  const LoginScreen({super.key, required this.accountService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Mantém o foco ao limpar ou mostrar a senha.
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
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
                          icon: Icon(
                            Icons.arrow_back,
                            color: AppColors.of(context).dashboardText,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Logo e nome do aplicativo.
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.savings_outlined,
                                size: 40,
                                color: AppColors.of(context).neon,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Finanças',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.of(context).dashboardText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        Text(
                          'Acesse sua conta',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.of(context).dashboardText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Continue de onde parou.',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: AppColors.of(context).textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildField(
                          fieldKey: const ValueKey('login-email'),
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          label: 'E-mail',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: _validateEmail,
                        ),

                        const SizedBox(height: 16),

                        _buildField(
                          fieldKey: const ValueKey('login-password'),
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          keyboardType: TextInputType.visiblePassword,
                          icon: Icons.lock_outline,
                          label: 'Senha',
                          obscure: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Informe sua senha.'
                              : null,
                          suffix: _passwordActions(),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const ValueKey('forgot-password'),
                            onPressed:
                                _isSubmitting ||
                                    AppSettingsScope.maybeOf(context)
                                            ?.passwords ==
                                        null
                                ? null
                                : _forgotPassword,
                            child: const Text('Esqueci minha senha'),
                          ),
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const ValueKey('login-submit'),
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.of(context).button,
                              foregroundColor: AppColors.of(context).background,
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
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.of(context).background,
                                    ),
                                  )
                                : Text(
                                    'Entrar',
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
                                'Ainda não tem uma conta?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.of(context).textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => RegisterScreen(
                                              accountService:
                                                  widget.accountService,
                                            ),
                                          ),
                                        );
                                      },
                                child: Text(
                                  'Criar conta',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.of(context).button,
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

  Widget _passwordActions() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _passwordController,

      // Atualiza os ícones sem recriar o campo durante a digitação.
      builder: (context, value, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.text.isNotEmpty)
              IconButton(
                key: const ValueKey('clear-login-password'),
                tooltip: 'Limpar senha',
                onPressed: _isSubmitting
                    ? null
                    : () {
                        _passwordController.clear();
                        _passwordFocus.requestFocus();
                      },
                icon: const Icon(Icons.close),
              ),
            IconButton(
              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() => _obscure = !_obscure);
                      _passwordFocus.requestFocus();
                    },
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _forgotPassword() async {
    final service = AppSettingsScope.maybeOf(context)?.passwords;

    if (service == null || _isSubmitting) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          passwordService: service,
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );

    if (mounted && changed == true) {
      _passwordController.clear();
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      // A raiz do aplicativo acompanha a sessão e abre a Home.
      await widget.accountService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AccountException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Não foi possível entrar. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    FocusNode? focusNode,
  }) {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color),
      );
    }

    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
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
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: AppColors.of(context).dashboardText,
      ),
      cursorColor: AppColors.of(context).neon,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.of(context).fieldFill,
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontSize: 15,
          color: AppColors.of(context).textSecondary,
        ),
        errorStyle: GoogleFonts.poppins(
          color: AppColors.of(context).dashboardExpense,
        ),
        errorMaxLines: 2,
        prefixIcon: Icon(icon, color: AppColors.of(context).textSecondary),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        enabledBorder: border(AppColors.of(context).outline),
        disabledBorder: border(AppColors.of(context).outline),
        focusedBorder: border(AppColors.of(context).neon),
        errorBorder: border(AppColors.of(context).dashboardExpense),
        focusedErrorBorder: border(AppColors.of(context).dashboardExpense),
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
