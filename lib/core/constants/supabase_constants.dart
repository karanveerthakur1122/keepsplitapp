import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  SupabaseConstants._();

  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL']?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_URL is missing or empty in .env');
    }
    return value;
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY']?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is missing or empty in .env');
    }
    return value;
  }
}
