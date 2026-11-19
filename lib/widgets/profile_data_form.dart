import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/business_profile_data.dart';
import '../models/financial_profile.dart';
import '../models/services/finance_repository.dart';
import '../utils/profile_input_formatters.dart';
import '../utils/profile_validators.dart';

// Reutilizado no Perfil e no editor modal: validação e salvamento ficam juntos.
class ProfileDataForm extends StatefulWidget {
  final AppUser user;
  final FinancialProfile? profile;
  final Future<void> Function(String)? onSavePersonalName;
  final Future<void> Function(BusinessProfileData)? onSaveBusiness;
  final VoidCallback? onSaved;
  final ValueChanged<bool>? onBusyChanged;
  const ProfileDataForm({
    super.key,
    required this.user,
    this.profile,
    this.onSavePersonalName,
    this.onSaveBusiness,
    this.onSaved,
    this.onBusyChanged,
  });
  @override
  State<ProfileDataForm> createState() => _ProfileDataFormState();
}

class _ProfileDataFormState extends State<ProfileDataForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController();
  final _legal = TextEditingController(), _cnpj = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false, _dirty = false;
  String? _error;
  bool get _business => widget.profile?.kind == FinancialProfileKind.business;
  bool get _canSave => _business
      ? widget.onSaveBusiness != null
      : widget.onSavePersonalName != null;
  @override
  void initState() {
    super.initState();
    _fill();
  }

  @override
  void didUpdateWidget(covariant ProfileDataForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Receber uma nova foto não apaga campos que estão sendo editados.
    if (!_dirty && !_saving) _fill();
  }

  void _fill() {
    final p = widget.profile;
    _name.text = _business ? p!.name : widget.user.name;
    _email.text = _business ? p?.contactEmail ?? '' : widget.user.email;
    _legal.text = p?.legalName ?? '';
    _cnpj.text = p?.cnpj == null ? '' : formatCnpj(p!.cnpj!);
    _phone.text = p?.contactPhone ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _legal, _cnpj, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          'profile-name-input',
          _name,
          _business ? 'Nome da empresa' : 'Nome',
          maxLength: 60,
          keyboard: TextInputType.name,
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? 'Informe o nome.' : null,
        ),
        if (!_business)
          _field(
            'profile-email-input',
            _email,
            'E-mail',
            readOnly: true,
            helper: 'E-mail usado para entrar na sua conta.',
          )
        else ...[
          _field(
            'business-legal-name-input',
            _legal,
            'Razão social',
            maxLength: 120,
          ),
          _field(
            'business-cnpj-input',
            _cnpj,
            'CNPJ',
            maxLength: CnpjInputFormatter.maxFormattedLength,
            formatters: [CnpjInputFormatter()],
            helper: 'Opcional. 14 posições, com máscara automática.',
            validator: (v) => (v?.trim().isEmpty ?? true) || isValidCnpj(v!)
                ? null
                : 'Informe um CNPJ válido.',
          ),
          _field(
            'business-contact-email-input',
            _email,
            'E-mail de contato',
            maxLength: 254,
            keyboard: TextInputType.emailAddress,
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ||
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!.trim())
                ? null
                : 'Informe um e-mail válido.',
          ),
          _field(
            'business-phone-input',
            _phone,
            'Telefone',
            maxLength: PhoneInputFormatter.maxFormattedLength,
            formatters: [PhoneInputFormatter()],
            keyboard: TextInputType.phone,
            helper: 'Opcional. Até 15 dígitos, incluindo DDD/DDI.',
            validator: (v) {
              final phone = v?.trim() ?? '';
              if (phone.isEmpty) return null;
              final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
              return RegExp(r'^\+?[0-9()\s.-]+$').hasMatch(phone) &&
                      digits.length >= 8 &&
                      digits.length <= 15
                  ? null
                  : 'Informe um telefone com 8 a 15 dígitos.';
            },
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        FilledButton(
          key: const ValueKey('save-profile'),
          onPressed: _saving || !_canSave ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
        ),
      ],
    ),
  );
  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    int? maxLength,
    bool readOnly = false,
    String? helper,
    List<TextInputFormatter>? formatters,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_saving,
      readOnly: readOnly,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: formatters,
      keyboardType: keyboard,
      textCapitalization: keyboard == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _dirty = true,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        counterText: '',
        suffixIcon: readOnly ? const Icon(Icons.lock_outline, size: 18) : null,
      ),
    ),
  );
  Future<void> _save() async {
    if (_saving || !_canSave || !_form.currentState!.validate()) return;
    BusinessProfileData? data;
    try {
      if (_business) {
        data = BusinessProfileData(
          name: _name.text,
          legalName: _legal.text,
          cnpj: _cnpj.text,
          contactEmail: _email.text,
          contactPhone: _phone.text,
        );
      }
    } on ArgumentError {
      setState(() => _error = 'Confira os dados informados.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      if (data != null) {
        await widget.onSaveBusiness!(data);
      } else {
        await widget.onSavePersonalName!(_name.text.trim());
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      widget.onSaved?.call();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FinanceException ? error.message : 'Não foi possível salvar. Confira sua conexão e tente novamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }
}
