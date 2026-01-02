import 'package:flutter/material.dart';
import 'explore_tab.dart';

class ExploreTabKamus extends StatelessWidget {
  const ExploreTabKamus({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"title": "Kamus", "isHeader": "true"},
      {
        "title": "Digital Pāḷi Dictionary",
        "desc": "Kamus Pāḷi modern dengan pencarian cepat",
        "url": "https://www.dpdict.net/",
      },
      {
        "title": "DSAL Dictionary",
        "desc": "Kamus Pāli berdasarkan PTS Pali-English Dictionary",
        "url": "https://dsal.uchicago.edu/dictionaries/pali/",
      },
      {"title": "Perpus (Indonesia)", "isHeader": "true"},

      {
        "title": "Sariputta",
        "desc":
            "Berbagai versi Tipiṭaka, paritta, referensi, dan sumber daya lainnya",
        "url": "https://www.sariputta.com/",
      },

      {"title": "Perpus (Inggris)", "isHeader": "true"},

      {
        "title": "Reading Faithfully",
        "desc": "Panduan taat membaca sutta (Inggris)",
        "url": "https://readingfaithfully.org/",
      },

      {
        "title": "dhammatalks.org: Books",
        "desc": "Buku online (Inggris)",
        "url": "https://www.dhammatalks.org/books/",
      },
      {
        "title": "Open Buddhist University",
        "desc": "Kursus dan perpustakaan online (Inggris)",
        "url": "https://buddhistuniversity.net/",
      },
      {
        "title": "Buddhist eLibrary",
        "desc": "Perpustakaan Buddhis online",
        "url": "https://www.buddhistelibrary.org/",
      },
      {
        "title": "Wisdom Library",
        "desc": "Portal agama Darmik: kamus dan teks suci",
        "url": "https://www.wisdomlib.org/",
      },
    ];

    return ExploreTab(
      items: items,
      defaultIcon: Icons
          .library_books_rounded, // ⬅️ semua item di page ini pakai icon apps
      defaultColor:
          Colors.blue.shade700, // ⬅️ semua item di page ini pakai warna orange
    );
  }
}
