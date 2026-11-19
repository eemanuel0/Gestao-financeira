import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../models/app_user.dart';
import '../models/business_profile_data.dart';
import '../models/financial_profile.dart';
import '../models/services/finance_repository.dart';
import '../widgets/profile_data_form.dart';
import 'password_screen.dart';
import 'preferences_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  final FinancialProfile? financialProfile;
  final bool isSigningOut;
  final VoidCallback onSignOut, onBack;
  final Future<void> Function(String)? onSavePersonalName;
  final Future<void> Function(BusinessProfileData)? onSaveBusiness;
  final Future<void> Function()? onChoosePhoto, onRemovePhoto;
  const ProfileScreen({
    super.key,
    required this.user,
    this.financialProfile,
    this.isSigningOut = false,
    required this.onSignOut,
    required this.onBack,
    this.onSavePersonalName,
    this.onSaveBusiness,
    this.onChoosePhoto,
    this.onRemovePhoto,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _photoBusy = false, _saving = false;
  int _generation = 0;
  bool get _busy => _photoBusy || _saving || widget.isSigningOut;
  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.financialProfile?.id != widget.financialProfile?.id) {
      _generation++;
      _photoBusy = false;
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scope = AppSettingsScope.maybeOf(context);
    final profile = widget.financialProfile;
    final business = profile?.kind == FinancialProfileKind.business;
    final name = business ? profile!.name : widget.user.name;
    final email = business
        ? profile?.contactEmail ?? widget.user.email
        : widget.user.email;
    final hasPhoto = profile?.avatarPath != null || profile?.avatarUrl != null;
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : String.fromCharCode(parts.first.runes.first) +
              (parts.length > 1
                  ? String.fromCharCode(parts.last.runes.first)
                  : '');
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('profile-back'),
                    tooltip: 'Voltar ao início',
                    onPressed: _busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Perfil',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // O avatar inteiro é tocável, com área maior que o mínimo de 48 dp.
              Center(
                child: Semantics(
                  button: true,
                  label: hasPhoto ? 'Alterar foto' : 'Adicionar foto',
                  child: InkWell(
                    key: const ValueKey('choose-profile-photo'),
                    customBorder: const CircleBorder(),
                    onTap: _busy || widget.onChoosePhoto == null
                        ? null
                        : () => _photoAction(widget.onChoosePhoto!),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: colors.surfaceContainerHighest,
                      child: _photoBusy
                          ? const CircularProgressIndicator()
                          : ClipOval(
                              child: profile?.avatarUrl == null
                                  ? Text(
                                      initials.toUpperCase(),
                                      key: const ValueKey('profile-initials'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                    )
                                  : Image.network(
                                      profile!.avatarUrl!,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      semanticLabel: 'Foto do perfil',
                                      errorBuilder: (_, _, _) => Text(initials),
                                    ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque na foto para alterar',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              if (hasPhoto && widget.onRemovePhoto != null)
                Center(
                  child: TextButton.icon(
                    key: const ValueKey('remove-profile-photo'),
                    onPressed: _busy
                        ? null
                        : () => _photoAction(widget.onRemovePhoto!),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Remover foto'),
                  ),
                ),
              const SizedBox(height: 28),
              Card.outlined(
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        business ? 'Dados da empresa' : 'Dados pessoais',
                        key: const ValueKey('profile-account'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      ProfileDataForm(
                        // Um novo perfil recebe novos campos, preservando o isolamento.
                        key: ValueKey(
                          'profile-form-${widget.user.id}-${profile?.id}',
                        ),
                        user: widget.user,
                        profile: profile,
                        onSavePersonalName: widget.onSavePersonalName,
                        onSaveBusiness: widget.onSaveBusiness,
                        onBusyChanged: (value) {
                          if (mounted) setState(() => _saving = value);
                        },
                        onSaved: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(
                                content: Text('Dados atualizados com sucesso.'),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card.outlined(
                color: colors.surface,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('profile-security'),
                      minVerticalPadding: 18,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Segurança'),
                      subtitle: const Text('Alterar senha'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_busy && scope?.passwords != null,
                      onTap: scope?.passwords == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PasswordScreen(
                                  passwordService: scope!.passwords!,
                                ),
                              ),
                            ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      key: const ValueKey('profile-preferences'),
                      minVerticalPadding: 18,
                      leading: const Icon(Icons.tune),
                      title: const Text('Preferências'),
                      subtitle: const Text('Tema claro ou escuro'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_busy && scope != null,
                      onTap: scope == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PreferencesScreen(settings: scope.settings),
                              ),
                            ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      key: const ValueKey('profile-help'),
                      minVerticalPadding: 18,
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Ajuda'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : _help,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: const ValueKey('sign-out'),
                onPressed: _busy ? null : widget.onSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colors.error),
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  widget.isSigningOut ? 'Saindo...' : 'Sair da conta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _photoAction(Future<void> Function() action) async {
    if (_busy) return;
    final generation = _generation;
    setState(() => _photoBusy = true);
    try {
      await action();
    } catch (error) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FinanceException
                  ? error.message
                  : 'Não foi possível atualizar a foto. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _photoBusy = false);
      }
    }
  }

  void _help() => showAboutDialog(
    context: context,
    applicationName: 'Finanças',
    applicationVersion: '1.0.0',
    children: const [
      Text(
        'Separe suas finanças em Pessoal e Empresa. '
        'Adicione lançamentos no botão + e acompanhe seus limites em Relatórios.',
      ),
    ],
  );
}
