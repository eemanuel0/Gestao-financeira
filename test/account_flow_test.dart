import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/app.dart';
import 'package:gestao_financeira/models/app_user.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/services/account_service.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/screens/add_transaction_screen.dart';
import 'package:gestao_financeira/screens/home_screen.dart';
import 'package:gestao_financeira/screens/login_screen.dart';
import 'package:gestao_financeira/screens/register_screen.dart';
import 'package:gestao_financeira/screens/welcome_screen.dart';
import 'package:gestao_financeira/widgets/balance_card.dart';
import 'package:gestao_financeira/widgets/summary_card.dart';

const _ana = AppUser(id: 'user-a', email: 'ana@teste.com', name: 'Ana Silva');
const _bia = AppUser(id: 'user-b', email: 'bia@teste.com', name: 'Bia Souza');
const _password = 'senha1234';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('login valida, trata erro e impede envios duplicados', (
    tester,
  ) async {
    final accounts = _FakeAccounts();
    final repository = _FakeRepository(accounts);
    await _mount(tester, accounts, repository);
    await _tap(tester, find.byKey(const ValueKey('welcome-login')));

    await _tap(tester, find.byKey(const ValueKey('login-submit')));
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    expect(accounts.signInCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      _ana.email,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'errada',
    );
    await _tap(tester, find.byKey(const ValueKey('login-submit')));
    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      _password,
    );
    accounts.signInGate = Completer<void>();
    final submit = find.byKey(const ValueKey('login-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(accounts.signInCalls, 2);
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(accounts.signInCalls, 2);

    accounts.signInGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Olá, Ana'), findsOneWidget);
    expect(_balance(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro valida e orienta confirmação de e-mail', (
    tester,
  ) async {
    final accounts = _FakeAccounts()..requiresEmailConfirmation = true;
    final repository = _FakeRepository(accounts);
    await _mount(tester, accounts, repository);
    await _tap(tester, find.byKey(const ValueKey('welcome-register')));

    // O rodapé Entrar precisa abrir o login, não outro cadastro.
    await _tap(tester, find.widgetWithText(TextButton, 'Entrar'));
    expect(find.byType(LoginScreen), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Criar conta'));
    expect(find.byType(RegisterScreen), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('register-submit')));
    expect(find.text('Informe seu nome.'), findsOneWidget);
    expect(accounts.signUpCalls, 0);
    await _enter(tester, 'register-name', '  Carla Silva  ');
    await _enter(tester, 'register-email', 'carla@teste.com');
    await _enter(tester, 'register-password', 'curta');
    await _enter(tester, 'register-confirm-password', 'diferente');
    await _tap(tester, find.byKey(const ValueKey('register-submit')));
    expect(
      find.text('Use uma senha com pelo menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(find.text('As senhas precisam ser iguais.'), findsOneWidget);
    expect(accounts.signUpCalls, 0);

    await _enter(tester, 'register-password', _password);
    await _enter(tester, 'register-confirm-password', _password);
    await _tap(tester, find.byKey(const ValueKey('register-submit')));
    expect(accounts.signUpCalls, 1);
    expect(accounts.lastRegisteredName, 'Carla Silva');
    expect(accounts.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text(
        'Confira seu e-mail para confirmar a conta. Depois, entre com sua senha.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contas começam zeradas e não mostram dados da outra pessoa', (
    tester,
  ) async {
    final accounts = _FakeAccounts(initialUser: _ana);
    final repository = _FakeRepository(accounts);
    await _mount(tester, accounts, repository);
    expect(_balance(tester), 0);
    expect(_summaryAmount(tester, 'Receitas'), 0);
    expect(_summaryAmount(tester, 'Despesas'), 0);

    await _openAndFillTransaction(
      tester,
      type: TransactionType.income,
      value: '1.000,00',
      category: TransactionCategory.salary,
      description: 'Salário da Ana',
    );
    await _tap(tester, find.byKey(const ValueKey('submit-transaction')));
    await _openAndFillTransaction(
      tester,
      type: TransactionType.expense,
      value: '250,00',
      category: TransactionCategory.food,
      description: 'Mercado da Ana',
    );
    await _tap(tester, find.byKey(const ValueKey('submit-transaction')));
    expect(_balance(tester), 75000);
    expect(_summaryAmount(tester, 'Receitas'), 100000);
    expect(_summaryAmount(tester, 'Despesas'), 25000);
    expect(repository.rows['user-a']!.length, 2);

    await _tap(tester, find.text('Lançamentos').last);
    expect(find.text('Salário da Ana'), findsOneWidget);
    expect(find.text('Mercado da Ana'), findsOneWidget);
    await _tap(tester, find.text('Perfil').last);
    await _logout(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await _signIn(tester, _bia);

    expect(find.text('Olá, Bia'), findsOneWidget);
    expect(_balance(tester), 0);
    expect(_summaryAmount(tester, 'Receitas'), 0);
    expect(_summaryAmount(tester, 'Despesas'), 0);
    expect(find.text('Salário da Ana', skipOffstage: false), findsNothing);
    expect(find.text('Mercado da Ana', skipOffstage: false), findsNothing);
    expect(repository.loadedUserIds.last, _bia.id);

    // Ao voltar à conta original, seus lançamentos continuam disponíveis.
    await _tap(tester, find.text('Perfil').last);
    await _logout(tester);
    await _signIn(tester, _ana);
    expect(_balance(tester), 75000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao salvar mantém o formulário e o envio não duplica', (
    tester,
  ) async {
    final accounts = _FakeAccounts(initialUser: _ana);
    final repository = _FakeRepository(accounts);
    await _mount(tester, accounts, repository);
    await _openAndFillTransaction(
      tester,
      type: TransactionType.expense,
      value: '40,50',
      category: TransactionCategory.food,
      description: 'Almoço',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pump();

    repository.nextAddError = const FinanceException(
      'Sem conexão. Tente novamente.',
    );
    final submit = find.byKey(const ValueKey('submit-transaction'));
    await _tap(tester, submit);
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    expect(find.text('Sem conexão. Tente novamente.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('transaction-amount')),
          )
          .controller!
          .text,
      '40,50',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('transaction-description')),
          )
          .controller!
          .text,
      'Almoço',
    );
    expect(repository.rows, isEmpty);

    // Aguarda o aviso sair antes de tocar no botão junto ao teclado.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    repository.saveGate = Completer<void>();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Salvando...'), findsOneWidget);
    expect(repository.addCalls, 2);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(repository.addCalls, 2);

    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AddTransactionScreen), findsNothing);
    expect(repository.rows['user-a']!.length, 1);
    expect(_balance(tester), -4050);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boas-vindas rola em janela de pouca altura', (tester) async {
    final accounts = _FakeAccounts();
    final repository = _FakeRepository(accounts);
    await _mount(tester, accounts, repository, size: const Size(360, 320));
    await _tap(tester, find.byKey(const ValueKey('welcome-register')));
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester tester,
  _FakeAccounts accounts,
  _FakeRepository repository, {
  Size size = const Size(360, 720),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await accounts.close();
    await repository.close();
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MyApp(accountService: accounts, repository: repository),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _signIn(WidgetTester tester, AppUser user) async {
  await _tap(tester, find.byKey(const ValueKey('welcome-login')));
  await _enter(tester, 'login-email', user.email);
  await _enter(tester, 'login-password', _password);
  await _tap(tester, find.byKey(const ValueKey('login-submit')));
}

Future<void> _openAndFillTransaction(
  WidgetTester tester, {
  required TransactionType type,
  required String value,
  required TransactionCategory category,
  required String description,
}) async {
  await _tap(tester, find.byKey(const ValueKey('add-transaction')));
  await _tap(tester, find.byKey(const ValueKey('transaction-type')));
  await _tap(tester, find.text(type.label).last);
  await _enter(tester, 'transaction-amount', value);
  await _tap(tester, find.byKey(ValueKey('transaction-category-${type.name}')));
  await _tap(tester, find.text(category.label).last);
  await _enter(tester, 'transaction-description', description);
}

int _balance(WidgetTester tester) =>
    tester.widget<BalanceCard>(find.byType(BalanceCard)).balanceCents;

int _summaryAmount(WidgetTester tester, String title) => tester
    .widgetList<SummaryCard>(find.byType(SummaryCard))
    .singleWhere((card) => card.title == title)
    .amountCents;

class _FakeAccounts implements AccountService {
  final _controller = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _currentUser;
  Completer<void>? signInGate;
  bool requiresEmailConfirmation = false;
  int signInCalls = 0;
  int signUpCalls = 0;
  String? lastRegisteredName;

  _FakeAccounts({AppUser? initialUser}) : _currentUser = initialUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    await signInGate?.future;
    final user = switch (email) {
      'ana@teste.com' => _ana,
      'bia@teste.com' => _bia,
      _ => null,
    };
    if (user == null || password != _password) {
      throw const AccountException('E-mail ou senha inválidos.');
    }
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    lastRegisteredName = name;
    if (requiresEmailConfirmation) return true;
    _currentUser = AppUser(id: 'new-user', email: email, name: name);
    _controller.add(_currentUser);
    return false;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  Future<void> close() => _controller.close();
}

class _FakeRepository implements FinanceRepository {
  final _FakeAccounts accounts;
  final rows = <String, List<FinanceTransaction>>{};
  final loadedUserIds = <String>[];
  final _controller = StreamController<void>.broadcast(sync: true);
  Completer<void>? saveGate;
  FinanceException? nextAddError;
  int addCalls = 0;

  _FakeRepository(this.accounts);

  @override
  Stream<void> get changes => _controller.stream;

  @override
  Future<List<FinanceTransaction>> loadTransactions() async {
    final userId = accounts.currentUser!.id;
    loadedUserIds.add(userId);
    return List.of(rows[userId] ?? []);
  }

  @override
  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  }) async {
    final userId = accounts.currentUser!.id;
    addCalls++;
    final failure = nextAddError;
    nextAddError = null;
    if (failure != null) throw failure;
    await saveGate?.future;
    rows
        .putIfAbsent(userId, () => [])
        .add(
          FinanceTransaction(
            id: 'transaction-$addCalls',
            userId: userId,
            type: type,
            amountCents: amountCents,
            category: category,
            description: description,
            occurredOn: occurredOn,
            createdAt: DateTime.now(),
          ),
        );
    _controller.add(null);
  }

  @override
  Future<FinanceTransaction> updateTransactionDescription({
    required String transactionId,
    required String description,
  }) async {
    final user = accounts.currentUser;
    if (user == null) {
      throw const FinanceException('Entre na sua conta para continuar.');
    }
    final transactions = rows[user.id] ?? [];
    final index = transactions.indexWhere(
      (row) => row.id == transactionId && row.userId == user.id,
    );
    if (index < 0) {
      throw const FinanceException('Lançamento não encontrado nesta conta.');
    }
    final original = transactions[index];
    final updated = FinanceTransaction(
      id: original.id,
      userId: original.userId,
      type: original.type,
      amountCents: original.amountCents,
      category: original.category,
      description: description.trim(),
      occurredOn: original.occurredOn,
      createdAt: original.createdAt,
    );
    transactions[index] = updated;
    _controller.add(null);
    return updated;
  }

  Future<void> close() => _controller.close();
}

// Aguarda avisos temporários que podem cobrir o botão após rolar o Perfil.
Future<void> _logout(WidgetTester tester) async {
  final notices = find.byType(SnackBar);
  while (notices.evaluate().isNotEmpty) {
    await tester.pump(tester.widget<SnackBar>(notices.first).duration);
    await tester.pumpAndSettle();
  }
  await _tap(tester, find.byKey(const ValueKey('sign-out')));
}
