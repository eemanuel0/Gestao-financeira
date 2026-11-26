import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/core/email_confirmation.dart';

void main() {
  test('detecta cadastro confirmado pelo tipo no fragmento', () {
    final uri = Uri.parse(
      'https://financas.example/#access_token=token&type=signup',
    );

    expect(
      emailConfirmationStatusFromUri(uri),
      EmailConfirmationStatus.confirmed,
    );
  });

  test('detecta token de acesso no fragmento', () {
    final uri = Uri.parse(
      'https://financas.example/#access_token=token&token_type=bearer',
    );

    expect(
      emailConfirmationStatusFromUri(uri),
      EmailConfirmationStatus.confirmed,
    );
  });

  test('detecta erro de confirmação na query', () {
    final uri = Uri.parse(
      'https://financas.example/?error=access_denied&error_code=otp_expired',
    );

    expect(
      emailConfirmationStatusFromUri(uri),
      EmailConfirmationStatus.invalid,
    );
  });

  test('detecta acesso negado mesmo sem código de erro', () {
    final uri = Uri.parse(
      'https://financas.example/?error=access_denied',
    );

    expect(
      emailConfirmationStatusFromUri(uri),
      EmailConfirmationStatus.invalid,
    );
  });

  test('detecta erro de confirmação no fragmento', () {
    final uri = Uri.parse(
      'https://financas.example/#error_code=otp_expired',
    );

    expect(
      emailConfirmationStatusFromUri(uri),
      EmailConfirmationStatus.invalid,
    );
  });

  test('não altera a inicialização em URLs comuns', () {
    final uri = Uri.parse('https://financas.example/');

    expect(
      emailConfirmationStatusFromUri(uri),
      EmailConfirmationStatus.none,
    );
  });
}
