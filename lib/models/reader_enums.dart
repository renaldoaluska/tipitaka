import 'package:flutter/material.dart';

enum ViewMode { translationOnly, lineByLine, sideBySide }

enum ReaderTheme { light, light2, sepia, dark, dark2, custom }

class ReaderThemeStyle {
  final Color bg;
  final Color text;
  final Color pali;

  ReaderThemeStyle({required this.bg, required this.text, required this.pali});

  static ReaderThemeStyle getStyle(
    ReaderTheme theme, {
    Color? customBg,
    Color? customText,
    Color? customPali,
  }) {
    switch (theme) {
      case ReaderTheme.light:
        return ReaderThemeStyle(
          bg: Colors.white,
          text: Colors.black,
          pali: const Color(0xFF8B4513),
        );
      case ReaderTheme.light2:
        return ReaderThemeStyle(
          bg: const Color(0xFFFAFAFA),
          text: const Color(0xFF424242),
          pali: const Color(0xFFA1887F),
        );
      case ReaderTheme.sepia:
        return ReaderThemeStyle(
          bg: const Color(0xFFF4ECD8), // Krem Terang
          text: const Color(0xFF5D4037), // Coklat Tua ← Teks Utama
          pali: const Color(0xFF3E2723),
        );
      case ReaderTheme.dark:
        return ReaderThemeStyle(
          bg: const Color(0xFF121212),
          text: Colors.white,
          pali: const Color(0xFFD4A574),
        );
      case ReaderTheme.dark2:
        return ReaderThemeStyle(
          bg: const Color(0xFF212121),
          text: const Color(0xFFB0BEC5),
          pali: const Color(0xFFC5B6A6),
        );
      case ReaderTheme.custom:
        return ReaderThemeStyle(
          bg: customBg ?? Colors.white,
          text: customText ?? Colors.black,
          //  Gunakan warna customPali yang dipilih user
          pali: customPali ?? const Color(0xFF8B4513),
        );
    }
  }
}
