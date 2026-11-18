import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/finance_summary.dart';
import '../models/finance_transaction.dart';
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

class HomeScreen extends StatefulWidget {
  final AppUser user;
  final AccountService accountService;
  final FinanceRepository repository;
  final MonthlyLimitRepository? monthlyLimitRepository;

  const HomeScreen({
    super.key,
    required this.user,
    required this.accountService,
    required this.repository,
    this.monthlyLimitRepository,
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
        oldWidget.accountService != widget.accountService) {
      // Descarta dados e respostas da conta anterior.
      _loadGeneration++;
      _transactions = const [];
      _loadError = null;
      _selectedIndex = 0;
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
    if (!mounted || _isSigningOut) return;
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
          loaded.any((transaction) => transaction.userId != widget.user.id)) {
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
        _isSigningOut ||
        !_sessionMatches) {
      return;
    }
    _isOpeningForm = true;
    final userId = widget.user.id;
    final repository = widget.repository;
    bool sameAccount() =>
        mounted &&
        _sessionMatches &&
        widget.user.id == userId &&
        identical(widget.repository, repository);
    try {
      final saved = await Navigator.of(context).push<NewTransactionData>(
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
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
        _isSigningOut ||
        !_sessionMatches) {
      return;
    }
    final userId = widget.user.id;
    if (transaction.userId != userId) return;
    final repository = widget.repository;
    bool sameAccount() =>
        mounted &&
        _sessionMatches &&
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
              updated.userId != userId ||
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
      if (!mounted || !_sessionMatches || widget.user.id != userId) return;
      if (limit != null &&
          (limit.userId != userId ||
              limit.month.year != saved.occurredOn.year ||
              limit.month.month != saved.occurredOn.month)) {
        throw const FinanceException(
          'Não foi possível conferir o limite desta conta.',
        );
      }
      final summary = FinanceSummary.forMonth(
        _transactions,
        userId: userId,
        month: saved.occurredOn,
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
      if (mounted && _sessionMatches && widget.user.id == userId) {
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
          backgroundColor: AppColors.dashboardSurface,
          content: _text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Oculta dados enquanto a raiz troca de sessão.
    if (!_sessionMatches || _isSigningOut) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: _isSigningOut
                ? CircularProgressIndicator(color: AppColors.neon)
                : _text('Sua sessão foi encerrada.', secondary: true),
          ),
        ),
      );
    }
    final summary = FinanceSummary.fromTransactions(_transactions);
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) => setState(() => _selectedIndex = index),
        onAddPressed: _openAddTransaction,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboard(summary),
            ReportsScreen(
              userId: widget.user.id,
              transactions: _transactions,
              limitRepository: widget.monthlyLimitRepository,
              isLoading: _isLoading,
              loadError: _loadError,
              onRefresh: _loadTransactions,
              isActive: _selectedIndex == 1,
            ),
            _buildTransactions(),
            _buildProfile(),
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
          color: AppColors.neon,
          backgroundColor: AppColors.dashboardSurface,
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
    return _scrollable([
      const AppHeader(),
      const SizedBox(height: 24),
      _text('Olá, ${widget.user.firstName}', size: 25, bold: true),
      const SizedBox(height: 4),
      _text('Aqui está o resumo das suas finanças.', secondary: true),
      const SizedBox(height: 22),
      if (_loadError != null || (_isLoading && _transactions.isEmpty))
        _buildLoadStatus()
      else ...[
        if (_isLoading) ...[_progress(), const SizedBox(height: 12)],
        BalanceCard(
          key: ValueKey(widget.user.id),
          balanceCents: summary.balanceCents,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Receitas',
                amountCents: summary.incomeCents,
                icon: Icons.arrow_upward,
                accentColor: AppColors.neon,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SummaryCard(
                title: 'Despesas',
                amountCents: summary.expenseCents,
                icon: Icons.arrow_downward,
                accentColor: AppColors.dashboardExpense,
              ),
            ),
          ],
        ),
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
              CircularProgressIndicator(color: AppColors.neon),
              const SizedBox(height: 16),
              _text('Carregando seus lançamentos...', secondary: true),
            ] else ...[
              Icon(
                Icons.cloud_off_outlined,
                color: AppColors.textSecondary,
                size: 36,
              ),
              const SizedBox(height: 12),
              _text(_loadError!, secondary: true, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadTransactions,
                icon: Icon(Icons.refresh, color: AppColors.neon),
                label: _text('Tentar novamente', color: AppColors.neon),
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
    final color = isIncome ? AppColors.neon : AppColors.dashboardExpense;
    final date = transaction.occurredOn;
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
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
            icon: Icon(Icons.edit_outlined, color: AppColors.neon, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _text('Perfil', size: 24, bold: true),
              const SizedBox(height: 24),
              Icon(Icons.person_outline, color: AppColors.neon, size: 56),
              const SizedBox(height: 16),
              _text(
                widget.user.name,
                size: 21,
                bold: true,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              _text(
                widget.user.email,
                secondary: true,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                key: const ValueKey('sign-out'),
                onPressed: _isSigningOut ? null : _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: _text(
                  'Sair da conta',
                  bold: true,
                  color: AppColors.background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() => LinearProgressIndicator(
    color: AppColors.neon,
    backgroundColor: AppColors.dashboardTrack,
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
          (secondary ? AppColors.textSecondary : AppColors.dashboardText),
      fontSize: size,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}
