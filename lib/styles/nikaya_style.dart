import 'package:flutter/material.dart';

/// Set warna untuk tiap Nikāya
const Map<String, Color> nikayaColors = {
  "DN": Color(0xFFEA4E4E), // merah terang
  "MN": Color(0xFFF57C00), // oranye
  "SN": Color(0xFF388E3C), // hijau
  "AN": Color(0xFF1976D2), // biru
  "KN": Color(0xFF7B1FA2), // ungu

  "Kp": Color(0xFF7B1FA2), // ungu
  "Dhp": Color(0xFF7B1FA2), // ungu
  "Ud": Color(0xFF7B1FA2), // ungu
  "Iti": Color(0xFF7B1FA2), // ungu
  "Snp": Color(0xFF7B1FA2), // ungu
  "Vv": Color(0xFF7B1FA2), // ungu
  "Pv": Color(0xFF7B1FA2), // ungu
  "Thag": Color(0xFF7B1FA2), // ungu
  "Thig": Color(0xFF7B1FA2), // ungu

  "Tha Ap": Color(0xFF7B1FA2), // ungu
  "Thi Ap": Color(0xFF7B1FA2), // ungu
  "Bv": Color(0xFF7B1FA2), // ungu
  "Cp": Color(0xFF7B1FA2), // ungu
  "Ja": Color(0xFF7B1FA2), // ungu
  "Mnd": Color(0xFF7B1FA2), // ungu
  "Cnd": Color(0xFF7B1FA2), // ungu
  "Ps": Color(0xFF7B1FA2), // ungu
  "Ne": Color(0xFF7B1FA2), // ungu
  "Pe": Color(0xFF7B1FA2), // ungu
  "Mil": Color(0xFF7B1FA2), // ungu

  "Ds": Color(0xFF00796B),
  "Vb": Color(0xFF00796B),
  "Dt": Color(0xFF00796B),
  "Pp": Color(0xFF00796B),
  "Kv": Color(0xFF00796B),
  "Ya": Color(0xFF00796B),
  "Pat": Color(0xFF00796B),

  "Kd": Color(0xFF795548),
  "Pvr": Color(0xFF795548),
  "Bu": Color(0xFF795548),
  "Bi": Color(0xFF795548),
  "Bu Pj": Color(0xFF795548),
  "Bu Ss": Color(0xFF795548),
  "Bu Ay": Color(0xFF795548),
  "Bu Np": Color(0xFF795548),
  "Bu Pc": Color(0xFF795548),
  "Bu Pd": Color(0xFF795548),
  "Bu Sk": Color(0xFF795548),
  "Bu As": Color(0xFF795548),
  "Bi Pj": Color(0xFF795548),
  "Bi Ss": Color(0xFF795548),
  "Bi Np": Color(0xFF795548),
  "Bi Pc": Color(0xFF795548),
  "Bi Pd": Color(0xFF795548),
  "Bi Sk": Color(0xFF795548),
  "Bi As": Color(0xFF795548),
};

/// Daftar kitab yang termasuk Khuddaka Nikāya
/*const Set<String> khuddakaSet = {
  "Kp",
  "Dhp",
  "Ud",
  "Iti",
  "Snp",
  "Vv",
  "Pv",
  "Thag",
  "Thig",
  "Tha-ap",
  "Thi-ap",
  "Bv",
  "Cp",
  "Ja",
  "Mnd",
  "Cnd",
  "Ps",
  "Ne",
  "Pe",
  "Mil",
};*/

String normalizeNikayaAcronym(String acronym) {
  // Ubah strip jadi spasi biar konsisten
  String normalized = acronym.replaceAll("-", " ");

  // Set khusus yang harus tetap full uppercase
  const fullUpperSet = {"DN", "MN", "SN", "AN", "KN"};

  if (fullUpperSet.contains(normalized.toUpperCase())) {
    return normalized.toUpperCase();
  }

  // Kalau lebih dari satu kata, kapitalisasi tiap kata
  normalized = normalized
      .split(" ")
      .map(
        (word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : "",
      )
      .join(" ");

  return normalized;
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
