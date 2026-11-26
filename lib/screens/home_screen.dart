import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/business_profile_data.dart';
import '../models/finance_summary.dart';
import '../models/finance_transaction.dart';
import '../models/financial_profile.dart';
import '../models/services/account_service.dart';
import '../models/services/finance_repository.dart';
import '../models/services/monthly_limit_repository.dart';
import '../utils/date_formatters.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/category_item.dart';
import '../widgets/edit_transaction_description_sheet.dart';
import '../widgets/summary_card.dart';
import 'add_transaction_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser user;
  final AccountService accountService;
  final FinanceRepository repository;
  final MonthlyLimitRepository? monthlyLimitRepository;
  final FinancialProfile? financialProfile;
  final ValueChanged<String>? onProfileSelected;
  final bool isSwitchingProfile;
  final bool showFamily;
  final VoidCallback? onOpenFamilyGroup;
  final Future<FinancialProfile> Function(String name)? onRenameBusiness;
  final Future<void> Function(String name)? onSavePersonalName;
  final Future<void> Function(BusinessProfileData data)? onSaveBusinessDetails;
  final Future<void> Function()? onChooseProfilePhoto;
  final Future<void> Function()? onRemoveProfilePhoto;
  final Future<void> Function()? onRefreshProfile;

  const HomeScreen({
    super.key,
    required this.user,
    required this.accountService,
    required this.repository,
    this.monthlyLimitRepository,
    this.financialProfile,
    this.onProfileSelected,
    this.isSwitchingProfile = false,
    this.showFamily = false,
    this.onOpenFamilyGroup,
    this.onRenameBusiness,
    this.onSavePersonalName,
    this.onSaveBusinessDetails,
    this.onChooseProfilePhoto,
    this.onRemoveProfilePhoto,
    this.onRefreshProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription<void>? _changesSubscription;
  List<FinanceTransaction> _transactions = const [];
  int _selectedIndex = 0;
  int _loadGeneration = 0;
  bool _isLoading = true;
  bool _isOpeningForm = false;
  bool _isEditingDescription = false;
  bool _isSigningOut = false;
  String? _loadError;

  bool get _sessionMatches =>
      widget.accountService.currentUser?.id == widget.user.id;
  String get _profileId =>
      widget.financialProfile?.id ?? FinancialProfile.personalId;
  String get _dataOwnerId =>
      widget.financialProfile?.dataOwnerId ?? widget.user.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForChanges();
    unawaited(_loadTransactions());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.repository != widget.repository ||
        oldWidget.financialProfile?.id != widget.financialProfile?.id ||
        oldWidget.accountService != widget.accountService) {
      // Descarta dados e respostas da conta ou perfil anterior.
      _loadGeneration++;
      _transactions = const [];
      _loadError = null;
      if (oldWidget.user.id != widget.user.id) _selectedIndex = 0;
      _changesSubscription?.cancel();
      _listenForChanges();
      unawaited(_loadTransactions());
    }
  }

  void _listenForChanges() {
    _changesSubscription = widget.repository.changes.listen(
      (_) => unawaited(_loadTransactions()),
      onError: (Object error) => unawaited(_loadTransactions()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadTransactions());
  }

  @override
  void dispose() {
    _loadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _changesSubscription?.cancel();
    super.dispose();
  }

  // Só publica respostas atuais e pertencentes à sessão autenticada.
  Future<void> _loadTransactions() async {
    if (!mounted || _isSigningOut || widget.isSwitchingProfile) return;
    final generation = ++_loadGeneration;
    if (!_sessionMatches) {
      setState(() {
        _transactions = const [];
        _isLoading = false;
        _loadError = 'Sua sessão foi encerrada. Entre novamente.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.repository.loadTransactions();
      if (!mounted || generation != _loadGeneration) return;
      if (!_sessionMatches ||
          loaded.any(
            (transaction) =>
                transaction.userId != _dataOwnerId ||
                transaction.profileId != _profileId,
          )) {
        throw const FinanceException(
          'Não foi possível carregar os dados desta conta. Entre novamente.',
        );
      }
      final sorted = loaded.toList()
        ..sort((first, second) {
          final byDate = second.occurredOn.compareTo(first.occurredOn);
          return byDate != 0
              ? byDate
              : second.createdAt.compareTo(first.createdAt);
        });
      setState(() {
        _transactions = List<FinanceTransaction>.unmodifiable(sorted);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _transactions = const [];
        _isLoading = false;
        _loadError = error is FinanceException
            ? error.message
            : 'Não foi possível carregar seus lançamentos. Tente novamente.';
      });
    }
  }

  Future<void> _openAddTransaction() async {
    if (_isOpeningForm ||
        _isEditingDescription ||
        widget.isSwitchingProfile ||
        _isSigningOut ||
        !_sessionMatches) {
      return;
    }
    _isOpeningForm = true;
    final userId = widget.user.id;
    final profileId = _profileId;
    final repository = widget.repository;
    bool sameAccount() =>
        mounted &&
        _sessionMatches &&
        !widget.isSwitchingProfile &&
        _profileId == profileId &&
        widget.user.id == userId &&
        identical(widget.repository, repository);
    try {
      final saved = await Navigator.of(context).push<NewTransactionData>(
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
            profileId: profileId,
            onSave: (data) async {
              // O formulário aberto por uma conta não grava em outra.
              if (!sameAccount() || _isSigningOut) {
                throw const FinanceException(
                  'Sua sessão mudou. Entre novamente.',
                );
              }
              await repository.addTransaction(
                type: data.type,
                amountCents: data.amountCents,
                category: data.category,
                description: data.description,
                occurredOn: data.occurredOn,
              );
              if (!sameAccount()) {
                throw const FinanceException(
                  'Sua sessão mudou. Entre novamente.',
                );
              }
            },
          ),
        ),
      );
      if (!sameAccount() || saved == null) return;
      await _loadTransactions();
      if (sameAccount()) await _showSavedTransactionMessage(saved);
    } finally {
      _isOpeningForm = false;
    }
  }

  Future<void> _editTransactionDescription(
    FinanceTransaction transaction,
  ) async {
    if (_isEditingDescription ||
        _isOpeningForm ||
        widget.isSwitchingProfile ||
        _isSigningOut ||
        !_sessionMatches) {
      return;
    }
    final userId = widget.user.id;
    final profileId = _profileId;
    if (transaction.userId != _dataOwnerId ||
        transaction.profileId != profileId) {
      return;
    }
    final repository = widget.repository;
    bool sameAccount() =>
        mounted &&
        _sessionMatches &&
        !widget.isSwitchingProfile &&
        _profileId == profileId &&
        !_isSigningOut &&
        widget.user.id == userId &&
        identical(widget.repository, repository);
    _isEditingDescription = true;
    try {
      final savedDescription = await showEditTransactionDescriptionSheet(
        context,
        currentDescription: transaction.description,
        onSave: (description) async {
          if (!sameAccount()) {
            throw const FinanceException('Sua sessão mudou. Entre novamente.');
          }
          final updated = await repository.updateTransactionDescription(
            transactionId: transaction.id,
            description: description,
          );
          if (!sameAccount()) {
            throw const FinanceException('Sua sessão mudou. Entre novamente.');
          }
          if (updated.id != transaction.id ||
              updated.userId != _dataOwnerId ||
              updated.profileId != profileId ||
              updated.description != description.trim()) {
            throw const FinanceException(
              'Não foi possível confirmar a alteração. Atualize seus lançamentos.',
            );
          }
          if (!_transactions.any((current) => current.id == updated.id)) {
            // Uma falha de atualização pode ter esvaziado a lista enquanto
            // o editor estava aberto. Recarrega sem inventar uma lista parcial.
            await _loadTransactions();
            if (!sameAccount()) {
              throw const FinanceException(
                'Sua sessão mudou. Entre novamente.',
              );
            }
            return;
          }
          // Invalida releituras iniciadas antes da edição para não restaurar
          // a descrição antiga. Todas as abas usam esta mesma lista.
          setState(() {
            _loadGeneration++;
            _transactions = List<FinanceTransaction>.unmodifiable([
              for (final current in _transactions)
                if (current.id == updated.id) updated else current,
            ]);
            _isLoading = false;
            _loadError = null;
          });
        },
      );
      if (sameAccount() && savedDescription != null) {
        _showMessage(
          _loadError == null ? 'Descrição atualizada com sucesso.' : 'Descrição salva. Atualize os dados para conferir seus lançamentos.',
        );
      }
    } finally {
      _isEditingDescription = false;
    }
  }

  // Confere o limite real depois que a despesa foi salva e recarregada.
  Future<void> _showSavedTransactionMessage(NewTransactionData saved) async {
    final limits = widget.monthlyLimitRepository;
    final userId = widget.user.id;
    final profileId = _profileId;
    final dataOwnerId = _dataOwnerId;
    if (saved.type != TransactionType.expense || limits == null) {
      _showMessage('Lançamento adicionado com sucesso.');
      return;
    }
    if (_isLoading || _loadError != null) {
      _showMessage(
        'Lançamento salvo. Atualize os dados para conferir o limite.',
      );
      return;
    }
    try {
      final limit = await limits.loadForMonth(saved.occurredOn);
      if (!mounted ||
          !_sessionMatches ||
          widget.user.id != userId ||
          _profileId != profileId ||
          _dataOwnerId != dataOwnerId ||
          widget.isSwitchingProfile) {
        return;
      }
      if (limit != null &&
          (limit.userId != dataOwnerId ||
              limit.profileId != profileId ||
              limit.month.year != saved.occurredOn.year ||
              limit.month.month != saved.occurredOn.month)) {
        throw const FinanceException(
          'Não foi possível conferir o limite desta conta.',
        );
      }
      final summary = FinanceSummary.forMonth(
        _transactions,
        userId: dataOwnerId,
        month: saved.occurredOn,
        profileId: profileId,
      );
      if (limit != null && summary.expenseCents > limit.limitCents) {
        final excess = summary.expenseCents - limit.limitCents;
        _showMessage(
          'Limite de ${formatMonthYear(saved.occurredOn)} ultrapassado em '
          '${formatCentsBRL(excess)}.',
        );
      } else {
        _showMessage('Lançamento adicionado com sucesso.');
      }
    } catch (_) {
      // A despesa já foi salva; uma falha no limite não deve sugerir novo envio.
      if (mounted &&
          _sessionMatches &&
          widget.user.id == userId &&
          _profileId == profileId &&
          _dataOwnerId == dataOwnerId &&
          !widget.isSwitchingProfile) {
        _showMessage(
          'Lançamento salvo. Não foi possível verificar o limite agora.',
        );
      }
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() {
      _isSigningOut = true;
      _loadGeneration++;
      _transactions = const [];
    });
    try {
      await widget.accountService.signOut();
      // A raiz mostra a entrada quando a sessão muda.
      if (mounted) setState(() => _isSigningOut = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      _showMessage(
        error is AccountException
            ? error.message
            : 'Não foi possível sair da conta. Tente novamente.',
      );
      unawaited(_loadTransactions());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.of(context).dashboardSurface,
          content: _text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Oculta dados enquanto a raiz troca de sessão.
    if (!_sessionMatches || _isSigningOut) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: SafeArea(
          child: Center(
            child: _isSigningOut
                ? CircularProgressIndicator(color: AppColors.of(context).neon)
                : _text('Sua sessão foi encerrada.', secondary: true),
          ),
        ),
      );
    }
    final summary = FinanceSummary.fromTransactions(_transactions);
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          if (!widget.isSwitchingProfile) {
            setState(() => _selectedIndex = index);
            if (index == 3 && widget.onRefreshProfile != null) {
              unawaited(widget.onRefreshProfile!());
            }
          }
        },
        onAddPressed: _openAddTransaction,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: AppHeader(
                    selectedProfileId: _profileId,
                    showFamily: widget.showFamily,
                    onProfileSelected: widget.onProfileSelected,
                    isSwitchingProfile: widget.isSwitchingProfile,
                    businessName:
                        widget.financialProfile?.kind ==
                            FinancialProfileKind.business
                        ? widget.financialProfile!.name
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    excluding: widget.isSwitchingProfile,
                    child: IgnorePointer(
                      ignoring: widget.isSwitchingProfile,
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildDashboard(summary),
                          ReportsScreen(
                            userId: _dataOwnerId,
                            profileId: _profileId,
                            showHeader: false,
                            transactions: _transactions,
                            limitRepository: widget.monthlyLimitRepository,
                            isLoading: _isLoading,
                            loadError: _loadError,
                            onRefresh: _loadTransactions,
                            isActive:
                                _selectedIndex == 1 &&
                                !widget.isSwitchingProfile,
                          ),
                          _buildTransactions(),
                          _buildProfile(),
                        ],
                      ),
                    ),
                  ),
                  if (widget.isSwitchingProfile)
                    ColoredBox(
                      key: const ValueKey('switching-financial-profile'),
                      color: AppColors.of(context).background,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.of(context).neon,
                            ),
                            const SizedBox(height: 16),
                            _text('Trocando perfil...'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Permite atualizar mesmo quando a conta ainda está vazia.
  Widget _scrollable(List<Widget> children) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: RefreshIndicator(
          onRefresh: _loadTransactions,
          color: AppColors.of(context).neon,
          backgroundColor: AppColors.of(context).dashboardSurface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(FinanceSummary summary) {
    final isBusiness = FinancialProfile.isBusinessId(_profileId);
    final isFamily = _profileId == FinancialProfile.familyId;
    final monthSummary = FinanceSummary.forMonth(
      _transactions,
      userId: _dataOwnerId,
      profileId: _profileId,
      month: DateTime.now(),
    );
    return _scrollable([
      _text(
        switch (_profileId) {
          FinancialProfile.personalId => 'Olá, ${widget.user.firstName}',
          FinancialProfile.familyId => 'Orçamento familiar',
          _ => 'Caixa da empresa',
        },
        size: 25,
        bold: true,
      ),
      const SizedBox(height: 4),
      _text(switch (_profileId) {
        FinancialProfile.personalId => 'Aqui está o resumo das suas finanças.',
        FinancialProfile.familyId =>
          'Acompanhe o dinheiro que entra e sai do grupo.',
        _ => 'Acompanhe as entradas e saídas do seu negócio.',
      }, secondary: true),
      if (widget.onOpenFamilyGroup != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onOpenFamilyGroup,
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Grupo familiar'),
        ),
      ],
      const SizedBox(height: 22),
      if (_loadError != null || (_isLoading && _transactions.isEmpty))
        _buildLoadStatus()
      else ...[
        if (_isLoading) ...[_progress(), const SizedBox(height: 12)],
        BalanceCard(
          key: ValueKey('${widget.user.id}-$_profileId'),
          balanceCents: summary.balanceCents,
          title: isBusiness
              ? 'Saldo em caixa'
              : isFamily
              ? 'Saldo do grupo'
              : 'Saldo atual',
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryCard(
                title: isBusiness ? 'Entradas' : 'Receitas',
                amountCents: summary.incomeCents,
                icon: Icons.arrow_upward,
                accentColor: AppColors.of(context).neon,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SummaryCard(
                title: isBusiness ? 'Saídas' : 'Despesas',
                amountCents: summary.expenseCents,
                icon: Icons.arrow_downward,
                accentColor: AppColors.of(context).dashboardExpense,
              ),
            ),
          ],
        ),
        if (isBusiness) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.of(context).dashboardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.of(context).outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('Faturamento no mês', secondary: true),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCentsBRL(monthSummary.revenueCents),
                    key: const ValueKey('business-revenue-month'),
                    style: GoogleFonts.poppins(
                      color: AppColors.of(context).dashboardText,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _text(
                  'Vendas e serviços registrados neste mês.',
                  size: 11,
                  secondary: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _text('Gastos por categoria', size: 16, bold: true),
        const SizedBox(height: 16),
        if (summary.categories.isEmpty)
          _text('Você ainda não tem despesas cadastradas.', secondary: true)
        else
          for (var index = 0; index < summary.categories.length; index++) ...[
            CategoryItem(category: summary.categories[index]),
            if (index < summary.categories.length - 1)
              const SizedBox(height: 10),
          ],
      ],
    ]);
  }

  Widget _buildLoadStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            if (_loadError == null) ...[
              CircularProgressIndicator(color: AppColors.of(context).neon),
              const SizedBox(height: 16),
              _text('Carregando seus lançamentos...', secondary: true),
            ] else ...[
              Icon(
                Icons.cloud_off_outlined,
                color: AppColors.of(context).textSecondary,
                size: 36,
              ),
              const SizedBox(height: 12),
              _text(_loadError!, secondary: true, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadTransactions,
                icon: Icon(Icons.refresh, color: AppColors.of(context).neon),
                label: _text(
                  'Tentar novamente',
                  color: AppColors.of(context).neon,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactions() {
    return _scrollable([
      _text('Lançamentos', size: 24, bold: true),
      const SizedBox(height: 8),
      _text(
        'Suas receitas e despesas, da mais recente para a antiga.',
        secondary: true,
      ),
      const SizedBox(height: 24),
      if (_loadError != null || (_isLoading && _transactions.isEmpty))
        _buildLoadStatus()
      else if (_transactions.isEmpty)
        _text(
          'Nenhum lançamento ainda. Toque no + para adicionar.',
          secondary: true,
        )
      else ...[
        if (_isLoading) ...[_progress(), const SizedBox(height: 16)],
        for (final transaction in _transactions) ...[
          _buildTransactionItem(transaction),
          const SizedBox(height: 12),
        ],
      ],
    ]);
  }

  Widget _buildTransactionItem(FinanceTransaction transaction) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome
        ? AppColors.of(context).neon
        : AppColors.of(context).dashboardExpense;
    final date = transaction.occurredOn;
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(transaction.category.icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  transaction.description,
                  size: 14,
                  bold: true,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                _text(
                  '${transaction.category.label} • $formattedDate',
                  secondary: true,
                  size: 11,
                ),
                const SizedBox(height: 6),
                _text(
                  '${isIncome ? '+' : '-'}${formatCentsBRL(transaction.amountCents)}',
                  color: color,
                  size: 15,
                  bold: true,
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('edit-transaction-${transaction.id}'),
            tooltip: 'Editar descrição',
            onPressed: () => _editTransactionDescription(transaction),
            icon: Icon(
              Icons.edit_outlined,
              color: AppColors.of(context).neon,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final rename = widget.onRenameBusiness;
    final saveBusiness =
        widget.onSaveBusinessDetails ??
        (rename == null
            ? null
            : (BusinessProfileData data) async {
                await rename(data.name);
              });
    return ProfileScreen(
      user: widget.user,
      financialProfile: widget.financialProfile,
      isSigningOut: _isSigningOut,
      onSignOut: _signOut,
      onBack: () => setState(() => _selectedIndex = 0),
      onSavePersonalName: widget.onSavePersonalName,
      onSaveBusiness: saveBusiness,
      onChoosePhoto: widget.onChooseProfilePhoto,
      onRemovePhoto: widget.onRemoveProfilePhoto,
      onOpenFamilyGroup: widget.onOpenFamilyGroup,
    );
  }

  Widget _progress() => LinearProgressIndicator(
    color: AppColors.of(context).neon,
    backgroundColor: AppColors.of(context).dashboardTrack,
  );

  Widget _text(
    String text, {
    double size = 13,
    bool bold = false,
    bool secondary = false,
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
  }) => Text(
    text,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: GoogleFonts.poppins(
      color:
          color ??
          (secondary
              ? AppColors.of(context).textSecondary
              : AppColors.of(context).dashboardText),
      fontSize: size,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}
