import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/financial_profile.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/supabase_financial_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

void main() {
  late _ProfileServer server;
  late SupabaseClient client;
  late SupabaseFinancialProfileRepository repository;

  setUp(() async {
    server = await _ProfileServer.start();
    client = SupabaseClient(
      server.url,
      'sb_publishable_local_test_only',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    repository = SupabaseFinancialProfileRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  Future<void> authenticate([String userId = _ownerA]) =>
      client.auth.setInitialSession(jsonEncode(_localSession(userId)));

  test('sem sessão não carrega, seleciona ou renomeia perfis', () async {
    await expectLater(
      repository.loadProfiles(),
      throwsA(isA<FinanceException>()),
    );
    await expectLater(
      repository.selectProfile('business'),
      throwsA(isA<FinanceException>()),
    );
    await expectLater(
      repository.renameBusiness(profileId: 'business', name: 'Minha empresa'),
      throwsA(isA<FinanceException>()),
    );
    expect(server.requests, isEmpty);
  });

  test('RPC restaura os dois perfis próprios e a seleção persistida', () async {
    await authenticate();
    server.rpcResponse = _profileState(
      activeId: 'business',
      businessName: 'Loja Central',
    );
    final state = await repository.loadProfiles();
    final request = server.requests.single;

    expect(request.method, 'POST');
    expect(request.path, '/rest/v1/rpc/ensure_financial_profiles');
    expect(request.authorization, startsWith('Bearer '));
    expect(state.profiles, hasLength(2));
    expect(
      state.profiles.every((profile) => profile.userId == _ownerA),
      isTrue,
    );
    expect(state.activeProfileId, 'business');
    expect(state.activeProfile.kind, FinancialProfileKind.business);
    expect(state.activeProfile.name, 'Loja Central');
  });

  test('RPC rejeita outro dono, seleção ausente e perfis inválidos', () async {
    await authenticate();
    final profiles = _profiles();
    for (final invalid in [
      _profileState(userId: _ownerB),
      {..._profileState(), 'active_profile_id': 'missing-profile'},
      {
        ..._profileState(),
        'profiles': [profiles.first, profiles.first],
      },
      {
        ..._profileState(),
        'profiles': [
          {...profiles.first, 'kind': 'business'},
          profiles.last,
        ],
      },
      {
        ..._profileState(),
        'profiles': [
          profiles.first,
          {...profiles.last, 'kind': 'personal'},
        ],
      },
    ]) {
      server.rpcResponse = invalid;
      await expectLater(
        repository.loadProfiles(),
        throwsA(isA<FinanceException>()),
      );
    }
  });

  test('seleção grava apenas preferência do usuário da sessão', () async {
    await authenticate();
    await repository.selectProfile('business');
    final request = server.requests.single;

    expect(request.method, 'PATCH');
    expect(request.path, '/rest/v1/financial_profile_preferences');
    expect(request.query['user_id'], 'eq.$_ownerA');
    expect(request.body, {'active_profile_id': 'business'});
  });

  test('seleção rejeita confirmação de outro dono ou perfil', () async {
    await authenticate();
    for (final invalid in [
      {'user_id': _ownerB, 'active_profile_id': 'business'},
      {'user_id': _ownerA, 'active_profile_id': 'personal'},
    ]) {
      server.preferenceResponse = invalid;
      await expectLater(
        repository.selectProfile('business'),
        throwsA(isA<FinanceException>()),
      );
    }
  });

  test(
    'nome da empresa é o único campo no PATCH com filtros de dono e tipo',
    () async {
      await authenticate();
      final profile = await repository.renameBusiness(
        profileId: 'business',
        name: '  Loja Central  ',
      );
      final request = server.requests.single;

      expect(request.method, 'PATCH');
      expect(request.path, '/rest/v1/financial_profiles');
      expect(request.query['user_id'], 'eq.$_ownerA');
      expect(request.query['id'], 'eq.business');
      expect(request.query['kind'], 'eq.business');
      expect(request.body, {'name': 'Loja Central'});
      expect(profile.userId, _ownerA);
      expect(profile.id, 'business');
      expect(profile.kind, FinancialProfileKind.business);
      expect(profile.name, 'Loja Central');
    },
  );

  test('nomes vazios, acima de 60 e IDs vazios não chegam ao banco', () async {
    await authenticate();
    for (final invalid in [
      (id: 'business', name: '   '),
      (id: 'business', name: List.filled(61, 'a').join()),
      (id: '   ', name: 'Empresa'),
    ]) {
      await expectLater(
        repository.renameBusiness(profileId: invalid.id, name: invalid.name),
        throwsA(isA<FinanceException>()),
      );
    }
    await expectLater(
      repository.selectProfile('   '),
      throwsA(isA<FinanceException>()),
    );
    expect(server.requests, isEmpty);
  });

  test(
    'renomeação rejeita confirmação com dono, ID, tipo ou nome divergente',
    () async {
      await authenticate();
      final valid = _profiles(businessName: 'Loja Central').last;
      for (final invalid in [
        {...valid, 'user_id': _ownerB},
        {...valid, 'id': 'other-business'},
        {...valid, 'id': 'personal', 'kind': 'personal'},
        {...valid, 'name': 'Nome diferente'},
      ]) {
        server.renameResponse = invalid;
        await expectLater(
          repository.renameBusiness(
            profileId: 'business',
            name: 'Loja Central',
          ),
          throwsA(isA<FinanceException>()),
        );
      }
    },
  );

  for (final operation in ['load', 'select', 'rename']) {
    test(
      '$operation descarta resposta após mudança de usuário durante o await',
      () async {
        await authenticate();
        final started = Completer<void>();
        final release = Completer<void>();
        server.beforeResponse = () async {
          started.complete();
          await release.future;
        };

        final Future<dynamic> pending = switch (operation) {
          'load' => repository.loadProfiles(),
          'select' => repository.selectProfile('business'),
          _ => repository.renameBusiness(
            profileId: 'business',
            name: 'Empresa',
          ),
        };
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

  test(
    'falhas do servidor viram FinanceException sem vazar detalhes internos',
    () async {
      await authenticate();
      server.fail = true;
      for (final operation in <Future<dynamic> Function()>[
        repository.loadProfiles,
        () => repository.selectProfile('business'),
        () => repository.renameBusiness(profileId: 'business', name: 'Empresa'),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<FinanceException>().having(
              (error) => error.message.contains('private_internal_detail'),
              'não expõe o erro interno',
              isFalse,
            ),
          ),
        );
      }
    },
  );
}

List<Map<String, dynamic>> _profiles({
  String userId = _ownerA,
  String businessName = 'Empresa',
}) => [
  {'id': 'personal', 'user_id': userId, 'kind': 'personal', 'name': 'Pessoal'},
  {
    'id': 'business',
    'user_id': userId,
    'kind': 'business',
    'name': businessName,
  },
];

Map<String, dynamic> _profileState({
  String userId = _ownerA,
  String activeId = 'personal',
  String businessName = 'Empresa',
}) => {
  'profiles': _profiles(userId: userId, businessName: businessName),
  'active_profile_id': activeId,
};

class _ProfileRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final String? authorization;
  final Map<String, dynamic>? body;

  _ProfileRequest(HttpRequest request, this.body)
    : method = request.method,
      path = request.uri.path,
      query = request.uri.queryParameters,
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
}

// Servidor apenas local; as chamadas usam o cliente Supabase real.
class _ProfileServer {
  final HttpServer _server;
  final List<_ProfileRequest> requests = [];
  Object? rpcResponse;
  Map<String, dynamic>? preferenceResponse;
  Map<String, dynamic>? renameResponse;
  bool fail = false;
  Future<void> Function()? beforeResponse;

  _ProfileServer(this._server) {
    _server.listen(_handle);
  }

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_ProfileServer> start() async =>
      _ProfileServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    final decoded = text.isEmpty ? null : jsonDecode(text);
    final body = decoded is Map<String, dynamic> ? decoded : null;
    final recorded = _ProfileRequest(request, body);
    requests.add(recorded);
    request.response.headers.contentType = ContentType.json;
    await beforeResponse?.call();

    if (fail) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(
        jsonEncode({'code': '42P01', 'message': 'private_internal_detail'}),
      );
    } else if (recorded.path == '/rest/v1/rpc/ensure_financial_profiles') {
      request.response.write(jsonEncode(rpcResponse ?? _profileState()));
    } else if (recorded.path == '/rest/v1/financial_profile_preferences') {
      request.response.write(
        jsonEncode(
          preferenceResponse ??
              {
                'user_id': recorded.query['user_id']?.replaceFirst('eq.', ''),
                'active_profile_id': body?['active_profile_id'],
              },
        ),
      );
    } else if (recorded.path == '/rest/v1/financial_profiles') {
      final response =
          renameResponse ??
          {
            'id': recorded.query['id']?.replaceFirst('eq.', ''),
            'user_id': recorded.query['user_id']?.replaceFirst('eq.', ''),
            'kind': 'business',
            'name': body?['name'],
          };
      request.response.write(jsonEncode(response));
    } else {
      request.response.statusCode = HttpStatus.notFound;
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
