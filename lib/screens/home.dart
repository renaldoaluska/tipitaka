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
      "range": "Tha Ap 1–563",
    },
    {
      "acronym": "Thi-Ap",
      "name": "Khuddakanikāya\nTherīapadāna",
      "desc": "Kumpulan Kecil\nLegenda Therī",
      "range": "Thi Ap 1–40",
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
      itemCount: kitabs.length,
      itemBuilder: (context, index) {
        final kitab = kitabs[index];
        final uid = kitab["acronym"]!.toLowerCase();
        final displayAcronym = normalizeNikayaAcronym(kitab["acronym"]!);

        return ListTile(
          leading: buildNikayaAvatar(kitab["acronym"]!),
          title: Text(kitab["name"]!),
          subtitle: Text(kitab["desc"]!),
          trailing: Text(
            kitab["range"]!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: getNikayaColor(displayAcronym),
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MenuPage(uid: uid, parentAcronym: displayAcronym),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSliderGreeting() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      //color: const Color(0xFFFFE0B2), // oranye terang
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  "Sotthi Hotu, Namo Ratanattayā",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text("2025 M / 2568–2569 TB", style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Biru Navy/Gelap untuk Paritta
              buildTopIcon("Paritta", Icons.book, const Color(0xFF283593)),

              // Kuning Terang untuk Ab-sanga
              buildTopIcon("Ab-saṅgaha", Icons.person, const Color(0xFFFDD835)),

              // Merah/Oranye Gelap untuk Uposatha (ikon bulan)
              buildTopIcon(
                "Uposatha",
                Icons.nightlight_round,
                const Color(0xFFD84315),
              ),

              // Oranye Terang untuk Meditasi
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
      appBar: AppBar(title: const Text("Tripitaka Indonesia")),
      body: Column(
        children: [
          buildSliderGreeting(),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            tabs: const [
              Tab(text: "Sutta"),
              Tab(text: "Abhidhamma"),
              Tab(text: "Vinaya"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                buildKitabList(suttaKitabs),
                const Center(child: Text("Abhidhamma belum diisi")),
                const Center(child: Text("Vinaya belum diisi")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
