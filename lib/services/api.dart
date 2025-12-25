import 'dart:collection';
import 'package:dio/dio.dart';

class Api {
  Api._(); // no instance

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://suttacentral.net/api/",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// =========================
  /// SIMPLE IN-MEMORY CACHE
  /// =========================

  static final Map<String, _CacheEntry> _cache = HashMap();
  static final Map<String, Future<dynamic>> _inflight = {};

  /// default TTL
  static const Duration _defaultTTL = Duration(minutes: 10);

  /// =========================
  /// PUBLIC GET
  /// =========================
  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Duration ttl = _defaultTTL,
    bool forceRefresh = false,
  }) async {
    final key = _makeKey(path, query);

    // 🔁 return inflight request
    if (_inflight.containsKey(key)) {
      return _inflight[key]!;
    }

    // 🧠 cache hit
    if (!forceRefresh && _cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (!entry.isExpired) {
        return entry.data;
      } else {
        _cache.remove(key);
      }
    }

    // 🌐 fetch from API
    final future = _dio
        .get(path, queryParameters: query)
        .then((res) {
          _cache[key] = _CacheEntry(
            data: res.data,
            expiry: DateTime.now().add(ttl),
          );
          return res.data;
        })
        .catchError((e) {
          throw Exception("API error [$path]: $e");
        })
        .whenComplete(() {
          _inflight.remove(key);
        });

    _inflight[key] = future;
    return future;
  }

  /// =========================
  /// CACHE CONTROL
  /// =========================

  static void clear() => _cache.clear();

  static void invalidate(String path, {Map<String, dynamic>? query}) {
    _cache.remove(_makeKey(path, query));
  }

  /// =========================
  /// INTERNAL
  /// =========================

  static String _makeKey(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return path;
    final sorted = Map.fromEntries(
      query.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return "$path?${sorted.entries.map((e) => "${e.key}=${e.value}").join("&")}";
  }
}

/// =========================
/// CACHE ENTRY
/// =========================

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}
