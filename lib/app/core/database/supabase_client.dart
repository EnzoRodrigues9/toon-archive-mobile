import 'package:supabase_flutter/supabase_flutter.dart';
import  '../helpers/app.config.dart';

/// Ponto central de acesso ao cliente Supabase.
/// Inicialize chamando [SupabaseClientHelper.init] no main.dart,
/// depois acesse o cliente via [SupabaseClientHelper.client].
class SupabaseClientHelper {
  SupabaseClientHelper._();

  /// Chame uma vez em main(), antes do runApp().
  static Future<void> init() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseKey,
      debug: AppConfig.isDevelopment,
    );
  }

  /// Cliente global — use em qualquer lugar do app.
  static SupabaseClient get client => Supabase.instance.client;

  /// Usuário autenticado no momento, ou null se não logado.
  static User? get currentUser => client.auth.currentUser;

  /// Stream de mudanças de estado de autenticação.
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}