import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DpdService {
  static const String _baseUrl = "https://www.dpdict.net";
  static const String _historyKey =
      "dpd_search_history"; // Key buat SharedPreferences

  static const String _favoritesKey = "dpd_favorites_key";

  // 1. Ganti List biasa jadi ValueNotifier
  final ValueNotifier<List<String>> historyNotifier =
      ValueNotifier<List<String>>([]);
  final ValueNotifier<List<String>> favoritesNotifier =
      ValueNotifier<List<String>>([]);

  // Internal list buat bantu olah data
  final List<String> _historyList = [];

  static const int _maxHistorySize = 10;
  static const int _maxCacheSize = 100;

  // --- LOGIKA FAVORIT ---
  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_favoritesKey) ?? [];
    favoritesNotifier.value = List.unmodifiable(saved);
  }

  //  SINGLETON PATTERN BIAR GAK BIKIN INSTANCE BANYAK
  static final DpdService _instance = DpdService._internal();
  factory DpdService() => _instance;
  DpdService._internal();

  // 1. TAMBAHKAN FLAG INITIALIZATION
  bool _isInitialized = false;
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await _loadHistoryFromDisk(); // Load history
    await loadFavorites(); //  Tambah ini biar favorit juga ke-load
    _isInitialized = true; // Indikator sudah siap
  }

  //  IN-MEMORY CACHE BUAT HASIL LOOKUP
  final Map<String, Map<String, dynamic>?> _cache = {};

  //  REUSABLE HTTP CLIENT (lebih efisien dari bikin baru terus)
  final http.Client _client = http.Client();

  //  TRACKING REQUEST YANG LAGI JALAN BIAR GAK DUPLICATE
  final Map<String, Future<Map<String, dynamic>?>> _ongoingRequests = {};

  // Shortcut buat dapetin list-nya aja
  List<String> get history => historyNotifier.value;

  Future<void> _loadHistoryFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList(_historyKey);
    if (savedHistory != null) {
      _historyList.clear();
      _historyList.addAll(savedHistory); // Sinkronkan ke internal list
      historyNotifier.value = List.unmodifiable(_historyList); // Update UI
    }
  }

  /// Lookup kata dengan caching + deduplication + safety
  Future<Map<String, dynamic>?> lookup(String word) async {
    // --- TAMBAHAN SAFETY 1 ---
    // Pastikan data lama sudah terbaca dari disk sebelum operasi apapun
    if (!_isInitialized) await ensureInitialized();

    final cleanWord = _sanitizePaliWord(word);
    if (cleanWord.isEmpty) return null;

    // 1. CEK CACHE
    if (_cache.containsKey(cleanWord)) {
      final data = _cache[cleanWord];

      // Update LRU Position
      _cache.remove(cleanWord);
      _cache[cleanWord] = data;

      // --- TAMBAHAN LOGIKA 2 ---
      // Hanya masukkan ke histori jika kata tersebut valid (bukan null)
      if (data != null) {
        _addToHistory(cleanWord);
      }
      return data;
    }

    // 2. CEK ONGOING REQUEST
    if (_ongoingRequests.containsKey(cleanWord)) {
      return _ongoingRequests[cleanWord];
    }

    final request = _performLookup(cleanWord);
    _ongoingRequests[cleanWord] = request;

    try {
      final result = await request;
      _addToCache(cleanWord, result);

      // --- TAMBAHAN LOGIKA 3 ---
      // Hanya simpan ke histori kalau kata ditemukan
      if (result != null) {
        _addToHistory(cleanWord);
      }

      return result;
    } finally {
      _ongoingRequests.remove(cleanWord);
    }
  }

  /// Actual HTTP request logic
  Future<Map<String, dynamic>?> _performLookup(String cleanWord) async {
    try {
      final url = "$_baseUrl/search_json?q=$cleanWord";
      if (kDebugMode) {
        print("🌐 Searching: $url");
      }

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              "Accept": "application/json",
              "User-Agent": "DPD-Flutter-App", //  Good practice
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw DpdTimeoutException(
                'Request timeout setelah 30 detik - cek koneksi internet',
              );
            },
          );

      if (kDebugMode) {
        print("📡 Status: ${response.statusCode}");
      }

      if (response.statusCode == 200) {
        //  HANDLE EMPTY RESPONSE
        if (response.body.isEmpty) {
          if (kDebugMode) {
            print("❌ Empty response body");
          }
          return null;
        }

        final data = jsonDecode(response.body);

        if (data == null || (data is Map && data.isEmpty)) {
          if (kDebugMode) {
            print("❌ Kata '$cleanWord' tidak ditemukan di DPD");
          }
          return null;
        }

        if (kDebugMode) {
          print(" Ditemukan!");
        }
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        //  HANDLE 404 EXPLICITLY
        if (kDebugMode) {
          print("❌ Kata tidak ditemukan (404)");
        }
        return null;
      } else if (response.statusCode >= 500) {
        //  SERVER ERROR
        throw DpdServerException('Server error (${response.statusCode})');
      } else {
        //  OTHER HTTP ERRORS
        throw DpdHttpException(
          'HTTP Error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DpdException {
      //  RE-THROW CUSTOM EXCEPTIONS
      rethrow;
    } on http.ClientException catch (e) {
      //  NETWORK ERRORS
      throw DpdNetworkException('Network error: ${e.message}');
    } on FormatException catch (e) {
      //  JSON PARSE ERRORS
      throw DpdParseException('Failed to parse response: ${e.message}');
    } catch (e) {
      //  CATCH-ALL
      if (kDebugMode) {
        print("💥 Unexpected error: $e");
      }
      throw DpdException('Unexpected error: $e');
    }
  }

  /// Add to cache with LRU-like behavior
  void _addToCache(String word, Map<String, dynamic>? result) {
    //  KALO CACHE PENUH, HAPUS YANG PALING LAMA
    if (_cache.length >= _maxCacheSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
      if (kDebugMode) {
        print("🗑️ Cache full, removed: $firstKey");
      }
    }

    _cache[word] = result;
  }

  /// Clear cache manually (misal user refresh)
  void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      print("🧹 Cache cleared");
    }
  }

  /// Clear specific word from cache
  void clearCacheFor(String word) {
    final cleanWord = _sanitizePaliWord(word);
    _cache.remove(cleanWord);
  }

  /// Get cache stats (debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'keys': _cache.keys.toList(),
    };
  }

  /// Sanitize Pali word
  String _sanitizePaliWord(String word) {
    return word
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}]', unicode: true), '')
        .trim();
  }

  // Panggil ini di constructor DpdService buat muat data dari disk

  Future<void> toggleFavorite(String word) async {
    final List<String> current = List.from(favoritesNotifier.value);

    if (current.contains(word)) {
      current.remove(word);
    } else {
      current.insert(0, word); // Yang baru ditambah ada di paling atas
    }

    favoritesNotifier.value = List.unmodifiable(current);
    await _saveFavoritesToDisk();
  }

  Future<void> clearAllFavorites() async {
    favoritesNotifier.value = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey); // Hapus permanen dari disk
  }

  Future<void> _saveFavoritesToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favoritesNotifier.value);
  }

  void _addToHistory(String word) {
    _historyList.remove(word); // Hapus biar gak duplikat
    _historyList.insert(0, word); // Taruh paling atas

    if (_historyList.length > _maxHistorySize) {
      _historyList.removeLast();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      historyNotifier.value = List.unmodifiable(_historyList);
    });

    _saveHistoryToDisk(_historyList);
  }

  Future<void> _saveHistoryToDisk(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, list);
  }

  ///  DISPOSE METHOD BUAT CLEANUP
  void dispose() {
    _client.close();
    _cache.clear();
    _ongoingRequests.clear();
    if (kDebugMode) {
      print("🔚 DpdService disposed");
    }
  }
}

//  CUSTOM EXCEPTIONS BUAT ERROR HANDLING YANG LEBIH BAIK
class DpdException implements Exception {
  final String message;
  DpdException(this.message);

  @override
  String toString() => message;
}

class DpdTimeoutException extends DpdException {
  DpdTimeoutException(super.message);
}

class DpdNetworkException extends DpdException {
  DpdNetworkException(super.message);
}

class DpdServerException extends DpdException {
  DpdServerException(super.message);
}

class DpdHttpException extends DpdException {
  final int statusCode;
  DpdHttpException(super.message, {required this.statusCode});
}

class DpdParseException extends DpdException {
  DpdParseException(super.message);
}
