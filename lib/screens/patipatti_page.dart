import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';
import '../services/dana_everyday_service.dart';
import '../widgets/header_depan.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import '../screens/html.dart';
import '../data/html_data.dart';

class PatipattiPage extends StatefulWidget {
  final String? highlightSection;
  const PatipattiPage({super.key, this.highlightSection});

  @override
  State<PatipattiPage> createState() => _PatipattiPageState();
}

class _PatipattiPageState extends State<PatipattiPage> {
  bool _showViewAllButton = false; // 🔧 Tambah ini
  String _selectedCategory = 'Semua'; // Tambah ini
  List<Campaign> _campaigns = [];
  bool _isLoadingCampaigns = false;
  final DanaEverydayService _danaService = DanaEverydayService();
  final ScrollController _campaignScrollController = ScrollController();

  // Keys untuk scroll
  final GlobalKey _dermaKey = GlobalKey();
  final GlobalKey _uposathaKey = GlobalKey();
  final GlobalKey _meditasiKey = GlobalKey();
  final GlobalKey _parittaKey = GlobalKey();

  String? _highlightedSection;
  // ═══════════════════════════════════════════════════════════
  // 🌑 STATE UPOSATHA
  // ═══════════════════════════════════════════════════════════
  String _selectedUposathaVersion = "Saṅgha Theravāda Indonesia";
  bool _isLoadingUposatha = false;

  final List<String> _uposathaVersions = [
    "Saṅgha Theravāda Indonesia",
    "Pa-Auk Tawya",
    "Dhammayuttika",
    "Mahānikāya",
    "Lunar Tionghoa",
  ];

  final Map<String, dynamic> _calendarEngines = {
    "RAMA_IV": {
      "next_label": "3 hari lagi",
      "phases": [
        {"date": "1 Jan", "phase_name": "New Moon"},
        {"date": "8 Jan", "phase_name": "First Quarter"},
        {"date": "15 Jan", "phase_name": "Full Moon"},
        {"date": "23 Jan", "phase_name": "Last Quarter"},
      ],
    },
    "TRADITIONAL": {
      "next_label": "BESOK",
      "phases": [
        {"date": "2 Jan", "phase_name": "New Moon"},
        {"date": "9 Jan", "phase_name": "First Quarter"},
        {"date": "16 Jan", "phase_name": "Full Moon"},
        {"date": "24 Jan", "phase_name": "Last Quarter"},
      ],
    },
    "CHINESE": {
      "next_label": "HARI INI",
      "phases": [
        {"date": "29 Jan", "phase_name": "Imlek (Baru)"},
        {"date": "5 Feb", "phase_name": "Kuartal Awal"},
        {"date": "12 Feb", "phase_name": "Cap Go Meh"},
        {"date": "19 Feb", "phase_name": "Kuartal Akhir"},
      ],
    },
  };

  final Map<String, String> _traditionToEngineMap = {
    "Saṅgha Theravāda Indonesia": "RAMA_IV",
    "Pa-Auk Tawya": "TRADITIONAL",
    "Dhammayuttika": "RAMA_IV",
    "Mahānikāya": "TRADITIONAL",
    "Lunar Tionghoa": "CHINESE",
  };

  // ═══════════════════════════════════════════════════════════
  // 💰 STATE DERMA
  // ═══════════════════════════════════════════════════════════
  /*  final List<Map<String, dynamic>> _dermaLinks = [
    //ini customtabs link nanti
    {"label": "Dana Everyday", "icon": Icons.volunteer_activism_rounded},
    {"label": "Pembangunan", "icon": Icons.foundation_rounded},
    {"label": "Buku Dhamma", "icon": Icons.menu_book_rounded},
    {"label": "Obat-obatan", "icon": Icons.medical_services_rounded},
    {"label": "Lainnya", "icon": Icons.more_horiz_rounded},
  ];*/

  // ═══════════════════════════════════════════════════════════
  // 📚 STATE PARITTA
  // ═══════════════════════════════════════════════════════════
  String _selectedParittaTradition = "Saṅgha Theravāda Indonesia";
  bool _isLoadingParitta = false;

  final Map<String, List<Map<String, dynamic>>> _parittaData = {
    "Saṅgha Theravāda Indonesia": [
      {
        "type": "link",
        "label": "Panduan Pembacaan",
        "icon": Icons.info_outline,
        "files": DaftarIsi.parSti0,
      },
      {
        "type": "group",
        "label": "I. Upacara & Pāṭha",
        "icon": Icons.spa_outlined,
        "items": [
          {
            "label": "Tujuh Bulan Kandungan",
            "icon": Icons.pregnant_woman_rounded,
            //    "id": "parSti1",
          },
          {"label": "Menjelang Kelahiran", "icon": Icons.child_care_rounded},
          {
            "label": "Pemberkahan Kelahiran",
            "icon": Icons.child_friendly_rounded,
          },
          {"label": "Ulang Tahun, Turun Tanah", "icon": Icons.cake_outlined},
          {"label": "Potong Rambut", "icon": Icons.content_cut_rounded},
          {"label": "Peletakan Batu Pertama", "icon": Icons.foundation_rounded},
          {"label": "Rumah & Usaha Baru", "icon": Icons.home_work_outlined},
          {
            "label": "Pembersihan Tempat",
            "icon": Icons.cleaning_services_outlined,
          },
          {
            "label": "Tirta Untuk Orang Sakit",
            "icon": Icons.local_hospital_outlined,
          },
          {"label": "Tanam Di Sawah", "icon": Icons.nature_people_outlined},
          {"label": "Pengukuhan Janji Jabatan", "icon": Icons.badge_outlined},
          {"label": "Janji Di Pengadilan", "icon": Icons.gavel_rounded},
          {"label": "Wisuda Upāsaka/upāsikā", "icon": Icons.school_outlined},
          {"label": "Upacara Perkawinan", "icon": Icons.handshake_outlined},
          {"label": "Upacara Kematian", "icon": Icons.local_florist_outlined},
          {
            "label": "Peringatan Kematian (Berkala)",
            "icon": Icons.event_repeat_rounded,
          },
          {
            "label": "Peringatan Kematian (Ziarah)",
            "icon": Icons.yard_outlined,
          },
          {"label": "Catatan", "icon": Icons.note_alt_outlined},
        ],
      },
      {
        "type": "link",
        "label": "II. Tuntunan Pūjā Bakti",
        "icon": Icons.volunteer_activism_outlined,
      },
      {
        "type": "link",
        "label": "III. Ārādhanā & Sikkhāpada",
        "icon": Icons.record_voice_over_outlined,
      },
      {
        "type": "link",
        "label": "IV. Upacara Maṅgala",
        "icon": Icons.favorite_border_rounded,
      },
      {
        "type": "link",
        "label": "V. Upacara Avamaṅgala",
        "icon": Icons.sentiment_dissatisfied_outlined,
      },
      {
        "type": "link",
        "label": "VI. Pāṭha-Pāṭha Khusus",
        "icon": Icons.star_outline_rounded,
      },
      {
        "type": "link",
        "label": "VII. Pūjā Kathā Hari Suci",
        "icon": Icons.calendar_month_outlined,
      },
      {
        "type": "link",
        "label": "VIII. Pakiṇṇakakathā",
        "icon": Icons.card_giftcard_outlined,
      },
    ],
    "Lainnya": [
      {
        "type": "link",
        "label": "Persembahan Cetiya",
        "icon": Icons.temple_buddhist_outlined,
      },
      {
        "type": "link",
        "label": "Paṭipattiyā Ratanattaya",
        "icon": Icons.self_improvement,
      },
      {
        "type": "link",
        "label": "Paṭiccasamuppāda",
        "icon": Icons.sync_alt_rounded,
      },
      {
        "type": "group",
        "label": "Pelafalan Pagi",
        "icon": Icons.wb_twilight,
        "items": [
          {"label": "Anekajāti Pāḷi", "icon": Icons.wb_sunny_outlined},
          {"label": "Paccavekkhaṇā", "icon": Icons.restaurant_menu_rounded},
        ],
      },
      {
        "type": "group",
        "label": "Pelafalan Malam",
        "icon": Icons.nights_stay_outlined,
        "items": [
          {"label": "Mahā Namakkāra Pāḷi", "icon": Icons.nights_stay_rounded},
        ],
      },
      {
        "type": "group",
        "label": "Hari Uposatha",
        "icon": Icons.calendar_month,
        "items": [
          {"label": "Paccayuddeso", "icon": Icons.list_alt_rounded},
          {"label": "Paccayaniddeso", "icon": Icons.description_outlined},
        ],
      },
    ],
  };

  static const String _keyUposatha = 'selected_uposatha_version';
  static const String _keyParitta = 'selected_paritta_tradition';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadCampaigns();

    // Cek jika ada highlight saat pertama kali dibuat
    if (widget.highlightSection != null) {
      _scheduleScroll(widget.highlightSection!);
    }
  }

  @override
  void dispose() {
    _campaignScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PatipattiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cek jika ada update data dari parent (main.dart)
    if (widget.highlightSection != oldWidget.highlightSection &&
        widget.highlightSection != null) {
      _scheduleScroll(widget.highlightSection!);
    }
  }

  Future<void> _launchCustomTab(BuildContext context, String url) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: const CustomTabsOptions(
          showTitle: true,
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: true,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: isDarkMode ? Colors.grey[900] : Colors.orange,
          preferredControlTintColor: Colors.white,
          barCollapsingEnabled: true,
        ),
      );
    } catch (e) {
      // ✅ Fix: Check if widget is still mounted before using context
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error membuka $url: $e")));
      }
    }
  }

  // Letakkan di bawah, dekat dengan method build atau dispose
  void _openHtmlBook(BuildContext context, String title, List<String>? files) {
    if (files != null && files.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlReaderPage(
            title: title,
            chapterFiles: files,
            initialIndex: 0,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Konten '$title' belum tersedia.")),
      );
    }
  }

  // 👇 FUNGSI BARU: Menjadwalkan scroll dengan delay aman
  // 👇 GANTI BAGIAN INI
  void _scheduleScroll(String section) {
    // Kita coba scroll dengan mekanisme retry (coba berulang)
    // Maksimal mencoba 10 kali (total ~2 detik)
    _attemptScroll(section, 0);
  }

  void _attemptScroll(String section, int attempt) {
    if (!mounted) return;

    // Tentukan target key
    GlobalKey? targetKey;
    switch (section) {
      case 'derma':
        targetKey = _dermaKey;
        break;
      case 'uposatha':
        targetKey = _uposathaKey;
        break;
      case 'meditasi':
        targetKey = _meditasiKey;
        break;
      case 'paritta':
        targetKey = _parittaKey;
        break;
    }

    // 🕵️ CEK: Apakah kuncinya sudah nempel di widget dan punya context?
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(
          milliseconds: 800,
        ), // Agak lambatin dikit biar smooth
        curve: Curves.easeOutCubic,
        alignment: 0.1, // Posisi item di 10% dari atas layar
      );

      // Nyalain efek highlight
      setState(() => _highlightedSection = section);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedSection = null);
      });
    } else {
      // ❌ Kalau belum ketemu
      if (attempt < 10) {
        // Tunggu 200ms, lalu coba lagi
        Future.delayed(const Duration(milliseconds: 200), () {
          _attemptScroll(section, attempt + 1);
        });
      }
      //else {
      //   print('💀 Nyerah. Context $section gak ketemu-ketemu.');
      //}
    }
  }

  /* void _scrollToSection(String section) {
    print('🚀 Mencoba scroll ke: $section');
    GlobalKey? targetKey;

    switch (section) {
      case 'derma':
        targetKey = _dermaKey;
        break;
      case 'uposatha':
        targetKey = _uposathaKey;
        break;
      case 'meditasi':
        targetKey = _meditasiKey;
        break;
      case 'paritta':
        targetKey = _parittaKey;
        break;
    }

    // Pastikan Key dan Context-nya sudah ada (Valid)
    if (targetKey != null && targetKey.currentContext != null) {
      print('✅ Context ditemukan. Scrolling...');
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(
          milliseconds: 600,
        ), // Durasi scroll lebih santai
        curve: Curves.easeInOutCubic, // Curve lebih smooth
        alignment: 0.1, // Posisi sedikit di bawah header
      );

      // Efek Glow/Highlight
      setState(() => _highlightedSection = section);

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedSection = null);
      });
    } else {
      print('❌ Gagal Scroll: Context belum siap/null untuk $section');
      // Opsional: Coba lagi sekali lagi jika gagal (Retry mechanism)
      // Future.delayed(const Duration(milliseconds: 200), () => _scrollToSection(section));
    }
  }
*/
  // Wrapper untuk highlight
  Widget _buildHighlightWrapper({
    required String sectionKey,
    required GlobalKey globalKey,
    required Widget child,
  }) {
    final isHighlighted = _highlightedSection == sectionKey;

    return AnimatedContainer(
      key: globalKey,
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  String _getMoonIcon(String phaseName) {
    final lower = phaseName.toLowerCase();
    if (lower.contains('new') ||
        lower.contains('baru') ||
        lower.contains('imlek') ||
        lower.contains('tilem')) {
      return '🌑';
    }
    if (lower.contains('full') ||
        lower.contains('penuh') ||
        lower.contains('purnama') ||
        lower.contains('cap go meh')) {
      return '🌕';
    }
    if (lower.contains('first') || lower.contains('awal')) return '🌓';
    if (lower.contains('last') || lower.contains('akhir')) return '🌗';
    return '🌑';
  }

  Future<void> _loadCampaigns({String? categoryId}) async {
    setState(() => _isLoadingCampaigns = true);

    // 🔧 Reset scroll ke awal
    if (_campaignScrollController.hasClients) {
      _campaignScrollController.jumpTo(0);
    }

    try {
      List<Campaign> campaigns;

      if (categoryId != null) {
        campaigns = await _danaService.fetchCampaigns(categoryId);
      } else {
        campaigns = await _danaService.fetchTopCampaigns();
      }

      if (mounted) {
        setState(() {
          _campaigns = campaigns;
          _isLoadingCampaigns = false;
          _showViewAllButton = false; // 🔧 Reset button juga
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCampaigns = false);
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedUposatha = prefs.getString(_keyUposatha);
      if (savedUposatha != null && _uposathaVersions.contains(savedUposatha)) {
        _selectedUposathaVersion = savedUposatha;
      }
      final savedParitta = prefs.getString(_keyParitta);
      if (savedParitta != null && _parittaData.containsKey(savedParitta)) {
        _selectedParittaTradition = savedParitta;
      }
    });
  }

  Future<void> _savePreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),

          // 🟢 1. DĀNA FRAMEWORK
          SliverToBoxAdapter(child: _buildDermaCard()),

          // 🟡 2. SĪLA FRAMEWORK
          SliverToBoxAdapter(child: _buildUposathaCard()),

          // 🔴 3. SAMĀDHI FRAMEWORK
          SliverToBoxAdapter(child: _buildMeditationCard()),

          // 🟠 4. PAÑÑĀ FRAMEWORK
          SliverToBoxAdapter(child: _buildParittaCard()),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final transparentColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.85);

    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 80,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(color: transparentColor),
        ),
      ),
      title: const HeaderDepan(title: "Paṭipatti", subtitle: "Praktik Dhamma"),
      centerTitle: true,
      titleSpacing: 0,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✨ HEADER STRIP BUILDER ("Payung")
  // Full width, nempel atas, teks rata kiri, tanpa icon
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeaderStrip(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.withValues(alpha: 0.08);
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity, // Mentok kiri kanan
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Text(
        text.toUpperCase(), // Uppercase biar lebih firm sebagai header
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 1.2, // Kasih jarak antar huruf biar estetik
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 1. DERMA CARD (Dāna)
  // ═══════════════════════════════════════════════════════════
  Widget _buildDermaCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFF009688); // Teal
    final lightBg = isDark ? const Color(0xFF1A3F3A) : const Color(0xFFE0F2F1);
    final borderColor = isDark
        ? const Color(0xFF2D6A64)
        : const Color(0xFFB2DFDB);

    return _buildHighlightWrapper(
      sectionKey: 'derma',
      globalKey: _dermaKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 🏷️ HEADER STRIP
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "DĀNA",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: subtextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Didukung oleh ",
                          style: TextStyle(
                            fontSize: 9,
                            color: subtextColor.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          "Yayasan Dana Everyday",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // KONTEN UTAMA
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Derma",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Praktik Memberi",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: accentColor,
                            size: 20,
                          ),
                          onPressed: _isLoadingCampaigns
                              ? null
                              : _loadCampaigns,
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🏷️ Category Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryChip(
                            label: 'Semua',
                            isSelected: _selectedCategory == 'Semua',
                            accentColor: accentColor,
                            lightBg: lightBg,
                            onTap: () {
                              setState(() => _selectedCategory = 'Semua');
                              _loadCampaigns();
                            },
                          ),
                          ...DanaEverydayService.categories.entries.map((
                            entry,
                          ) {
                            return _buildCategoryChip(
                              label: entry.key,
                              isSelected: _selectedCategory == entry.key,
                              accentColor: accentColor,
                              lightBg: lightBg,
                              onTap: () {
                                setState(() => _selectedCategory = entry.key);
                                _loadCampaigns(categoryId: entry.value);
                              },
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Campaign Cards dengan dynamic button
                    _isLoadingCampaigns
                        ? _buildLoadingShimmer(lightBg, borderColor)
                        : _campaigns.isEmpty
                        ? _buildEmptyState(subtextColor)
                        : SizedBox(
                            height: 185,
                            child: Stack(
                              children: [
                                // Cards ListView
                                NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification
                                        is ScrollUpdateNotification) {
                                      final scrollController =
                                          notification.metrics;
                                      final isAtEnd =
                                          scrollController.pixels >=
                                          scrollController.maxScrollExtent - 50;

                                      if (isAtEnd != _showViewAllButton) {
                                        setState(
                                          () => _showViewAllButton = isAtEnd,
                                        );
                                      }
                                    }
                                    return false;
                                  },
                                  child: ListView.separated(
                                    controller: _campaignScrollController,
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.only(
                                      right: 95,
                                    ), // 🔧 Tambah padding kanan
                                    itemCount: _campaigns.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final campaign = _campaigns[index];
                                      return _buildCampaignCard(
                                        campaign: campaign,
                                        accentColor: accentColor,
                                        lightBg: lightBg,
                                        borderColor: borderColor,
                                        textColor: textColor,
                                        subtextColor: subtextColor,
                                      );
                                    },
                                  ),
                                ),

                                // Floating "Lihat Semua" button (muncul di kanan)
                                if (_showViewAllButton)
                                  Positioned(
                                    right: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Material(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(30),
                                        elevation: 4,
                                        child: InkWell(
                                          onTap: () => _launchCustomTab(
                                            context,
                                            'https://www.danaeveryday.id/campaign_category',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.open_in_new_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Lebih\nBanyak',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                    const SizedBox(height: 10),

                    // Bottom Button (restore)
                    SizedBox(
                      width: double.infinity,
                      child: _buildMenuButton(
                        label: "Lihat Semua Campaign",
                        icon: Icons.open_in_new_rounded,
                        color: accentColor,
                        lightBg: lightBg,
                        borderColor: borderColor,
                        isHorizontal: true,
                        isCentered: true,
                        onTap: () => _launchCustomTab(
                          context,
                          'https://www.danaeveryday.id/campaign_category',
                        ),
                      ),
                    ),

                    // Bottom Button
                    SizedBox(width: double.infinity),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // 🎴 CAMPAIGN CARD WIDGET
  // ==============================================================
  // 🔧 GANTI _buildCampaignCard() dengan yang ini:

  Widget _buildCampaignCard({
    required Campaign campaign,
    required Color accentColor,
    required Color lightBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: lightBg.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _launchCustomTab(context, campaign.fullUrl),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼️ Image Header (LEBIH KECIL LAGI)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: campaign.imageUrl.isNotEmpty
                        ? Image.network(
                            campaign.imageUrl,
                            height: 80, // 🔧 REDUCED dari 100 ke 80
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildImagePlaceholder(accentColor, 80),
                          )
                        : _buildImagePlaceholder(accentColor, 80),
                  ),
                  // Category Badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        campaign.categoryName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 📝 Content (LEBIH COMPACT)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        campaign.name,
                        style: TextStyle(
                          fontSize: 12, // 🔧 dari 13 ke 12
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),

                      // Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                campaign.formattedCollected,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              Text(
                                '${campaign.percent}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: campaign.percent / 100,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accentColor,
                              ),
                              minHeight: 4, // 🔧 dari 6 ke 4
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Target: ${campaign.formattedTarget}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: subtextColor,
                                ),
                              ),
                              if (campaign.daysRemaining > 0)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 10,
                                      color: subtextColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${campaign.daysRemaining} hari',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // 🎨 HELPER WIDGETS
  // ==============================================================
  Widget _buildImagePlaceholder(Color color, double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      child: Icon(
        Icons.image_outlined,
        size: 35,
        color: color.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildLoadingShimmer(Color lightBg, Color borderColor) {
    return SizedBox(
      height: 185, // 🔧 Match dengan campaign height
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 280,
          decoration: BoxDecoration(
            color: lightBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFF009688),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subtextColor) {
    return Container(
      height: 185, // 🔧 Match dengan campaign height
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: subtextColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada campaign tersedia',
            style: TextStyle(fontSize: 12, color: subtextColor),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌙 2. UPOSATHA CARD (Sīla)
  // ═══════════════════════════════════════════════════════════
  Widget _buildUposathaCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFF57F17);
    final lightBg = isDark ? const Color(0xFF4A4417) : const Color(0xFFFFF8E1);
    final borderColor = isDark
        ? const Color(0xFF6D621F)
        : const Color(0xFFFFE082);

    String engineKey =
        _traditionToEngineMap[_selectedUposathaVersion] ?? "TRADITIONAL";
    final currentData = _calendarEngines[engineKey]!;
    final String nextLabel = currentData['next_label'];
    final List<Map<String, String>> phasesRaw = List<Map<String, String>>.from(
      currentData['phases'],
    );

    return _buildHighlightWrapper(
      sectionKey: 'uposatha',
      globalKey: _uposathaKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 🏷️ HEADER STRIP
              _buildHeaderStrip("Sīla"),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.nightlight_round,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Uposatha",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Pengamalan Puasa",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isLoadingUposatha ? 0.5 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              nextLabel,
                              style: const TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: lightBg.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Versi",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUposathaVersion,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: accentColor,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: _uposathaVersions.map((version) {
                                  return DropdownMenuItem(
                                    value: version,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        version,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) async {
                                  if (value != null &&
                                      value != _selectedUposathaVersion) {
                                    setState(() => _isLoadingUposatha = true);
                                    await Future.delayed(
                                      const Duration(milliseconds: 500),
                                    );
                                    setState(() {
                                      _selectedUposathaVersion = value;
                                      _isLoadingUposatha = false;
                                    });
                                    _savePreference(_keyUposatha, value);
                                  }
                                },
                                selectedItemBuilder: (BuildContext context) {
                                  return _uposathaVersions.map((String value) {
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        value,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: accentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      height: 85,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: _isLoadingUposatha
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accentColor,
                                ),
                              ),
                            )
                          : AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: _isLoadingUposatha ? 0.0 : 1.0,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: phasesRaw.map((phaseData) {
                                  String icon = _getMoonIcon(
                                    phaseData["phase_name"]!,
                                  );
                                  String date = phaseData["date"]!;
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        icon,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        date,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            label: "Kalender",
                            icon: Icons.calendar_today,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: true,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Panduan",
                            icon: Icons.article_outlined,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: true,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🧘 3. MEDITASI CARD (Samādhi)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMeditationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFD32F2F);
    final lightBg = isDark ? const Color(0xFF4A1F1F) : const Color(0xFFFFEBEE);
    final borderColor = isDark
        ? const Color(0xFF6D2C2C)
        : const Color(0xFFFFCDD2);

    return _buildHighlightWrapper(
      sectionKey: 'meditasi',
      globalKey: _meditasiKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 🏷️ HEADER STRIP
              _buildHeaderStrip("Bhāvanā"),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.self_improvement_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Meditasi",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Pengembangan Batin",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            label: "Timer",
                            icon: Icons.timer_outlined,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: false,
                            isCentered: false,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Audio",
                            icon: Icons.headphones_rounded,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: false,
                            isCentered: false,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Video",
                            icon: Icons.play_circle_outline,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: false,
                            isCentered: false,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📖 4. PARITTA CARD (Paññā)
  // ═══════════════════════════════════════════════════════════
  Widget _buildParittaCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFF57C00);
    final lightBg = isDark ? const Color(0xFF4A3517) : const Color(0xFFFFF3E0);
    final borderColor = isDark
        ? const Color(0xFF6D4C1F)
        : const Color(0xFFFFE0B2);

    final List<Map<String, dynamic>> currentList =
        _parittaData[_selectedParittaTradition] ?? [];

    return _buildHighlightWrapper(
      sectionKey: 'paritta',
      globalKey: _parittaKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 🏷️ HEADER STRIP
              _buildHeaderStrip("Bhāvanā"),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.book_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Paritta",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Syair Perlindungan",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: lightBg.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Tradisi",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedParittaTradition,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: accentColor,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: _parittaData.keys.map((String key) {
                                  return DropdownMenuItem(
                                    value: key,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        key,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) async {
                                  if (value != null &&
                                      value != _selectedParittaTradition) {
                                    setState(() => _isLoadingParitta = true);
                                    await Future.delayed(
                                      const Duration(milliseconds: 500),
                                    );
                                    setState(() {
                                      _selectedParittaTradition = value;
                                      _isLoadingParitta = false;
                                    });
                                    _savePreference(_keyParitta, value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    const SizedBox(height: 12),
                    _isLoadingParitta
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: accentColor,
                              ),
                            ),
                          )
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _isLoadingParitta ? 0.0 : 1.0,
                            child: Column(
                              children: currentList.map((item) {
                                if (item['type'] == 'group') {
                                  return _buildExpansionGroup(
                                    title: item['label'],
                                    sectionIcon: item['icon'],
                                    items: item['items'],
                                    accentColor: accentColor,
                                    lightBg: lightBg,
                                  );
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildMenuButton(
                                      label: item['label'],
                                      icon: item['icon'],
                                      color: accentColor,
                                      lightBg: lightBg,
                                      borderColor: borderColor,
                                      isHorizontal: true,
                                      onTap: () {
                                        _openHtmlBook(
                                          context,
                                          item['label'],
                                          item['files'],
                                        );
                                      },
                                    ),
                                  );
                                }
                              }).toList(),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required Color accentColor,
    required Color lightBg,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? accentColor : lightBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white24 : Colors.black12),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✨ HELPER: EXPANSION GROUP
  // ═══════════════════════════════════════════════════════════
  Widget _buildExpansionGroup({
    required String title,
    required IconData sectionIcon,
    required List<Map<String, dynamic>> items,
    required Color accentColor,
    required Color lightBg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF6D4C1F)
        : const Color(0xFFFFE0B2);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final iconBoxColor = isDark
        ? Colors.black26
        : Colors.white.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: lightBg.withValues(alpha: 0.3),
            collapsedBackgroundColor: lightBg,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            collapsedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 0,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBoxColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(sectionIcon, color: accentColor, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildMenuButton(
                  label: item['label'],
                  icon: item['icon'],
                  color: accentColor,
                  lightBg: lightBg,
                  borderColor: borderColor,
                  isHorizontal: true,
                  onTap: () {
                    _openHtmlBook(context, item['label'], item['files']);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✨ HELPER: MENU BUTTON
  // ═══════════════════════════════════════════════════════════
  // Ganti function _buildMenuButton yang paling bawah dengan ini:
  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color lightBg,
    required Color borderColor,
    required VoidCallback onTap,
    bool isHorizontal = false,
    bool isCentered = true,
    bool isSlider =
        false, // 👈 Parameter baru default false (aman buat Paritta)
    double? width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final iconBoxColor = isDark
        ? Colors.black26
        : Colors.white.withValues(alpha: 0.6);

    return Material(
      color: lightBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          width: width,
          height: isHorizontal ? 54 : 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: isHorizontal
              ? Row(
                  mainAxisAlignment: isCentered
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBoxColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // 👇 LOGIKA BARU:
                    // Kalau isSlider = true (Derma) -> Pakai Text biasa biar lebar ngikutin teks.
                    // Kalau isSlider = false (Paritta) -> Pakai Expanded biar teks kepotong (...) kalo kepentok layar.
                    isSlider
                        ? Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          )
                        : Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBoxColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
