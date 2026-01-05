import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../styles/nikaya_style.dart';
import 'menu_page.dart';
import 'suttaplex.dart';

class PariyattiContent extends StatefulWidget {
  final int tab; // 0=Sutta, 1=Abhidhamma, 2=Vinaya

  const PariyattiContent({super.key, required this.tab});

  @override
  State<PariyattiContent> createState() => _PariyattiContentState();
}

class _PariyattiContentState extends State<PariyattiContent> {
  bool _isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    // Anggap tablet kalau width > 600dp
    final isTablet = size.shortestSide >= 600;
    final isLandscape = orientation == Orientation.landscape;

    return isTablet && isLandscape;
  }

  // Paste ulang data list (suttaKitabs, khuddakaChildren, dll) di sini
  // sesuai file aslimu...
  final suttaKitabs = [
    {
      "acronym": "DN",
      "name": "Dīghanikāya",
      "desc": "Kumpulan Panjang",
      "range": "DN 1–34",
    },
    {
      "acronym": "MN",
      "name": "Majjhimanikāya",
      "desc": "Kumpulan Sedang",
      "range": "MN 1–152",
    },
    {
      "acronym": "SN",
      "name": "Saṁyuttanikāya",
      "desc": "Kumpulan Bertaut",
      "range": "SN 1–56",
    },
    {
      "acronym": "AN",
      "name": "Aṅguttaranikāya",
      "desc": "Kumpulan Berangka",
      "range": "AN 1–11",
    },
    {
      "acronym": "KN",
      "name": "Khuddakanikāya",
      "desc": "Kumpulan Kecil",
      "range": "KN",
    },
  ];

  final khuddakaChildren = [
    {
      "acronym": "Kp",
      "name": "Khuddakapāṭha",
      "desc": "Petikan Pendek",
      "range": "Kp 1–9",
    },
    {
      "acronym": "Dhp",
      "name": "Dhammapada",
      "desc": "Bait Kebenaran",
      "range": "Dhp 1–423",
    },
    {
      "acronym": "Ud",
      "name": "Udāna",
      "desc": "Seruan Luhur",
      "range": "Ud 1–8",
    },
    {
      "acronym": "Iti",
      "name": "Itivuttaka",
      "desc": "Sedemikian Dikatakan",
      "range": "Iti 1–112",
    },
    {
      "acronym": "Snp",
      "name": "Suttanipāta",
      "desc": "Himpunan Pembabaran",
      "range": "Snp 1–5",
    },
    {
      "acronym": "Vv",
      "name": "Vimānavatthu",
      "desc": "Cerita Wisma",
      "range": "Vv 1–85",
    },
    {
      "acronym": "Pv",
      "name": "Petavatthu",
      "desc": "Cerita Hantu",
      "range": "Pv 1–51",
    },
    {
      "acronym": "Thag",
      "name": "Theragāthā",
      "desc": "Syair Thera",
      "range": "Thag 1–21",
    },
    {
      "acronym": "Thig",
      "name": "Therīgāthā",
      "desc": "Syair Therī",
      "range": "Thig 1–16",
    },
    {
      "acronym": "Tha Ap",
      "name": "Therāpadāna",
      "desc": "Legenda Thera",
      "range": "Tha Ap 1–563",
      "url": "tha-ap",
    },
    {
      "acronym": "Thi Ap",
      "name": "Therīapadāna",
      "desc": "Legenda Therī",
      "range": "Thi Ap 1–40",
      "url": "thi-ap",
    },
    {
      "acronym": "Bv",
      "name": "Buddhavaṁsa",
      "desc": "Wangsa Buddha",
      "range": "Bv 1–29",
    },
    {
      "acronym": "Cp",
      "name": "Cariyāpiṭaka",
      "desc": "Keranjang Perilaku",
      "range": "Cp 1–35",
    },
    {
      "acronym": "Ja",
      "name": "Jātaka",
      "desc": "Kisah Kelahiran",
      "range": "Ja 1–547",
    },
    {
      "acronym": "Mnd",
      "name": "Mahāniddesa",
      "desc": "Eksposisi Besar",
      "range": "Mnd 1–16",
    },
    {
      "acronym": "Cnd",
      "name": "Cūḷaniddesa",
      "desc": "Eksposisi Kecil",
      "range": "Cnd 1–23",
    },
    {
      "acronym": "Ps",
      "name": "Paṭisambhidāmagga",
      "desc": "Jalan Analitis",
      "range": "Ps 1–3",
    },
    {"acronym": "Ne", "name": "Netti", "desc": "Panduan", "range": "Ne 1–37"},
    {
      "acronym": "Pe",
      "name": "Peṭakopadesa",
      "desc": "Wilayah Keranjang",
      "range": "Pe 1–9",
    },
    {
      "acronym": "Mil",
      "name": "Milindapañha",
      "desc": "Pertanyaan Milinda",
      "range": "Mil 1–8",
    },
  ];

  final abhidhammaKitabs = [
    {
      "acronym": "Ds",
      "name": "Dhammasaṅgaṇī",
      "desc": "Ringkasan Fenomena",
      "range": "Ds 1–2",
    },
    {
      "acronym": "Vb",
      "name": "Vibhaṅga",
      "desc": "Kitab Analisis",
      "range": "Vb 1–18",
    },
    {
      "acronym": "Dt",
      "name": "Dhātukathā",
      "desc": "Diskusi Unsur",
      "range": "Dt 1–2",
    },
    {
      "acronym": "Pp",
      "name": "Puggalapaññatti",
      "desc": "Penggolongan Orang",
      "range": "Pp 1–2",
    },
    {
      "acronym": "Kv",
      "name": "Kathāvatthu",
      "desc": "Landasan Diskusi",
      "range": "Kv 1–23",
    },
    {
      "acronym": "Ya",
      "name": "Yamaka",
      "desc": "Berpasangan",
      "range": "Ya 1–10",
    },
    {
      "acronym": "Pat",
      "name": "Paṭṭhāna",
      "desc": "Hubungan Kondisi",
      "range": "Pat 1–24",
      "url": "patthana",
    },
  ];

  final vinayaKitabs = [
    {
      "acronym": "Kd",
      "name": "Khandhaka",
      "desc": "Bagian Aturan",
      "range": "Kd 1–22",
      "url": "pli-tv-kd",
    },
    {
      "acronym": "Pvr",
      "name": "Parivāra",
      "desc": "Ringkasan Aturan",
      "range": "Pvr 1–21",
      "url": "pli-tv-pvr",
    },
    {
      "acronym": "Bu",
      "name": "Suttavibhaṅga\nBhikkhupātimokkha",
      "desc": "Aturan Biku",
      "range": "Bu",
      "url": "pli-tv-bu-pm",
    },
    {
      "acronym": "Bi",
      "name": "Suttavibhaṅga\nBhikkhunīpātimokkha",
      "desc": "Aturan Bikuni",
      "range": "Bi",
      "url": "pli-tv-bi-pm",
    },
    {
      "acronym": "Bu Pj",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nPārājika",
      "desc": "Analisis Aturan Biku\nPārājika",
      "range": "Bu Pj 1–4",
      "url": "pli-tv-bu-vb-pj",
    },
    {
      "acronym": "Bu Ss",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nSaṅghādisesa",
      "desc": "Analisis Aturan Biku\nSaṅghādisesa",
      "range": "Bu Ss 1–13",
      "url": "pli-tv-bu-vb-ss",
    },
    {
      "acronym": "Bu Ay",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nAniyata",
      "desc": "Analisis Aturan Biku\nAniyata",
      "range": "Bu Ay 1–2",
      "url": "pli-tv-bu-vb-ay",
    },
    {
      "acronym": "Bu Np",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nNissaggiya Pācittiya",
      "desc": "Analisis Aturan Biku\nNissaggiya Pācittiya",
      "range": "Bu Np 1–30",
      "url": "pli-tv-bu-vb-np",
    },
    {
      "acronym": "Bu Pc",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nPācittiya",
      "desc": "Analisis Aturan Biku\nPācittiya",
      "range": "Bu Pc 1–92",
      "url": "pli-tv-bu-vb-pc",
    },
    {
      "acronym": "Bu Pd",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nPāṭidesanīya",
      "desc": "Analisis Aturan Biku\nPāṭidesanīya",
      "range": "Bu Pd 1–4",
      "url": "pli-tv-bu-vb-pd",
    },
    {
      "acronym": "Bu Sk",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nSekhiya",
      "desc": "Analisis Aturan Biku\nSekhiya",
      "range": "Bu Sk 1–75",
      "url": "pli-tv-bu-vb-sk",
    },
    {
      "acronym": "Bu As",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nAdhikaraṇasamatha",
      "desc": "Analisis Aturan Biku\nAdhikaraṇasamatha",
      "range": "Bu As 1–7",
      "url": "pli-tv-bu-vb-as",
    },
    {
      "acronym": "Bi Pj",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nPārājika",
      "desc": "Analisis Aturan Bikuni\nPārājika",
      "range": "Bi Pj 1–8",
      "url": "pli-tv-bi-vb-pj",
    },
    {
      "acronym": "Bi Ss",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nSaṅghādisesa",
      "desc": "Analisis Aturan Bikuni\nSaṅghādisesa",
      "range": "Bi Ss 1–17",
      "url": "pli-tv-bi-vb-ss",
    },
    {
      "acronym": "Bi Np",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nNissaggiya Pācittiya",
      "desc": "Analisis Aturan Bikuni\nNissaggiya Pācittiya",
      "range": "Bi Np 1–30",
      "url": "pli-tv-bi-vb-np",
    },
    {
      "acronym": "Bi Pc",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nPācittiya",
      "desc": "Analisis Aturan Bikuni\nPācittiya",
      "range": "Bi Pc 1–166",
      "url": "pli-tv-bi-vb-pc",
    },
    {
      "acronym": "Bi Pd",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nPāṭidesanīya",
      "desc": "Analisis Aturan Bikuni\nPāṭidesanīya",
      "range": "Bi Pd 1–8",
      "url": "pli-tv-bi-vb-pd",
    },
    {
      "acronym": "Bi Sk",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nSekhiya",
      "desc": "Analisis Aturan Bikuni\nSekhiya",
      "range": "Bi Sk 1–75",
      "url": "pli-tv-bi-vb-sk",
    },
    {
      "acronym": "Bi As",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nAdhikaraṇasamatha",
      "desc": "Analisis Aturan Bikuni\nAdhikaraṇasamatha",
      "range": "Bi As 1–7",
      "url": "pli-tv-bi-vb-as",
    },
  ];

  List<Map<String, String>> _getKitabList() {
    switch (widget.tab) {
      case 0:
        return suttaKitabs;
      case 1:
        return abhidhammaKitabs;
      case 2:
        return vinayaKitabs;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Ambil dari Theme
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(color: bgColor, child: buildKitabList(_getKitabList()));
  }

  // ðŸ"¥ 2. Method utama buildKitabList (DIGANTI JADI GINI)
  Widget buildKitabList(List<Map<String, String>> kitabs) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isTabletLandscape = _isTabletLandscape(context);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final contentPadding = EdgeInsets.only(
      top: isLandscape
          ? isTabletLandscape
                ? 200
                : 218
          : 234,
      left: 18,
      right: 18,
      bottom: 90,
    );

    // Jika Sutta Tab (ada KN expansion)
    if (widget.tab == 0) {
      return _buildSuttaLayout(isTabletLandscape, contentPadding, bgColor);
    }

    // Jika Abhidhamma atau Vinaya
    return _buildRegularLayout(
      kitabs,
      isLandscape,
      isTabletLandscape,
      contentPadding,
      bgColor,
    );
  }

  Widget _buildSuttaLayout(
    bool isTabletLandscape,
    EdgeInsets padding,
    Color bgColor,
  ) {
    const knSet = {
      "Kp",
      "Dhp",
      "Ud",
      "Iti",
      "Snp",
      "Vv",
      "Pv",
      "Thag",
      "Thig",
      "Tha Ap",
      "Thi Ap",
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

    final parents = suttaKitabs
        .where((k) => !knSet.contains(k["acronym"]))
        .toList();

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      // ðŸ"¥ GA PAKAI flatList, langsung loop parents aja
      return Container(
        color: bgColor,
        child: MasonryGridView.builder(
          padding: padding,
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTabletLandscape ? 3 : 2, // 2 kolom
          ),
          mainAxisSpacing: 4,
          crossAxisSpacing: 12,
          itemCount: parents.length, // ðŸ"¥ Cuma 5: DN, MN, SN, AN, KN
          itemBuilder: (context, index) {
            final kitab = parents[index];
            final acronym = normalizeNikayaAcronym(kitab["acronym"]!);

            // ðŸ"¥ KN pakai bottom sheet
            if (kitab["acronym"] == "KN") {
              return _buildKNGridCard(kitab, acronym); // Buka bottom sheet
            }

            // DN, MN, SN, AN pakai card biasa
            return _buildKitabCard(kitab, acronym, context);
          },
        ),
      );
    }

    // ðŸ"¥ MODE LIST (Portrait/Mobile)
    return Container(
      color: bgColor,
      child: ListView(
        padding: padding,
        children: parents.map((kitab) {
          final acronym = normalizeNikayaAcronym(kitab["acronym"]!);

          if (kitab["acronym"] == "KN") {
            return _buildKNExpansionCard(kitab, acronym);
          }
          return _buildKitabCard(kitab, acronym, context);
        }).toList(),
      ),
    );
  }

  Widget _buildKNGridCard(Map<String, String> kitab, String acronym) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: cardColor,
      elevation: 1,
      margin: EdgeInsets.only(top: 5.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: buildNikayaAvatar("KN"),
        title: Text(
          "Khuddakanikāya",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor,
          ),
        ),
        subtitle: Text(
          kitab["desc"]!,
          style: TextStyle(color: subtextColor, fontSize: 12),
        ),
        trailing: Text(
          kitab["range"]!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: getNikayaColor("KN"),
          ),
        ),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => FractionallySizedBox(
              heightFactor: 0.85,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: textColor),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Khuddakanikāya",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          Text(
                            "KN",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: getNikayaColor("KN"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),

                    // 🔥 PERBAIKAN DI SINI (Pakai LayoutBuilder)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Logika kolom berdasarkan LEBAR AKTUAL container
                          // > 500px anggap landscape/tablet -> 2 kolom
                          // < 500px anggap portrait HP -> 1 kolom
                          final int crossAxisCount = constraints.maxWidth > 500
                              ? 2
                              : 1;

                          return MasonryGridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                ),
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 12,
                            itemCount: khuddakaChildren.length,
                            itemBuilder: (context, index) {
                              final child = khuddakaChildren[index];
                              final childAcronym = normalizeNikayaAcronym(
                                child["acronym"]!,
                              );
                              return _buildKitabCard(
                                child,
                                childAcronym,
                                context,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ðŸ"¥ 4. Card ExpansionTile untuk KN (dipindah ke method sendiri)
  Widget _buildKNExpansionCard(Map<String, String> kitab, String acronym) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: Colors.deepOrange),
      ),
      child: Card(
        color: cardColor,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTileTheme(
          data: ExpansionTileThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: ExpansionTile(
            leading: buildNikayaAvatar("KN"),
            title: Text(
              "Khuddakanikāya",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            subtitle: Text(
              kitab["desc"]!,
              style: TextStyle(color: subtextColor, fontSize: 12),
            ),
            initiallyExpanded: false,
            children: khuddakaChildren.map((child) {
              final childAcronym = normalizeNikayaAcronym(child["acronym"]!);
              return _buildKitabTile(child, childAcronym, context);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ðŸ"¥ 5. Layout untuk Abhidhamma & Vinaya (lebih simple, gak ada expansion)
  Widget _buildRegularLayout(
    List<Map<String, String>> kitabs,
    bool isLandscape,
    bool isTabletLandscape,
    EdgeInsets padding,
    Color bgColor,
  ) {
    if (isLandscape) {
      // ðŸ"¥ GA PAKAI flatList, langsung loop parents aja
      return Container(
        color: bgColor,
        child: MasonryGridView.builder(
          padding: padding,
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTabletLandscape ? 3 : 2, // 2 kolom
          ),
          mainAxisSpacing: 4,
          crossAxisSpacing: 12,
          itemCount: kitabs.length,
          itemBuilder: (context, index) {
            final kitab = kitabs[index];
            final acronym = normalizeNikayaAcronym(kitab["acronym"]!);
            return _buildKitabCard(kitab, acronym, context);
          },
        ),
      );
    }

    // ðŸ"¥ MODE LIST (Original)
    return Container(
      color: bgColor,
      child: ListView.builder(
        padding: padding,
        itemCount: kitabs.length,
        itemBuilder: (context, index) {
          final kitab = kitabs[index];
          final acronym = normalizeNikayaAcronym(kitab["acronym"]!);
          return _buildKitabCard(kitab, acronym, context);
        },
      ),
    );
  }

  // Tambahin parameter context di sini
  Widget _buildKitabCard(
    Map<String, String> kitab,
    String acronym,
    BuildContext context,
  ) {
    // Sekarang Theme.of(context) bakal pake context yang dikirim (yang masih hidup), bukan yang lama
    final cardColor = Theme.of(context).colorScheme.surface;

    return Card(
      color: cardColor,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Oper context lagi ke bawah
      child: _buildKitabTile(kitab, acronym, context),
    );
  }

  Widget _buildKitabTile(
    Map<String, String> kitab,
    String acronym,
    BuildContext context,
  ) {
    // Pake context parameter
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).colorScheme.surface;
    //   final isTabletLandscape = _isTabletLandscape(context);

    //final isLandscape =
    MediaQuery.of(context).orientation == Orientation.landscape;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: buildNikayaAvatar(acronym),
      title: Text(
        //   isTabletLandscape
        //    ? kitab["name"]!.replaceAll('\n', '→')
        // :
        kitab["name"]!,
        maxLines: acronym.contains("Bu ") || acronym.contains("Bi ") ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: textColor, // ✅ Dinamis
        ),
      ),
      subtitle: Text(
        kitab["desc"]!,
        maxLines: acronym.contains("Bu ") || acronym.contains("Bi ") ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: subtextColor, fontSize: 12), // ✅ Dinamis
      ),
      trailing: Text(
        kitab["range"]!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: getNikayaColor(acronym),
        ),
      ),
      onTap: () {
        final uid = kitab["url"] ?? kitab["acronym"]!.toLowerCase();

        // 🔥 LOGIC KHUSUS: Cek apakah ini Patimokkha (Bu/Bi)?
        if (uid == "pli-tv-bu-pm" || uid == "pli-tv-bi-pm") {
          // Jika YA, buka Suttaplex (Langsung baca teks)
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: cardColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.85,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Suttaplex(
                  uid: uid,
                  sourceMode: "pariyatti", // Penanda entry point
                ),
              ),
            ),
          );
        } else {
          // Jika TIDAK (Folder biasa), buka MenuPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuPage(uid: uid, parentAcronym: acronym),
            ),
          );
        }
      },
    );
  }
}
