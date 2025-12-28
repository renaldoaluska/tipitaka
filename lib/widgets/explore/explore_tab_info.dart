import 'package:flutter/material.dart';
import 'explore_tab.dart';

class ExploreTabInfo extends StatelessWidget {
  const ExploreTabInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      // 📑 Indonesia
      {"title": "Artikel Indonesia", "isHeader": "true"},
      {
        "title": "DhammaCitta:\nArtikel Dhamma",
        "desc": "Kumpulan artikel Buddhis",
        "url": "https://dhammacitta.org/artikel.html",
      },

      {
        "title": "Dhammadāyāda Vihāra (PATVDH Indonesia):\nArtikel Dhamma",
        "desc": "Kumpulan artikel Dhamma dalam tradisi Pa-Auk",
        "url": "https://www.dhammadayada.org/artikel-dhamma",
      },

      {
        "title": "Lokuttara Dhamma:\nTips Dhamma",
        "desc": "Tips Dhamma oleh Yayasan Lokuttara Dhamma",
        "url": "http://lokuttaradhamma.id/index.php?page=tips",
      },

      {
        "title": "Samaggi Phala:\nNaskah Dhamma",
        "desc": "Kumpulan artikel, ringkasan buku, cerita, dan nama Buddhis",
        "url": "https://samaggi-phala.or.id/naskah-dhamma/",
      },
      {
        "title": "STI: Bhikkhu",
        "desc": "Daftar bhikkhu Saṅgha Theravāda Indonesia",
        "url": "https://sanghatheravadaindonesia.or.id/daftar-bhikkhu/",
      },
      {
        "title": "STI: Vihāra",
        "desc": "Daftar vihāra binaan Saṅgha Theravāda Indonesia",
        "url": "https://sanghatheravadaindonesia.or.id/vihara-binaan-sti/",
      },
      {"title": "Berita Indonesia", "isHeader": "true"},
      {
        "title": "Berita STI",
        "desc": "Berita Saṅgha Theravāda Indonesia",
        "url":
            "https://sanghatheravadaindonesia.or.id/category/berita-kegiatan/",
      },
      {
        "title": "Berita Bhagavant",
        "desc": "Berita Buddhis Mingguan Bhagavant",
        "url": "https://berita.bhagavant.com/",
      },
      {
        "title": "Berita Bimas Buddha",
        "desc": "Ditjen Bimas Buddha Kemenag",
        "url": "https://bimasbuddha.kemenag.go.id/berita.html",
      },
      {
        "title": "BuddhaZine Indonesia",
        "desc": "Situs Berita Buddhis",
        "url": "https://buddhazine.com",
      },

      // 🌍  Internasional
      {"title": "Berita Inggris", "isHeader": "true"},
      {
        "title": "Buddhistdoor Global",
        "desc": "Your Doorway to the World of Buddhism",
        "url": "https://www.buddhistdoor.net",
      },
      {
        "title": "Lion's Roar",
        "desc": "Buddhist Wisdom for Our Time",
        "url": "https://www.lionsroar.com",
      },
      {
        "title": "TheBuddhist.News",
        "desc": "News about Buddhism from around the World",
        "url": "https://thebuddhist.news",
      },
      {
        "title": "Tricycle",
        "desc": "The independent voice of Buddhism",
        "url": "https://tricycle.org",
      },
    ];

    return ExploreTab(
      items: items,
      defaultIcon:
          Icons.newspaper_rounded, // ⬅️ semua item di page ini pakai icon apps
      defaultColor:
          Colors.red.shade600, // ⬅️ semua item di page ini pakai warna orange
    );
  }
}
