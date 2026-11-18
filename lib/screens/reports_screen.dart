import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/category_total.dart';
import '../models/finance_summary.dart';
import '../models/finance_transaction.dart';
import '../models/monthly_limit.dart';
import '../models/services/finance_repository.dart';
import '../models/services/monthly_limit_repository.dart';
import '../utils/formatters.dart';
import '../widgets/app_header.dart';
import '../widgets/category_totals_table.dart';
import '../widgets/edit_limit_sheet.dart';
import '../widgets/limit_alert_banner.dart';
import '../widgets/month_selector.dart';
import '../widgets/spending_limit_card.dart';

// Recebe a mesma lista de lançamentos usada pelo Início e pelo histórico.
class ReportsScreen extends StatefulWidget {
  final String userId;
  final List<FinanceTransaction> transactions;
  final MonthlyLimitRepository? limitRepository;
  final bool isLoading;
  final String? loadError;
  final Future<void> Function()? onRefresh;
  final bool isActive;

  const ReportsScreen({
    super.key,
    required this.userId,
    required this.transactions,
    this.limitRepository,
    this.isLoading = false,
    this.loadError,
    this.onRefresh,
    this.isActive = true,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with WidgetsBindingObserver {
  DateTime _selectedMonth = MonthlyLimit.normalizeMonth(DateTime.now());
  MonthlyLimit? _limit;
  Timer? _poll;
  bool _limitLoading = false;
  bool _editing = false;
  String? _limitError;
  int _limitGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLimitUpdates();
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedAccount = oldWidget.userId != widget.userId;
    if (changedAccount || oldWidget.limitRepository != widget.limitRepository) {
      _limitGeneration++;
      _limit = null;
      _limitError = null;
      _limitLoading = false;
      _editing = false;
      if (changedAccount) {
        _selectedMonth = MonthlyLimit.normalizeMonth(DateTime.now());
      }
    }
    if (changedAccount ||
        oldWidget.limitRepository != widget.limitRepository ||
        oldWidget.isActive != widget.isActive) {
      _startLimitUpdates();
    }
  }

  @override
  void dispose() {
    _limitGeneration++;
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadLimit());
  }

  bool _sameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;

  void _startLimitUpdates() {
    _poll?.cancel();
    if (!widget.isActive) return;
    unawaited(_loadLimit());
    if (widget.limitRepository != null) {
      _poll = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(_loadLimit());
      });
    }
  }

  Future<void> _loadLimit() async {
    if (!mounted || !widget.isActive || _editing) return;
    final generation = ++_limitGeneration;
    final month = _selectedMonth;
    final userId = widget.userId;
    setState(() {
      _limitLoading = true;
      _limitError = null;
    });
    try {
      final repository = widget.limitRepository;
      if (repository == null) {
        throw const FinanceException(
          'Não foi possível carregar seu limite mensal.',
        );
      }
      final limit = await repository.loadForMonth(month);
      if (!mounted ||
          generation != _limitGeneration ||
          widget.userId != userId) {
        return;
      }
      if (limit != null &&
          (limit.userId != userId || !_sameMonth(limit.month, month))) {
        throw const FinanceException(
          'Não foi possível carregar o limite desta conta.',
        );
      }
      setState(() => _limit = limit);
    } catch (error) {
      if (!mounted ||
          generation != _limitGeneration ||
          widget.userId != userId) {
        return;
      }
      setState(() {
        _limit = null;
        _limitError = error is FinanceException
            ? error.message
            : 'Não foi possível carregar seu limite mensal. Tente novamente.';
      });
    } finally {
      if (mounted &&
          generation == _limitGeneration &&
          widget.userId == userId) {
        setState(() => _limitLoading = false);
      }
    }
  }

  void _changeMonth(DateTime month) {
    if (_editing || _sameMonth(month, _selectedMonth)) return;
    setState(() {
      _limitGeneration++;
      _selectedMonth = MonthlyLimit.normalizeMonth(month);
      _limit = null;
      _limitError = null;
    });
    unawaited(_loadLimit());
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      if (widget.onRefresh != null) widget.onRefresh!(),
      _loadLimit(),
    ]);
  }

  Future<void> _editLimit() async {
    final repository = widget.limitRepository;
    if (_editing ||
        _limitLoading ||
        _limitError != null ||
        repository == null) {
      return;
    }
    final month = _selectedMonth;
    final userId = widget.userId;
    setState(() {
      _editing = true;
      _limitGeneration++;
    });
    try {
      final saved = await showEditLimitSheet(
        context,
        currentLimit: _limit == null ? null : _limit!.limitCents / 100,
        onSave: (value) async {
          if (!mounted ||
              widget.userId != userId ||
              !identical(widget.limitRepository, repository) ||
              !_sameMonth(month, _selectedMonth)) {
            throw const FinanceException('Sua sessão mudou. Entre novamente.');
          }
          final record = await repository.saveForMonth(
            month: month,
            limitCents: (value * 100).round(),
          );
          if (!mounted ||
              widget.userId != userId ||
              !identical(widget.limitRepository, repository) ||
              !_sameMonth(month, _selectedMonth)) {
            throw const FinanceException('Sua sessão mudou. Entre novamente.');
          }
          if (record.userId != userId || !_sameMonth(record.month, month)) {
            throw const FinanceException(
              'Não foi possível salvar seu limite mensal.',
            );
          }
          setState(() {
            _limitGeneration++;
            _limit = record;
            _limitError = null;
          });
        },
      );
      if (!mounted || saved == null || widget.userId != userId) return;
      final summary = FinanceSummary.forMonth(
        widget.transactions,
        userId: userId,
        month: month,
      );
      final limit = _limit;
      if (limit != null && summary.expenseCents > limit.limitCents) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Limite ultrapassado em '
              '${formatCentsBRL(summary.expenseCents - limit.limitCents)}.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = FinanceSummary.forMonth(
      widget.transactions,
      userId: widget.userId,
      month: _selectedMonth,
    );
    final categories = summary.expenseTotals.entries
        .map(
          (entry) => CategoryTotal(
            name: entry.key.label,
            icon: entry.key.icon,
            total: entry.value / 100,
          ),
        )
        .toList(growable: false);
    final spent = summary.expenseCents / 100;
    final limit = _limit;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.neon,
          backgroundColor: AppColors.dashboardSurface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.bar_chart, color: AppColors.neon, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Relatórios',
                        style: GoogleFonts.poppins(
                          color: AppColors.dashboardText,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                MonthSelector(
                  selectedMonth: _selectedMonth,
                  onChanged: _changeMonth,
                ),
                const SizedBox(height: 24),
                Text(
                  'Controle de gastos',
                  style: GoogleFonts.poppins(
                    color: AppColors.dashboardText,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.loadError != null) ...[
                  Text(
                    widget.loadError!,
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Tentar novamente'),
                  ),
                ] else if (widget.isLoading && widget.transactions.isEmpty) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else ...[
                  if (widget.isLoading) ...[
                    LinearProgressIndicator(color: AppColors.neon),
                    const SizedBox(height: 12),
                  ],
                  SpendingLimitCard(
                    limit: limit == null ? null : limit.limitCents / 100,
                    spent: spent,
                    onEdit: _editLimit,
                    isLoading: _limitLoading,
                    errorMessage: _limitError,
                    onRetry: _loadLimit,
                  ),
                  const SizedBox(height: 16),
                  if (limit != null &&
                      !_limitLoading &&
                      _limitError == null) ...[
                    LimitAlertBanner(
                      limit: limit.limitCents / 100,
                      spent: spent,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (categories.isEmpty)
                    Text(
                      'Você ainda não tem despesas neste mês.',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    CategoryTotalsTable(categories: categories),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
