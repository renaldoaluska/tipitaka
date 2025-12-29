import 'package:flutter/material.dart';
import '../styles/nikaya_style.dart';
import 'menu_page.dart';
import '../widgets/header_depan.dart';

class PariyattiPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const PariyattiPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<PariyattiPage> createState() => _PariyattiPageState();
}

class _PariyattiPageState extends State<PariyattiPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isFabExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

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
      "name": "Saṃyuttanikāya",
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
      "name": "Buddhavaṃsa",
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
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      _isFabExpanded ? _fabController.forward() : _fabController.reverse();
    });
  }

  Color _bgColor(bool dark) => dark ? Colors.grey[900]! : Colors.grey[50]!;
  Color _cardColor(bool dark) => dark ? Colors.grey[850]! : Colors.white;
  Color _textColor(bool dark) => dark ? Colors.white : Colors.black;
  Color _subtextColor(bool dark) =>
      dark ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor(widget.isDarkMode),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    buildKitabList(suttaKitabs),
                    buildKitabList(abhidhammaKitabs),
                    buildKitabList(vinayaKitabs),
                  ],
                ),
              ),
            ],
          ),
          _buildFabSearch(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        HeaderDepan(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
          title: "Pariyatti",
          subtitle: "Studi Dhamma",
        ),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.indigo.shade700.withOpacity(
                        0.3,
                      ), // pakai accentColor
                      width: 1.5,
                    ),
                  ),
                  child: _buildQuickButton(
                    label: "Tematik",
                    icon: Icons.category_rounded,
                    color: Colors.indigo.shade700,
                    onTap: () {
                      // TODO: Navigate to Tematik
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.shade700.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: _buildQuickButton(
                    label: "Ab-saṅgaha",
                    icon: Icons.auto_stories_rounded,
                    color: Colors.amber.shade700,
                    onTap: () {
                      // TODO: Navigate to Sangaha
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _bgColor(widget.isDarkMode),
      padding: const EdgeInsets.only(top: 12),
      child: TabBar(
        controller: _tabController,
        labelColor: _textColor(widget.isDarkMode),
        unselectedLabelColor: _subtextColor(widget.isDarkMode),
        indicatorColor: Colors.deepOrange,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        isScrollable: false,
        tabs: const [
          Tab(text: "Sutta"),
          Tab(text: "Abhidhamma"),
          Tab(text: "Vinaya"),
        ],
      ),
    );
  }

  Widget buildKitabList(List<Map<String, String>> kitabs) {
    final isSutta = identical(kitabs, suttaKitabs);
    if (isSutta) {
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
      return Container(
        color: _bgColor(widget.isDarkMode),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: parents.map((kitab) {
            final acronym = normalizeNikayaAcronym(kitab["acronym"]!);
            if (kitab["acronym"] == "KN") {
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Card(
                  color: _cardColor(widget.isDarkMode),
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: buildNikayaAvatar("KN"),
                    title: Text(
                      "Khuddakanikāya",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _textColor(widget.isDarkMode),
                      ),
                    ),
                    subtitle: Text(
                      kitab["desc"]!,
                      style: TextStyle(
                        color: _subtextColor(widget.isDarkMode),
                        fontSize: 12,
                      ),
                    ),
                    initiallyExpanded: false,
                    children: khuddakaChildren.map((child) {
                      final childAcronym = normalizeNikayaAcronym(
                        child["acronym"]!,
                      );
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: _cardColor(widget.isDarkMode),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        leading: buildNikayaAvatar(childAcronym),
                        title: Text(
                          child["name"]!,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: _textColor(widget.isDarkMode),
                          ),
                        ),
                        subtitle: Text(
                          child["desc"]!,
                          style: TextStyle(
                            color: _subtextColor(widget.isDarkMode),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          child["range"]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: getNikayaColor(childAcronym),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MenuPage(
                              uid:
                                  child["url"] ??
                                  child["acronym"]!.toLowerCase(),
                              parentAcronym: childAcronym,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }
            return Card(
              color: _cardColor(widget.isDarkMode),
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0, // ✅ samain kayak KN children
                ),
                leading: buildNikayaAvatar(acronym),
                title: Text(
                  kitab["name"]!,
                  style: TextStyle(
                    fontWeight: FontWeight.w500, // ✅ samain kayak KN children
                    fontSize: 14, // ✅ samain kayak KN children
                    color: _textColor(widget.isDarkMode),
                  ),
                ),
                subtitle: Text(
                  kitab["desc"]!,
                  style: TextStyle(
                    color: _subtextColor(widget.isDarkMode),
                    fontSize: 12, // ✅ tetap
                  ),
                ),
                trailing: Text(
                  kitab["range"]!,
                  style: TextStyle(
                    fontSize: 12, // ✅ samain kayak KN children
                    fontWeight: FontWeight.bold,
                    color: getNikayaColor(acronym),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuPage(
                      uid: kitab["url"] ?? kitab["acronym"]!.toLowerCase(),
                      parentAcronym: acronym,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
    return Container(
      color: _bgColor(widget.isDarkMode),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        itemCount: kitabs.length,
        itemBuilder: (context, index) {
          final kitab = kitabs[index];
          final acronym = normalizeNikayaAcronym(kitab["acronym"]!);
          return Card(
            color: _cardColor(widget.isDarkMode),
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0, // ✅ samain kayak KN children
              ),
              leading: buildNikayaAvatar(acronym),
              title: Text(
                kitab["name"]!,
                style: TextStyle(
                  fontWeight: FontWeight.w500, // ✅ samain kayak KN children
                  fontSize: 14, // ✅ samain kayak KN children
                  color: _textColor(widget.isDarkMode),
                ),
              ),
              subtitle: Text(
                kitab["desc"]!,
                style: TextStyle(
                  color: _subtextColor(widget.isDarkMode),
                  fontSize: 12, // ✅ tetap
                ),
              ),
              trailing: Text(
                kitab["range"]!,
                style: TextStyle(
                  fontSize: 12, // ✅ samain kayak KN children
                  fontWeight: FontWeight.bold,
                  color: getNikayaColor(acronym),
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuPage(
                    uid: kitab["url"] ?? kitab["acronym"]!.toLowerCase(),
                    parentAcronym: acronym,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFabSearch() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            ScaleTransition(
              scale: _fabAnimation,
              child: _buildFabOption(
                label: "Kode Sutta",
                icon: Icons.tag_rounded,
                color: Colors.blue.shade600,
                onTap: () => _showCodeInput(),
              ),
            ),
            const SizedBox(height: 10),
            ScaleTransition(
              scale: _fabAnimation,
              child: _buildFabOption(
                label: "Pencarian",
                icon: Icons.search_rounded,
                color: Colors.green.shade600,
                onTap: () => _showSearchModal(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            onPressed: _toggleFab,
            backgroundColor: Colors.deepOrange,
            elevation: 2,
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isFabExpanded ? Icons.close : Icons.search,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _cardColor(widget.isDarkMode),
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor(widget.isDarkMode),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: color,
          elevation: 2,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  void _showCodeInput() {
    _toggleFab();
    showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: _cardColor(widget.isDarkMode),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Masukkan Kode Sutta",
            style: TextStyle(
              color: _textColor(widget.isDarkMode),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Contoh: mn1, sn12.1",
              hintStyle: TextStyle(color: _subtextColor(widget.isDarkMode)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: _textColor(widget.isDarkMode)),
            onSubmitted: (v) {
              if (v.isNotEmpty) {
                Navigator.pop(context);
                // TODO: Parse & navigate
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: TextStyle(color: _subtextColor(widget.isDarkMode)),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.isNotEmpty) {
                  Navigator.pop(context);
                  // TODO: Parse & navigate
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
              child: const Text("Buka"),
            ),
          ],
        );
      },
    );
  }

  void _showSearchModal() {
    _toggleFab();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: _cardColor(widget.isDarkMode),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _subtextColor(widget.isDarkMode).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Cari judul sutta...",
                        hintStyle: TextStyle(
                          color: _subtextColor(widget.isDarkMode),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _subtextColor(widget.isDarkMode),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(color: _textColor(widget.isDarkMode)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _textColor(widget.isDarkMode),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: _subtextColor(widget.isDarkMode).withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Ketik untuk mencari sutta...",
                      style: TextStyle(
                        color: _subtextColor(widget.isDarkMode),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
