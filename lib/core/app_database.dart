import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

// Mantém um único cliente, com sessão persistida pelo SDK do Supabase.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Future<SupabaseClient>? _initialization;

  Future<SupabaseClient> get database async {
    final initialization = _initialization ??= _open();
    try {
      return await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) _initialization = null;
      rethrow;
    }
  }

  Future<SupabaseClient> _open() async {
    final config = AppConfig.fromEnvironment();
    config.validate();
    await Supabase.initialize(
      url: config.supabaseUrl.trim(),
      publishableKey: config.supabasePublishableKey.trim(),
    );
    return Supabase.instance.client;
  }
}
