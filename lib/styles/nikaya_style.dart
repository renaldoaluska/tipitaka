import 'package:flutter/material.dart';

/// Set warna untuk tiap Nikāya
const Map<String, Color> nikayaColors = {
  "DN": Color(0xFFEA4E4E), // merah terang
  "MN": Color(0xFFF57C00), // oranye
  "SN": Color(0xFF388E3C), // hijau
  "AN": Color(0xFF1976D2), // biru
  "KN": Color(0xFFBA68C8), // ungu

  "Kp": Color(0xFFBA68C8), // ungu
  "Dhp": Color(0xFFBA68C8), // ungu
  "Ud": Color(0xFFBA68C8), // ungu
  "Iti": Color(0xFFBA68C8), // ungu
  "Snp": Color(0xFFBA68C8), // ungu
  "Vv": Color(0xFFBA68C8), // ungu
  "Pv": Color(0xFFBA68C8), // ungu
  "Thag": Color(0xFFBA68C8), // ungu
  "Thig": Color(0xFFBA68C8), // ungu

  "Tha Ap": Color(0xFFBA68C8), // ungu
  "Thi Ap": Color(0xFFBA68C8), // ungu
  "Bv": Color(0xFFBA68C8), // ungu
  "Cp": Color(0xFFBA68C8), // ungu
  "Ja": Color(0xFFBA68C8), // ungu
  "Mnd": Color(0xFFBA68C8), // ungu
  "Cnd": Color(0xFFBA68C8), // ungu
  "Ps": Color(0xFFBA68C8), // ungu
  "Ne": Color(0xFFBA68C8), // ungu
  "Pe": Color(0xFFBA68C8), // ungu
  "Mil": Color(0xFFBA68C8), // ungu

  "Ds": Color(0xFF00796B),
  "Vb": Color(0xFF00796B),
  "Dt": Color(0xFF00796B),
  "Pp": Color(0xFF00796B),
  "Kv": Color(0xFF00796B),
  "Ya": Color(0xFF00796B),
  "Pat": Color(0xFF00796B),

  "Kd": Color(0xFFA1887F),
  "Pvr": Color(0xFFA1887F),
  "Bu": Color(0xFFA1887F),
  "Bi": Color(0xFFA1887F),
  "Bu Pj": Color(0xFFA1887F),
  "Bu Ss": Color(0xFFA1887F),
  "Bu Ay": Color(0xFFA1887F),
  "Bu Np": Color(0xFFA1887F),
  "Bu Pc": Color(0xFFA1887F),
  "Bu Pd": Color(0xFFA1887F),
  "Bu Sk": Color(0xFFA1887F),
  "Bu As": Color(0xFFA1887F),
  "Bi Pj": Color(0xFFA1887F),
  "Bi Ss": Color(0xFFA1887F),
  "Bi Np": Color(0xFFA1887F),
  "Bi Pc": Color(0xFFA1887F),
  "Bi Pd": Color(0xFFA1887F),
  "Bi Sk": Color(0xFFA1887F),
  "Bi As": Color(0xFFA1887F),
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
  if (acronym.isEmpty) return "";

  // 1. Ubah strip/dash jadi spasi biar konsisten
  String normalized = acronym.replaceAll("-", " ");

  // 2. 🔥 FIX: Buang SEMUA yang ada angka dan teks setelahnya
  // Misal: "Tha Ap 1. Upalivagga" → "Tha Ap"
  //        "Bi Pj 1-4" → "Bi Pj"
  //        "Bu Vb Pj 123" → "Bu Vb Pj"
  normalized = normalized.replaceAll(RegExp(r'\s+\d+.*$'), "").trim();

  // 3. Set khusus yang harus tetap full uppercase
  const fullUpperSet = {"DN", "MN", "SN", "AN", "KN"};
  if (fullUpperSet.contains(normalized.toUpperCase())) {
    return normalized.toUpperCase();
  }

  // 4. Kapitalisasi tiap kata (Bi Pj, Tha Ap, dll)
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
