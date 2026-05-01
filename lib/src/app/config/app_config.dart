import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap.',
  );
});

class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  static Future<AppConfig> load() async {
    await dotenv.load();

    final supabaseUrl = _requiredEnv('SUPABASE_URL');
    final supabaseAnonKey = _requiredEnv('SUPABASE_ANON_KEY');

    _validateUrl(supabaseUrl);

    return AppConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  static String _requiredEnv(String key) {
    final value = dotenv.env[key];

    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }

    return value.trim();
  }

  static void _validateUrl(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw StateError('SUPABASE_URL must be a valid URL.');
    }
  }
}
