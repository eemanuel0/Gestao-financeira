import 'dart:convert';

import 'package:flutter/foundation.dart';

// Recebe apenas a URL e a chave pública do projeto Supabase.
class AppConfig {
  final String supabaseUrl;
  final String supabasePublishableKey;

  static String? get emailConfirmationRedirect =>
      kIsWeb ? Uri.base.origin : null;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: publishableKey.isEmpty
          ? legacyKey
          : publishableKey,
    );
  }

  void validate() {
    final url = Uri.tryParse(supabaseUrl.trim());
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw const FormatException('Configure uma SUPABASE_URL HTTPS válida.');
    }

    final key = supabasePublishableKey.trim();
    if (key.isEmpty) {
      throw const FormatException('Configure SUPABASE_PUBLISHABLE_KEY.');
    }
    if (key.startsWith('sb_secret_') || _isServiceRoleJwt(key)) {
      throw const FormatException(
        'Use somente a chave pública publishable/anon; nunca service_role.',
      );
    }
  }

  // Evita colocar por engano uma chave administrativa no aplicativo.
  static bool _isServiceRoleJwt(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}
