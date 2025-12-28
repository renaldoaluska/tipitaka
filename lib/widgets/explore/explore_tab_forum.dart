import 'package:flutter/material.dart';
import 'explore_tab.dart';

class ExploreTabForum extends StatelessWidget {
  const ExploreTabForum({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      // 💬 Forum Diskusi
      {"title": "Forum Diskusi", "isHeader": "true"},
      {
        "title": "DhammaWheel",
        "desc": "Forum diskusi Theravāda internasional",
        "url": "https://www.dhammawheel.com/",
      },
      {
        "title": "Discuss & Discover",
        "desc": "Forum diskusi Early Buddhism oleh SuttaCentral",
        "url": "https://discourse.suttacentral.net/",
      },
      {
        "title": "Classical Theravāda",
        "desc": "Forum diskusi Theravāda internasional",
        "url": "https://classicaltheravada.org/",
      },
    ];

    return ExploreTab(
      items: items,
      defaultIcon:
          Icons.forum_rounded, // ⬅️ semua item di page ini pakai icon apps
      defaultColor:
          Colors.teal.shade600, // ⬅️ semua item di page ini pakai warna orange
    );
  }
}
