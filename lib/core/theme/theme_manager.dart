import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeManager extends ChangeNotifier {
  static const String _key = 'theme_mode_v2';
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

    //  HAPUS if-else kosong, langsung notifyListeners aja
    notifyListeners();
  }

  Future<void> toggleTheme(bool isCurrentlyDark) async {
    _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      _themeMode == ThemeMode.light ? 'light' : 'dark',
    );

    //  HAPUS Future.delayed - ga perlu lagi!
    notifyListeners();
  }

  // Theme definitions tetap sama
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.deepOrange,
    scaffoldBackgroundColor: Colors.grey[50],
    colorScheme: ColorScheme.light(
      primary: Colors.deepOrange,
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: const Color(0xFF757575),
      secondary: Colors.redAccent,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    primaryTextTheme: GoogleFonts.interTextTheme(),
    useMaterial3: true,
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.deepOrange,
    scaffoldBackgroundColor: Colors.grey[900],
    colorScheme: ColorScheme.dark(
      primary: Colors.deepOrange,
      surface: const Color(0xFF303030),
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFBDBDBD),
      secondary: Colors.amber,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    primaryTextTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().primaryTextTheme,
    ),
    useMaterial3: true,
  );
}
