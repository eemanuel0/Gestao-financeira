import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

// Mantém um único cliente, com sessão persistida pelo SDK do Supabase.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Future<SupabaseClient>? _initialization;

  Future<SupabaseClient> get database => open();

  Future<SupabaseClient> open({bool detectSessionInUri = true}) async {
    final initialization = _initialization ??= _open(
      detectSessionInUri: detectSessionInUri,
    );
    try {
      return await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) _initialization = null;
      rethrow;
    }
  }

  Future<SupabaseClient> _open({required bool detectSessionInUri}) async {
    final config = AppConfig.fromEnvironment();
    config.validate();
    await Supabase.initialize(
      url: config.supabaseUrl.trim(),
      publishableKey: config.supabasePublishableKey.trim(),
      authOptions: FlutterAuthClientOptions(
        detectSessionInUri: detectSessionInUri,
      ),
    );
    return Supabase.instance.client;
  }
}
