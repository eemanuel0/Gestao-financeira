import '../app_user.dart';

// Permite testar as telas sem depender de uma conta real na nuvem.
abstract interface class AccountService {
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;

  Future<void> signIn({required String email, required String password});

  // Retorna true quando é preciso confirmar o cadastro pelo e-mail.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class AccountException implements Exception {
  final String message;
  const AccountException(this.message);

  @override
  String toString() => message;
}
