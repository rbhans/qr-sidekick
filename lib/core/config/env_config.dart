import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration
///
/// Values are loaded in this priority order:
/// 1. .env file (for local development)
/// 2. Compile-time --dart-define (for CI/CD builds)
/// 3. Default values (where applicable)
class EnvConfig {
  EnvConfig._();

  /// Load environment from .env file
  /// Call this before accessing any config values
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file not found - will fall back to dart-define values
      // This is normal for production builds
    }
  }

  /// Supabase project URL
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://cwdoklplunlaqakiyagb.supabase.co',
        );
  }

  /// Supabase anonymous key (public, safe to include in client apps)
  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  /// Check if required config is present
  static bool get isConfigured => supabaseAnonKey.isNotEmpty;

  /// Validate configuration and throw if invalid
  static void validate() {
    if (supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not configured.\n'
        'Option 1: Add your key to .env file\n'
        'Option 2: Run with --dart-define=SUPABASE_ANON_KEY=your_key',
      );
    }
  }
}
