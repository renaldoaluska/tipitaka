import 'package:flutter/material.dart';
import 'dart:math';
import '../styles/nikaya_style.dart';
import '../widgets/compact_card.dart';
import '../widgets/icon_button_builder.dart';
import '../widgets/header_depan.dart';
import '../widgets/explore/explore_tab_app.dart';
import '../widgets/explore/explore_tab_kamus.dart';
import '../widgets/explore/explore_tab_forum.dart';
import '../widgets/explore/explore_tab_info.dart';
import '../widgets/explore/explore_tab_unduh.dart';
import '../widgets/explore/explore_tab_ikuti.dart';
import 'dart:ui';
import '../services/history.dart';
import '../screens/suttaplex.dart';

class Home extends StatefulWidget {
  final void Function(int index, {String? highlightSection})?
  onNavigate; // 👈 Callback untuk navigasi ke tab lain

  const Home({super.key, this.onNavigate});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isEditMode = false; // 🔥 Mode edit
  final Set<String> _selectedBookmarks = {}; // 🔥 Selected items
  final List<Map<String, String>> _dhammapadaQuotes = [
    {
      "verse": "183",
      "pali":
          "Sabbapāpassa akaraṇaṁ, kusalassa upasampadā; Sacittapariyodapanaṁ, etaṁ buddhāna sāsanaṁ.",
      "trans":
          "Tidak berbuat kejahatan, mengembangkan kebajikan, memurnikan pikiran—inilah ajaran para Buddha.",
    },
    {
      "verse": "1",
      "pali": "Manopubbaṅgamā dhammā, manoseṭṭhā manomayā;",
      "trans":
          "Pikiran adalah pelopor dari segala hal, pikiran adalah pemimpin, pikiran adalah pembentuk.",
    },
    {
      "verse": "223",
      "pali": "Akkodhena jine kodhaṁ, asādhuṁ sādhunā jine;",
      "trans":
          "Kalahkan amarah dengan tidak marah, kalahkan kejahatan dengan kebaikan.",
    },
    {
      "verse": "103",
      "pali":
          "Yo sahassaṃ sahassena, saṅgāme mānuse jine; Ekañca jeyyamattānaṁ, sa ve saṅgāmajuttamo.",
      "trans":
          "Walaupun seseorang dapat menaklukkan ribuan musuh, dalam ribuan kali pertempuran; Namun sesungguhnya penakluk terbesar, adalah orang yang dapat menaklukkan dirinya sendiri.",
    },
  ];
  Map<String, String>? _todayQuote;
  List<Map<String, dynamic>> _recentlyViewed = [];
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoadingHistory = true;

  /* final List<Map<String, String>> _recentlyViewed = [
    {"uid": "mn1", "title": "MN 1 Mūlapariyāya Sutta", "kitab": "MN"},
    {"uid": "sn56.11", "title": "SN 56.11 Dhammacakka", "kitab": "SN"},
    {"uid": "an3.65", "title": "AN 3.65 Kālāma", "kitab": "AN"},
  ];

  final List<Map<String, dynamic>> _bookmarks = [
    {"uid": "sn56.11", "title": "SN 56.11 Dhammacakka", "kitab": "SN"},
    {"uid": "an3.65", "title": "AN 3.65 Kālāma", "kitab": "AN"},
    {"uid": "dhp183", "title": "Dhp 183 Sabbapāpassa", "kitab": "Dhp"},
  ];*/

  @override
  void initState() {
    super.initState();
    _loadTodayQuote();
    _loadHistoryAndBookmarks(); // 🔥 TAMBAH INI
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadHistoryAndBookmarks() async {
    final history = await HistoryService.getHistory();
    final bookmarks = await HistoryService.getBookmarks();

    if (mounted) {
      setState(() {
        _recentlyViewed = history;
        _bookmarks = bookmarks;
        _isLoadingHistory = false;
      });
    }
  }

  // Refresh data secara manual
  Future<void> _refreshData() async {
    await _loadHistoryAndBookmarks();
  }

  void _loadTodayQuote() {
    final seed = DateTime.now().day + DateTime.now().month * 100;
    final random = Random(seed);
    setState(() {
      _todayQuote = _dhammapadaQuotes[random.nextInt(_dhammapadaQuotes.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Ambil warna dari Theme, bukan parameter
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          final isLandscape = constraints.maxWidth > constraints.maxHeight;

          if (isTablet && isLandscape) {
            // TABLET LANDSCAPE: Grid 2x2 dengan Eksplor combine
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // Baris 1: Ayat | Akses Cepat
                SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        // 🔥 KIRI: Margin kanan 0
                        child: _buildQuoteCard(
                          customMargin: const EdgeInsets.fromLTRB(16, 0, 0, 8),
                        ),
                      ), // ← TAMBAH flex: 4
                      // 🔥 JARAK TENGAH: Cuma ini yang ngasih jarak (24px)
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6, // 🔥 KANAN: Padding kiri 0
                        child: _buildQuickAccess(
                          customPadding: const EdgeInsets.only(
                            left: 0,
                            right: 16,
                          ),
                        ),
                      ), // ← TAMBAH flex: 6
                    ],
                  ),
                ),
                // Baris 2: Eksplor | (Terakhir Dilihat + Penanda)
                SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Eksplor (makan tinggi penuh)
                      Expanded(
                        flex:
                            4, // ← TAMBAH INI (40%)// 🔥 KIRI: Padding kanan 0
                        child: _buildExploreSection(
                          customPadding: const EdgeInsets.only(
                            left: 16,
                            right: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24), // 🔥 Jarak Tengah
                      // Kolom Kanan: Terakhir Dilihat + Penanda (stack vertikal)
                      Expanded(
                        flex: 6, // ← TAMBAH INI (60%)
                        child: Column(
                          children: [
                            // 🔥 KANAN: Padding kiri 0
                            _buildRecentlyViewed(
                              customPadding: const EdgeInsets.only(
                                left: 0,
                                right: 16,
                              ),
                            ),
                            _buildBookmarks(
                              customPadding: const EdgeInsets.only(
                                left: 0,
                                right: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            /*} else if (isTablet && !isLandscape) {
            // TABLET PORTRAIT: Ayat | Akses Cepat, lalu sisanya full width
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // ← UBAH JADI center
                    children: [
                      // Kolom Kiri: Akses Cepat
                      Expanded(child: _buildQuickAccess()),
                      const SizedBox(width: 16),
                      // Kolom Kanan: Ayat
                      Expanded(child: _buildQuoteCard()),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: _buildRecentlyViewed()),
                SliverToBoxAdapter(child: _buildBookmarks()),
                SliverToBoxAdapter(child: _buildExploreSection()),
              ],
            );
         */
          } else {
            // MOBILE: 1 kolom vertikal (seperti sekarang)
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildQuoteCard()),
                SliverToBoxAdapter(child: _buildQuickAccess()),
                SliverToBoxAdapter(child: _buildRecentlyViewed()),
                SliverToBoxAdapter(child: _buildBookmarks()),
                SliverToBoxAdapter(child: _buildExploreSection()),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildAppBar() {
    // Ambil warna background dari tema, terus dibikin agak transparan
    final transparentColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.85);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SliverAppBar(
      pinned: true, // Wajib true biar melayang
      floating: true,

      // ✅ Bikin background aslinya transparan biar flexibleSpace kelihatan
      backgroundColor: Colors.transparent,

      // Matikan bayangan default biar gak numpuk
      elevation: 0,
      scrolledUnderElevation: 0,

      automaticallyImplyLeading: false,

      toolbarHeight: isLandscape ? 60 : 80,

      // ✅ INI RAHASIANYA: Efek Kaca Buram (Frosted Glass)
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          // Atur tingkat keburaman (makin gede makin ngeblur)
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            color: transparentColor, // Warna semi-transparan
          ),
        ),
      ),

      title:
          //Transform.translate(
          //  offset: Offset(0, (isLandscape ? 0 : 0)),
          //child:
          const HeaderDepan(
            title: "myDhamma",
            subtitle: "Namo Buddhāya", // Subtitle utama
            subtitlesList: [
              // List tambahannya
              "Sotthi Hotu",
              "Suvatthi Hotu",
              "Sukhī Hotu",
              "Sukhitā Hontu Ñātayo",
              "Sabbe Sattā Bhavantu Sukhitattā",
              "Nibbānassa Paccayo Hotu",
              "Buddhasāsanaṁ Ciraṁ Tiṭṭhatu",
              "Sādhu Sādhu Sādhu",
            ],
            enableAnimation: true,
          ),
      // ),
      centerTitle: true,
      titleSpacing: 0,
    );
  }

  Widget _buildQuoteCard({EdgeInsets? customMargin}) {
    if (_todayQuote == null) return const SizedBox.shrink();

    // ✅ Ambil warna dari Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Container(
      // 🔥 Pake customMargin kalau ada, kalau null pake default
      margin: customMargin ?? const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        elevation: 1,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.orange.shade900, Colors.deepOrange.shade900]
                  : [Colors.orange.shade50, Colors.amber.shade50],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: isDark ? Colors.amber : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Dhammapada ${_todayQuote!["verse"]}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amber : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _todayQuote!["pali"]!,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _todayQuote!["trans"]!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccess({EdgeInsets? customPadding}) {
    // 🔥 Pake customPadding kalau ada
    final padding = customPadding ?? const EdgeInsets.symmetric(horizontal: 16);

    final features = [
      {
        "label": "Tipiṭaka",
        "icon": Icons.menu_book_rounded,
        "color": const Color(0xFF1565C0),
        "onTap": () {
          widget.onNavigate?.call(1);
        },
      },
      {
        "label": "Uposatha",
        "icon": Icons.nightlight_round,
        "color": const Color(0xFFF9A825),
        "onTap": () {
          widget.onNavigate?.call(4, highlightSection: 'uposatha');
        },
      },
      {
        "label": "Meditasi",
        "icon": Icons.self_improvement_rounded,
        "color": const Color(0xFFD32F2F),
        "onTap": () {
          widget.onNavigate?.call(4, highlightSection: 'meditasi');
        },
      },
      {
        "label": "Paritta",
        "icon": Icons.book_rounded,
        "color": const Color(0xFFF57C00),
        "onTap": () {
          widget.onNavigate?.call(4, highlightSection: 'paritta');
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: padding, // 🔥 Gunakan padding variabel
          child: Text(
            "Akses Cepat",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: padding, // 🔥 Gunakan padding variabel
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: features.map((f) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButtonBuilder(
                    label: f["label"] as String,
                    icon: f["icon"] as IconData,
                    color: f["color"] as Color,
                    onTap: f["onTap"] as VoidCallback,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyViewed({EdgeInsets? customPadding}) {
    // 🔥 Pake customPadding kalau ada
    final padding = customPadding ?? const EdgeInsets.symmetric(horizontal: 16);

    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).colorScheme.surface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: padding, // 🔥 Gunakan padding variabel
          child: Text(
            "Terakhir Dilihat",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_recentlyViewed.isEmpty)
          Padding(
            padding: padding, // 🔥 Gunakan padding variabel
            child: Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 24,
                      color: subTextColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Belum ada riwayat bacaan",
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: padding, // 🔥 Gunakan padding variabel
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _recentlyViewed.length.clamp(0, 3),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final rv = _recentlyViewed[index];
                final displayAcronym = _getDisplayAcronym(
                  rv["uid"],
                  rv["acronym"],
                );
                final String nikayaKey = _getNikayaKey(displayAcronym);

                return Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    leading: buildNikayaAvatar(nikayaKey),
                    title: Text(
                      rv["title"] ?? rv["uid"],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rv["original_title"] != null &&
                            rv["original_title"].toString().isNotEmpty)
                          Text(
                            rv["original_title"],
                            style: TextStyle(fontSize: 12, color: subTextColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          "${rv["lang_name"] ?? '-'} • ${rv["author"] ?? '-'}",
                          style: TextStyle(
                            fontSize: 11,
                            color: subTextColor.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: Text(
                      displayAcronym,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: getNikayaColor(nikayaKey),
                      ),
                    ),
                    onTap: () {
                      _openSuttaplex(context, rv["uid"]);
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBookmarks({EdgeInsets? customPadding}) {
    // 🔥 Pake customPadding kalau ada
    final padding = customPadding ?? const EdgeInsets.symmetric(horizontal: 16);

    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: padding, // 🔥 Gunakan padding variabel
          child: Row(
            children: [
              Text(
                "Penanda",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(80, 36),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: () {
                  _showAllBookmarks(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("Lihat Semua", style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_bookmarks.isEmpty)
          Padding(
            padding: padding, // 🔥 Gunakan padding variabel
            child: SizedBox(
              height: 56,
              child: Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 24,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Belum ada sutta yang ditandai",
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 135,
            child: ListView.builder(
              padding:
                  padding, // 🔥 Gunakan padding variabel buat horizontal list
              scrollDirection: Axis.horizontal,
              itemCount: _bookmarks.length.clamp(0, 5),
              itemBuilder: (context, index) {
                final b = _bookmarks[index];
                final displayAcronym = _getDisplayAcronym(
                  b["uid"],
                  b["acronym"],
                );
                final nikayaKey = _getNikayaKey(displayAcronym);
                return Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 10, bottom: 5),
                  child: Card(
                    elevation: 1,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _openSuttaplex(context, b["uid"]);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                buildNikayaAvatar(nikayaKey),
                                const Spacer(),
                                Text(
                                  displayAcronym,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: getNikayaColor(nikayaKey),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              b["title"] ?? b["uid"],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (b["note"] != null &&
                                b["note"].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                b["note"],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _getNikayaKey(String displayAcronym) {
    final match = RegExp(r'\d').firstMatch(displayAcronym);
    if (match != null) {
      return displayAcronym.substring(0, match.start).trim();
    }
    return displayAcronym.trim();
  }

  String _getDisplayAcronym(String? uid, String? rawAcronym) {
    // 1. Jika acronym dari database sudah ada angka, pakai saja.
    if (rawAcronym != null && rawAcronym.contains(RegExp(r'[0-9]'))) {
      return rawAcronym;
    }

    if (uid == null || uid.isEmpty) return rawAcronym ?? "";

    String derivedAcronym = "";
    String numberPart = "";

    // Ambil angka dari UID
    final match = RegExp(r'\d').firstMatch(uid);
    if (match != null) {
      numberPart = uid.substring(match.start);
    }

    // --- FILTER 1: KHUSUS VINAYA (Mapping Manual) ---
    if (uid.startsWith("pli-tv-")) {
      if (uid.contains("bu-vb-pj")) {
        derivedAcronym = "Bu Pj";
      } else if (uid.contains("bu-vb-ss")) {
        derivedAcronym = "Bu Ss";
      } else if (uid.contains("bu-vb-ay")) {
        derivedAcronym = "Bu Ay";
      } else if (uid.contains("bu-vb-np")) {
        derivedAcronym = "Bu Np";
      } else if (uid.contains("bu-vb-pc")) {
        derivedAcronym = "Bu Pc";
      } else if (uid.contains("bu-vb-pd")) {
        derivedAcronym = "Bu Pd";
      } else if (uid.contains("bu-vb-sk")) {
        derivedAcronym = "Bu Sk";
      } else if (uid.contains("bu-vb-as")) {
        derivedAcronym = "Bu As";
      } else if (uid.contains("bi-vb-pj")) {
        derivedAcronym = "Bi Pj";
      } else if (uid.contains("bi-vb-ss")) {
        derivedAcronym = "Bi Ss";
      } else if (uid.contains("bi-vb-np")) {
        derivedAcronym = "Bi Np";
      } else if (uid.contains("bi-vb-pc")) {
        derivedAcronym = "Bi Pc";
      } else if (uid.contains("bi-vb-pd")) {
        derivedAcronym = "Bi Pd";
      } else if (uid.contains("bi-vb-sk")) {
        derivedAcronym = "Bi Sk";
      } else if (uid.contains("bi-vb-as")) {
        derivedAcronym = "Bi As";
      } else if (uid.contains("kd")) {
        derivedAcronym = "Kd";
      } else if (uid.contains("pvr")) {
        derivedAcronym = "Pvr";
      } else if (uid.contains("bu-pm")) {
        derivedAcronym = "Bu";
      } else if (uid.contains("bi-pm")) {
        derivedAcronym = "Bi";
      }
    }

    // --- FILTER 2: LOGIKA FORMAT TEXT ---
    if (derivedAcronym.isEmpty) {
      String cleanText = (match != null)
          ? uid.substring(0, match.start).replaceAll('-', ' ').trim()
          : uid.replaceAll('-', ' ').trim();

      // List yang harus UPPERCASE (The Big 5)
      const bigFive = ["dn", "mn", "sn", "an", "kn"];

      if (bigFive.contains(cleanText.toLowerCase())) {
        derivedAcronym = cleanText.toUpperCase();
      } else {
        // Capitalize Each Word (untuk sisanya)
        derivedAcronym = cleanText
            .split(' ')
            .map((word) {
              if (word.isEmpty) return "";
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
      }
    }

    return "$derivedAcronym $numberPart".trim();
  }

  Future<void> _openSuttaplex(BuildContext context, String uid) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Suttaplex(uid: uid, sourceMode: "home"),
          ),
        );
      },
    );
    await _refreshData();
  }

  void _showAllBookmarks(BuildContext context) {
    // 🔥 Extract unique nikaya yang ada di bookmarks
    final Set<String> availableNikayas = {};
    for (var b in _bookmarks) {
      final displayAcronym = _getDisplayAcronym(b["uid"], b["acronym"]);

      final nikayaKey = _getNikayaKey(displayAcronym);

      if (nikayaKey.isNotEmpty) {
        availableNikayas.add(nikayaKey);
      }
    }

    final sortedNikayas = availableNikayas.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? selectedFilter;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // --- HEADER (Tetap sama) ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_isEditMode)
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setState(() {
                                  _isEditMode = false;
                                  _selectedBookmarks.clear();
                                });
                                setModalState(() {});
                              },
                            ),
                          Text(
                            _isEditMode
                                ? "${_selectedBookmarks.length} dipilih"
                                : "Semua Penanda",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (_isEditMode && _selectedBookmarks.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Hapus Penanda?"),
                                    content: Text(
                                      "Hapus ${_selectedBookmarks.length} penanda yang dipilih?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Batal"),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text("Hapus"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await HistoryService.deleteBookmarks(
                                    _selectedBookmarks.toList(),
                                  );
                                  setState(() {
                                    _isEditMode = false;
                                    _selectedBookmarks.clear();
                                  });
                                  await _refreshData();
                                  setModalState(() {});
                                }
                              },
                            ),
                          if (_isEditMode)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditMode = false;
                                  _selectedBookmarks.clear();
                                });
                                setModalState(() {});
                              },
                              child: const Text("Selesai"),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                setState(() => _isEditMode = true);
                                setModalState(() {});
                              },
                              child: const Text("Atur"),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isEditMode = false;
                                _selectedBookmarks.clear();
                              });
                              Navigator.pop(context);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // 🔥 FILTER CHIPS
                    if (sortedNikayas.isNotEmpty)
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text("Semua (${_bookmarks.length})"),
                                selected: selectedFilter == null,
                                onSelected: (selected) {
                                  setModalState(() {
                                    selectedFilter = null;
                                  });
                                },
                                selectedColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                checkmarkColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                labelStyle: TextStyle(
                                  color: selectedFilter == null
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            ...sortedNikayas.map((nikaya) {
                              // nikaya sekarang pasti bersih (misal "Bi Pj" atau "AN")

                              final count = _bookmarks.where((b) {
                                final displayAcronym = _getDisplayAcronym(
                                  b["uid"],
                                  b["acronym"],
                                );
                                final cleanKey = _getNikayaKey(displayAcronym);
                                return cleanKey == nikaya;
                              }).length;

                              final avatarText = nikaya.split(" ").first;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text("$nikaya ($count)"),
                                  selected: selectedFilter == nikaya,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      selectedFilter = selected ? nikaya : null;
                                    });
                                  },
                                  selectedColor: getNikayaColor(
                                    nikaya,
                                  ).withValues(alpha: 0.2),
                                  checkmarkColor: getNikayaColor(nikaya),

                                  avatar: selectedFilter == nikaya
                                      ? null
                                      : CircleAvatar(
                                          backgroundColor: getNikayaColor(
                                            nikaya,
                                          ),
                                          radius: 12,
                                          child: Text(
                                            avatarText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // 🔥 LIST BOOKMARKS
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final filteredBookmarks = selectedFilter == null
                              ? _bookmarks
                              : _bookmarks.where((b) {
                                  final displayAcronym = _getDisplayAcronym(
                                    b["uid"],
                                    b["acronym"],
                                  );
                                  final cleanKey = _getNikayaKey(
                                    displayAcronym,
                                  );
                                  return cleanKey == selectedFilter;
                                }).toList();

                          if (filteredBookmarks.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bookmark_border,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Tidak ada penanda",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredBookmarks.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final b = filteredBookmarks[index];

                              final String displayAcronym = _getDisplayAcronym(
                                b["uid"],
                                b["acronym"] ?? "",
                              );

                              final String nikayaKey = _getNikayaKey(
                                displayAcronym,
                              );

                              return Card(
                                elevation: 1,
                                margin: EdgeInsets.zero,
                                color: Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () async {
                                    // 🔥 From previous fix
                                    if (_isEditMode) {
                                      setState(() {
                                        if (_selectedBookmarks.contains(
                                          b["uid"],
                                        )) {
                                          _selectedBookmarks.remove(b["uid"]);
                                        } else {
                                          _selectedBookmarks.add(b["uid"]);
                                        }
                                      });
                                      setModalState(() {});
                                    } else {
                                      await _openSuttaplex(context, b["uid"]);
                                      setModalState(() {});
                                    }
                                  },
                                  onLongPress: _isEditMode
                                      ? null
                                      : () async {
                                          final confirm = await showModalBottomSheet<bool>(
                                            context: context,
                                            // 🔥 FIXED: Add shape for rounding
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(16),
                                                  ),
                                            ),
                                            builder: (ctx) => ClipRRect(
                                              // 🔥 FIXED: Clip the content to prevent overflow
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(16),
                                                  ),
                                              child: Material(
                                                // 🔥 FIXED: Provide Material for proper ink/ripple behavior
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                child: SafeArea(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                        ),
                                                        title: const Text(
                                                          "Hapus Penanda",
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                      ),
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons.close,
                                                        ),
                                                        title: const Text(
                                                          "Batal",
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );

                                          if (confirm == true) {
                                            await HistoryService.removeBookmark(
                                              b["uid"],
                                            );
                                            await _refreshData();
                                            setModalState(() {});

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Dihapus dari Penanda',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 0,
                                    ),
                                    child: Row(
                                      children: [
                                        if (_isEditMode)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            child: Checkbox(
                                              value: _selectedBookmarks
                                                  .contains(b["uid"]),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedBookmarks.add(
                                                      b["uid"],
                                                    );
                                                  } else {
                                                    _selectedBookmarks.remove(
                                                      b["uid"],
                                                    );
                                                  }
                                                });
                                                setModalState(() {});
                                              },
                                            ),
                                          ),
                                        Expanded(
                                          child: ListTile(
                                            contentPadding: EdgeInsets.only(
                                              left: _isEditMode ? 0 : 16,
                                              right: 16,
                                            ),
                                            leading: buildNikayaAvatar(
                                              nikayaKey,
                                            ),

                                            title: Text(
                                              b["title"] ?? b["uid"],
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),

                                            subtitle:
                                                (b["note"] != null &&
                                                    b["note"]
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                ? Text(
                                                    b["note"],
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  )
                                                : null,

                                            trailing: Text(
                                              displayAcronym,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: getNikayaColor(
                                                  nikayaKey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _refreshData();
    });
  }

  void _openExplore(BuildContext context, int initialIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: DefaultTabController(
                length: 6,
                initialIndex: initialIndex,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text("Eksplor"),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    bottom: const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: "Tipiṭakapps"),
                        Tab(text: "Kamus & Perpus"),
                        Tab(text: "Artikel & Berita"),
                        Tab(text: "Unduh"),
                        Tab(text: "Forum"),
                        Tab(text: "Medsos"),
                      ],
                    ),
                  ),
                  body: const TabBarView(
                    children: [
                      ExploreTabApp(),
                      ExploreTabKamus(),
                      ExploreTabInfo(),
                      ExploreTabUnduh(),
                      ExploreTabForum(),
                      ExploreTabIkuti(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExploreSection({EdgeInsets? customPadding}) {
    // 🔥 Pake customPadding kalau ada
    final padding = customPadding ?? const EdgeInsets.symmetric(horizontal: 16);

    final exploreItems = [
      {
        "title": "Tipiṭaka Web Apps",
        "icon": Icons.apps_rounded,
        "color": Colors.orange.shade700,
        "index": 0,
      },
      {
        "title": "Kamus & Perpus",
        "icon": Icons.library_books_rounded,
        "color": Colors.blue.shade700,
        "index": 1,
      },
      {
        "title": "Artikel & Berita",
        "icon": Icons.newspaper_rounded,
        "color": Colors.red.shade600,
        "index": 2,
      },
      {
        "title": "Unduh Sumber Daya",
        //   "subtitle": "Ebook, majalah, komik, materi",
        "icon": Icons.download_rounded,
        "color": Colors.green.shade700,
        "index": 3,
      },
      {
        "title": "Forum Diskusi",
        //     "subtitle": "Forum diskusi Buddhis",
        "icon": Icons.forum_rounded,
        "color": Colors.teal.shade600,
        "index": 4,
      },
      {
        "title": "Media Sosial",
        //  "subtitle": "Akun media sosial Buddhis",
        "icon": Icons.people_rounded,
        "color": Colors.indigo.shade600,
        "index": 5,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Eksplor",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant, // 🔥 ABU-ABU
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: padding, // 🔥 Pakai variabel padding
          //padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Explore items dengan CompactCardBuilder
              ...exploreItems.asMap().entries.map((entry) {
                final item = entry.value;
                //final isLast = entry.key == exploreItems.length - 1;

                return Padding(
                  // ATUR JARAK ANTAR LISTVIEW ITEM
                  // padding: EdgeInsets.only(bottom: isLast ? 6 : 8),
                  padding: EdgeInsets.only(bottom: 8),
                  child: CompactCard(
                    title: item["title"] as String,
                    //   subtitle: item["subtitle"] as String,
                    icon: item["icon"] as IconData,
                    color: item["color"] as Color,
                    titleFontSize: 13, // 👈 Override
                    titleFontWeight: FontWeight.w500, // 👈 Override
                    onTap: () => _openExplore(context, item["index"] as int),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
