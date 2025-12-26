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
      "acronym": "Kp",
      "name": "Khuddakanikāya\nKhuddakapāṭha",
      "desc": "Kumpulan Kecil\nPetikan Pendek",
      "range": "Kp 1–9",
    },
    {
      "acronym": "Dhp",
      "name": "Khuddakanikāya\nDhammapada",
      "desc": "Kumpulan Kecil\nBait Kebenaran",
      "range": "Dhp 1–423",
    },
    {
      "acronym": "Ud",
      "name": "Khuddakanikāya\nUdāna",
      "desc": "Kumpulan Kecil\nSeruan Luhur",
      "range": "Ud 1–8",
    },
    {
      "acronym": "Iti",
      "name": "Khuddakanikāya\nItivuttaka",
      "desc": "Kumpulan Kecil\nSedemikian Dikatakan",
      "range": "Iti 1–112",
    },
    {
      "acronym": "Snp",
      "name": "Khuddakanikāya\nSuttanipāta",
      "desc": "Kumpulan Kecil\nKoleksi Diskursus",
      "range": "Snp 1–5",
    },
    {
      "acronym": "Vv",
      "name": "Khuddakanikāya\nVimānavatthu",
      "desc": "Kumpulan Kecil\nCerita Wisma",
      "range": "Vv 1–85",
    },
    {
      "acronym": "Pv",
      "name": "Khuddakanikāya\nPetavatthu",
      "desc": "Kumpulan Kecil\nCerita Hantu",
      "range": "Pv 1–51",
    },
    {
      "acronym": "Thag",
      "name": "Khuddakanikāya\nTheragāthā",
      "desc": "Kumpulan Kecil\nSyair Thera",
      "range": "Thag 1–21",
    },
    {
      "acronym": "Thig",
      "name": "Khuddakanikāya\nTherīgāthā",
      "desc": "Kumpulan Kecil\nSyair Therī",
      "range": "Thig 1–16",
    },
    {
      "acronym": "Tha-Ap",
      "name": "Khuddakanikāya\nTherāpadāna",
      "desc": "Kumpulan Kecil\nLegenda Thera",
      "range": "Tha-Ap 1–563",
    },
    {
      "acronym": "Thi-Ap",
      "name": "Khuddakanikāya\nTherīapadāna",
      "desc": "Kumpulan Kecil\nLegenda Therī",
      "range": "Thi-Ap 1–40",
    },
    {
      "acronym": "Bv",
      "name": "Khuddakanikāya\nBuddhavaṁsa",
      "desc": "Kumpulan Kecil\nWangsa Buddha",
      "range": "Bv 1–29",
    },
    {
      "acronym": "Cp",
      "name": "Khuddakanikāya\nCariyāpiṭaka",
      "desc": "Kumpulan Kecil\nKeranjang Perilaku",
      "range": "Cp 1–35",
    },
    {
      "acronym": "Ja",
      "name": "Khuddakanikāya\nJātaka",
      "desc": "Kumpulan Kecil\nKisah Kelahiran",
      "range": "Ja 1–547",
    },
    {
      "acronym": "Mnd",
      "name": "Khuddakanikāya\nMahāniddesa",
      "desc": "Kumpulan Kecil\nEksposisi Besar",
      "range": "Mnd 1–16",
    },
    {
      "acronym": "Cnd",
      "name": "Khuddakanikāya\nCūḷaniddesa",
      "desc": "Kumpulan Kecil\nEksposisi Kecil",
      "range": "Cnd 1–23",
    },
    {
      "acronym": "Ps",
      "name": "Khuddakanikāya\nPaṭisambhidāmagga",
      "desc": "Kumpulan Kecil\nJalan Analitis",
      "range": "Ps 1–3",
    },
    {
      "acronym": "Ne",
      "name": "Khuddakanikāya\nNetti",
      "desc": "Kumpulan Kecil\nPanduan",
      "range": "Ne 1–37",
    },
    {
      "acronym": "Pe",
      "name": "Khuddakanikāya\nPeṭakopadesa",
      "desc": "Kumpulan Kecil\nWilayah Keranjang",
      "range": "Pe 1–9",
    },
    {
      "acronym": "Mil",
      "name": "Khuddakanikāya\nMilindapañha",
      "desc": "Kumpulan Kecil\nPertanyaan Milinda",
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

  Widget buildKitabList(List<Map<String, String>> kitabs) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: kitabs.length,
      itemBuilder: (context, index) {
        final kitab = kitabs[index];
        final uid = kitab["acronym"]!.toLowerCase();
        final displayAcronym = normalizeNikayaAcronym(kitab["acronym"]!);

        return ListTile(
          leading: buildNikayaAvatar(kitab["acronym"]!),
          title: Text(
            kitab["name"]!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: (kitab["desc"]?.isNotEmpty ?? false)
              ? Text(
                  kitab["desc"]!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
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
            // kalau ada field "url" (khusus Vinaya)
            if (kitab.containsKey("url") &&
                (kitab["url"]?.isNotEmpty ?? false)) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuPage(
                    uid: kitab["url"]!, // pakai url sebagai uid
                    parentAcronym:
                        displayAcronym, // tetap kirim acronym untuk style
                  ),
                ),
              );
            } else {
              // default: Sutta & Abhidhamma
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MenuPage(uid: uid, parentAcronym: displayAcronym),
                ),
              );
            }
          },
        );
      },
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
