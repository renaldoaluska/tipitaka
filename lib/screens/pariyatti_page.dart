import 'package:flutter/material.dart';
import '../styles/nikaya_style.dart';
import 'menu_page.dart';

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

  // Data kitab - COPY dari home.dart yang lama
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
      "name": "TheragāthÄ",
      "desc": "Syair Thera",
      "range": "Thag 1–21",
    },
    {
      "acronym": "Thig",
      "name": "TherīgÄthÄ",
      "desc": "Syair Therī",
      "range": "Thig 1–16",
    },
    {
      "acronym": "Tha Ap",
      "name": "TherÄpadÄna",
      "desc": "Legenda Thera",
      "range": "Tha Ap 1–563",
      "url": "tha-ap",
    },
    {
      "acronym": "Thi Ap",
      "name": "TherīapadÄna",
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
      "name": "JÄtaka",
      "desc": "Kisah Kelahiran",
      "range": "Ja 1–547",
    },
    {
      "acronym": "Mnd",
      "name": "MahÄniddesa",
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
      "name": "DhÄtukathÄ",
      "desc": "Diskusi Unsur",
      "range": "Dt 1–2",
    },
    {
      "acronym": "Pp",
      "name": "PuggalapaÃ±Ã±atti",
      "desc": "Penggolongan Orang",
      "range": "Pp 1–2",
    },
    {
      "acronym": "Kv",
      "name": "KathÄvatthu",
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
      "name": "ParivÄra",
      "desc": "Ringkasan Aturan",
      "range": "Pvr 1–21",
      "url": "pli-tv-pvr",
    },
    {
      "acronym": "Bu",
      "name": "Suttavibhaṅga\nBhikkhupÄtimokkha",
      "desc": "Aturan Bhikkhu",
      "range": "Bu",
      "url": "pli-tv-bu-pm",
    },
    {
      "acronym": "Bi",
      "name": "Suttavibhaṅga\nBhikkhunīpÄtimokkha",
      "desc": "Aturan Bhikkhunī",
      "range": "Bi",
      "url": "pli-tv-bi-pm",
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Studi Dhamma",
                        style: TextStyle(
                          fontSize: 13,
                          color: _subtextColor(widget.isDarkMode),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "📚 Pariyatti",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor(widget.isDarkMode),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: widget.isDarkMode ? Colors.amber : Colors.grey[700],
                  ),
                  onPressed: widget.onThemeToggle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Compact buttons for Paritta & Sangaha
            Row(
              children: [
                Expanded(
                  child: _buildQuickButton(
                    "🙏 Tematik",
                    Colors.indigo.shade700,
                    () {
                      // TODO: Navigate to Paritta
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickButton(
                    "📖 Saṅgaha",
                    Colors.amber.shade700,
                    () {
                      // TODO: Navigate to Sangaha
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
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
        isScrollable: false,
        tabs: const [
          Tab(text: "Sutta"),
          Tab(text: "Abhidhamma"),
          Tab(text: "Vinaya"),
        ],
      ),
    );
  }

  // COPY build method dari home.dart yang lama
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
          padding: const EdgeInsets.all(8),
          children: parents.map((kitab) {
            final acronym = normalizeNikayaAcronym(kitab["acronym"]!);
            if (kitab["acronym"] == "KN") {
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Card(
                  color: _cardColor(widget.isDarkMode),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: buildNikayaAvatar("KN"),
                    title: Text(
                      "Khuddakanikāya",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _textColor(widget.isDarkMode),
                      ),
                    ),
                    subtitle: Text(
                      kitab["desc"]!,
                      style: TextStyle(
                        color: _subtextColor(widget.isDarkMode),
                        fontSize: 13,
                      ),
                    ),
                    initiallyExpanded: false,
                    children: khuddakaChildren.map((child) {
                      final childAcronym = normalizeNikayaAcronym(
                        child["acronym"]!,
                      );
                      return ListTile(
                        tileColor: _cardColor(widget.isDarkMode),
                        leading: buildNikayaAvatar(childAcronym),
                        title: Text(
                          child["name"]!,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _textColor(widget.isDarkMode),
                          ),
                        ),
                        subtitle: Text(
                          child["desc"]!,
                          style: TextStyle(
                            color: _subtextColor(widget.isDarkMode),
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          child["range"]!,
                          style: TextStyle(
                            fontSize: 13,
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
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: buildNikayaAvatar(acronym),
                title: Text(
                  kitab["name"]!,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _textColor(widget.isDarkMode),
                  ),
                ),
                subtitle: Text(
                  kitab["desc"]!,
                  style: TextStyle(
                    color: _subtextColor(widget.isDarkMode),
                    fontSize: 13,
                  ),
                ),
                trailing: Text(
                  kitab["range"]!,
                  style: TextStyle(
                    fontSize: 14,
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
        padding: const EdgeInsets.all(8),
        itemCount: kitabs.length,
        itemBuilder: (context, index) {
          final kitab = kitabs[index];
          final acronym = normalizeNikayaAcronym(kitab["acronym"]!);
          return Card(
            color: _cardColor(widget.isDarkMode),
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: buildNikayaAvatar(acronym),
              title: Text(
                kitab["name"]!,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _textColor(widget.isDarkMode),
                ),
              ),
              subtitle: Text(
                kitab["desc"]!,
                style: TextStyle(
                  color: _subtextColor(widget.isDarkMode),
                  fontSize: 13,
                ),
              ),
              trailing: Text(
                kitab["range"]!,
                style: TextStyle(
                  fontSize: 14,
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
                "Kode Sutta",
                Icons.tag,
                Colors.blue,
                () => _showCodeInput(),
              ),
            ),
            const SizedBox(height: 10),
            ScaleTransition(
              scale: _fabAnimation,
              child: _buildFabOption(
                "Pencarian",
                Icons.search,
                Colors.green,
                () => _showSearchModal(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            onPressed: _toggleFab,
            backgroundColor: Colors.deepOrange,
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(_isFabExpanded ? Icons.close : Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabOption(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _cardColor(widget.isDarkMode),
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textColor(widget.isDarkMode),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, size: 18),
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
          title: Text(
            "Masukkan Kode Sutta",
            style: TextStyle(color: _textColor(widget.isDarkMode)),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Contoh: mn1, sn12.1",
              border: OutlineInputBorder(),
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
              child: const Text("Batal"),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.isNotEmpty) Navigator.pop(context);
              },
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Cari judul sutta...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: TextStyle(color: _textColor(widget.isDarkMode)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  "Ketik untuk mencari...",
                  style: TextStyle(color: _subtextColor(widget.isDarkMode)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
