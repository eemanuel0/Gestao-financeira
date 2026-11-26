import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/core/app_config.dart';

void main() {
  AppConfig config(String key, {String url = 'https://projeto-teste.supabase.co'}) {
    return AppConfig(supabaseUrl: url, supabasePublishableKey: key);
  }

  test('aceita URL HTTPS e chave pública publishable', () {
    expect(() => config('sb_publishable_test').validate(), returnsNormally);
  });

  test('rejeita configuração ausente e URL sem HTTPS', () {
    expect(() => config('').validate(), throwsFormatException);
    expect(() => config('key', url: '').validate(), throwsFormatException);
    expect(
      () => config('key', url: 'http://example.supabase.co').validate(),
      throwsFormatException,
    );
  });

  test('rejeita os valores de exemplo do arquivo de configuração', () {
    expect(
      () => config(
        'sb_publishable_test',
        url: 'https://seu-projeto.supabase.co',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => config('sb_publishable_substitua_pela_chave_publica').validate(),
      throwsFormatException,
    );
    expect(() => config('sua-chave-publica').validate(), throwsFormatException);
    expect(() => config('chave-qualquer').validate(), throwsFormatException);
  });

  test('rejeita chaves administrativas novas e JWT service_role', () {
    final payload = base64Url.encode(utf8.encode('{"role":"service_role"}'));
    expect(() => config('sb_secret_test').validate(), throwsFormatException);
    expect(
      () => config('header.$payload.signature').validate(),
      throwsFormatException,
    );
  });

  test('aceita a chave anon legada', () {
    final payload = base64Url.encode(utf8.encode('{"role":"anon"}'));
    expect(
      () => config('header.$payload.signature').validate(),
      returnsNormally,
    );
  });
}
