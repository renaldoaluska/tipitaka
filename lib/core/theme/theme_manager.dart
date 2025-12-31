import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  // Ganti key biar gak bentrok sama settingan lama
  static const String _key = 'theme_mode_v2';

  // Default System biar ngikut HP pas baru install
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeManager() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_key);

    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  // ✅ BAGIAN INI YANG BIKIN ERROR SEBELUMNYA
  // Sekarang kita tambahin parameter (bool isCurrentlyDark) biar cocok sama HeaderDepan
  Future<void> toggleTheme(bool isCurrentlyDark) async {
    // Kalau skrg gelap -> paksa jadi Light
    // Kalau skrg terang -> paksa jadi Dark
    _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    // Simpan string 'light'/'dark' biar jelas
    await prefs.setString(
      _key,
      _themeMode == ThemeMode.light ? 'light' : 'dark',
    );

    notifyListeners();
  }

  // ==========================================================
  // 👇 INI BAGIAN WARNA (GAK SAYA UBAH SAMA SEKALI) 👇
  // ==========================================================

  // ✅ Light theme
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.deepOrange,
    scaffoldBackgroundColor: Colors.grey[50],
    colorScheme: ColorScheme.light(
      primary: Colors.deepOrange,
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: Colors.grey[600]!,
      secondary: Colors.blueGrey,
    ),
    useMaterial3: true,
  );

  // ✅ Dark theme
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.deepOrange,
    scaffoldBackgroundColor: Colors.grey[900],
    colorScheme: ColorScheme.dark(
      primary: Colors.deepOrange,
      surface: Colors.grey[850]!,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.grey[400]!,
      secondary: Colors.amber,
    ),
    useMaterial3: true,
  );
}
