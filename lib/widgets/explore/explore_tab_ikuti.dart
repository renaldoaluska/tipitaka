import 'package:flutter/material.dart';
import 'explore_tab.dart';

class ExploreTabIkuti extends StatelessWidget {
  const ExploreTabIkuti({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      // 🎥 YouTube Channels
      {"title": "Saluran YouTube", "isHeader": "true"},
      {
        "title": "Buddha Dhamma Indonesia",
        "desc":
            "Saluran oleh Bhante Santacitto yang membahas Dhamma dari berbagai aspek",
        "url": "https://www.youtube.com/@buddhadhammaindonesia5688",
      },
      {
        "title": "Buddha Vision",
        "desc": "Film, studi sutta, tokoh, animasi cerita, dan lagu",
        "url": "https://www.youtube.com/@BuddhaVision",
      },
      {
        "title": "Ceramah Bhante Uttamo",
        "desc": "Video ceramah Bhante Uttamo",
        "url": "https://www.youtube.com/@CeramahBhanteUttamo",
      },
      {
        "title": "Dhammavihārī Buddhist Studies",
        "desc": "Saluran Yayasan Dhammavihārī: pariyatti sāsana",
        "url": "https://www.youtube.com/@DhammavihariBuddhistStudies",
      },
      {
        "title": "Dhamma Nusantara",
        "desc": "Kumpulan ceramah Dhamma",
        "url": "https://www.youtube.com/@dhammanusantara",
      },
      {
        "title": "Lentera Dhamma",
        "desc": "Media belajar dan berbagi Dhamma",
        "url": "https://www.youtube.com/@lenteradhamma577",
      },
      {
        "title": "Medkom STI",
        "desc": "Informasi kegiatan Saṅgha Theravāda Indonesia",
        "url": "https://www.youtube.com/@medkomsanghatheravadaindon9531",
      },
      {
        "title": "PATVDH Indonesia",
        "desc": "Pa Auk Tawya Vipassanā Dhura Hermitage Indonesia",
        "url": "https://www.youtube.com/@PATVDHIndonesia",
      },
      {
        "title": "Pusdiklat Dhammarakkhita",
        "desc": "Saluran Pusdiklat Dhammarakkhita",
        "url": "https://www.youtube.com/@PusdiklatDhammarakkhita",
      },
      {
        "title": "Siniar Buddha Dhamma",
        "desc": "Ceramah Dhamma untuk hidup lebih baik, bijak, dan damai",
        "url": "https://www.youtube.com/@siniarbuddhadhamma",
      },
      {
        "title": "STAB Kertarajasa",
        "desc": "Saluran STAB Kertarajasa",
        "url": "https://www.youtube.com/@stabkertarajasa",
      },
      {
        "title": "Vihāra Mahāsampatti",
        "desc": "Saluran Vihāra Mahāsampatti Medan",
        "url": "https://www.youtube.com/@ViharaMahasampatti",
      },
      {
        "title": "Vihāra Buddharatana Medan",
        "desc": "Saluran Vihāra Buddharatana Medan",
        "url": "https://www.youtube.com/@viharabuddharatanamedan4529/",
      },
      {
        "title": "Yayasan Satipaṭṭhāna Indonesia",
        "desc": "Saluran Yayasan Satipaṭṭhāna Indonesia",
        "url": "https://www.youtube.com/@yayasansatipatthanaindones6164",
      },

      // 📸 Instagram Accounts
      {"title": "Akun Instagram", "isHeader": "true"},
      {
        "title": "@MedkomSTI",
        "desc":
            "Akun Instagram media dan komunikasi Saṅgha Theravāda Indonesia",
        "url": "https://www.instagram.com/medkomsti/",
      },
      {
        "title": "@PelitaBuddha",
        "desc": "Akun Instagram yang rutin mengunggah kutipan Buddhis",
        "url": "https://www.instagram.com/pelitabuddha/",
      },
      {
        "title": "@TipitakaHarian",
        "desc": "Akun Instagram yang rutin mengunggah kutipan Buddhis",
        "url": "https://www.instagram.com/tipitakaharian/",
      },
    ];

    return ExploreTab(
      items: items,
      defaultIcon:
          Icons.people_rounded, // ⬅️ semua item di page ini pakai icon apps
      defaultColor: Colors
          .indigo
          .shade600, // ⬅️ semua item di page ini pakai warna orange
    );
  }
}
