import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseKey => dotenv.env['SUPABASE_KEY'] ?? '';
  static String get groupId => dotenv.env['GROUP_ID'] ?? 'SF-GP-01';
  static String get huggingFaceApiKey => dotenv.env['HF_API_KEY'] ?? '';
  static const bool isDevelopment = true;
}