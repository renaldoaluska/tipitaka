import 'api.dart';

class SuttaService {
  /// =========================
  /// MENU
  /// =========================
  static Future<dynamic> fetchMenu(String uid, {String language = "id"}) {
    return Api.get(
      "menu/$uid",
      query: {"language": language},
      ttl: const Duration(minutes: 30),
    );
  }

  /// =========================
  /// SUTTAPLEX (metadata)
  /// =========================
  static Future<dynamic> fetchSuttaplex(String uid, {String language = "id"}) {
    return Api.get(
      "suttaplex/$uid",
      query: {"language": language},
      ttl: const Duration(minutes: 30),
    );
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

    return data;
  }
}
