import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/app.dart';
import 'package:gestao_financeira/models/app_user.dart';
import 'package:gestao_financeira/models/financial_profile.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/monthly_limit.dart';
import 'package:gestao_financeira/models/services/account_service.dart';
import 'package:gestao_financeira/models/services/family_group_repository.dart';
import 'package:gestao_financeira/models/services/financial_profile_repository.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/monthly_limit_repository.dart';
import 'package:gestao_financeira/widgets/app_bottom_nav.dart';
import 'package:gestao_financeira/widgets/app_header.dart';
import 'package:gestao_financeira/widgets/balance_card.dart';
import 'package:gestao_financeira/widgets/category_totals_table.dart';
import 'package:gestao_financeira/widgets/spending_limit_card.dart';
import 'package:gestao_financeira/widgets/summary_card.dart';

const _ana = AppUser(id: 'user-a', email: 'ana@teste.com', name: 'Ana Silva');
const _bia = AppUser(id: 'user-b', email: 'bia@teste.com', name: 'Bia Souza');

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'convite abre o orçamento compartilhado e sair volta à configuração',
    (tester) async {
      final harness = _Harness(familyEnabled: true);
      await _mount(tester, harness);
      await _profile(tester, FinancialProfile.familyId);
      await _tap(tester, find.text('Criar grupo familiar'));
      expect(find.text('Orçamento familiar'), findsOneWidget);
      await _addExpense(tester, 3500, 'Conta de luz da casa');
      await _tap(tester, find.text('Grupo familiar'));
      await _tap(tester, find.text('Gerar convite'));
      expect(find.text(_Profiles.inviteCode), findsOneWidget);

      harness.accounts.switchTo(_bia);
      await tester.pumpAndSettle();
      _expectHome(tester, income: 0, expenses: 0, balance: 0);
      await _profile(tester, FinancialProfile.familyId);
      await _tap(tester, find.text('Entrar com convite'));
      expect(
        find.text('Cole o código de 32 caracteres do convite.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), _Profiles.inviteCode);
      await _tap(tester, find.text('Entrar com convite'));
      _expectHome(tester, income: 0, expenses: 3500, balance: -3500);
      await _tab(tester, 'Relatórios');
      expect(_spending(tester).spent, 35);
      await _setLimit(tester, 10500);
      await _tab(tester, 'Início');
      await _tap(tester, find.text('Grupo familiar'));
      expect(find.text('Gerar convite'), findsNothing);
      await _tap(tester, find.text('Sair do grupo'));
      await _tap(tester, find.text('Sair do grupo').last);
      expect(find.text('Entrar com convite'), findsOneWidget);
      expect(find.byType(BalanceCard), findsNothing);

      harness.accounts.switchTo(_ana);
      await tester.pumpAndSettle();
      _expectHome(tester, income: 0, expenses: 3500, balance: -3500);
      await _tab(tester, 'Relatórios');
      expect(_spending(tester).limit, 105);
    },
  );

  testWidgets(
    'legado, despesas, limites e nome permanecem no perfil escolhido',
    (tester) async {
      final harness = _Harness();
      final legacy = harness.data.rows[(_ana.id, 'personal')]!
          .map((transaction) => transaction.toJson())
          .toList();
      final now = DateTime.now();
      await _mount(tester, harness);
      expect(_header(tester).selectedProfileId, 'personal');
      _expectHome(tester, income: 100000, expenses: 12500, balance: 87500);

      await _profile(tester, 'business');
      _expectHome(tester, income: 0, expenses: 0, balance: 0);
      await _addExpense(tester, 2500, 'Despesa da empresa');
      _expectHome(tester, income: 0, expenses: 2500, balance: -2500);
      final businessRow = harness.data.rows[(_ana.id, 'business')]!.single;
      expect(businessRow.profileId, 'business');

      await _tab(tester, 'Lançamentos');
      await _tap(
        tester,
        find.byKey(ValueKey('edit-transaction-${businessRow.id}')),
      );
      await _enter(
        tester,
        'transaction-description-input',
        'Despesa empresarial editada',
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('save-transaction-description')),
      );
      expect(find.text('Despesa empresarial editada'), findsOneWidget);
      expect(
        harness.data.rows[(_ana.id, 'business')]!.single.description,
        'Despesa empresarial editada',
      );

      await _tab(tester, 'Relatórios');
      expect(_spending(tester).spent, 25);
      expect(_spending(tester).limit, isNull);
      await _setLimit(tester, 4000);
      expect(_spending(tester).limit, 40);

      await _profile(tester, 'personal');
      expect(_selectedTab(tester), 1);
      expect(_spending(tester).spent, 125);
      expect(_spending(tester).limit, isNull);
      await _setLimit(tester, 20000);
      expect(_spending(tester).limit, 200);
      await _profile(tester, 'business');
      expect(_selectedTab(tester), 1);
      expect(_spending(tester).spent, 25);
      expect(_spending(tester).limit, 40);
      final categories = tester
          .widget<CategoryTotalsTable>(find.byType(CategoryTotalsTable))
          .categories;
      expect(categories.single.total, 25);
      expect(
        harness
            .data
            .limits[(_ana.id, 'personal', MonthlyLimit.formatMonth(now))]!
            .limitCents,
        20000,
      );
      expect(
        harness
            .data
            .limits[(_ana.id, 'business', MonthlyLimit.formatMonth(now))]!
            .limitCents,
        4000,
      );

      final previousMonth = DateTime(now.year, now.month - 1);
      await _selectMonth(tester, previousMonth);
      expect(_spending(tester).spent, 0);
      expect(_spending(tester).limit, isNull);
      await _setLimit(tester, 3000);
      await _profile(tester, 'personal');
      expect(_selectedTab(tester), 1);
      expect(_spending(tester).spent, 0);
      expect(_spending(tester).limit, isNull);
      await _profile(tester, 'business');
      expect(_spending(tester).limit, 30);
      await _selectMonth(tester, now);
      expect(_spending(tester).spent, 25);
      expect(_spending(tester).limit, 40);

      await _tab(tester, 'Perfil');
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-name-input')),
      );
      expect(_input(tester, 'profile-name-input'), 'Empresa');
      await _enter(tester, 'profile-name-input', '  Loja da Ana  ');
      final renameGate = Completer<void>();
      harness.profiles.renameGate = renameGate;
      await tester.ensureVisible(find.byKey(const ValueKey('save-profile')));
      await tester.tap(find.byKey(const ValueKey('save-profile')));
      await tester.pump();
      expect(harness.profiles.stateFor(_ana.id).activeProfile.name, 'Empresa');
      expect(harness.profiles.renameCalls, 1);
      renameGate.complete();
      await tester.pumpAndSettle();
      expect(_header(tester).businessName, 'Loja da Ana');
      expect(
        harness.profiles.stateFor(_ana.id).activeProfile.name,
        'Loja da Ana',
      );

      await _remount(tester, harness);
      expect(_header(tester).selectedProfileId, 'business');
      expect(_header(tester).businessName, 'Loja da Ana');
      _expectHome(tester, income: 0, expenses: 2500, balance: -2500);
      await _tab(tester, 'Relatórios');
      expect(_spending(tester).spent, 25);
      expect(_spending(tester).limit, 40);
      expect(
        harness.data.rows[(_ana.id, 'personal')]!
            .map((transaction) => transaction.toJson())
            .toList(),
        legacy,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('falhas não mudam a seleção confirmada nem inventam saldo zero', (
    tester,
  ) async {
    final harness = _Harness();
    await _mount(tester, harness);
    harness.profiles.selectionError = const FinanceException(
      'Não foi possível mudar o perfil.',
    );
    await _profile(tester, 'business');
    expect(_header(tester).selectedProfileId, 'personal');
    expect(harness.profiles.stateFor(_ana.id).activeProfileId, 'personal');
    _expectHome(tester, income: 100000, expenses: 12500, balance: 87500);

    harness.profiles.selectionError = null;
    harness.data.loadErrors[(_ana.id, 'business')] = const FinanceException(
      'Dados da empresa indisponíveis.',
    );
    await _profile(tester, 'business');
    expect(find.text('Dados da empresa indisponíveis.'), findsOneWidget);
    expect(find.byType(BalanceCard), findsNothing);
    expect(find.byType(SummaryCard), findsNothing);
    expect(harness.data.rows[(_ana.id, 'business')], isNull);

    await _profile(tester, 'personal');
    _expectHome(tester, income: 100000, expenses: 12500, balance: 87500);
    expect(harness.data.rows[(_ana.id, 'personal')]!.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'seleção aguarda gravação e resposta antiga não vaza para outra conta',
    (tester) async {
      final harness = _Harness();
      await _mount(tester, harness);
      final selectionGate = Completer<void>();
      final businessLoad = Completer<List<FinanceTransaction>>();
      harness.profiles.selectionGate = selectionGate;
      harness.data.loadGates[(_ana.id, 'business')] = businessLoad;
      await tester.tap(find.byKey(const ValueKey('profile-business')));
      await tester.pump();
      expect(harness.profiles.stateFor(_ana.id).activeProfileId, 'personal');
      expect(harness.data.loadCalls[(_ana.id, 'business')] ?? 0, 0);
      final switching = find.byKey(
        const ValueKey('switching-financial-profile'),
      );
      expect(switching, findsOneWidget);
      expect(tester.widget<ColoredBox>(switching).color.a, 1);
      expect(find.byType(BalanceCard).hitTestable(), findsNothing);

      selectionGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(harness.profiles.stateFor(_ana.id).activeProfileId, 'business');
      expect(harness.data.loadCalls[(_ana.id, 'business')], greaterThan(0));
      expect(find.byType(BalanceCard), findsNothing);

      harness.accounts.switchTo(_bia);
      await tester.pumpAndSettle();
      expect(_header(tester).selectedProfileId, 'personal');
      expect(find.text('Olá, Bia'), findsOneWidget);
      _expectHome(tester, income: 0, expenses: 0, balance: 0);

      final now = DateTime.now();
      businessLoad.complete([
        FinanceTransaction(
          id: 'late-a',
          userId: _ana.id,
          profileId: 'business',
          type: TransactionType.expense,
          amountCents: 99999,
          category: TransactionCategory.food,
          description: 'Resposta antiga da Ana',
          occurredOn: now,
          createdAt: now.toUtc(),
        ),
      ]);
      await tester.pumpAndSettle();
      _expectHome(tester, income: 0, expenses: 0, balance: 0);
      expect(
        find.text('Resposta antiga da Ana', skipOffstage: false),
        findsNothing,
      );
      expect(harness.profiles.stateFor(_bia.id).activeProfileId, 'personal');
      await _profile(tester, 'business');
      _expectHome(tester, income: 0, expenses: 0, balance: 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'trocar perfil remove o alerta real e os avisos financeiros pendentes',
    (tester) async {
      final harness = _Harness();
      await _mount(tester, harness);
      await _tab(tester, 'Relatórios');
      await _setLimit(tester, 10000);
      expect(find.text('Limite ultrapassado em R\$ 25,00.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      // O segundo alerta fica na fila do mesmo ScaffoldMessenger.
      await _setLimit(tester, 11000);
      expect(find.text('Limite ultrapassado em R\$ 25,00.'), findsOneWidget);

      final gate = Completer<void>();
      harness.profiles.selectionGate = gate;
      await tester.tap(find.byKey(const ValueKey('profile-business')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('switching-financial-profile')),
        findsOneWidget,
      );
      expect(
        find.text('Limite ultrapassado em R\$ 25,00.', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('Limite ultrapassado em R\$ 15,00.', skipOffstage: false),
        findsNothing,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(_spending(tester).spent, 0);
      expect(_spending(tester).limit, isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'trocar conta remove imediatamente o alerta financeiro da pessoa anterior',
    (tester) async {
      final harness = _Harness();
      await _mount(tester, harness);
      await _tab(tester, 'Relatórios');
      await _setLimit(tester, 10000);
      expect(find.text('Limite ultrapassado em R\$ 25,00.'), findsOneWidget);

      harness.accounts.switchTo(_bia);
      await tester.pump();
      expect(
        find.text('Limite ultrapassado em R\$ 25,00.', skipOffstage: false),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('Olá, Bia'), findsOneWidget);
      _expectHome(tester, income: 0, expenses: 0, balance: 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(WidgetTester tester, _Harness harness) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 720);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await harness.accounts.close();
    await harness.data.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
}

Future<void> _remount(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _profile(WidgetTester tester, String id) =>
    _tap(tester, find.byKey(ValueKey('profile-$id')));
Future<void> _tab(WidgetTester tester, String label) =>
    _tap(tester, find.text(label).last);
AppHeader _header(WidgetTester tester) =>
    tester.widget<AppHeader>(find.byType(AppHeader));
int _selectedTab(WidgetTester tester) =>
    tester.widget<AppBottomNav>(find.byType(AppBottomNav)).selectedIndex;
SpendingLimitCard _spending(WidgetTester tester) =>
    tester.widget<SpendingLimitCard>(find.byType(SpendingLimitCard));
String _input(WidgetTester tester, String key) {
  final field = tester.widget(find.byKey(ValueKey(key)));
  if (field is TextField) return field.controller!.text;
  if (field is TextFormField) return field.controller!.text;
  throw StateError('Campo de edição não encontrado.');
}

void _expectHome(
  WidgetTester tester, {
  required int income,
  required int expenses,
  required int balance,
}) {
  expect(
    tester.widget<BalanceCard>(find.byType(BalanceCard)).balanceCents,
    balance,
  );
  final cards = tester.widgetList<SummaryCard>(find.byType(SummaryCard));
  final business = FinancialProfile.isBusinessId(
    _header(tester).selectedProfileId,
  );
  expect(
    cards
        .singleWhere(
          (card) => card.title == (business ? 'Entradas' : 'Receitas'),
        )
        .amountCents,
    income,
  );
  expect(
    cards
        .singleWhere((card) => card.title == (business ? 'Saídas' : 'Despesas'))
        .amountCents,
    expenses,
  );
}

Future<void> _addExpense(
  WidgetTester tester,
  int cents,
  String description,
) async {
  final business = FinancialProfile.isBusinessId(
    _header(tester).selectedProfileId,
  );
  await _tap(tester, find.byKey(const ValueKey('add-transaction')));
  await _tap(tester, find.byKey(const ValueKey('transaction-type')));
  await _tap(tester, find.text(business ? 'Saída' : 'Despesa').last);
  await _enter(tester, 'transaction-amount', cents.toString());
  await _tap(
    tester,
    find.byKey(const ValueKey('transaction-category-expense')),
  );
  await _tap(tester, find.text(business ? 'Fornecedores' : 'Alimentação').last);
  await _enter(tester, 'transaction-description', description);
  await _tap(tester, find.byKey(const ValueKey('submit-transaction')));
}

Future<void> _setLimit(WidgetTester tester, int cents) async {
  await _tap(tester, find.byKey(const ValueKey('edit-spending-limit')));
  await _enter(tester, 'spending-limit-input', cents.toString());
  await _tap(tester, find.byKey(const ValueKey('save-spending-limit')));
}

Future<void> _selectMonth(WidgetTester tester, DateTime month) async {
  await _tap(tester, find.byKey(const ValueKey('month-selector')));
  await _tap(
    tester,
    find.byKey(
      ValueKey(
        'month-option-${month.year}-${month.month.toString().padLeft(2, '0')}',
      ),
    ),
  );
}

class _Harness {
  final bool familyEnabled;
  final accounts = _Accounts();
  late final profiles = _Profiles(accounts, familyEnabled);
  late final data = _Data(accounts);

  _Harness({this.familyEnabled = false});

  Widget app() => MyApp(
    accountService: accounts,
    repository: data.finance('personal'),
    monthlyLimitRepository: data.budget('personal'),
    profileRepository: profiles,
    familyGroupRepository: familyEnabled ? profiles : null,
    financeRepositoryForProfile: (profile) =>
        data.finance(profile.id, profile.familyOwnerId),
    monthlyLimitRepositoryForProfile: (profile) =>
        data.budget(profile.id, profile.familyOwnerId),
  );
}

class _Accounts implements AccountService {
  final _changes = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _user = _ana;
  @override
  AppUser? get currentUser => _user;
  @override
  Stream<AppUser?> get userChanges => _changes.stream;
  void switchTo(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => switchTo(email == _bia.email ? _bia : _ana);
  @override
  Future<void> signOut() async => switchTo(null);
  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async => false;
  Future<void> close() => _changes.close();
}

class _Profiles implements FinancialProfileRepository, FamilyGroupRepository {
  static const inviteCode = '0123456789abcdef0123456789abcdef';
  final bool familyEnabled;
  String? _invitingOwner;
  final _Accounts accounts;
  final _states = <String, FinancialProfileState>{};
  FinanceException? selectionError;
  Completer<void>? selectionGate;
  Completer<void>? renameGate;
  int renameCalls = 0;
  _Profiles(this.accounts, this.familyEnabled);

  FinancialProfileState stateFor(String userId) => _states.putIfAbsent(
    userId,
    () => FinancialProfileState(
      profiles: [
        FinancialProfile(
          id: 'personal',
          userId: userId,
          kind: FinancialProfileKind.personal,
          name: 'Pessoal',
        ),
        FinancialProfile(
          id: 'business',
          userId: userId,
          kind: FinancialProfileKind.business,
          name: 'Empresa',
        ),
        if (familyEnabled) _familyProfile(userId, null),
      ],
      activeProfileId: 'personal',
    ),
  );

  FinancialProfile _familyProfile(String userId, String? owner) =>
      FinancialProfile(
        id: FinancialProfile.familyId,
        userId: userId,
        kind: FinancialProfileKind.family,
        name: 'Familiar',
        familyOwnerId: owner,
      );

  void _setFamilyOwner(String userId, String? ownerId) {
    final state = stateFor(userId);
    _states[userId] = FinancialProfileState(
      profiles: [
        for (final profile in state.profiles)
          if (profile.kind == FinancialProfileKind.family)
            _familyProfile(userId, ownerId)
          else
            profile,
      ],
      activeProfileId: state.activeProfileId,
    );
  }

  @override
  Future<void> createGroup() async {
    final userId = accounts.currentUser!.id;
    _setFamilyOwner(userId, userId);
  }

  @override
  Future<String> createInvite() async {
    _invitingOwner = accounts.currentUser!.id;
    return inviteCode;
  }

  @override
  Future<void> joinGroup(String code) async {
    if (code != inviteCode || _invitingOwner == null) {
      throw const FinanceException('Convite inválido.');
    }
    _setFamilyOwner(accounts.currentUser!.id, _invitingOwner);
    _invitingOwner = null;
  }

  @override
  Future<List<FamilyMember>> loadMembers() async {
    final ownerId = stateFor(accounts.currentUser!.id)
        .activeProfile
        .familyOwnerId;
    return [
      for (final user in [_ana, _bia])
        if (stateFor(user.id).profiles.any(
          (profile) => ownerId != null && profile.familyOwnerId == ownerId,
        ))
          FamilyMember(userId: user.id, name: user.name),
    ];
  }

  @override
  Future<void> leaveGroup() async =>
      _setFamilyOwner(accounts.currentUser!.id, null);

  @override
  Future<void> removeMember(String userId) async =>
      _setFamilyOwner(userId, null);

  @override
  Future<FinancialProfileState> loadProfiles() async =>
      stateFor(accounts.currentUser!.id);
  @override
  Future<void> selectProfile(String profileId) async {
    final userId = accounts.currentUser!.id;
    await selectionGate?.future;
    final error = selectionError;
    if (error != null) throw error;
    _states[userId] = FinancialProfileState(
      profiles: stateFor(userId).profiles,
      activeProfileId: profileId,
    );
  }

  @override
  Future<FinancialProfile> renameBusiness({
    required String profileId,
    required String name,
  }) async {
    renameCalls++;
    final userId = accounts.currentUser!.id;
    await renameGate?.future;
    final state = stateFor(userId);
    final original = state.profiles.singleWhere(
      (profile) => profile.id == profileId,
    );
    final renamed = FinancialProfile(
      id: original.id,
      userId: userId,
      kind: original.kind,
      name: name.trim(),
    );
    _states[userId] = FinancialProfileState(
      profiles: [
        for (final profile in state.profiles)
          if (profile.id == profileId) renamed else profile,
      ],
      activeProfileId: state.activeProfileId,
    );
    return renamed;
  }
}

class _Data {
  final _Accounts accounts;
  final rows = <(String, String), List<FinanceTransaction>>{};
  final limits = <(String, String, String), MonthlyLimit>{};
  final loadErrors = <(String, String), FinanceException>{};
  final loadGates = <(String, String), Completer<List<FinanceTransaction>>>{};
  final loadCalls = <(String, String), int>{};
  final _finances = <(String, String?), _FinanceScope>{};
  final _budgets = <(String, String?), _BudgetScope>{};
  int nextId = 0;
  _Data(this.accounts) {
    final now = DateTime.now();
    // Registros anteriores à migração continuam no perfil Pessoal por padrão.
    rows[(_ana.id, 'personal')] = [
      FinanceTransaction(
        id: 'legacy-income',
        userId: _ana.id,
        type: TransactionType.income,
        amountCents: 100000,
        category: TransactionCategory.salary,
        description: 'Receita pessoal antiga',
        occurredOn: now,
        createdAt: now.toUtc(),
      ),
      FinanceTransaction(
        id: 'legacy-expense',
        userId: _ana.id,
        type: TransactionType.expense,
        amountCents: 12500,
        category: TransactionCategory.food,
        description: 'Despesa pessoal antiga',
        occurredOn: now,
        createdAt: now.toUtc(),
      ),
    ];
  }
  _FinanceScope finance(String profileId, [String? familyOwnerId]) =>
      _finances.putIfAbsent((
        profileId,
        familyOwnerId,
      ), () => _FinanceScope(this, profileId, familyOwnerId));
  _BudgetScope budget(String profileId, [String? familyOwnerId]) =>
      _budgets.putIfAbsent((
        profileId,
        familyOwnerId,
      ), () => _BudgetScope(this, profileId, familyOwnerId));
  Future<void> close() async {
    for (final repository in _finances.values) {
      await repository.changesController.close();
    }
  }
}

class _FinanceScope implements FinanceRepository {
  final _Data data;
  final String profileId;
  final changesController = StreamController<void>.broadcast(sync: true);
  final String? familyOwnerId;
  _FinanceScope(this.data, this.profileId, this.familyOwnerId);
  String get _ownerId => familyOwnerId ?? data.accounts.currentUser!.id;
  @override
  Stream<void> get changes => changesController.stream;
  @override
  Future<List<FinanceTransaction>> loadTransactions() async {
    final key = (_ownerId, profileId);
    data.loadCalls.update(key, (count) => count + 1, ifAbsent: () => 1);
    final gate = data.loadGates.remove(key);
    if (gate != null) return gate.future;
    final error = data.loadErrors[key];
    if (error != null) throw error;
    return List.of(data.rows[key] ?? []);
  }

  @override
  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  }) async {
    final userId = _ownerId;
    data.rows
        .putIfAbsent((userId, profileId), () => [])
        .add(
          FinanceTransaction(
            id: '$profileId-${++data.nextId}',
            userId: userId,
            profileId: profileId,
            type: type,
            amountCents: amountCents,
            category: category,
            description: description,
            occurredOn: occurredOn,
            createdAt: DateTime.now().toUtc(),
          ),
        );
    changesController.add(null);
  }

  @override
  Future<FinanceTransaction> updateTransactionDescription({
    required String transactionId,
    required String description,
  }) async {
    final owned = data.rows[(_ownerId, profileId)] ?? [];
    final index = owned.indexWhere((row) => row.id == transactionId);
    if (index < 0) throw const FinanceException('Lançamento não encontrado.');
    final updated = FinanceTransaction.fromJson({
      ...owned[index].toJson(),
      'description': description.trim(),
    });
    owned[index] = updated;
    return updated;
  }
}

class _BudgetScope implements MonthlyLimitRepository {
  final _Data data;
  final String profileId;
  final String? familyOwnerId;
  _BudgetScope(this.data, this.profileId, this.familyOwnerId);
  String get _ownerId => familyOwnerId ?? data.accounts.currentUser!.id;
  @override
  Future<MonthlyLimit?> loadForMonth(DateTime month) async =>
      data.limits[(_ownerId, profileId, MonthlyLimit.formatMonth(month))];
  @override
  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  }) async {
    final userId = _ownerId;
    final record = MonthlyLimit(
      userId: userId,
      profileId: profileId,
      month: month,
      limitCents: limitCents,
    );
    data.limits[(userId, profileId, record.monthKey)] = record;
    return record;
  }
}
