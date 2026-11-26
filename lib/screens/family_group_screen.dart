import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/services/family_group_repository.dart';
import '../models/services/finance_repository.dart';

class FamilyGroupScreen extends StatefulWidget {
  final FamilyGroupRepository repository;
  final String userId;
  final String? ownerId;
  final Widget? header;
  final Future<void> Function() onMembershipChanged;
  final bool Function() isCurrent;

  const FamilyGroupScreen({
    super.key,
    required this.repository,
    required this.userId,
    this.ownerId,
    this.header,
    required this.onMembershipChanged,
    required this.isCurrent,
  });

  @override
  State<FamilyGroupScreen> createState() => _FamilyGroupScreenState();
}

class _FamilyGroupScreenState extends State<FamilyGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  List<FamilyMember>? _members;
  String? _invite;
  String? _error;
  bool _busy = false;

  bool get _isOwner => widget.ownerId == widget.userId;

  @override
  void initState() {
    super.initState();
    if (widget.ownerId != null) unawaited(_run(_loadMembers));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!widget.isCurrent()) {
        throw const FinanceException(
          'Seu grupo mudou. Volte e abra esta tela novamente.',
        );
      }
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FinanceException
              ? error.message
              : 'Não foi possível concluir a ação. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadMembers() async {
    final members = await widget.repository.loadMembers();
    if (members.isEmpty) {
      throw const FinanceException('Sua conta não participa mais deste grupo.');
    }
    if (mounted) setState(() => _members = members);
  }

  Future<void> _changeMembership(Future<void> Function() action) async {
    await action();
    if (mounted) await widget.onMembershipChanged();
  }

  Future<void> _confirmChange(
    String title,
    String details,
    String action,
    Future<void> Function() change,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _run(change);
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.ownerId == null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: setup
          ? null
          : AppBar(
              title: const Text('Grupo familiar'),
              actions: [
                IconButton(
                  tooltip: 'Atualizar membros',
                  onPressed: _busy ? null : () => _run(_loadMembers),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                if (widget.header case final header?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    child: header,
                  ),
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      if (setup)
                        ..._buildSetup(theme)
                      else
                        ..._buildMembers(theme),
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSetup(ThemeData theme) => [
    Align(
      alignment: Alignment.centerLeft,
      child: Icon(
        Icons.groups_outlined,
        size: 40,
        color: theme.colorScheme.primary,
      ),
    ),
    const SizedBox(height: 12),
    Text('Finanças em conjunto', style: theme.textTheme.headlineSmall),
    const SizedBox(height: 8),
    const Text(
      'Crie um grupo ou use um convite para acompanhar receitas, despesas '
      'e o limite mensal com outras pessoas.',
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: _busy
          ? null
          : () => _run(() => _changeMembership(widget.repository.createGroup)),
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Criar grupo familiar'),
    ),
    const SizedBox(height: 24),
    Text('Já tem um convite?', style: theme.textTheme.titleMedium),
    const SizedBox(height: 12),
    Form(
      key: _form,
      child: TextFormField(
        controller: _code,
        enabled: !_busy,
        decoration: const InputDecoration(labelText: 'Código do convite'),
        autocorrect: false,
        enableSuggestions: false,
        validator: (value) =>
            RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value?.trim() ?? '')
            ? null
            : 'Cole o código de 32 caracteres do convite.',
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed: _busy
          ? null
          : () {
              if (_form.currentState?.validate() != true) return;
              final code = _code.text.trim();
              unawaited(
                _run(
                  () => _changeMembership(
                    () => widget.repository.joinGroup(code),
                  ),
                ),
              );
            },
      child: const Text('Entrar com convite'),
    ),
  ];

  List<Widget> _buildMembers(ThemeData theme) => [
    Text('Membros', style: theme.textTheme.titleLarge),
    const SizedBox(height: 8),
    const Text(
      'Os membros podem registrar lançamentos e ajustar o limite do grupo.',
    ),
    const SizedBox(height: 12),
    if (_members case final members?) ...[
      for (final member in members)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(member.userId == widget.userId ? 'Você' : member.name),
          subtitle: member.userId == widget.ownerId
              ? const Text('Responsável')
              : null,
          trailing: _isOwner && member.userId != widget.userId
              ? IconButton(
                  tooltip: 'Remover ${member.name}',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: _busy
                      ? null
                      : () => _confirmChange(
                          'Remover membro?',
                          '${member.name} perderá o acesso ao grupo.',
                          'Remover',
                          () async {
                            await widget.repository.removeMember(member.userId);
                            await _loadMembers();
                          },
                        ),
                )
              : null,
        ),
    ],
    const SizedBox(height: 16),
    if (_isOwner) ...[
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () => _run(() async {
                final invite = await widget.repository.createInvite();
                if (mounted) setState(() => _invite = invite);
              }),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(_invite == null ? 'Gerar convite' : 'Gerar novo convite'),
      ),
      if (_invite case final invite?) ...[
        const SizedBox(height: 12),
        SelectableText(invite),
        const SizedBox(height: 8),
        const Text(
          'Envie o código a quem você quer convidar. Ele vale por 7 dias, '
          'pode ser usado uma vez e é substituído ao gerar outro.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar código'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await Clipboard.setData(ClipboardData(text: invite));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado.')),
                      );
                    }
                  }),
          ),
        ),
      ],
    ] else
      OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () => _confirmChange(
                'Sair do grupo?',
                'Você perderá o acesso e precisará de outro convite para voltar.',
                'Sair do grupo',
                () => _changeMembership(widget.repository.leaveGroup),
              ),
        icon: const Icon(Icons.logout),
        label: const Text('Sair do grupo'),
      ),
  ];
}
