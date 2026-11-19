import 'package:flutter/material.dart';

// As cores e a fonte acompanham o tema claro ou escuro do aplicativo.
class PasswordFormPage extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final bool isBusy;
  final List<Widget> children;

  const PasswordFormPage({
    super.key,
    required this.title,
    required this.formKey,
    required this.isBusy,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          leading: IconButton(
            tooltip: 'Voltar',
            onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool enabled;
  final bool isNewPassword;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.validator,
    this.enabled = true,
    this.isNewPassword = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.action,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        errorMaxLines: 3,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: widget.enabled
              ? () => setState(() => _hidden = !_hidden)
              : null,
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class PasswordActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PasswordActionButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: theme.textTheme.labelLarge,
      ),
      child: Text(label),
    );
  }
}

class PasswordFormError extends StatelessWidget {
  final String? message;
  const PasswordFormError(this.message, {super.key});

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}
