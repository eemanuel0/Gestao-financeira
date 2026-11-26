import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../app_user.dart';
import 'account_service.dart';

class SupabaseAccountService implements AccountService {
  final SupabaseClient _client;

  SupabaseAccountService(this._client);

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _client.auth.onAuthStateChange.map(
    (state) => _toAppUser(state.session?.user),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AccountException(_authMessage(error));
    } catch (_) {
      throw const AccountException(
        'Não foi possível entrar. Confira sua conexão e tente novamente.',
      );
    }
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: AppConfig.emailConfirmationRedirect,
        data: {'name': name.trim()},
      );
      return result.session == null;
    } on AuthException catch (error) {
      throw AccountException(_authMessage(error));
    } catch (_) {
      throw const AccountException(
        'Não foi possível cadastrar. Confira sua conexão e tente novamente.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // A saída afeta este dispositivo, preservando sessões em outros locais.
      await _client.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (error) {
      throw AccountException(_authMessage(error));
    } catch (_) {
      throw const AccountException('Não foi possível sair. Tente novamente.');
    }
  }

  static AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final email = user.email ?? '';
    final storedName = user.userMetadata?['name'];
    final name = storedName is String && storedName.trim().isNotEmpty
        ? storedName.trim()
        : email.split('@').first;
    return AppUser(id: user.id, email: email, name: name);
  }

  static String _authMessage(AuthException error) {
    return switch (error.code) {
      'invalid_credentials' => 'E-mail ou senha incorretos.',
      'email_not_confirmed' => 'Confirme seu e-mail antes de entrar.',
      'weak_password' =>
        'Use uma senha mais forte, com pelo menos 8 caracteres.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Muitas tentativas. Aguarde e tente novamente.',
      'user_already_exists' || 'email_exists' =>
        'Confira seu e-mail ou tente entrar na conta existente.',
      'signup_disabled' => 'O cadastro está indisponível no momento.',
      _ => 'Não foi possível concluir. Confira os dados e tente novamente.',
    };
  }
}
