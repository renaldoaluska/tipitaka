import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 ENUM PROVIDER
enum AIProvider { gemini, openai, anthropic, openrouter }

// 🔥 MODEL RESPONSE
class AITranslationResult {
  final String translatedText;
  final String? error;
  final bool success;

  AITranslationResult({
    required this.translatedText,
    this.error,
    required this.success,
  });
}

// 🔥 HISTORY MODEL
class TranslationHistory {
  final String id;
  final String originalText;
  final String translatedText;
  final String provider;
  final String model;
  final DateTime timestamp;

  TranslationHistory({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.provider,
    required this.model,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalText': originalText,
    'translatedText': translatedText,
    'provider': provider,
    'model': model,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranslationHistory.fromJson(Map<String, dynamic> json) {
    return TranslationHistory(
      id: json['id'],
      originalText: json['originalText'],
      translatedText: json['translatedText'],
      provider: json['provider'],
      model: json['model'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// 🔥 MAIN SERVICE CLASS
class AITranslationService {
  static const String _keyPrefix = 'ai_api_key_';
  static const String _modelPrefix = 'ai_model_';
  static const String _selectedProviderKey = 'ai_selected_provider';
  static const String _historyKey = 'ai_translation_history';
  static const int _maxHistoryItems = 50;

  // ============================================
  // STORAGE METHODS & HISTORY METHODS (TIDAK BERUBAH)
  // (Bagian ini sama persis seperti file lama, saya singkat biar fokus ke prompt)
  // ... Paste Storage & History methods here ...
  // ============================================

  static Future<void> saveApiKey(AIProvider provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${provider.name}', apiKey);
  }

  static Future<String?> getApiKey(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix${provider.name}');
  }

  static Future<void> deleteApiKey(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix${provider.name}');
    await prefs.remove('$_modelPrefix${provider.name}');
  }

  static Future<void> saveModelName(AIProvider provider, String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_modelPrefix${provider.name}', model);
  }

  static Future<String?> getModelName(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_modelPrefix${provider.name}');
  }

  static Future<void> setActiveProvider(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedProviderKey, provider.name);
  }

  static Future<AIProvider> getActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_selectedProviderKey);
    if (providerName == null) return AIProvider.gemini;
    return AIProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => AIProvider.gemini,
    );
  }

  static Future<bool> isProviderReady(AIProvider provider) async {
    final key = await getApiKey(provider);
    final model = await getModelName(provider);
    return key != null &&
        key.trim().isNotEmpty &&
        model != null &&
        model.trim().isNotEmpty;
  }

  static Future<void> saveToHistory({
    required String originalText,
    required String translatedText,
    required String provider,
    required String model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    final history = TranslationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalText: originalText,
      translatedText: translatedText,
      provider: provider,
      model: model,
      timestamp: DateTime.now(),
    );
    historyJson.insert(0, jsonEncode(history.toJson()));
    if (historyJson.length > _maxHistoryItems) {
      historyJson.removeRange(_maxHistoryItems, historyJson.length);
    }
    await prefs.setStringList(_historyKey, historyJson);
  }

  static Future<List<TranslationHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    return historyJson
        .map((json) {
          try {
            return TranslationHistory.fromJson(jsonDecode(json));
          } catch (e) {
            return null;
          }
        })
        .whereType<TranslationHistory>()
        .toList();
  }

  static Future<void> deleteHistoryItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    historyJson.removeWhere((json) {
      try {
        return TranslationHistory.fromJson(jsonDecode(json)).id == id;
      } catch (e) {
        return false;
      }
    });
    await prefs.setStringList(_historyKey, historyJson);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ============================================
  // TRANSLATION METHOD (LOGIC TETAP, PROMPT BERUBAH)
  // ============================================

  static Future<AITranslationResult> translate(String text) async {
    final provider = await getActiveProvider();
    final apiKey = await getApiKey(provider);
    final modelName = await getModelName(provider);

    if (apiKey == null || apiKey.trim().isEmpty) {
      return AITranslationResult(
        translatedText: '',
        error: 'API Key belum diatur',
        success: false,
      );
    }
    if (modelName == null || modelName.trim().isEmpty) {
      return AITranslationResult(
        translatedText: '',
        error: 'Model belum dipilih',
        success: false,
      );
    }

    AITranslationResult result;

    switch (provider) {
      case AIProvider.gemini:
        result = await _translateWithGemini(text, apiKey, modelName);
        break;
      case AIProvider.openai:
        result = await _translateWithOpenAI(text, apiKey, modelName);
        break;
      case AIProvider.anthropic:
        result = await _translateWithAnthropic(text, apiKey, modelName);
        break;
      case AIProvider.openrouter:
        result = await _translateWithOpenRouter(text, apiKey, modelName);
        break;
    }

    if (result.success) {
      await saveToHistory(
        originalText: text,
        translatedText: result.translatedText,
        provider: getProviderDisplayName(provider),
        model: modelName,
      );
    }
    return result;
  }

  // ============================================
  // PROMPTS (BAHASA INDONESIA)
  // ============================================

  static const String _systemInstruction =
      "Anda adalah penerjemah ahli bahasa Pāli ke Bahasa Indonesia, dengan spesialisasi teks-teks Theravāda (Tipitaka, Aṭṭhakathā, Ṭīkā).\n\n"
      "ATURAN KRUSIAL:\n"
      "1. JANGAN terjemahkan istilah teknis Pāli yang mendalam (seperti: jhāna, vipassanā, samādhi, kamma, arahant, dukkha, anattā, dll). Biarkan dalam bahasa aslinya.\n"
      "2. Gunakan terminologi khas Theravāda (Gunakan 'Sutta', JANGAN 'Sutra'; Gunakan ejaan Pāli, bukan Sanskerta/Mahayana).\n"
      "3. Untuk teks Aṭṭhakathā (Komentar) yang mendefinisikan istilah: Pertahankan istilah Pāli yang sedang didefinisikan, lalu terjemahkan penjelasannya. Jika perlu, sertakan istilah Pāli dalam kurung.\n"
      "4. PERTAHANKAN diakritik Pāli dengan akurat (ā, ī, ū, ṃ, ṅ, ñ, ṭ, ḍ, ṇ, ḷ).\n"
      "5. Gaya Bahasa: Formal, mengalir alami, dan hormat sesuai konteks Buddhis di Indonesia.\n"
      "6. HANYA berikan hasil terjemahan akhirnya saja tanpa pengantar atau penutup.";

  static Future<AITranslationResult> _translateWithGemini(
    String text,
    String apiKey,
    String model,
  ) async {
    try {
      final url = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:generateContent',
        {'key': apiKey},
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "$_systemInstruction\n\nTeks untuk diterjemahkan:\n\"$text\"",
                },
              ],
            },
          ],
          "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_NONE",
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_NONE",
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_NONE",
            },
          ],
          "generationConfig": {"temperature": 0.3, "maxOutputTokens": 2000},
        }),
      );
      return _handleGeminiResponse(response);
    } catch (e) {
      return AITranslationResult(
        translatedText: '',
        error: 'Koneksi gagal: $e',
        success: false,
      );
    }
  }

  static Future<AITranslationResult> _translateWithOpenAI(
    String text,
    String apiKey,
    String model,
  ) async {
    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": model,
          "messages": [
            {"role": "system", "content": _systemInstruction},
            {
              "role": "user",
              "content":
                  "Terjemahkan teks Pāli ini ke Bahasa Indonesia:\n\n$text",
            },
          ],
          "temperature": 0.3,
          "max_tokens": 2000,
        }),
      );
      return _handleOpenAIResponse(response);
    } catch (e) {
      return AITranslationResult(
        translatedText: '',
        error: 'Connection failed: $e',
        success: false,
      );
    }
  }

  static Future<AITranslationResult> _translateWithAnthropic(
    String text,
    String apiKey,
    String model,
  ) async {
    try {
      final url = Uri.parse('https://api.anthropic.com/v1/messages');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          "model": model,
          "max_tokens": 2000,
          "system":
              _systemInstruction, // Anthropic supports system parameter directly
          "messages": [
            {"role": "user", "content": "Terjemahkan teks ini:\n$text"},
          ],
        }),
      );
      return _handleAnthropicResponse(response);
    } catch (e) {
      return AITranslationResult(
        translatedText: '',
        error: 'Connection failed: $e',
        success: false,
      );
    }
  }

  static Future<AITranslationResult> _translateWithOpenRouter(
    String text,
    String apiKey,
    String model,
  ) async {
    try {
      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/yourusername/yourapp',
          'X-Title': 'Pali Translation App',
        },
        body: jsonEncode({
          "model": model,
          "messages": [
            {"role": "system", "content": _systemInstruction},
            {
              "role": "user",
              "content":
                  "Terjemahkan teks Pāli ini ke Bahasa Indonesia:\n\n$text",
            },
          ],
          "temperature": 0.3,
          "max_tokens": 2000,
        }),
      );
      return _handleOpenAIResponse(response);
    } catch (e) {
      return AITranslationResult(
        translatedText: '',
        error: 'Connection failed: $e',
        success: false,
      );
    }
  }

  // ============================================
  // RESPONSE HANDLERS & HELPERS (TIDAK BERUBAH)
  // ... Paste sisa kode (handleResponse dan helpers) disini ...
  // ============================================

  static AITranslationResult _handleGeminiResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final result = data['candidates'][0]['content']['parts'][0]['text'];
        return AITranslationResult(translatedText: result ?? '', success: true);
      }
      return AITranslationResult(
        translatedText: '',
        error: 'Tidak ada respons dari AI',
        success: false,
      );
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Rate limit tercapai. Tunggu sebentar.',
        success: false,
      );
    } else if (response.statusCode == 400) {
      final data = jsonDecode(response.body);
      final errorMsg = data['error']?['message'] ?? 'Bad request';
      return AITranslationResult(
        translatedText: '',
        error: 'Error: $errorMsg',
        success: false,
      );
    } else {
      return AITranslationResult(
        translatedText: '',
        error: 'Error ${response.statusCode}',
        success: false,
      );
    }
  }

  static AITranslationResult _handleOpenAIResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['choices'][0]['message']['content'];
      return AITranslationResult(translatedText: result ?? '', success: true);
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Rate limit exceeded',
        success: false,
      );
    } else if (response.statusCode == 401) {
      return AITranslationResult(
        translatedText: '',
        error: 'API Key tidak valid',
        success: false,
      );
    } else {
      return AITranslationResult(
        translatedText: '',
        error: 'Error ${response.statusCode}',
        success: false,
      );
    }
  }

  static AITranslationResult _handleAnthropicResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['content'][0]['text'];
      return AITranslationResult(translatedText: result ?? '', success: true);
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Rate limit exceeded',
        success: false,
      );
    } else if (response.statusCode == 401) {
      return AITranslationResult(
        translatedText: '',
        error: 'API Key tidak valid',
        success: false,
      );
    } else {
      return AITranslationResult(
        translatedText: '',
        error: 'Error ${response.statusCode}',
        success: false,
      );
    }
  }

  static String getProviderDisplayName(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Google Gemini';
      case AIProvider.openai:
        return 'OpenAI';
      case AIProvider.anthropic:
        return 'Anthropic Claude';
      case AIProvider.openrouter:
        return 'OpenRouter';
    }
  }

  static String getProviderSignupUrl(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'aistudio.google.com/apikey';
      case AIProvider.openai:
        return 'platform.openai.com/api-keys';
      case AIProvider.anthropic:
        return 'console.anthropic.com/settings/keys';
      case AIProvider.openrouter:
        return 'openrouter.ai/keys';
    }
  }

  static String getModelPlaceholder(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Contoh: gemini-2.0-flash-exp';
      case AIProvider.openai:
        return 'Contoh: gpt-4o-mini';
      case AIProvider.anthropic:
        return 'Contoh: claude-3-5-haiku-20241022';
      case AIProvider.openrouter:
        return 'Contoh: google/gemini-2.0-flash-exp:free';
    }
  }
}
