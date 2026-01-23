import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DpdService {
  static const String _baseUrl = "https://www.dpdict.net";

  // ✅ SINGLETON PATTERN BIAR GAK BIKIN INSTANCE BANYAK
  static final DpdService _instance = DpdService._internal();
  factory DpdService() => _instance;
  DpdService._internal();

  // ✅ IN-MEMORY CACHE BUAT HASIL LOOKUP
  final Map<String, Map<String, dynamic>?> _cache = {};

  // ✅ REUSABLE HTTP CLIENT (lebih efisien dari bikin baru terus)
  final http.Client _client = http.Client();

  // ✅ TRACKING REQUEST YANG LAGI JALAN BIAR GAK DUPLICATE
  final Map<String, Future<Map<String, dynamic>?>> _ongoingRequests = {};

  // ✅ MAX CACHE SIZE BIAR GAK MAKAN MEMORY KEBANYAKAN
  static const int _maxCacheSize = 100;

  /// Lookup kata dengan caching + deduplication
  Future<Map<String, dynamic>?> lookup(String word) async {
    final cleanWord = _sanitizePaliWord(word);

    if (cleanWord.isEmpty) return null;

    // ✅ CEK CACHE DULU
    if (_cache.containsKey(cleanWord)) {
      if (kDebugMode) {
        print("💾 Cache hit: $cleanWord");
      }

      // TAMBAHAN: Pindahin ke "paling baru" biar jadi True LRU
      final data = _cache[cleanWord];
      _cache.remove(cleanWord); // Hapus posisi lama
      _cache[cleanWord] = data; // Masukin lagi di posisi paling belakang

      return data;
    }

    // ✅ CEK ADA REQUEST YANG SAMA LAGI JALAN GAK
    if (_ongoingRequests.containsKey(cleanWord)) {
      if (kDebugMode) {
        print("⏳ Nunggu request yang udah jalan: $cleanWord");
      }
      return _ongoingRequests[cleanWord];
    }

    // ✅ BIKIN REQUEST BARU
    final request = _performLookup(cleanWord);
    _ongoingRequests[cleanWord] = request;

    try {
      final result = await request;

      // ✅ SIMPEN KE CACHE
      _addToCache(cleanWord, result);

      return result;
    } finally {
      // ✅ BERSIHIN TRACKING
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
              "User-Agent": "DPD-Flutter-App", // ✅ Good practice
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
        // ✅ HANDLE EMPTY RESPONSE
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
          print("✅ Ditemukan!");
        }
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // ✅ HANDLE 404 EXPLICITLY
        if (kDebugMode) {
          print("❌ Kata tidak ditemukan (404)");
        }
        return null;
      } else if (response.statusCode >= 500) {
        // ✅ SERVER ERROR
        throw DpdServerException('Server error (${response.statusCode})');
      } else {
        // ✅ OTHER HTTP ERRORS
        throw DpdHttpException(
          'HTTP Error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DpdException {
      // ✅ RE-THROW CUSTOM EXCEPTIONS
      rethrow;
    } on http.ClientException catch (e) {
      // ✅ NETWORK ERRORS
      throw DpdNetworkException('Network error: ${e.message}');
    } on FormatException catch (e) {
      // ✅ JSON PARSE ERRORS
      throw DpdParseException('Failed to parse response: ${e.message}');
    } catch (e) {
      // ✅ CATCH-ALL
      if (kDebugMode) {
        print("💥 Unexpected error: $e");
      }
      throw DpdException('Unexpected error: $e');
    }
  }

  /// Add to cache with LRU-like behavior
  void _addToCache(String word, Map<String, dynamic>? result) {
    // ✅ KALO CACHE PENUH, HAPUS YANG PALING LAMA
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

  /// ✅ DISPOSE METHOD BUAT CLEANUP
  void dispose() {
    _client.close();
    _cache.clear();
    _ongoingRequests.clear();
    if (kDebugMode) {
      print("🔚 DpdService disposed");
    }
  }
}

// ✅ CUSTOM EXCEPTIONS BUAT ERROR HANDLING YANG LEBIH BAIK
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
