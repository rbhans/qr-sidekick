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
        const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          // Fallback to the bundled anon key if .env isn't loaded in release.
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3ZG9rbHBsdW5sYXFha2l5YWdiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNTQ4NTgsImV4cCI6MjA3NzgzMDg1OH0.ralsEJ8t6Cu1prIIiWqvuiw-WVP0RjxX1TAw9Bkqffw',
        );
  }

  /// RevenueCat public SDK key for iOS (appl_...)
  static String get revenueCatIosApiKey {
    return dotenv.env['REVENUECAT_IOS_API_KEY'] ??
        const String.fromEnvironment(
          'REVENUECAT_IOS_API_KEY',
          defaultValue: 'appl_bVfZzWURnCQcEOVnNnfufLLGcTu',
        );
  }

  /// RevenueCat public SDK key for Android (goog_...)
  static String get revenueCatAndroidApiKey {
    return dotenv.env['REVENUECAT_ANDROID_API_KEY'] ??
        const String.fromEnvironment(
          'REVENUECAT_ANDROID_API_KEY',
          defaultValue: 'goog_mSViypHBZBhnrzPuLxIenauLljG',
        );
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
