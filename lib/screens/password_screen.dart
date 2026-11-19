import 'package:flutter/material.dart';

import '../models/services/account_service.dart';
import '../models/services/password_service.dart';
import '../widgets/password_form_widgets.dart';

class PasswordScreen extends StatefulWidget {
  final PasswordService passwordService;
  const PasswordScreen({super.key, required this.passwordService});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PasswordFormPage(
    title: 'Alterar senha',
    formKey: _formKey,
    isBusy: _busy,
    children: [
      Text(
        'Confirme a senha atual e escolha uma nova senha.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 24),
      PasswordField(
        fieldKey: const ValueKey('current-password-input'),
        controller: _current,
        label: 'Senha atual',
        enabled: !_busy,
        validator: (value) =>
            value == null || value.isEmpty ? 'Informe a senha atual.' : null,
      ),
      const SizedBox(height: 18),
      PasswordField(
        fieldKey: const ValueKey('new-password-input'),
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
        fieldKey: const ValueKey('confirm-password-input'),
        controller: _confirmation,
        label: 'Confirmar nova senha',
        enabled: !_busy,
        isNewPassword: true,
        action: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        validator: (value) => value == null || value.isEmpty
            ? 'Confirme a nova senha.'
            : value != _password.text
            ? 'As senhas precisam ser iguais.'
            : null,
      ),
      const SizedBox(height: 24),
      PasswordFormError(_error),
      PasswordActionButton(
        key: const ValueKey('change-password-submit'),
        label: _busy ? 'Salvando...' : 'Alterar senha',
        onPressed: _busy ? null : _submit,
      ),
    ],
  );

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A senha é enviada exatamente como foi digitada, incluindo espaços.
      await widget.passwordService.changePassword(
        currentPassword: _current.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso.')),
      );
      Navigator.of(context).pop(true);
    } on AccountException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível alterar a senha. Tente novamente.',
        );
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }
}
