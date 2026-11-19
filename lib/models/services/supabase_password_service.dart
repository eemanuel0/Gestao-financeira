import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_service.dart';
import 'password_service.dart';

class SupabasePasswordService extends PasswordService {
  final SupabaseClient _client;
  final String url, publishableKey;
  final http.Client _http = http.Client();
  bool _recovering = false, _changing = false;
  SupabasePasswordService(
    this._client, {
    required this.url,
    required this.publishableKey,
  });
  @override
  bool get recoveryInProgress => _recovering;

  @override
  Future<void> sendRecoveryCode(String email) async {
    // No Supabase, o template Reset Password deve exibir {{ .Token }}.
    await _request('POST', 'recover', {'email': _email(email)});
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_recovering) {
      throw const AccountException('Aguarde a redefinição em andamento.');
    }
    _validatePassword(newPassword);
    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      throw const AccountException('Informe o código de 8 dígitos.');
    }
    _recovering = true;
    notifyListeners();
    String? temporaryToken;
    try {
      // HTTP sem sessão persistente evita o BroadcastChannel dos clientes Auth.
      // O código de recuperação nunca autentica a Home nem outras abas.
      final result = await _request('POST', 'verify', {
        'email': _email(email),
        'token': code,
        'type': 'recovery',
      });
      temporaryToken = result['access_token'] as String?;
      if (temporaryToken == null) {
        throw const AccountException(
          'Código inválido ou expirado. Solicite outro.',
        );
      }
      await _request(
        'PUT',
        'user',
        {'password': newPassword},
        token: temporaryToken,
        passwordWrite: true,
      );
    } finally {
      await _revoke(temporaryToken);
      _recovering = false;
      notifyListeners();
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_changing) {
      throw const AccountException('Aguarde a alteração em andamento.');
    }
    _validatePassword(newPassword);
    final user = _client.auth.currentUser;
    if (user?.email == null) {
      throw const AccountException('Entre novamente na sua conta.');
    }
    if (currentPassword.isEmpty) {
      throw const AccountException('Informe a senha atual.');
    }
    if (currentPassword == newPassword) {
      throw const AccountException('Escolha uma senha diferente da atual.');
    }
    _changing = true;
    String? temporaryToken;
    try {
      // Confirma a senha atual sem substituir a sessão do aplicativo.
      final verification = await _request(
        'POST',
        'token',
        {'email': user!.email!, 'password': currentPassword},
        query: {'grant_type': 'password'},
      );
      temporaryToken = verification['access_token'] as String?;
      if (temporaryToken == null ||
          verification['user']?['id'] != user.id ||
          _client.auth.currentUser?.id != user.id) {
        throw const AccountException(
          'A conta mudou. Entre novamente antes de continuar.',
        );
      }
      await _client.auth.updateUser(
        UserAttributes(password: newPassword, currentPassword: currentPassword),
      );
    } on AuthException catch (error) {
      throw AccountException(_message(error.code));
    } on AccountException {
      rethrow;
    } catch (_) {
      throw const AccountException(
        'Não foi possível confirmar a alteração. Tente entrar com a nova senha antes de repetir.',
      );
    } finally {
      await _revoke(temporaryToken);
      _changing = false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic> body, {
    String? token,
    Map<String, String>? query,
    bool passwordWrite = false,
  }) async {
    final uri = Uri.parse(url)
        .resolve('/auth/v1/$path')
        .replace(queryParameters: query);
    final headers = {
      'apikey': publishableKey,
      'Authorization': 'Bearer ${token ?? publishableKey}',
      'Content-Type': 'application/json',
    };
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      final response = await http.Response.fromStream(await _http.send(request))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AccountException(
          _message((data['error_code'] ?? data['code']) as String?),
        );
      }
      return response.body.isEmpty
          ? {}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw AccountException(
        passwordWrite
            ? 'Não foi possível confirmar a alteração. Tente entrar com a nova senha antes de repetir.'
            : 'Não foi possível concluir. Confira sua conexão e tente novamente.',
      );
    }
  }

  Future<void> _revoke(String? token) async {
    if (token == null) return;
    try {
      await _request(
        'POST',
        'logout',
        {},
        token: token,
        query: {'scope': 'local'},
      );
    } catch (_) {
      /* A limpeza não deve ocultar uma senha já alterada. */
    }
  }

  static String _email(String value) => value.trim().toLowerCase();
  static void _validatePassword(String value) {
    // Não use trim(): espaços podem fazer parte de uma senha.
    if (value.length < 8) {
      throw const AccountException('Use pelo menos 8 caracteres.');
    }
  }

  static String _message(String? code) => switch (code) {
    'invalid_credentials' => 'A senha atual está incorreta.',
    'otp_expired' ||
    'otp_disabled' => 'Código inválido ou expirado. Solicite outro.',
    'weak_password' => 'Use uma senha mais forte, com pelo menos 8 caracteres.',
    'same_password' => 'Escolha uma senha diferente da atual.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Muitas tentativas. Aguarde antes de solicitar novamente.',
    'reauthentication_needed' || 'reauthentication_not_valid' =>
      'Por segurança, saia e entre novamente antes de alterar a senha.',
    _ => 'Não foi possível concluir. Confira os dados e tente novamente.',
  };
  @override
  void dispose() {
    _http.close();
    super.dispose();
  }
}
