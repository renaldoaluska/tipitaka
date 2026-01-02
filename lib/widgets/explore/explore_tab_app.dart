import 'package:flutter/material.dart';
import 'explore_tab.dart';

class ExploreTabApp extends StatelessWidget {
  const ExploreTabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      // 📚 Aplikasi & Pustaka Digital
      {"title": "Tipiṭaka, Aṭṭhakathā, Ṭīkā", "isHeader": "true"},
      {
        "title": "DigitalPaliReader.online",
        "desc":
            "Edisi Mahāsaṅgīti Tipiṭaka Buddhavasse 2500 oleh Dhamma Society",
        "url": "https://www.digitalpalireader.online/",
      },
      {
        "title": "Tipitaka.app",
        "desc":
            "Edisi Chaṭṭha Saṅgāyana Tipiṭaka oleh Vipassanā Research Institute",
        "url": "https://tipitaka.app/",
      },

      {"title": "Terjemahan Indonesia", "isHeader": "true"},

      {
        "title": "DhammaCitta\nTipiṭaka",
        "desc": "Tipiṭaka Indonesia versi DhammaCitta",
        "url": "https://dhammacitta.org/definisi/teks-buddhisme.html",
      },
      {
        "title": "DhammaCitta\nPencarian",
        "desc": "Pencarian sutta dan sumber daya lainnya",
        "url": "https://dhammacitta.org/pencarian.html",
      },
      {
        "title": "Pāḷi & Aṭṭhakathā Nissaya",
        "desc": "Tipiṭaka Indonesia versi Dhammavihārī Buddhist Studies",
        "url": "https://www.palinissaya.com/",
      },
      {
        "title": "Samaggi Phala:\nTipiṭaka",
        "desc": "Tipiṭaka Indonesia versi Samaggi Phala",
        "url": "https://samaggi-phala.or.id/tipitaka/",
      },

      {"title": "Terjemahan Inggris", "isHeader": "true"},
      {
        "title": "dhammatalks.org: Suttas",
        "desc": "Sutta Piṭaka Inggris versi Bhikkhu Ṭhānissaro",
        "url": "https://www.dhammatalks.org/suttas/",
      },

      // 🗂️ SuttaCentral
      {"title": "SuttaCentral", "isHeader": "true"},
      {
        "title": "Home",
        "desc": "Halaman depan SuttaCentral",
        "url": "https://suttacentral.net/",
      },
      {
        "title": "Indeks Nama",
        "desc": "Indeks nama makhluk",
        "url": "https://suttacentral.net/names",
      },
      {
        "title": "Indeks Perumpamaan",
        "desc": "Indeks perumpamaan",
        "url": "https://suttacentral.net/similes",
      },
      {
        "title": "Indeks Peta",
        "desc": "Peta India zaman Buddha",
        "url": "https://suttacentral.net/map",
      },
      {
        "title": "Indeks Subjek",
        "desc": "Indeks subjek (tematik)",
        "url": "https://suttacentral.net/subjects",
      },
      {
        "title": "Indeks Terminologi",
        "desc": "Indeks terminologi",
        "url": "https://suttacentral.net/terminology",
      },
    ];
    return ExploreTab(
      items: items,
      defaultIcon:
          Icons.apps_rounded, // ⬅️ semua item di page ini pakai icon apps
      defaultColor: Colors
          .orange
          .shade700, // ⬅️ semua item di page ini pakai warna orange
    );
  }
}
