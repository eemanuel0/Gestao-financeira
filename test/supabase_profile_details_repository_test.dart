import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/business_profile_data.dart';
import 'package:gestao_financeira/models/financial_profile.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/supabase_profile_details_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _uid = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _bucket = 'profile-photos';

final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNQrHADAAGdAOCJFnJrAAAAAElFTkSuQmCC',
  ),
);

final _webp = Uint8List.fromList(
  base64Decode(
    'UklGRjYAAABXRUJQVlA4ICoAAABwAQCdASoBAAEAAUAmJaACdAFAAAD+8GyvLM4V7L/+YJ/7/f9/u4oAAAA=',
  ),
);

final _jpeg = Uint8List.fromList(
  base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAABP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AO//Z',
  ),
);

void main() {
  late _Server server;
  late SupabaseClient client;
  late SupabaseProfileDetailsRepository repository;

  setUp(() async {
    server = await _Server.start();
    client = SupabaseClient(
      server.url,
      'sb_publishable_local_only',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      storageOptions: const StorageClientOptions(retryAttempts: 0),
    );
    repository = SupabaseProfileDetailsRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close();
  });
  Future<void> login() async {
    await client.auth.signInWithPassword(
      email: 'ana@example.com',
      password: 'senha-local',
    );
    server.requests.clear();
  }

  Future<FinancialProfile> upload([String profileId = 'business']) => repository
      .uploadPhoto(profileId: profileId, bytes: _png, contentType: 'image/png');

  test('sem sessão não atualiza dados nem envia ou remove foto', () async {
    final failures = [
      repository.updatePersonalName('Ana'),
      repository.updateBusiness(
        profileId: 'business',
        data: BusinessProfileData(name: 'Loja'),
      ),
      upload(),
      repository.removePhoto('personal'),
    ];
    await Future.wait(
      failures.map(
        (future) => expectLater(future, throwsA(isA<FinanceException>())),
      ),
    );
    expect(server.requests, isEmpty);
  });

  test(
    'nome pessoal usa somente metadata e confirma usuário autenticado',
    () async {
      await login();
      final updated = await repository.updatePersonalName('  Ana Silva  ');
      final request = server.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/auth/v1/user');
      expect(request.json, {
        'data': {'name': 'Ana Silva'},
      });
      expect(request.authorization, startsWith('Bearer '));
      expect(updated.id, _uid);
      expect(updated.email, 'ana@example.com');
      expect(updated.name, 'Ana Silva');
      expect(client.auth.currentUser!.userMetadata!['name'], 'Ana Silva');
      for (final name in [' ', 'a' * 61]) {
        await expectLater(
          repository.updatePersonalName(name),
          throwsA(isA<FinanceException>()),
        );
      }
      expect(server.requests, hasLength(1));
    },
  );

  test(
    'empresa atualiza apenas cinco campos e filtra dono, perfil e tipo',
    () async {
      await login();
      final data = BusinessProfileData(
        name: ' Minha Loja ',
        legalName: ' Minha Loja Ltda ',
        cnpj: '00.000.000/e08g-12',
        contactEmail: 'contato@example.com',
        contactPhone: '(71) 99999-9999',
      );
      final updated = await repository.updateBusiness(
        profileId: 'business',
        data: data,
      );
      final request = server.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/rest/v1/financial_profiles');
      expect(request.query['user_id'], 'eq.$_uid');
      expect(request.query['id'], 'eq.business');
      expect(request.query['kind'], 'eq.business');
      expect(request.json, data.toJson());
      expect(updated.name, 'Minha Loja');
      expect(updated.cnpj, '00000000E08G12');
      expect(updated.avatarPath, isNull);
      await expectLater(
        repository.updateBusiness(profileId: 'personal', data: data),
        throwsA(isA<FinanceException>()),
      );
      expect(server.requests, hasLength(1));
    },
  );

  test(
    'dados empresariais rejeitam resposta de outro dono, perfil ou conteúdo',
    () async {
      await login();
      for (final invalid in [
        {..._profile(), 'user_id': _other, 'name': 'Loja'},
        {..._profile(), 'id': 'other-business', 'name': 'Loja'},
        {..._profile(), 'name': 'Nome divergente'},
        {..._profile(), 'name': 'Loja', 'legal_name': 'Não solicitado'},
      ]) {
        server.patchResponse = invalid;
        await expectLater(
          repository.updateBusiness(
            profileId: 'business',
            data: BusinessProfileData(name: 'Loja'),
          ),
          throwsA(isA<FinanceException>()),
        );
      }
      expect(server.requests.where((request) => request.isStorage), isEmpty);
    },
  );

  test(
    'upload privado usa caminho único do perfil e salva somente avatar_path',
    () async {
      await login();
      final first = await upload();
      final second = await upload();
      await server.waitFor((request) => request.isDelete);
      expect(first.avatarPath, isNot(second.avatarPath));
      for (final profile in [first, second]) {
        expect(
          profile.avatarPath,
          matches(RegExp('^$_uid/business/[a-f0-9]{32}\\.png\$')),
        );
        expect(
          profile.avatarUrl,
          startsWith('${server.url}/storage/v1/object/sign/$_bucket/'),
        );
        expect(profile.avatarUrl, contains('?token=local-test'));
        expect(profile.toJson().containsKey('avatar_url'), isFalse);
      }
      final uploads = server.requests
          .where((request) => request.isUpload)
          .toList();
      expect(uploads, hasLength(2));
      for (final request in uploads) {
        expect(request.headers['x-upsert'], 'false');
        expect(
          latin1.decode(request.raw).toLowerCase(),
          contains('content-type: image/png'),
        );
        expect(_containsBytes(request.raw, _png), isTrue);
        expect(request.authorization, startsWith('Bearer '));
      }
      final patches = server.requests
          .where((request) => request.isProfilePatch)
          .toList();
      expect(patches, hasLength(2));
      expect(patches.last.json, {'avatar_path': second.avatarPath});
      expect(patches.last.query['id'], 'eq.business');
      expect(patches.last.query['user_id'], 'eq.$_uid');
      final signs = server.requests.where((request) => request.isSign).toList();
      expect(
        signs.every((request) => request.json?['expiresIn'] == 3600),
        isTrue,
      );
      expect(server.requests.lastWhere((request) => request.isDelete).json, {
        'prefixes': [first.avatarPath],
      });
      expect(server.profiles['business']!['avatar_path'], second.avatarPath);
      expect(server.profiles['personal']!['avatar_path'], isNull);
    },
  );

  test(
    'imagem vazia, acima de 5MB, assinatura ou MIME inválidos não fazem HTTP',
    () async {
      await login();
      for (final invalid in [
        (bytes: Uint8List(0), type: 'image/png'),
        (bytes: Uint8List(5 * 1024 * 1024 + 1), type: 'image/png'),
        (bytes: Uint8List.fromList(utf8.encode('<svg/>')), type: 'image/png'),
        (bytes: _png, type: 'image/jpeg'),
        (
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
          type: 'image/jpeg',
        ),
      ]) {
        await expectLater(
          repository.uploadPhoto(
            profileId: 'personal',
            bytes: invalid.bytes,
            contentType: invalid.type,
          ),
          throwsA(isA<FinanceException>()),
        );
      }
      expect(server.requests, isEmpty);
    },
  );

  test(
    'JPEG e WebP decodificáveis usam extensão e MIME correspondentes',
    () async {
      await login();
      for (final image in [
        (bytes: _jpeg, type: 'image/jpeg', extension: 'jpg'),
        (bytes: _webp, type: 'image/webp', extension: 'webp'),
      ]) {
        final saved = await repository.uploadPhoto(
          profileId: 'personal',
          bytes: image.bytes,
          contentType: image.type,
        );
        expect(saved.avatarPath, startsWith('$_uid/personal/'));
        expect(saved.avatarPath, endsWith('.${image.extension}'));
        final request = server.requests.lastWhere(
          (request) => request.isUpload,
        );
        expect(
          latin1.decode(request.raw).toLowerCase(),
          contains('content-type: ${image.type}'),
        );
        expect(_containsBytes(request.raw, image.bytes), isTrue);
      }
    },
  );

  test(
    'falha ao assinar limpa nova imagem e mantém metadados e foto anterior',
    () async {
      await login();
      const oldPath = '$_uid/business/old.png';
      server.profiles['business']!['avatar_path'] = oldPath;
      server.signFailure = true;
      await expectLater(upload(), throwsA(isA<FinanceException>()));
      final uploaded = server.requests.singleWhere(
        (request) => request.isUpload,
      );
      final candidate = uploaded.path.substring(
        '/storage/v1/object/$_bucket/'.length,
      );
      expect(server.requests.singleWhere((request) => request.isDelete).json, {
        'prefixes': [candidate],
      });
      expect(candidate, isNot(oldPath));
      expect(
        server.requests.where((request) => request.isProfilePatch),
        isEmpty,
      );
      expect(server.profiles['business']!['avatar_path'], oldPath);
    },
  );

  test(
    'rejeição definitiva no banco limpa candidata e preserva foto antiga',
    () async {
      await login();
      const oldPath = '$_uid/business/old.png';
      server.profiles['business']!['avatar_path'] = oldPath;
      server.rejectPatch = true;
      await expectLater(upload(), throwsA(isA<FinanceException>()));
      final candidate = server.requests
          .singleWhere((request) => request.isUpload)
          .path
          .substring('/storage/v1/object/$_bucket/'.length);
      expect(server.requests.singleWhere((request) => request.isDelete).json, {
        'prefixes': [candidate],
      });
      expect(server.profiles['business']!['avatar_path'], oldPath);
    },
  );

  test(
    'resposta perdida após gravação é reconciliada sem apagar foto confirmada',
    () async {
      await login();
      const oldPath = '$_uid/business/old.png';
      server.profiles['business']!['avatar_path'] = oldPath;
      server.ambiguousPatchFailure = true;
      final saved = await upload();
      await server.waitFor((request) => request.isDelete);
      expect(saved.avatarPath, server.profiles['business']!['avatar_path']);
      expect(saved.avatarPath, isNot(oldPath));
      expect(server.requests.singleWhere((request) => request.isDelete).json, {
        'prefixes': [oldPath],
      });
      expect(
        server.requests.where((request) => request.isProfileRead),
        hasLength(2),
      );
    },
  );

  test(
    'falha de limpeza posterior não transforma foto salva em erro',
    () async {
      await login();
      const oldPath = '$_uid/business/old.png';
      server.profiles['business']!['avatar_path'] = oldPath;
      server.deleteFailure = true;
      final saved = await upload();
      await server.waitFor((request) => request.isDelete);
      expect(saved.avatarPath, server.profiles['business']!['avatar_path']);
      expect(saved.avatarUrl, isNotNull);
    },
  );

  test(
    'remover limpa metadados antes de apagar só a imagem do mesmo perfil',
    () async {
      await login();
      const oldPath = '$_uid/personal/old.png';
      server.profiles['personal']!['avatar_path'] = oldPath;
      final removed = await repository.removePhoto('personal');
      await server.waitFor((request) => request.isDelete);
      expect(removed.avatarPath, isNull);
      expect(removed.avatarUrl, isNull);
      final patchIndex = server.requests.indexWhere(
        (request) => request.isProfilePatch,
      );
      final deleteIndex = server.requests.indexWhere(
        (request) => request.isDelete,
      );
      expect(deleteIndex, greaterThan(patchIndex));
      expect(server.requests[patchIndex].json, {'avatar_path': null});
      expect(server.requests[deleteIndex].json, {
        'prefixes': [oldPath],
      });
      server.profiles['business']!['avatar_path'] =
          '$_other/business/foreign.png';
      server.requests.clear();
      await repository.removePhoto('business');
      expect(server.requests.where((request) => request.isDelete), isEmpty);
    },
  );

  test(
    'leitura de outro dono ou perfil interrompe antes do envio de imagem',
    () async {
      await login();
      for (final row in [
        {..._profile(), 'user_id': _other},
        {..._profile(), 'id': 'personal', 'kind': 'personal'},
      ]) {
        server.readResponse = row;
        await expectLater(upload(), throwsA(isA<FinanceException>()));
      }
      expect(server.requests.where((request) => request.isStorage), isEmpty);
    },
  );

  test('remoção com resposta perdida confirma metadados e apaga somente arquivo antigo', () async {
    await login();
    const oldPath = '$_uid/personal/old.png';
    server.profiles['personal']!['avatar_path'] = oldPath;
    server.ambiguousPatchFailure = true;
    final saved = await repository.removePhoto('personal');
    await server.waitFor((request) => request.isDelete);
    expect(saved.avatarPath, isNull);
    expect(saved.avatarUrl, isNull);
    expect(server.profiles['personal']!['avatar_path'], isNull);
    expect(
      server.requests.where((request) => request.isProfileRead),
      hasLength(2),
    );
    expect(server.requests.singleWhere((request) => request.isDelete).json, {
      'prefixes': [oldPath],
    });
  });

  test(
    'remoção rejeitada preserva metadados e não apaga arquivo anterior',
    () async {
      await login();
      const oldPath = '$_uid/personal/old.png';
      server.profiles['personal']!['avatar_path'] = oldPath;
      server.rejectPatch = true;
      await expectLater(
        repository.removePhoto('personal'),
        throwsA(isA<FinanceException>()),
      );
      expect(server.profiles['personal']!['avatar_path'], oldPath);
      expect(server.requests.where((request) => request.isDelete), isEmpty);
    },
  );

  test('troca de conta durante envio não publica nem apaga metadados de outra conta', () async {
    await login();
    final started = Completer<void>();
    final release = Completer<void>();
    server.beforeUploadResponse = () async {
      started.complete();
      await release.future;
    };
    final pending = upload();
    final expectation = expectLater(pending, throwsA(isA<FinanceException>()));
    await started.future;
    await client.auth.signOut(scope: SignOutScope.local);
    server.authUserId = _other;
    await client.auth.signInWithPassword(
      email: 'bia@example.com',
      password: 'senha-local',
    );
    expect(client.auth.currentUser!.id, _other);
    release.complete();
    await expectation;
    expect(server.requests.where((request) => request.isProfilePatch), isEmpty);
    expect(server.requests.where((request) => request.isDelete), isEmpty);
  });

  test(
    'sessão encerrada durante edição não confirma nome pessoal ou empresa',
    () async {
      for (final personal in [true, false]) {
        await login();
        final started = Completer<void>();
        final release = Completer<void>();
        server.beforeEditResponse = () async {
          started.complete();
          await release.future;
        };
        final Future<Object> pending = personal
            ? repository.updatePersonalName('Ana nova')
            : repository.updateBusiness(
                profileId: 'business',
                data: BusinessProfileData(name: 'Loja nova'),
              );
        final expectation = expectLater(
          pending,
          throwsA(isA<FinanceException>()),
        );
        await started.future;
        await client.auth.signOut(scope: SignOutScope.local);
        release.complete();
        await expectation;
        server.beforeEditResponse = null;
      }
    },
  );

  test('URL assinada só é criada para caminho do usuário e perfil; falha usa iniciais', () async {
    await login();
    for (final invalid in [
      '$_other/business/a.png',
      '$_uid/personal/a.png',
      '$_uid/business/../a.png',
      '$_uid/business/a.svg',
    ]) {
      final profile = FinancialProfile.fromJson({
        ..._profile(),
        'avatar_path': invalid,
      });
      final resolved = await SupabaseProfileDetailsRepository.resolveAvatarUrl(
        client,
        profile,
      );
      expect(resolved.avatarUrl, isNull);
    }
    expect(server.requests, isEmpty);
    server.signFailure = true;
    final profile = FinancialProfile.fromJson({
      ..._profile(),
      'avatar_path': '$_uid/business/owned.png',
    });
    final resolved = await SupabaseProfileDetailsRepository.resolveAvatarUrl(
      client,
      profile,
    );
    expect(resolved.avatarPath, profile.avatarPath);
    expect(resolved.avatarUrl, isNull);
    expect(server.requests.single.isSign, isTrue);
  });
}

Map<String, dynamic> _profile([String id = 'business']) => {
  'id': id,
  'user_id': _uid,
  'kind': id == 'personal' ? 'personal' : 'business',
  'name': id == 'personal' ? 'Pessoal' : 'Empresa',
  'legal_name': null,
  'cnpj': null,
  'contact_email': null,
  'contact_phone': null,
  'avatar_path': null,
};

bool _containsBytes(List<int> all, List<int> needle) {
  for (var start = 0; start + needle.length <= all.length; start++) {
    var match = true;
    for (var i = 0; i < needle.length; i++) {
      if (all[start + i] != needle[i]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

class _Request {
  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final List<int> raw;
  final Map<String, dynamic>? json;
  _Request(HttpRequest request, this.raw)
    : method = request.method,
      path = request.uri.path,
      query = request.uri.queryParameters,
      headers = {
        for (final name in ['x-upsert', 'content-type', 'authorization'])
          name: request.headers.value(name) ?? '',
      },
      json =
          request.headers.contentType?.mimeType == 'application/json' &&
              raw.isNotEmpty
          ? jsonDecode(utf8.decode(raw)) as Map<String, dynamic>
          : null;
  String get authorization => headers['authorization']!;
  bool get isProfileRead =>
      method == 'GET' && path == '/rest/v1/financial_profiles';
  bool get isProfilePatch =>
      method == 'PATCH' && path == '/rest/v1/financial_profiles';
  bool get isSign =>
      method == 'POST' && path.startsWith('/storage/v1/object/sign/');
  bool get isUpload =>
      method == 'POST' && path.startsWith('/storage/v1/object/$_bucket/');
  bool get isDelete =>
      method == 'DELETE' && path == '/storage/v1/object/$_bucket';
  bool get isStorage => path.startsWith('/storage/');
}

class _Server {
  final HttpServer _server;
  final requests = <_Request>[];
  final _events = StreamController<_Request>.broadcast();
  final profiles = {'personal': _profile('personal'), 'business': _profile()};
  Map<String, dynamic>? patchResponse;
  Map<String, dynamic>? readResponse;
  bool signFailure = false;
  bool deleteFailure = false;
  bool rejectPatch = false;
  bool ambiguousPatchFailure = false;
  Future<void> Function()? beforeUploadResponse;
  Future<void> Function()? beforeEditResponse;
  String personalName = 'Ana Silva';
  String authUserId = _uid;

  _Server(this._server) {
    _server.listen(_handle);
  }
  String get url => 'http://127.0.0.1:${_server.port}';
  static Future<_Server> start() async =>
      _Server(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  Future<void> close() async {
    await _events.close();
    await _server.close(force: true);
  }

  Future<void> waitFor(bool Function(_Request) check) async {
    if (requests.any(check)) return;
    await _events.stream.firstWhere(check).timeout(const Duration(seconds: 5));
  }

  Future<void> _handle(HttpRequest incoming) async {
    final bytes = await incoming.fold<List<int>>(
      [],
      (buffer, next) => buffer..addAll(next),
    );
    final request = _Request(incoming, bytes);
    requests.add(request);
    _events.add(request);
    incoming.response.headers.contentType = ContentType.json;
    dynamic response;
    if (request.path == '/auth/v1/token') {
      response = _session();
    } else if (request.path == '/auth/v1/logout') {
      incoming.response.statusCode = 204;
    } else if (request.path == '/auth/v1/user' && request.method == 'PUT') {
      personalName = (request.json!['data'] as Map)['name'] as String;
      await beforeEditResponse?.call();
      response = _user();
    } else if (request.isProfileRead) {
      final id = request.query['id']!.substring(3);
      response = readResponse ?? profiles[id];
    } else if (request.isProfilePatch) {
      final id = request.query['id']!.substring(3);
      if (rejectPatch) {
        incoming.response.statusCode = 400;
        response = {'code': '23514', 'message': 'Internal rejected metadata'};
      } else {
        profiles[id] = {...profiles[id]!, ...request.json!};
        await beforeEditResponse?.call();
        if (ambiguousPatchFailure) {
          incoming.response.statusCode = 500;
          response = {
            'code': 'XX000',
            'message': 'Ambiguous response after commit',
          };
        } else {
          response = patchResponse ?? profiles[id];
        }
      }
    } else if (request.isUpload) {
      await beforeUploadResponse?.call();
      response = {'Key': request.path.substring('/storage/v1/object/'.length)};
    } else if (request.isSign) {
      if (signFailure) {
        incoming.response.statusCode = 400;
        response = {
          'statusCode': '400',
          'error': 'BadRequest',
          'message': 'Signing unavailable',
        };
      } else {
        response = {
          'signedURL':
              '${request.path.substring('/storage/v1'.length)}?token=local-test',
        };
      }
    } else if (request.isDelete) {
      if (deleteFailure) {
        incoming.response.statusCode = 400;
        response = {
          'statusCode': '400',
          'error': 'BadRequest',
          'message': 'Cleanup unavailable',
        };
      } else {
        response = <Object>[];
      }
    } else {
      incoming.response.statusCode = 404;
      response = {'message': 'Unexpected local request'};
    }
    if (response != null) incoming.response.write(jsonEncode(response));
    await incoming.response.close();
  }

  Map<String, dynamic> _user() => {
    'id': authUserId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': authUserId == _uid ? 'ana@example.com' : 'bia@example.com',
    'app_metadata': {'provider': 'email'},
    'user_metadata': {'name': personalName},
    'created_at': '2026-11-18T12:00:00Z',
  };
  Map<String, dynamic> _session() {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final jwt =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': authUserId, 'role': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.${base64Url.encode(List.filled(32, 0)).replaceAll('=', '')}';
    return {
      'access_token': jwt,
      'token_type': 'bearer',
      'refresh_token': 'local-refresh',
      'expires_in': 3600,
      'user': _user(),
    };
  }
}
