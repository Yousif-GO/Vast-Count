import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeyService {
  static String getGeminiApiKey() {
    // For web, try to get from window.ENV
    if (kIsWeb) {
      try {
        final env = js.context['ENV'];
        if (env != null && env['GEMINI_API_KEY'] != null) {
          return env['GEMINI_API_KEY'] as String;
        }
      } catch (e) {
        print('Error accessing web environment: $e');
      }
    }

    // Fallback to dotenv for non-web or if web env is not available
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }
}
