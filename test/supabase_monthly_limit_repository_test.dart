import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/monthly_limit.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/supabase_monthly_limit_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

void main() {
  late _LimitServer server;
  late SupabaseClient client;
  late SupabaseMonthlyLimitRepository repository;
  final november = DateTime(2026, 11, 18, 23, 30);

  setUp(() async {
    server = await _LimitServer.start();
    client = SupabaseClient(
      server.url,
      'sb_publishable_local_test_only',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    repository = SupabaseMonthlyLimitRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  Future<void> authenticate([String userId = _ownerA]) {
    return client.auth.setInitialSession(jsonEncode(_localSession(userId)));
  }

  test('modelo normaliza mês e valida valores inteiros positivos', () {
    final limit = MonthlyLimit(
      userId: _ownerA,
      month: november,
      limitCents: 150000,
    );
    expect(limit.month, DateTime(2026, 11));
    expect(limit.monthKey, '2026-11-01');
    expect(MonthlyLimit.fromJson(limit.toJson()).limitCents, 150000);
    expect(
      () => MonthlyLimit(userId: _ownerA, month: november, limitCents: 0),
      throwsArgumentError,
    );
    for (final invalid in [
      _limitRow(month: '2026-13-01'),
      _limitRow(month: '2026-11-18'),
      {..._limitRow(), 'limit_cents': 1.5},
    ]) {
      expect(() => MonthlyLimit.fromJson(invalid), throwsFormatException);
    }
  });

  test('sem sessão não consulta nem salva limite', () async {
    await expectLater(
      repository.loadForMonth(november),
      throwsA(isA<FinanceException>()),
    );
    await expectLater(
      repository.saveForMonth(month: november, limitCents: 150000),
      throwsA(isA<FinanceException>()),
    );
    expect(server.requests, isEmpty);
  });

  test('consulta filtra proprietário e primeiro dia do mês', () async {
    await authenticate();
    server.readRows = [_limitRow()];
    final limit = await repository.loadForMonth(november);
    final request = server.requests.single;

    expect(limit?.userId, _ownerA);
    expect(limit?.month, DateTime(2026, 11));
    expect(limit?.limitCents, 150000);
    expect(request.method, 'GET');
    expect(request.query['user_id'], 'eq.$_ownerA');
    expect(request.query['month'], 'eq.2026-11-01');
    expect(request.query['select'], 'user_id,month,limit_cents');
    expect(request.authorization, startsWith('Bearer '));
  });

  test('ausência retorna null sem criar limite pré-definido', () async {
    await authenticate();
    expect(await repository.loadForMonth(november), isNull);
    expect(server.requests, hasLength(1));
    expect(server.requests.single.method, 'GET');
  });

  test('falha no banco nunca é interpretada como limite ausente', () async {
    await authenticate();
    server.readError = true;
    await expectLater(
      repository.loadForMonth(november),
      throwsA(isA<FinanceException>()),
    );
  });

  test('upsert envia dono da sessão e chave composta do mês', () async {
    await authenticate();
    final saved = await repository.saveForMonth(
      month: november,
      limitCents: 225050,
    );
    final request = server.requests.single;

    expect(saved.userId, _ownerA);
    expect(saved.limitCents, 225050);
    expect(saved.monthKey, '2026-11-01');
    expect(request.method, 'POST');
    expect(request.query['on_conflict'], 'user_id,month');
    expect(request.prefer, contains('resolution=merge-duplicates'));
    expect(request.body, {
      'user_id': _ownerA,
      'month': '2026-11-01',
      'limit_cents': 225050,
    });
  });

  test('zero, negativos e valores acima do limite não fazem POST', () async {
    await authenticate();
    for (final cents in [0, -1, 10000000000]) {
      await expectLater(
        repository.saveForMonth(month: november, limitCents: cents),
        throwsA(isA<FinanceException>()),
      );
    }
    expect(server.requests, isEmpty);
  });

  test(
    'descarta leitura pendente quando outra pessoa assume a sessão',
    () async {
      await authenticate();
      server.readRows = [_limitRow()];
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeRead = () async {
        started.complete();
        await release.future;
      };

      final pending = repository.loadForMonth(november);
      final expectation = expectLater(
        pending,
        throwsA(isA<FinanceException>()),
      );
      await started.future;
      await authenticate(_ownerB);
      release.complete();
      await expectation;
    },
  );

  test('rejeita leitura com proprietário, mês ou valor inválido', () async {
    await authenticate();
    for (final invalid in [
      _limitRow(userId: _ownerB),
      _limitRow(month: '2026-12-01'),
      _limitRow(limitCents: 0),
    ]) {
      server.readRows = [invalid];
      await expectLater(
        repository.loadForMonth(november),
        throwsA(isA<FinanceException>()),
      );
    }
  });

  test(
    'rejeita confirmação de gravação de outro usuário, mês ou valor',
    () async {
      await authenticate();
      for (final invalid in [
        _limitRow(userId: _ownerB),
        _limitRow(month: '2026-12-01'),
        _limitRow(limitCents: 999),
      ]) {
        server.writeRow = invalid;
        await expectLater(
          repository.saveForMonth(month: november, limitCents: 150000),
          throwsA(isA<FinanceException>()),
        );
      }
    },
  );

  test(
    'não confirma gravação após mudança de sessão durante o envio',
    () async {
      await authenticate();
      final started = Completer<void>();
      final release = Completer<void>();
      server.beforeWrite = () async {
        started.complete();
        await release.future;
      };

      final pending = repository.saveForMonth(
        month: november,
        limitCents: 150000,
      );
      final expectation = expectLater(
        pending,
        throwsA(isA<FinanceException>()),
      );
      await started.future;
      await authenticate(_ownerB);
      release.complete();
      await expectation;
    },
  );
}

Map<String, dynamic> _limitRow({
  String userId = _ownerA,
  String month = '2026-11-01',
  int limitCents = 150000,
}) => {'user_id': userId, 'month': month, 'limit_cents': limitCents};

class _LimitRequest {
  final String method;
  final Map<String, String> query;
  final String? authorization;
  final String? prefer;
  final Map<String, dynamic>? body;

  _LimitRequest(HttpRequest request, this.body)
    : method = request.method,
      query = request.uri.queryParameters,
      authorization = request.headers.value(HttpHeaders.authorizationHeader),
      prefer = request.headers.value('prefer');
}

// Apenas HTTP local: o SDK é real, mas nenhum projeto Supabase é acessado.
class _LimitServer {
  final HttpServer _server;
  final List<_LimitRequest> requests = [];
  List<Map<String, dynamic>> readRows = [];
  Map<String, dynamic>? writeRow;
  bool readError = false;
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeWrite;

  _LimitServer(this._server) {
    _server.listen(_handle);
  }

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_LimitServer> start() async =>
      _LimitServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    final body = text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
    requests.add(_LimitRequest(request, body));
    request.response.headers.contentType = ContentType.json;
    if (request.uri.path != '/rest/v1/monthly_limits') {
      request.response.statusCode = HttpStatus.notFound;
    } else if (request.method == 'GET') {
      await beforeRead?.call();
      if (readError) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(
          jsonEncode({
            'code': '42P01',
            'message': 'relation monthly_limits does not exist',
          }),
        );
      } else {
        request.response.write(jsonEncode(readRows));
      }
    } else if (request.method == 'POST') {
      await beforeWrite?.call();
      request.response.statusCode = HttpStatus.created;
      request.response.write(jsonEncode(writeRow ?? body));
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    }
    await request.response.close();
  }
}

Map<String, dynamic> _localSession(String userId) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode({
    'sub': userId,
    'role': 'authenticated',
    'exp': expiresAt,
  });
  final signature = base64Url
      .encode(List<int>.filled(32, 0))
      .replaceAll('=', '');
  return {
    'access_token': '$header.$payload.$signature',
    'token_type': 'bearer',
    'refresh_token': 'local-test-only',
    'expires_in': 3600,
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'user@example.com',
      'app_metadata': {'provider': 'email'},
      'user_metadata': {'name': 'Usuário Teste'},
      'created_at': '2026-11-18T12:00:00Z',
    },
  };
}
