import 'api.dart';
import 'package:flutter/foundation.dart';

class SuttaService {
  // ✅ 1. Variable Cache (Nyangkut di RAM)
  static final Map<String, dynamic> _memoryCache = {};

  /// Fungsi bantu buat bersihin cache (opsional, bisa dipanggil kalau mau refresh total)
  static void clearCache() {
    _memoryCache.clear();
  }

  /// =========================
  /// MENU
  /// =========================
  static Future<dynamic> fetchMenu(String uid, {String language = "id"}) async {
    // 1. Bikin Key Unik
    final String cacheKey = "menu_${uid}_$language";

    // 2. Cek Cache
    if (_memoryCache.containsKey(cacheKey)) {
      // print("⚡ Cache HIT: Menu $uid");
      return _memoryCache[cacheKey];
    }

    // 3. Fetch Network
    try {
      final response = await Api.get(
        "menu/$uid",
        query: {"language": language},
        ttl: const Duration(minutes: 30),
      );

      // 4. Simpan ke Cache
      _memoryCache[cacheKey] = response;
      return response;
    } catch (e, stackTrace) {
      debugPrint("❌ fetchMenu error for $uid: $e");
      debugPrint("Stack: $stackTrace");
      rethrow;
    }
  }

  /// =========================
  /// SUTTAPLEX (metadata)
  /// =========================
  static Future<dynamic> fetchSuttaplex(
    String uid, {
    String language = "id",
  }) async {
    final String cacheKey = "suttaplex_${uid}_$language";

    if (_memoryCache.containsKey(cacheKey)) {
      // print("⚡ Cache HIT: Suttaplex $uid");
      return _memoryCache[cacheKey];
    }

    try {
      final response = await Api.get(
        "suttaplex/$uid",
        query: {"language": language},
        ttl: const Duration(minutes: 30),
      );

      _memoryCache[cacheKey] = response;
      return response;
    } catch (e, stackTrace) {
      debugPrint("❌ fetchSuttaplex error for $uid: $e");
      debugPrint("Stack: $stackTrace");
      rethrow;
    }
  }

  /// =========================
  /// TEXT / TRANSLATION
  /// =========================
  static Future<Map<String, dynamic>> fetchTextForTranslation({
    required String uid,
    required String authorUid,
    required String lang,
    required bool segmented,
    String siteLanguage = "id",
  }) async {
    // Key unik kombinasi parameter (include siteLanguage untuk safety)
    final String cacheKey =
        "text_${uid}_${authorUid}_${lang}_${segmented}_$siteLanguage";

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey] as Map<String, dynamic>;
    }

    try {
      final raw = await Api.get(
        segmented ? "bilarasuttas/$uid/$authorUid" : "suttas/$uid/$authorUid",
        query: segmented
            ? {"lang": lang}
            : {"lang": lang, "siteLanguage": siteLanguage},
        ttl: const Duration(hours: 6),
      );

      final data = Map<String, dynamic>.from(raw);

      // flatten segments biar UI gampang
      if (data.containsKey("translation_text")) {
        data["segments"] = data["translation_text"];
      } else if (data.containsKey("comment_text")) {
        data["segments"] = data["comment_text"];
      } else if (data.containsKey("translation") &&
          data["translation"] is Map &&
          data["translation"].containsKey("segments")) {
        data["segments"] = data["translation"]["segments"];
      } else if (data.containsKey("root_text") &&
          data["root_text"] is Map &&
          data["root_text"].containsKey("segments")) {
        data["segments"] = data["root_text"]["segments"];
      }

      // Simpan hasil olahan ke cache
      _memoryCache[cacheKey] = data;
      return data;
    } catch (e, stackTrace) {
      debugPrint("❌ fetchTextForTranslation error for $uid: $e");
      debugPrint("Stack: $stackTrace");
      rethrow;
    }
  }

  /// =========================
  /// FULL SUTTA (isi + metadata navigasi)
  /// =========================
  static Future<Map<String, dynamic>> fetchFullSutta({
    required String uid,
    required String authorUid,
    required String lang,
    required bool segmented,
    String siteLanguage = "id",
  }) async {
    // Include siteLanguage di cache key untuk mencegah collision
    final String cacheKey =
        "fullsutta_${uid}_${authorUid}_${lang}_${segmented}_$siteLanguage";

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey] as Map<String, dynamic>;
    }

    try {
      Map<String, dynamic> result;

      if (segmented) {
        // 1. Ambil isi teks (bilarasuttas) -> SUMBER UTAMA KONTEN
        final bilara =
            await Api.get(
                  "bilarasuttas/$uid/$authorUid",
                  query: {"lang": lang},
                  ttl: const Duration(hours: 6),
                )
                as Map<String, dynamic>;

        // 2. Ambil metadata navigasi (suttas) -> SUMBER UTAMA METADATA
        final meta =
            await Api.get(
                  "suttas/$uid/$authorUid",
                  query: {"lang": lang, "siteLanguage": siteLanguage},
                  ttl: const Duration(minutes: 30),
                )
                as Map<String, dynamic>;

        //  debugPrint("=== FETCH FULL SUTTA MERGE DEBUG ===");
        //  debugPrint("📦 UID: $uid | Author: $authorUid | Lang: $lang");

        // 3. Siapkan container hasil merge
        final merged = <String, dynamic>{
          ...bilara, // Base-nya konten bilara
          "segmented": true,
          "author_uid": authorUid,
          "lang": lang,
        };

        // --- LOGIC MERGE ROOT_TEXT (PALI) ---
        if (bilara["root_text"] != null || meta["root_text"] != null) {
          final bilaraRoot = bilara["root_text"] as Map<String, dynamic>? ?? {};
          final metaRoot = meta["root_text"] as Map<String, dynamic>? ?? {};

          // Kuncinya: Metadata (navigasi) AMBIL DARI META, Konten (segmen) AMBIL DARI BILARA
          final metadataKeys = [
            'previous',
            'next',
            'vagga_uid',
            'author_uid',
            'lang',
            'title',
            'acronym',
            'uid',
          ];

          // Ambil SEMUA segmen teks dari Bilara
          final contentMap = Map<String, dynamic>.from(bilaraRoot)
            ..removeWhere(
              (k, v) => metadataKeys.contains(k),
            ); // Hapus metadata bawaan bilara (kalo ada)

          // Ambil SEMUA metadata dari Meta (Legacy API)
          final metadataMap = Map<String, dynamic>.from(metaRoot)
            ..removeWhere(
              (k, v) => !metadataKeys.contains(k),
            ); // Cuma ambil metadata

          // Gabungkan: Metadata + Konten
          merged["root_text"] = {...metadataMap, ...contentMap};

          // debugPrint(
          //   "✅ Merged root_text: ${metadataMap.keys.length} meta keys + ${contentMap.keys.length} content segments",
          // );
          // debugPrint("   🔗 Vagga: ${metadataMap['vagga_uid']}");
          // debugPrint("   ⬅️ Prev: ${metadataMap['previous']?['uid']}");
          // debugPrint("   ➡️ Next: ${metadataMap['next']?['uid']}");
        }

        // --- LOGIC MERGE TRANSLATION_TEXT ---
        if (bilara["translation_text"] != null ||
            meta["translation_text"] != null) {
          final bilaraTrans =
              bilara["translation_text"] as Map<String, dynamic>? ?? {};
          final metaTrans =
              meta["translation_text"] as Map<String, dynamic>? ?? {};

          final metadataKeys = [
            'previous',
            'next',
            'vagga_uid',
            'author_uid',
            'lang',
            'title',
            'acronym',
            'uid',
            'text',
          ];

          final contentMap = Map<String, dynamic>.from(bilaraTrans)
            ..removeWhere((k, v) => metadataKeys.contains(k));

          final metadataMap = Map<String, dynamic>.from(metaTrans)
            ..removeWhere((k, v) => !metadataKeys.contains(k));

          merged["translation_text"] = {...metadataMap, ...contentMap};

          if (contentMap.isNotEmpty) {
            debugPrint(
              "✅ Merged translation_text: ${metadataMap.keys.length} meta keys + ${contentMap.keys.length} content segments",
            );
          }
        }

        // --- SUTTAPLEX (Opsional tapi berguna) ---
        if (meta["suttaplex"] != null) {
          merged["suttaplex"] = meta["suttaplex"];
        }

        // Preserve keys_order (PENTING BUAT URUTAN)
        if (bilara["keys_order"] != null) {
          merged["keys_order"] = bilara["keys_order"];
        }

        debugPrint("=====================================\n");

        result = merged;
      } else {
        // Non-Segmented: Langsung dari Legacy API
        final data =
            await Api.get(
                  "suttas/$uid/$authorUid",
                  query: {"lang": lang, "siteLanguage": siteLanguage},
                  ttl: const Duration(hours: 6),
                )
                as Map<String, dynamic>;

        result = {
          ...data,
          "segmented": false,
          "author_uid": authorUid,
          "lang": lang,
        };
      }

      _memoryCache[cacheKey] = result;
      return result;
    } catch (e, stackTrace) {
      debugPrint("❌ fetchFullSutta error for $uid: $e");
      debugPrint("Stack: $stackTrace");
      rethrow;
    }
  }
}
