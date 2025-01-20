import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String apiKey;
  final String modelName;

  GeminiService({required this.apiKey, required this.modelName});

  GenerativeModel getModel() {
    return GenerativeModel(model: modelName, apiKey: apiKey);
  }
}
