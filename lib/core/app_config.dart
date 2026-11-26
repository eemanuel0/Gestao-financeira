import 'dart:convert';

// Recebe apenas a URL e a chave pública do projeto Supabase.
class AppConfig {
  // Usa a origem atual do app como destino do link de confirmação.
  static String get emailRedirectTo => Uri.base.origin;

  final String supabaseUrl;
  final String supabasePublishableKey;

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

    final host = url.host.toLowerCase();
    if (host == 'seu-projeto.supabase.co' ||
        host == 'example.supabase.co' ||
        host.contains('your-project')) {
      throw const FormatException(
        'Substitua a URL de exemplo pela Project URL do seu projeto Supabase.',
      );
    }

    final key = supabasePublishableKey.trim();
    if (key.isEmpty) {
      throw const FormatException('Configure SUPABASE_PUBLISHABLE_KEY.');
    }
    final normalizedKey = key.toLowerCase();
    if (normalizedKey.contains('substitua') ||
        normalizedKey == 'sua-chave-publica') {
      throw const FormatException(
        'Substitua a chave de exemplo pela Publishable key do Supabase.',
      );
    }
    if (key.startsWith('sb_secret_') || _jwtRole(key) == 'service_role') {
      throw const FormatException(
        'Use somente a chave pública publishable/anon; nunca service_role.',
      );
    }
    if (!key.startsWith('sb_publishable_') && _jwtRole(key) != 'anon') {
      throw const FormatException(
        'A chave deve ser a Publishable key (sb_publishable_) ou a chave anon legada.',
      );
    }
  }

  // Lê apenas o papel do JWT para aceitar anon e bloquear service_role.
  static String? _jwtRole(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final role = payload['role'];
      return role is String ? role : null;
    } on FormatException {
      return null;
    }
  }
}
