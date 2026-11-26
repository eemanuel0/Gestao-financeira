import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/services/account_service.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/supabase_account_service.dart';
import 'package:gestao_financeira/models/services/supabase_finance_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userA = '11111111-1111-4111-8111-111111111111';
const _userB = '22222222-2222-4222-8222-222222222222';

void main() {
  late _LocalSupabase server;
  late SupabaseClient client;
  late SupabaseAccountService accounts;
  late SupabaseFinanceRepository finances;

  setUp(() async {
    server = await _LocalSupabase.start();
    client = SupabaseClient(
      server.url,
      'sb_publishable_local_test_only',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    accounts = SupabaseAccountService(client);
    finances = SupabaseFinanceRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  Future<void> signIn() => accounts.signIn(
    email: ' Emanuel@Example.com ',
    password: 'senha-local-123',
  );

  test(
    'login normaliza e-mail, preserva senha e publica usuário da sessão',
    () async {
      final event = accounts.userChanges.firstWhere((user) => user != null);
      await signIn();
      final user = await event;
      final request = server.requests.single;

      expect(request.path, '/auth/v1/token');
      expect(request.query['grant_type'], 'password');
      expect(request.body!['email'], 'emanuel@example.com');
      expect(request.body!['password'], 'senha-local-123');
      expect(accounts.currentUser?.id, _userA);
      expect(user?.name, 'Emanuel Teste');
    },
  );

  test(
    'cadastro envia nome e aguarda confirmação quando não há sessão',
    () async {
      final needsConfirmation = await accounts.signUp(
        name: '  Maria Silva  ',
        email: ' MARIA@Example.com ',
        password: 'senha-local-123',
      );
      final request = server.requests.single;

      expect(needsConfirmation, isTrue);
      expect(accounts.currentUser, isNull);
      expect(request.path, '/auth/v1/signup');
      expect(request.body!['email'], 'maria@example.com');
      expect(request.body!['data'], {'name': 'Maria Silva'});
    },
  );

  test(
    'erros de autenticação retornam mensagem amigável sem expor servidor',
    () async {
      server.authError = 'invalid_credentials';
      await expectLater(
        signIn(),
        throwsA(
          isA<AccountException>().having(
            (error) => error.message,
            'message',
            'E-mail ou senha incorretos.',
          ),
        ),
      );
      expect(accounts.currentUser, isNull);
    },
  );

  test('identifica quando o Supabase rejeita a chave pública', () async {
    server.authError = 'invalid_api_key';
    await expectLater(
      signIn(),
      throwsA(
        isA<AccountException>().having(
          (error) => error.message,
          'message',
          'A chave pública do Supabase foi recusada. Confira a Project URL e a Publishable key em config/supabase.json.',
        ),
      ),
    );
  });

  test('sem sessão não consulta nem grava lançamentos', () async {
    await expectLater(
      finances.loadTransactions(),
      throwsA(isA<FinanceException>()),
    );
    await expectLater(
      finances.addTransaction(
        type: TransactionType.income,
        amountCents: 100,
        category: TransactionCategory.salary,
        description: 'Salário',
        occurredOn: DateTime(2026, 11, 17),
      ),
      throwsA(isA<FinanceException>()),
    );
    await expectLater(
      finances.updateTransactionDescription(
        transactionId: 'row-1',
        description: 'Novo nome',
      ),
      throwsA(isA<FinanceException>()),
    );
    expect(server.requests, isEmpty);
  });

  test('consulta filtra usuário e pagina além de mil registros', () async {
    await signIn();
    server.rows = List.generate(1001, (index) => _transaction('row-$index'));

    final transactions = await finances.loadTransactions();
    final queries = server.requests
        .where((request) => request.isTransactionRead)
        .toList();

    expect(transactions, hasLength(1001));
    expect(transactions.last.id, 'row-1000');
    expect(queries, hasLength(3));
    expect(queries.map((request) => request.query['offset']), [
      '0',
      '500',
      '1000',
    ]);
    for (final query in queries) {
      expect(query.query['user_id'], 'eq.$_userA');
      expect(query.query['profile_id'], 'eq.personal');
      expect(query.query['limit'], '500');
      final order = query.query['order']!.split(',');
      expect(order, hasLength(3));
      expect(order[0], startsWith('occurred_on.desc'));
      expect(order[1], startsWith('created_at.desc'));
      expect(order[2], startsWith('id.'));
      expect(query.authorization, startsWith('Bearer '));
    }
  });

  test(
    'rejeita resposta que contenha lançamento de outro proprietário',
    () async {
      await signIn();
      server.rows = [_transaction('other-user-row', userId: _userB)];
      await expectLater(
        finances.loadTransactions(),
        throwsA(isA<FinanceException>()),
      );
    },
  );

  test('grava usuário da sessão, centavos inteiros e data civil', () async {
    await signIn();
    await finances.addTransaction(
      type: TransactionType.expense,
      amountCents: 123456,
      category: TransactionCategory.food,
      description: '  Compra do mês  ',
      occurredOn: DateTime(2026, 11, 17, 23, 40),
    );
    final request = server.requests.singleWhere(
      (request) => request.isTransactionInsert,
    );

    expect(request.body, {
      'user_id': _userA,
      'profile_id': 'personal',
      'type': 'expense',
      'amount_cents': 123456,
      'category': 'food',
      'description': 'Compra do mês',
      'occurred_on': '2026-11-17',
    });
  });

  test('valores e categorias inválidos não geram POST no banco', () async {
    await signIn();
    final invalid = [
      (amount: 0, category: TransactionCategory.food, description: 'Teste'),
      (amount: -1, category: TransactionCategory.food, description: 'Teste'),
      (
        amount: 10000000000,
        category: TransactionCategory.food,
        description: 'Teste',
      ),
      (amount: 100, category: TransactionCategory.salary, description: 'Teste'),
      (amount: 100, category: TransactionCategory.food, description: '   '),
    ];
    for (final entry in invalid) {
      await expectLater(
        finances.addTransaction(
          type: TransactionType.expense,
          amountCents: entry.amount,
          category: entry.category,
          description: entry.description,
          occurredOn: DateTime(2026, 11, 17),
        ),
        throwsA(isA<FinanceException>()),
      );
    }
    expect(
      server.requests.where((request) => request.isTransactionInsert),
      isEmpty,
    );
  });

  test('descarta consulta pendente quando a sessão termina', () async {
    await signIn();
    server.rows = [_transaction('pending-row')];
    final queryStarted = Completer<void>();
    final releaseQuery = Completer<void>();
    server.beforeReadResponse = () async {
      queryStarted.complete();
      await releaseQuery.future;
    };

    final pending = finances.loadTransactions();
    final expectation = expectLater(pending, throwsA(isA<FinanceException>()));
    await queryStarted.future;
    await accounts.signOut();
    expect(accounts.currentUser, isNull);
    releaseQuery.complete();
    await expectation;
  });

  test(
    'edição envia somente nome e filtra lançamento e proprietário',
    () async {
      await signIn();
      server.rows = [_transaction('row-1')];
      final original = FinanceTransaction.fromJson(server.rows.single);

      final updated = await finances.updateTransactionDescription(
        transactionId: 'row-1',
        description: '  Mercado da semana  ',
      );
      final request = server.requests.singleWhere(
        (request) => request.isTransactionUpdate,
      );

      expect(request.method, 'PATCH');
      expect(request.body, {'description': 'Mercado da semana'});
      expect(request.query['id'], 'eq.row-1');
      expect(request.query['user_id'], 'eq.$_userA');
      expect(request.query['profile_id'], 'eq.personal');
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.description, 'Mercado da semana');
      expect(updated.amountCents, original.amountCents);
      expect(updated.type, original.type);
      expect(updated.category, original.category);
      expect(updated.occurredOn, original.occurredOn);
      expect(updated.createdAt, original.createdAt);
    },
  );

  test('edição inválida não gera PATCH no banco', () async {
    await signIn();
    for (final invalid in [
      (id: '   ', name: 'Mercado'),
      (id: 'row-1', name: '   '),
      (id: 'row-1', name: List.filled(121, 'a').join()),
    ]) {
      await expectLater(
        finances.updateTransactionDescription(
          transactionId: invalid.id,
          description: invalid.name,
        ),
        throwsA(isA<FinanceException>()),
      );
    }
    expect(
      server.requests.where((request) => request.isTransactionUpdate),
      isEmpty,
    );
  });

  test('edição rejeita resposta com outro dono, ID ou nome', () async {
    await signIn();
    for (final invalid in [
      {..._transaction('row-1', userId: _userB), 'description': 'Novo nome'},
      {..._transaction('other-row'), 'description': 'Novo nome'},
      {..._transaction('row-1'), 'description': 'Nome diferente'},
    ]) {
      server.updateResponse = invalid;
      await expectLater(
        finances.updateTransactionDescription(
          transactionId: 'row-1',
          description: 'Novo nome',
        ),
        throwsA(isA<FinanceException>()),
      );
    }
  });

  test('edição ausente ou com falha no banco retorna erro amigável', () async {
    await signIn();
    for (final status in [406, 500]) {
      server.updateErrorStatus = status;
      await expectLater(
        finances.updateTransactionDescription(
          transactionId: 'missing-row',
          description: 'Novo nome',
        ),
        throwsA(
          isA<FinanceException>().having(
            (error) => error.message,
            'message',
            'Não foi possível editar o lançamento. Tente novamente.',
          ),
        ),
      );
    }
  });

  test('não confirma edição se a sessão terminar durante o PATCH', () async {
    await signIn();
    server.rows = [_transaction('row-1')];
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeUpdateResponse = () async {
      started.complete();
      await release.future;
    };

    final pending = finances.updateTransactionDescription(
      transactionId: 'row-1',
      description: 'Novo nome',
    );
    final expectation = expectLater(pending, throwsA(isA<FinanceException>()));
    await started.future;
    await accounts.signOut();
    release.complete();
    await expectation;
  });
  test('consulta empresa isolada e rejeita resposta de outro perfil', () async {
    await signIn();
    final business = SupabaseFinanceRepository(client, profileId: 'business');
    server.rows = [_transaction('business-row', profileId: 'business')];
    await expectLater(
      finances.loadTransactions(),
      throwsA(isA<FinanceException>()),
    );
    final loaded = await business.loadTransactions();
    expect(loaded.single.profileId, 'business');
    expect(server.requests.last.query['profile_id'], 'eq.business');
    server.rows = [_transaction('personal-row')];
    await expectLater(
      business.loadTransactions(),
      throwsA(isA<FinanceException>()),
    );
    server.rows = [_transaction('legacy-row')..remove('profile_id')];
    await expectLater(
      business.loadTransactions(),
      throwsA(isA<FinanceException>()),
    );
  });

  test('receita empresarial envia perfil fixo no payload', () async {
    await signIn();
    final business = SupabaseFinanceRepository(client, profileId: 'business');
    await business.addTransaction(
      type: TransactionType.income,
      amountCents: 12500,
      category: TransactionCategory.services,
      description: 'Serviço prestado',
      occurredOn: DateTime(2026, 11, 18),
    );
    final request = server.requests.singleWhere(
      (request) => request.isTransactionInsert,
    );
    expect(request.body!['profile_id'], 'business');
    expect(request.body!['user_id'], _userA);
    expect(request.body!['amount_cents'], 12500);
  });

  test('editar nome também fica restrito ao perfil do repositório', () async {
    await signIn();
    final business = SupabaseFinanceRepository(client, profileId: 'business');
    server.rows = [_transaction('business-row', profileId: 'business')];
    await expectLater(
      finances.updateTransactionDescription(
        transactionId: 'business-row',
        description: 'Novo nome',
      ),
      throwsA(isA<FinanceException>()),
    );
    final updated = await business.updateTransactionDescription(
      transactionId: 'business-row',
      description: 'Novo nome',
    );
    expect(updated.profileId, 'business');
    expect(server.requests.last.query['profile_id'], 'eq.business');
    server.updateResponse = {
      ..._transaction('business-row'),
      'description': 'Outro nome',
    };
    await expectLater(
      business.updateTransactionDescription(
        transactionId: 'business-row',
        description: 'Outro nome',
      ),
      throwsA(isA<FinanceException>()),
    );
  });
}

Map<String, dynamic> _transaction(
  String id, {
  String userId = _userA,
  String profileId = 'personal',
}) => {
  'id': id,
  'user_id': userId,
  'profile_id': profileId,
  'type': 'expense',
  'amount_cents': 100,
  'category': 'food',
  'description': 'Mercado',
  'occurred_on': '2026-11-17',
  'created_at': '2026-11-17T12:00:00Z',
};

class _RecordedRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final String? authorization;
  final Map<String, dynamic>? body;

  _RecordedRequest(HttpRequest request, this.body)
    : method = request.method,
      path = request.uri.path,
      query = request.uri.queryParameters,
      authorization = request.headers.value(HttpHeaders.authorizationHeader);

  bool get isTransactionRead =>
      method == 'GET' && path == '/rest/v1/transactions';
  bool get isTransactionInsert =>
      method == 'POST' && path == '/rest/v1/transactions';
  bool get isTransactionUpdate =>
      method == 'PATCH' && path == '/rest/v1/transactions';
}

// O SDK real fala HTTP com este servidor de teste, sem acessar a internet.
class _LocalSupabase {
  final HttpServer _server;
  final List<_RecordedRequest> requests = [];
  List<Map<String, dynamic>> rows = [];
  String? authError;
  Future<void> Function()? beforeReadResponse;
  Future<void> Function()? beforeUpdateResponse;
  Map<String, dynamic>? updateResponse;
  int? updateErrorStatus;

  _LocalSupabase(this._server) {
    _server.listen(_handle);
  }

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_LocalSupabase> start() async {
    return _LocalSupabase(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    final body = text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
    final recorded = _RecordedRequest(request, body);
    requests.add(recorded);
    request.response.headers.contentType = ContentType.json;

    if (recorded.path == '/auth/v1/token') {
      if (authError != null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(
          jsonEncode({
            'code': authError,
            'error_code': authError,
            'message': 'Internal server detail that must not reach the user',
          }),
        );
      } else {
        request.response.write(jsonEncode(_session()));
      }
    } else if (recorded.path == '/auth/v1/signup') {
      request.response.write(jsonEncode(_user()));
    } else if (recorded.path == '/auth/v1/logout') {
      request.response.statusCode = HttpStatus.noContent;
    } else if (recorded.isTransactionRead) {
      await beforeReadResponse?.call();
      final offset = int.parse(recorded.query['offset'] ?? '0');
      final limit = int.parse(recorded.query['limit'] ?? '500');
      request.response.write(
        jsonEncode(rows.skip(offset).take(limit).toList()),
      );
    } else if (recorded.isTransactionInsert) {
      request.response.statusCode = HttpStatus.created;
    } else if (recorded.isTransactionUpdate) {
      await beforeUpdateResponse?.call();
      final matches = rows.where(
        (row) =>
            recorded.query['id'] == 'eq.${row['id']}' &&
            recorded.query['user_id'] == 'eq.${row['user_id']}' &&
            recorded.query['profile_id'] == 'eq.${row['profile_id']}',
      );
      if (updateErrorStatus != null ||
          (updateResponse == null && matches.isEmpty)) {
        request.response.statusCode = updateErrorStatus ?? 406;
        request.response.write(
          jsonEncode({
            'code': 'PGRST116',
            'message': 'Internal database detail that must not reach the user',
          }),
        );
      } else {
        request.response.write(
          jsonEncode(updateResponse ?? {...matches.first, ...body!}),
        );
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(
        jsonEncode({'message': 'Unexpected test request'}),
      );
    }
    await request.response.close();
  }

  Map<String, dynamic> _user() => {
    'id': _userA,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'emanuel@example.com',
    'app_metadata': {'provider': 'email'},
    'user_metadata': {'name': 'Emanuel Teste'},
    'created_at': '2026-11-17T12:00:00Z',
  };

  Map<String, dynamic> _session() {
    String encode(Map<String, dynamic> object) =>
        base64Url.encode(utf8.encode(jsonEncode(object))).replaceAll('=', '');
    final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final header = encode({'alg': 'HS256', 'typ': 'JWT'});
    final payload = encode({
      'sub': _userA,
      'role': 'authenticated',
      'exp': expiresAt,
    });
    final signature = base64Url
        .encode(List<int>.filled(32, 0))
        .replaceAll('=', '');
    return {
      'access_token': '$header.$payload.$signature',
      'token_type': 'bearer',
      'refresh_token': 'local-test-refresh-token',
      'expires_in': 3600,
      'user': _user(),
    };
  }
}
