import 'package:flutter/material.dart';

/// Set warna untuk tiap Nikāya
const Map<String, Color> nikayaColors = {
  "DN": Color(0xFFEA4E4E), // merah terang
  "MN": Color(0xFFF57C00), // oranye
  "SN": Color(0xFF388E3C), // hijau
  "AN": Color(0xFF1976D2), // biru
  "KN": Color(0xFF7B1FA2), // ungu
};

/// Daftar kitab yang termasuk Khuddaka Nikāya
const Set<String> khuddakaSet = {
  "Kp",
  "Dhp",
  "Ud",
  "Iti",
  "Snp",
  "Vv",
  "Pv",
  "Thag",
  "Thig",
  "Tha-Ap",
  "Thi-Ap",
  "Bv",
  "Cp",
  "Ja",
  "Mnd",
  "Cnd",
  "Ps",
  "Ne",
  "Pe",
  "Mil",
};

/// Normalisasi acronym: semua Khuddaka ditampilkan sebagai KN
String normalizeNikayaAcronym(String acronym) {
  return khuddakaSet.contains(acronym) ? "KN" : acronym;
}

/// Ambil warna sesuai Nikāya (fallback ke grey kalau tidak ada)
Color getNikayaColor(String acronym) {
  final normalized = normalizeNikayaAcronym(acronym);
  return nikayaColors[normalized] ?? Colors.grey;
}

/// Helper untuk bikin CircleAvatar konsisten
Widget buildNikayaAvatar(
  String acronym, {
  double radius = 18,
  double fontSize = 15,
}) {
  final display = normalizeNikayaAcronym(acronym);
  return CircleAvatar(
    radius: radius,
    backgroundColor: getNikayaColor(display),
    child: FittedBox(
      // <— ini bikin teks nge‑fit ke lingkaran
      fit: BoxFit.scaleDown,
      child: Text(
        display,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize, // default14
        ),
      ),
    ),
  );
}
