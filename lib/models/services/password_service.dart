import 'package:flutter/foundation.dart';

// Separado do login para testar recuperação sem trocar a sessão do aplicativo.
abstract class PasswordService extends ChangeNotifier {
  bool get recoveryInProgress;
  Future<void> sendRecoveryCode(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
