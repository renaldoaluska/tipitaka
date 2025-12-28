import 'package:flutter/material.dart';
import 'explore_tab.dart';

class ExploreTabUnduh extends StatelessWidget {
  const ExploreTabUnduh({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      // 📑 Bahasa Indonesia
      //{"title": "📑 Bahasa Indonesia", "isHeader": "true"},

      // DhammaCitta
      {"title": "DhammaCitta", "isHeader": "true"},
      {
        "title": "Download",
        "desc": "Buku, majalah, audio, video, dan lain-lain",
        "url": "https://dhammacitta.org/download/ebook.html",
      },

      {"title": "Dhammadāyāda Vihāra (PATVDH Indonesia)", "isHeader": "true"},
      {
        "title": "Ebook Dhamma",
        "desc": "Kumpulan ebook Dhamma dalam tradisi Pa-Auk",
        "url": "https://www.dhammadayada.org/ebook-dhamma",
      },

      // Dhammavihārī Buddhist Studies (DBS)
      {"title": "Dhammavihārī Buddhist Studies (DBS)", "isHeader": "true"},
      {
        "title": "Ebook",
        "desc": "Buku-buku terbitan DBS",
        "url": "https://dhammavihari.or.id/ebook",
      },
      {
        "title": "Materi Kelas",
        "desc": "Materi kelas DBS",
        "url": "https://dhammavihari.or.id/pdf-slide",
      },

      // Ehipassiko Foundation
      {"title": "Ehipassiko Foundation", "isHeader": "true"},
      {
        "title": "Unduh Gratis",
        "desc": "Dharma e-book, lagu dharma, buletin, gambar Buddhis",
        "url": "https://ehipassiko.or.id/unduh-gratis/",
      },

      // Indonesia Tipiṭaka Center
      {"title": "Indonesia Tipiṭaka Center", "isHeader": "true"},
      {
        "title": "Tipiṭaka Bahasa Indonesia",
        "desc": "Tipiṭaka terjemahan Indonesia",
        "url": "https://itc-tipitaka.org/tipitaka.html",
      },

      // Lokuttara Dhamma
      {"title": "Lokuttara Dhamma", "isHeader": "true"},
      {
        "title": "Cerita Dhamma",
        "desc": "Komik cerita dhamma",
        "url": "http://lokuttaradhamma.id/index.php?page=komik",
      },

      // Nalanda Foundation
      {"title": "Nalanda Foundation", "isHeader": "true"},
      {
        "title": "Majalah",
        "desc": "Majalah Nalanda Foundation",
        "url": "https://nalandafoundation.net/majalah-nalanda/",
      },

      // P
      {"title": "Pusdiklat Dhammarakkhita", "isHeader": "true"},
      {
        "title": "Ebook",
        "desc": "Buku-buku terbitan Yayasan DKS",
        "url": "https://pusdiklatdhammarakkhita.com/pariyatti/e-book",
      },

      // Samaggi Phala
      {"title": "Samaggi Phala", "isHeader": "true"},
      {
        "title": "Download Files",
        "desc": "Kumpulan naskah PDF",
        "url": "https://samaggi-phala.or.id/naskah-dhamma/download-files/",
      },
      {
        "title": "Ebook Vidyasena",
        "desc": "Ebook terbitan Vidyasena",
        "url":
            "https://samaggi-phala.or.id/category/naskah-dhamma/download/ebook-terbitan-vidyasena/",
      },
      {
        "title": "Komik Buddhis",
        "desc": "Komik Buddhis",
        "url":
            "https://samaggi-phala.or.id/category/naskah-dhamma/download-files/komik-buddhis/",
      },

      // Yasati (Yayasan Satipaṭṭhāna Indonesia)
      {"title": "Yayasan Satipaṭṭhāna Indonesia (Yasati)", "isHeader": "true"},
      {
        "title": "eBook",
        "desc": "E-book Yasati",
        "url": "https://yasati.com/ebook",
      },
      {
        "title": "DhammaTalk",
        "desc": "DhammaTalk Yasati",
        "url": "https://yasati.com/dhammatalk",
      },

      // 🌍 Bahasa Inggris
      {"title": "Bahasa Inggris", "isHeader": "true"},
      {
        "title": "BuddhaNet",
        "desc": "E-book, ceramah, meditasi, lagu, komik (EN)",
        "url": "http://www.buddhanet.net/",
      },
      {
        "title": "dhammatalks.org: Books",
        "desc": "E-book (EN)",
        "url": "https://www.dhammatalks.org/books/",
      },
    ];

    return ExploreTab(
      items: items,
      defaultIcon:
          Icons.download_rounded, // ⬅️ semua item di page ini pakai icon apps
      defaultColor:
          Colors.green.shade700, // ⬅️ semua item di page ini pakai warna orange
    );
  }
}
