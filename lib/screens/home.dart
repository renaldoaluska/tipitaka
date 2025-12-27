import 'package:flutter/material.dart';
import 'menu_page.dart';
import '../styles/nikaya_style.dart'; // import style nikaya

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late TabController _tabController;

  // 🔎 Data menu Sutta sesuai fragment Android
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
      "desc": "Aturan Bhikkhu",
      "range": "Bu",
      "url": "pli-tv-bu-pm",
    },
    {
      "acronym": "Bi",
      "name": "Suttavibhaṅga\nBhikkhunīpātimokkha",
      "desc": "Aturan Bhikkhunī",
      "range": "Bi",
      "url": "pli-tv-bi-pm",
    },
    {
      "acronym": "Bu Pj",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nPārājika",
      "desc": "Analisis Aturan Bhikkhu Pārājika",
      "range": "Bu Pj 1–4",
      "url": "pli-tv-bu-vb-pj",
    },
    {
      "acronym": "Bu Ss",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nSaṅghādisesa",
      "desc": "Analisis Aturan Bhikkhu Saṅghādisesa",
      "range": "Bu Ss 1–13",
      "url": "pli-tv-bu-vb-ss",
    },
    {
      "acronym": "Bu Ay",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nAniyata",
      "desc": "Analisis Aturan Bhikkhu Aniyata",
      "range": "Bu Ay 1–2",
      "url": "pli-tv-bu-vb-ay",
    },
    {
      "acronym": "Bu Np",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nNissaggiya Pācittiya",
      "desc": "Analisis Aturan Bhikkhu Nissaggiya Pācittiya",
      "range": "Bu Np 1–30",
      "url": "pli-tv-bu-vb-np",
    },
    {
      "acronym": "Bu Pc",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nPācittiya",
      "desc": "Analisis Aturan Bhikkhu Pācittiya",
      "range": "Bu Pc 1–92",
      "url": "pli-tv-bu-vb-pc",
    },
    {
      "acronym": "Bu Pd",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nPāṭidesanīya",
      "desc": "Analisis Aturan Bhikkhu Pāṭidesanīya",
      "range": "Bu Pd 1–4",
      "url": "pli-tv-bu-vb-pd",
    },
    {
      "acronym": "Bu Sk",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nSekhiya",
      "desc": "Analisis Aturan Bhikkhu Sekhiya",
      "range": "Bu Sk 1–75",
      "url": "pli-tv-bu-vb-sk",
    },
    {
      "acronym": "Bu As",
      "name": "Suttavibhaṅga\nBhikkhuvibhaṅga\nAdhikaraṇasamatha",
      "desc": "Analisis Aturan Bhikkhu Adhikaraṇasamatha",
      "range": "Bu As 1–7",
      "url": "pli-tv-bu-vb-as",
    },
    {
      "acronym": "Bi Pj",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nPārājika",
      "desc": "Analisis Aturan Bhikkhunī Pārājika",
      "range": "Bi Pj 1–8",
      "url": "pli-tv-bi-vb-pj",
    },
    {
      "acronym": "Bi Ss",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nSaṅghādisesa",
      "desc": "Analisis Aturan Bhikkhunī Saṅghādisesa",
      "range": "Bi Ss 1–17",
      "url": "pli-tv-bi-vb-ss",
    },
    {
      "acronym": "Bi Np",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nNissaggiya Pācittiya",
      "desc": "Analisis Aturan Bhikkhunī Nissaggiya Pācittiya",
      "range": "Bi Np 1–30",
      "url": "pli-tv-bi-vb-np",
    },
    {
      "acronym": "Bi Pc",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nPācittiya",
      "desc": "Analisis Aturan Bhikkhunī Pācittiya",
      "range": "Bi Pc 1–166",
      "url": "pli-tv-bi-vb-pc",
    },
    {
      "acronym": "Bi Pd",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nPāṭidesanīya",
      "desc": "Analisis Aturan Bhikkhunī Pāṭidesanīya",
      "range": "Bi Pd 1–8",
      "url": "pli-tv-bi-vb-pd",
    },
    {
      "acronym": "Bi Sk",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nSekhiya",
      "desc": "Analisis Aturan Bhikkhunī Sekhiya",
      "range": "Bi Sk 1–75",
      "url": "pli-tv-bi-vb-sk",
    },
    {
      "acronym": "Bi As",
      "name": "Suttavibhaṅga\nBhikkhunīvibhaṅga\nAdhikaraṇasamatha",
      "desc": "Analisis Aturan Bhikkhunī Adhikaraṇasamatha",
      "range": "Bi As 1–7",
      "url": "pli-tv-bi-vb-as",
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget buildTopIcon(String label, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget buildKitabList(List<Map<String, String>> kitabs) {
    // Kalau ini list Sutta
    final isSutta = identical(kitabs, suttaKitabs);

    if (isSutta) {
      // Set anak KN
      const knChildrenSet = {
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

      /*final knChildren = suttaKitabs
          .where((k) => knChildrenSet.contains(k["acronym"]))
          .toList();*/
      final parents = suttaKitabs
          .where((k) => !knChildrenSet.contains(k["acronym"]))
          .toList();

      return Container(
        color: Colors.grey[50], // 👉 background utama abu-abu muda
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: parents.map((kitab) {
            final displayAcronym = normalizeNikayaAcronym(kitab["acronym"]!);

            if (kitab["acronym"] == "KN") {
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Card(
                  color: Colors.white, // 👉 kotak putih
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior:
                      Clip.antiAlias, // 👉 ripple & hover ke-clip radius
                  child: ExpansionTile(
                    leading: buildNikayaAvatar("KN"),
                    title: Text(
                      "Khuddakanikāya",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      kitab["desc"]!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    initiallyExpanded: true,
                    children: khuddakaChildren.map((child) {
                      final childAcronym = normalizeNikayaAcronym(
                        child["acronym"]!,
                      );
                      return ListTile(
                        tileColor: Colors.white, // anak tetap putih
                        hoverColor: Colors.grey[200], // efek hover
                        leading: buildNikayaAvatar(childAcronym),
                        title: Text(
                          child["name"]!,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (child["desc"]?.isNotEmpty ?? false)
                            ? Text(
                                child["desc"]!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text(
                          child["range"]!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: getNikayaColor(childAcronym),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuPage(
                                uid:
                                    child["url"] ??
                                    child["acronym"]!.toLowerCase(),
                                parentAcronym: childAcronym,
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            }

            // Default DN/MN/SN/AN
            return Card(
              color: Colors.white, // 👉 kotak putih
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias, // 👉 ripple & hover ke-clip radius
              child: ListTile(
                leading: buildNikayaAvatar(displayAcronym),
                title: Text(
                  kitab["name"]!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: (kitab["desc"]?.isNotEmpty ?? false)
                    ? Text(
                        kitab["desc"]!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Text(
                  kitab["range"]!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getNikayaColor(displayAcronym),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MenuPage(
                        uid: kitab["url"] ?? kitab["acronym"]!.toLowerCase(),
                        parentAcronym: displayAcronym,
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      );
    }

    // Default untuk Abhidhamma/Vinaya
    return Container(
      color: Colors.grey[50], // background utama abu-abu muda
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: kitabs.length,
        itemBuilder: (context, index) {
          final kitab = kitabs[index];
          final displayAcronym = normalizeNikayaAcronym(kitab["acronym"]!);
          final uid = kitab["acronym"]!.toLowerCase();

          return Card(
            color: Colors.white, // kotak putih
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias, // 👉 ripple & hover ke-clip radius
            child: ListTile(
              leading: buildNikayaAvatar(displayAcronym),
              title: Text(
                kitab["name"]!,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: (kitab["desc"]?.isNotEmpty ?? false)
                  ? Text(
                      kitab["desc"]!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Text(
                kitab["range"]!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: getNikayaColor(displayAcronym),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuPage(
                      uid: kitab["url"] ?? uid,
                      parentAcronym: displayAcronym,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildSliderGreeting() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 35),
          Row(
            children: const [
              Expanded(
                child: Text(
                  "Sotthi Hotu,\nNamo Ratanattayā",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "2025 M\n2568–2569 TB",
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildTopIcon("Paritta", Icons.book, const Color(0xFF283593)),
              buildTopIcon("Ab-saṅgaha", Icons.person, const Color(0xFFFDD835)),
              buildTopIcon(
                "Uposatha",
                Icons.nightlight_round,
                const Color(0xFFD84315),
              ),
              buildTopIcon(
                "Meditasi",
                Icons.self_improvement,
                const Color(0xFFFF9800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          buildSliderGreeting(),
          Center(
            child: Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                isScrollable: true, // biar teks panjang ga kepotong
                tabs: const [
                  Tab(text: "Sutta"),
                  Tab(text: "Abhidhamma"),
                  Tab(text: "Vinaya"),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController, // sinkron dengan TabBar
              children: [
                buildKitabList(suttaKitabs),
                buildKitabList(abhidhammaKitabs),
                buildKitabList(vinayaKitabs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
