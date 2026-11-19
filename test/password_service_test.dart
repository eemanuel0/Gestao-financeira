import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestao_financeira/models/services/account_service.dart';
import 'package:gestao_financeira/models/services/supabase_password_service.dart';

void main() {
  late HttpServer server;
  late SupabaseClient mainClient;
  late SupabasePasswordService service;
  final requests =
      <
        ({String path, String method, String auth, Map<String, dynamic> body})
      >[];
  bool rejectUpdate = false;
  SupabaseClient createClient() => SupabaseClient(
    'http://127.0.0.1:${server.port}',
    'sb_publishable_local',
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  setUp(() async {
    requests.clear();
    rejectUpdate = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final path = request.uri.path;
      final auth = request.headers.value('authorization') ?? '';
      requests.add((
        path: path,
        method: request.method,
        auth: auth,
        body: body,
      ));
      Object response = <String, dynamic>{};
      if (path.endsWith('/token')) {
        if (body['password'] == 'wrong-password') {
          request.response.statusCode = 400;
          response = {
            'error_code': 'invalid_credentials',
            'msg': 'Private server message',
          };
        } else {
          response = _session(
            body['email'] == 'ana@example.com' ? 'ana' : 'bia',
          );
        }
      } else if (path.endsWith('/verify')) {
        if (body['token'] != '12345678') {
          request.response.statusCode = 403;
          response = {'error_code': 'otp_expired', 'msg': 'Token expired'};
        } else {
          response = _session('bia');
        }
      } else if (path.endsWith('/user') && request.method == 'PUT') {
        if (rejectUpdate) {
          request.response.statusCode = 422;
          response = {
            'error_code': 'weak_password',
            'msg': 'Private password policy',
          };
        } else {
          response = _user(auth.contains(_token('bia')) ? 'bia' : 'ana');
        }
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    mainClient = createClient();
    service = SupabasePasswordService(
      mainClient,
      url: 'http://127.0.0.1:${server.port}',
      publishableKey: 'sb_publishable_local',
    );
  });
  tearDown(() async {
    service.dispose();
    await mainClient.dispose();
    await server.close(force: true);
  });

  test(
    'enviar código normaliza e-mail e mantém aplicativo deslogado',
    () async {
      await service.sendRecoveryCode(' BIA@Example.com ');
      expect(
        requests.singleWhere((r) => r.path.endsWith('/recover')).body['email'],
        'bia@example.com',
      );
      expect(mainClient.auth.currentSession, isNull);
    },
  );
  test(
    'reset usa sessão isolada e nunca abre a conta recuperada na principal',
    () async {
      await mainClient.auth.signInWithPassword(
        email: 'ana@example.com',
        password: 'old-password',
      );
      final token = mainClient.auth.currentSession!.accessToken;
      final flags = <bool>[];
      service.addListener(() => flags.add(service.recoveryInProgress));
      await service.resetPassword(
        email: ' BIA@Example.com ',
        code: '12345678',
        newPassword: ' nova senha  ',
      );
      final verification = requests.singleWhere(
        (r) => r.path.endsWith('/verify'),
      );
      final update = requests.singleWhere((r) => r.path.endsWith('/user'));
      expect(verification.body['type'], 'recovery');
      expect(verification.body['email'], 'bia@example.com');
      expect(update.body['password'], ' nova senha  ');
      expect(update.auth, 'Bearer ${_token('bia')}');
      expect(mainClient.auth.currentSession!.accessToken, token);
      expect(mainClient.auth.currentUser!.id, 'ana');
      expect(flags, [true, false]);
    },
  );
  test('código expirado não envia senha e permite nova tentativa', () async {
    await expectLater(
      service.resetPassword(
        email: 'bia@example.com',
        code: '00000000',
        newPassword: 'nova-senha',
      ),
      throwsA(isA<AccountException>()),
    );
    expect(requests.where((r) => r.path.endsWith('/user')), isEmpty);
    expect(service.recoveryInProgress, isFalse);
    expect(mainClient.auth.currentUser, isNull);
  });
  test(
    'senha atual errada impede alteração sem substituir sessão principal',
    () async {
      await mainClient.auth.signInWithPassword(
        email: 'ana@example.com',
        password: 'old-password',
      );
      requests.clear();
      await expectLater(
        service.changePassword(
          currentPassword: 'wrong-password',
          newPassword: 'nova-senha',
        ),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            'A senha atual está incorreta.',
          ),
        ),
      );
      expect(requests.where((r) => r.path.endsWith('/user')), isEmpty);
      expect(mainClient.auth.currentUser!.id, 'ana');
    },
  );
  test('alterar senha envia valor exato e mantém dono da sessão', () async {
    await mainClient.auth.signInWithPassword(
      email: 'ana@example.com',
      password: 'old-password',
    );
    await service.changePassword(
      currentPassword: 'old-password',
      newPassword: ' nova senha  ',
    );
    final update = requests.singleWhere((r) => r.path.endsWith('/user'));
    expect(update.body['password'], ' nova senha  ');
    expect(update.body['current_password'], 'old-password');
    expect(mainClient.auth.currentUser!.id, 'ana');
  });
  test(
    'falha ao gravar senha encerra cliente temporário e preserva sessão',
    () async {
      rejectUpdate = true;
      await expectLater(
        service.resetPassword(
          email: 'bia@example.com',
          code: '12345678',
          newPassword: 'nova-senha',
        ),
        throwsA(isA<AccountException>()),
      );
      expect(service.recoveryInProgress, isFalse);
      expect(mainClient.auth.currentSession, isNull);
      expect(requests.where((r) => r.path.endsWith('/logout')), hasLength(1));
    },
  );
}

Map<String, dynamic> _user(String name) => {
  'id': name,
  'email': '$name@example.com',
  'aud': 'authenticated',
  'role': 'authenticated',
  'user_metadata': {'name': name},
  'app_metadata': {'provider': 'email'},
  'created_at': '2026-01-01T00:00:00Z',
};
String _token(String name) =>
    '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': name, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.test';
Map<String, dynamic> _session(String name) => {
  'access_token': _token(name),
  'refresh_token': 'refresh-$name',
  'expires_in': 3600,
  'token_type': 'bearer',
  'user': _user(name),
};
