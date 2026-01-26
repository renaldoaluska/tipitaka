import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

//  ENUM PROVIDER
enum AIProvider { gemini, openai, anthropic, openrouter }

//  MODEL RESPONSE
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

//  HISTORY MODEL
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

//  MAIN SERVICE CLASS
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
      "Task: Translate Pāli to Indonesian (Formal/Respectful).\n"
      "Mode: SENTENCE-BY-SENTENCE STUDY.\n\n"
      "Strict Rules:\n"
      "1. NO introductory text. Direct output only.\n"
      "2. Format per point:\n"
      "   • **[Pāli Source]** (Use 2 stars)\n"
      "   [Translation]\n"
      "3. Use double newlines between points.\n"
      "4. Inside translation, Pāli terms must use 1 star (*italic*).\n\n"
      "Example:\n"
      "In: Asevanā ca bālānaṁ.\n"
      "Out:\n"
      "• **Asevanā ca bālānaṁ.**\n\n"
      "  Tidak bergaul dengan orang bodoh (*bāla*).";

  static Future<AITranslationResult> _translateWithGemini(
    String text,
    String apiKey,
    String model,
  ) async {
    final url = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': apiKey},
    );

    // Fungsi Helper untuk kirim request
    Future<http.Response> sendRequest({bool strictMode = true}) {
      final Map<String, dynamic> body = {
        "contents": [
          {
            "parts": [
              {"text": "$_systemInstruction\n\nTeks Pāli:\n\"$text\""},
            ],
          },
        ],
        // Safety settings standar
        "safetySettings": [
          {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
          {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_NONE",
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_NONE",
          },
        ],
      };

      // Hanya kirim config jika strictMode = true
      if (strictMode) {
        body["generationConfig"] = {
          "temperature": 0.3,
          "maxOutputTokens": 4096, // SUDAH DINAIKKAN (sebelumnya 2000)
        };
      }

      return http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    }

    try {
      var response = await sendRequest(strictMode: true);

      if (response.statusCode == 400) {
        response = await sendRequest(strictMode: false);
      }

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
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // --- HELPER FUNCTION UNTUK KIRIM REQUEST ---
    Future<http.Response> sendRequest({bool useTemperature = true}) {
      final Map<String, dynamic> body = {
        "model": model,
        "messages": [
          {"role": "system", "content": _systemInstruction},
          {"role": "user", "content": "Terjemahkan teks Pāli ini:\n\n$text"},
        ],
        // Param lain (max_completion_tokens lebih aman buat model baru drpd max_tokens)
        // Tapi max_tokens biasanya masih backward compatible.
      };

      // Hanya masukkan temperature jika diminta
      if (useTemperature) {
        body["temperature"] = 0.3;
      }

      return http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );
    }

    try {
      // PERCOBAAN 1: Kirim dengan settingan ideal (pakai temperature)
      var response = await sendRequest(useTemperature: true);

      // Jika error 400 (Bad Request), kemungkinan besar karena parameter tidak didukung
      // oleh model tersebut (misal: o1, gpt-5, atau gpt-6 nanti).
      if (response.statusCode == 400) {
        // PERCOBAAN 2: Retry otomatis tanpa parameter temperature (Safe Mode)
        response = await sendRequest(useTemperature: false);
      }

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
    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    };

    Future<http.Response> sendRequest({bool useTemperature = true}) {
      final Map<String, dynamic> body = {
        "model": model,
        "max_tokens": 4096, // SUDAH DINAIKKAN (sebelumnya 2000)
        "system": _systemInstruction,
        "messages": [
          {"role": "user", "content": "Terjemahkan teks ini:\n$text"},
        ],
      };

      if (useTemperature) {
        body["temperature"] = 0.3;
      }

      return http.post(url, headers: headers, body: jsonEncode(body));
    }

    try {
      var response = await sendRequest(useTemperature: true);

      if (response.statusCode == 400) {
        response = await sendRequest(useTemperature: false);
      }

      return _handleAnthropicResponse(response);
    } catch (e) {
      return AITranslationResult(
        translatedText: '',
        error: 'Connection failed: $e',
        success: false,
      );
    }
  }

  // ============================================
  // UPDATE 1: GANTI TOKEN LIMIT (Lakukan di method Gemini, OpenAI, Claude juga)
  // Ganti angka 2000 menjadi 4096 di semua tempat 'max_tokens' atau 'maxOutputTokens'
  // ============================================

  // Contoh di Gemini: "maxOutputTokens": 4096
  // Contoh di OpenAI/Claude: "max_tokens": 4096

  // ============================================
  // UPDATE 2: OPENROUTER YANG LEBIH PINTAR (ANTI ERROR 400)
  // ============================================

  static Future<AITranslationResult> _translateWithOpenRouter(
    String text,
    String apiKey,
    String model,
  ) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'HTTP-Referer': 'https://github.com/renaldoaluska/tipitaka',
      'X-Title': 'myDhamma Pali Translator',
    };

    Future<http.Response> sendRequest({bool strictMode = true}) {
      final Map<String, dynamic> body = {
        "model": model,
        "messages": [
          {"role": "system", "content": _systemInstruction},
          {
            "role": "user",
            "content":
                "Terjemahkan teks Pāli ini ke Bahasa Indonesia:\n\n$text",
          },
        ],
      };

      if (strictMode) {
        body["temperature"] = 0.3;
        body["max_tokens"] = 4096;
      }

      return http.post(url, headers: headers, body: jsonEncode(body));
    }

    try {
      var response = await sendRequest(strictMode: true);

      if (response.statusCode == 400) {
        response = await sendRequest(strictMode: false);
      }

      //  GANTI INI: Panggil handler khusus OpenRouter
      return _handleOpenRouterResponse(response);
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
  // ============================================
  // RESPONSE HANDLERS (SUDAH DIPERBAIKI BIAR GAK CUMA "ERROR 404")
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
        error: 'AI tidak memberikan jawaban.',
        success: false,
      );
    }
    //  HANDLE ERROR SPESIFIK
    else if (response.statusCode == 404) {
      return AITranslationResult(
        translatedText: '',
        error: 'Model tidak ditemukan (404). Cek ejaan nama model.',
        success: false,
      );
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Limit kuota habis (429). Tunggu sebentar.',
        success: false,
      );
    } else if (response.statusCode == 400) {
      final data = jsonDecode(response.body);
      final errorMsg = data['error']?['message'] ?? 'Request tidak valid.';
      return AITranslationResult(
        translatedText: '',
        error: 'Error 400: $errorMsg',
        success: false,
      );
    } else if (response.statusCode == 403) {
      return AITranslationResult(
        translatedText: '',
        error: 'Akses ditolak (403). Cek API Key atau Lokasi.',
        success: false,
      );
    } else {
      return AITranslationResult(
        translatedText: '',
        error: 'Server Error (${response.statusCode})',
        success: false,
      );
    }
  }

  static AITranslationResult _handleOpenAIResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['choices'][0]['message']['content'];
      return AITranslationResult(translatedText: result ?? '', success: true);
    }
    //  HANDLE ERROR SPESIFIK
    else if (response.statusCode == 404) {
      return AITranslationResult(
        translatedText: '',
        error: 'Model tidak ditemukan (404). Cek ejaan nama model.',
        success: false,
      );
    } else if (response.statusCode == 401) {
      return AITranslationResult(
        translatedText: '',
        error: 'API Key salah/tidak valid (401).',
        success: false,
      );
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Limit kuota habis (429). Cek saldo OpenAI.',
        success: false,
      );
    } else {
      final data = jsonDecode(response.body);
      final msg = data['error']?['message'] ?? 'Error ${response.statusCode}';
      return AITranslationResult(
        translatedText: '',
        error: msg,
        success: false,
      );
    }
  }

  static AITranslationResult _handleAnthropicResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['content'][0]['text'];
      return AITranslationResult(translatedText: result ?? '', success: true);
    }
    //  HANDLE ERROR SPESIFIK
    else if (response.statusCode == 404) {
      return AITranslationResult(
        translatedText: '',
        error: 'Model tidak ditemukan (404). Cek ejaan nama model.',
        success: false,
      );
    } else if (response.statusCode == 401) {
      return AITranslationResult(
        translatedText: '',
        error: 'API Key salah/tidak valid (401).',
        success: false,
      );
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Limit kuota habis (429).',
        success: false,
      );
    } else {
      final data = jsonDecode(response.body);
      final msg = data['error']?['message'] ?? 'Error ${response.statusCode}';
      return AITranslationResult(
        translatedText: '',
        error: msg,
        success: false,
      );
    }
  }

  //  HANDLER KHUSUS OPENROUTER
  static AITranslationResult _handleOpenRouterResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // OpenRouter kadang return error di dalam body meski status 200 (jarang, tapi mungkin)
      if (data['error'] != null) {
        final msg = data['error']['message'] ?? 'Unknown OpenRouter Error';
        return AITranslationResult(
          translatedText: '',
          error: 'OpenRouter: $msg',
          success: false,
        );
      }
      final result = data['choices']?[0]?['message']?['content'];
      return AITranslationResult(translatedText: result ?? '', success: true);
    }
    // Error Spesifik OpenRouter
    else if (response.statusCode == 401) {
      return AITranslationResult(
        translatedText: '',
        error: 'API Key OpenRouter salah/tidak valid.',
        success: false,
      );
    } else if (response.statusCode == 402) {
      return AITranslationResult(
        translatedText: '',
        error: 'Saldo OpenRouter habis (Insufficient Credits).',
        success: false,
      );
    } else if (response.statusCode == 404) {
      return AITranslationResult(
        translatedText: '',
        error: 'Model tidak ditemukan di OpenRouter. Cek nama model.',
        success: false,
      );
    } else if (response.statusCode == 429) {
      return AITranslationResult(
        translatedText: '',
        error: 'Rate Limit OpenRouter tercapai.',
        success: false,
      );
    } else if (response.statusCode == 502 || response.statusCode == 503) {
      return AITranslationResult(
        translatedText: '',
        error: 'Provider model sedang down/sibuk. Coba model lain.',
        success: false,
      );
    } else {
      // Fallback pesan error dari body response
      try {
        final data = jsonDecode(response.body);
        final msg = data['error']?['message'] ?? 'Error ${response.statusCode}';
        return AITranslationResult(
          translatedText: '',
          error: msg,
          success: false,
        );
      } catch (_) {
        return AITranslationResult(
          translatedText: '',
          error: 'Error ${response.statusCode}',
          success: false,
        );
      }
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
        return 'Contoh: gemini-2.5-flash';
      case AIProvider.openai:
        return 'Contoh: gpt-4.1';
      case AIProvider.anthropic:
        return 'Contoh: claude-3-5-haiku-20241022';
      case AIProvider.openrouter:
        return 'Contoh: google/gemini-2.5-flash:free';
    }
  }
}
