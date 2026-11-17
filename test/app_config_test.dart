import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/core/app_config.dart';

void main() {
  AppConfig config(String key, {String url = 'https://example.supabase.co'}) {
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
