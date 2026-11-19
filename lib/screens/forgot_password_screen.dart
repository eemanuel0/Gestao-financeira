import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/services/account_service.dart';
import '../models/services/password_service.dart';
import '../widgets/password_form_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final PasswordService passwordService;
  final String initialEmail;
  const ForgotPasswordScreen({
    super.key,
    required this.passwordService,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _targetEmail, _error, _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    for (final controller in [_email, _code, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sent = _targetEmail != null;
    final decoration = InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.45,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      errorMaxLines: 3,
    );
    return PasswordFormPage(
      title: 'Recuperar acesso',
      formKey: sent ? _resetForm : _emailForm,
      isBusy: _busy,
      children: [
        Text(
          sent
              ? 'Digite o código recebido em $_targetEmail e escolha uma nova senha.'
              : 'Informe seu e-mail. Se ele estiver cadastrado, você receberá um código de 8 dígitos.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (!sent)
          TextFormField(
            key: const ValueKey('recovery-email-input'),
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            style: theme.textTheme.bodyLarge,
            decoration: decoration.copyWith(labelText: 'E-mail'),
            onFieldSubmitted: (_) => _sendCode(),
            validator: (value) {
              final email = value?.trim() ?? '';
              return email.length <= 254 &&
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                  ? null
                  : 'Informe um e-mail válido.';
            },
          )
        else ...[
          TextFormField(
            key: const ValueKey('recovery-code-input'),
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: theme.textTheme.bodyLarge,
            maxLength: 8,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: decoration.copyWith(labelText: 'Código de 8 dígitos'),
            validator: (value) => RegExp(r'^[0-9]{8}$').hasMatch(value ?? '')
                ? null
                : 'Informe o código de 8 dígitos.',
          ),
          const SizedBox(height: 18),
          PasswordField(
            fieldKey: const ValueKey('recovery-new-password-input'),
            controller: _password,
            label: 'Nova senha',
            enabled: !_busy,
            isNewPassword: true,
            validator: (value) => value == null || value.length < 8
                ? 'Use pelo menos 8 caracteres.'
                : null,
          ),
          const SizedBox(height: 18),
          PasswordField(
            fieldKey: const ValueKey('recovery-confirm-password-input'),
            controller: _confirmation,
            label: 'Confirmar nova senha',
            enabled: !_busy,
            isNewPassword: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _reset(),
            validator: (value) => value == null || value.isEmpty
                ? 'Confirme a nova senha.'
                : value != _password.text
                ? 'As senhas precisam ser iguais.'
                : null,
          ),
        ],
        const SizedBox(height: 24),
        PasswordFormError(_error),
        if (_notice != null) ...[
          Text(
            _notice!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
        ],
        PasswordActionButton(
          key: ValueKey(sent ? 'reset-password-submit' : 'send-recovery-code'),
          label: _busy
              ? (sent ? 'Redefinindo...' : 'Enviando...')
              : sent
              ? 'Redefinir senha'
              : 'Enviar código',
          onPressed: _busy
              ? null
              : sent
              ? _reset
              : _sendCode,
        ),
        if (sent) ...[
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey('resend-recovery-code'),
            onPressed: _busy ? null : () => _sendCode(resend: true),
            child: const Text('Reenviar código'),
          ),
          TextButton(
            key: const ValueKey('change-recovery-email'),
            onPressed: _busy ? null : _changeEmail,
            child: const Text('Usar outro e-mail'),
          ),
        ],
      ],
    );
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy || (!resend && !_emailForm.currentState!.validate())) return;
    final email = resend ? _targetEmail! : _email.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.passwordService.sendRecoveryCode(email);
      if (!mounted) return;
      setState(() {
        _targetEmail = email;
        _code.clear();
        if (resend) {
          _notice =
              'Solicitação enviada. Confira seu e-mail e a caixa de spam.';
        }
      });
    } on AccountException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível solicitar o código. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !_resetForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // O serviço confirma o código, altera a senha e encerra a recuperação.
      await widget.passwordService.resetPassword(
        email: _targetEmail!,
        code: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha redefinida. Entre com a nova senha.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on AccountException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível redefinir a senha. Tente novamente.',
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  void _changeEmail() {
    if (_busy) return;
    setState(() {
      _targetEmail = null;
      _error = null;
      _notice = null;
      _code.clear();
      _password.clear();
      _confirmation.clear();
    });
  }
}
