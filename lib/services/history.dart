import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryService {
  static const String _keyHistory = 'recently_viewed';
  static const String _keyBookmarks = 'bookmarks';
  static const int _maxHistory = 3; // Simpan max n history

  // ═══════════════════════════════════════════════════════════
  // 📖 RECENTLY VIEWED
  // ═══════════════════════════════════════════════════════════

  static Future<void> addToHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_keyHistory) ?? [];

    // Convert item ke JSON string
    final itemJson = jsonEncode(item);

    // Hapus duplikat (kalau ada)
    history.removeWhere((h) {
      final decoded = jsonDecode(h);
      return decoded['uid'] == item['uid'];
    });

    // Tambah di posisi pertama
    history.insert(0, itemJson);

    // Limit ke max 10
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }

    await prefs.setStringList(_keyHistory, history);
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_keyHistory) ?? [];

    return history.map((h) {
      return Map<String, dynamic>.from(jsonDecode(h));
    }).toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔖 BOOKMARKS
  // ═══════════════════════════════════════════════════════════

  static Future<void> toggleBookmark(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarks = prefs.getStringList(_keyBookmarks) ?? [];

    //final itemJson = jsonEncode(item);

    final index = bookmarks.indexWhere((b) {
      final decoded = jsonDecode(b);
      return decoded['uid'] == item['uid'];
    });

    if (index >= 0) {
      bookmarks.removeAt(index);
    } else {
      //  TAMBAH: Default note kosong kalau gak ada
      if (!item.containsKey('note')) {
        item['note'] = '';
      }
      bookmarks.insert(0, jsonEncode(item));
    }

    await prefs.setStringList(_keyBookmarks, bookmarks);
  }

  //  FUNGSI BARU: Update note bookmark
  static Future<void> updateBookmarkNote(String uid, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarks = prefs.getStringList(_keyBookmarks) ?? [];

    final index = bookmarks.indexWhere((b) {
      final decoded = jsonDecode(b);
      return decoded['uid'] == uid;
    });

    if (index >= 0) {
      final item = jsonDecode(bookmarks[index]);
      item['note'] = note;
      bookmarks[index] = jsonEncode(item);
      await prefs.setStringList(_keyBookmarks, bookmarks);
    }
  }

  //  FUNGSI BARU: Delete multiple bookmarks
  static Future<void> deleteBookmarks(List<String> uids) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarks = prefs.getStringList(_keyBookmarks) ?? [];

    bookmarks.removeWhere((b) {
      final decoded = jsonDecode(b);
      return uids.contains(decoded['uid']);
    });

    await prefs.setStringList(_keyBookmarks, bookmarks);
  }

  static Future<bool> isBookmarked(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarks = prefs.getStringList(_keyBookmarks) ?? [];

    return bookmarks.any((b) {
      final decoded = jsonDecode(b);
      return decoded['uid'] == uid;
    });
  }

  static Future<List<Map<String, dynamic>>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarks = prefs.getStringList(_keyBookmarks) ?? [];

    return bookmarks.map((b) {
      return Map<String, dynamic>.from(jsonDecode(b));
    }).toList();
  }

  static Future<void> removeBookmark(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarks = prefs.getStringList(_keyBookmarks) ?? [];

    bookmarks.removeWhere((b) {
      final decoded = jsonDecode(b);
      return decoded['uid'] == uid;
    });

    await prefs.setStringList(_keyBookmarks, bookmarks);
  }
}
