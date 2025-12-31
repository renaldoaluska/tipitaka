import 'package:flutter/material.dart';
import 'dart:math';
import '../styles/nikaya_style.dart';
import '../widgets/icon_button_builder.dart';
import '../widgets/panjang_card_builder.dart';
import '../widgets/header_depan.dart';
import '../widgets/explore/explore_tab_app.dart';
import '../widgets/explore/explore_tab_kamus.dart';
import '../widgets/explore/explore_tab_forum.dart';
import '../widgets/explore/explore_tab_info.dart';
import '../widgets/explore/explore_tab_unduh.dart';
import '../widgets/explore/explore_tab_ikuti.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui'; // 👈 Wajib ada buat efek Blur
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
          "Sabbapāpassa akaraṇaṁ, kusalassa upasampadā;\nSacittapariyodapanaṁ,\netaṁ buddhāna sāsanaṁ.",
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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildQuoteCard()),
          SliverToBoxAdapter(child: _buildQuickAccess()),
          // 🔥 HAPUS IF, SELALU MUNCUL
          SliverToBoxAdapter(child: _buildRecentlyViewed()),
          SliverToBoxAdapter(child: _buildBookmarks()),
          SliverToBoxAdapter(child: _buildExploreSection()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    // Ambil warna background dari tema, terus dibikin agak transparan
    final transparentColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.85);

    return SliverAppBar(
      pinned: true, // Wajib true biar melayang
      floating: true,

      // ✅ Bikin background aslinya transparan biar flexibleSpace kelihatan
      backgroundColor: Colors.transparent,

      // Matikan bayangan default biar gak numpuk
      elevation: 0,
      scrolledUnderElevation: 0,

      automaticallyImplyLeading: false,
      toolbarHeight: 80,

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

      title: HeaderDepan(
        title: "Namo Buddhāya",
        subtitle: "Sotthi Hotu", // Subtitle utama
        subtitlesList: const [
          // List tambahannya
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
      centerTitle: true,
      titleSpacing: 0,
    );
  }

  Widget _buildQuoteCard() {
    if (_todayQuote == null) return const SizedBox.shrink();

    // ✅ Ambil warna dari Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

  Widget _buildQuickAccess() {
    final features = [
      {
        "label": "Tipiṭaka",
        "icon": Icons.menu_book_rounded,
        "color": const Color(0xFF1565C0),
        "onTap": () {
          // 👈 Navigasi ke tab Pariyatti (Sutta) - index 1
          widget.onNavigate?.call(1);
        },
      },
      {
        "label": "Uposatha",
        "icon": Icons.nightlight_round,
        "color": const Color(0xFFF9A825),
        "onTap": () {
          // 👈 Navigasi ke Paṭipatti dengan highlight Uposatha
          widget.onNavigate?.call(4, highlightSection: 'uposatha');
        },
      },
      {
        "label": "Meditasi",
        "icon": Icons.self_improvement_rounded,
        "color": const Color(0xFFD32F2F),
        "onTap": () {
          // 👈 Navigasi ke Paṭipatti dengan highlight Meditasi
          widget.onNavigate?.call(4, highlightSection: 'meditasi');
                  },
      },
      {
        "label": "Paritta",
        "icon": Icons.book_rounded,
        "color": const Color(0xFFF57C00),
        "onTap": () {
          // 👈 Navigasi ke Paṭipatti dengan highlight Paritta
          widget.onNavigate?.call(4, highlightSection: 'paritta');
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildRecentlyViewed() {
    final textColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant; // 🔥 ABU-ABU
    final cardColor = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        // 🔥 LOADING STATE
        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        // 🔥 EMPTY STATE (COMPACT)
        else if (_recentlyViewed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Belum ada riwayat bacaan",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ) // 🔥 LIST CONTENT
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _recentlyViewed.length.clamp(0, 3),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final rv = _recentlyViewed[index];
                final acronym = rv["acronym"] ?? "";
                final nikaya = acronym.split(" ").first;
                //.toUpperCase();

                return Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: getNikayaColor(nikaya),
                      radius: 20,
                      child: Text(
                        acronym.split(" ").first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          "${rv["lang_name"]} • ${rv["author"]}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: Text(
                      acronym,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: getNikayaColor(nikaya),
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

  Widget _buildBookmarks() {
    final textColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant; // 🔥 ABU-ABU
    final cardColor = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                "Penanda",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor, // 🔥 ABU-ABU
                ),
              ),
              const Spacer(),
              // if (_bookmarks.length > 5)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ), // ✅ Tambah padding
                  minimumSize: const Size(80, 36), // ✅ Minimum size yang layak
                  tapTargetSize:
                      MaterialTapTargetSize.padded, // ✅ Ganti jadi padded
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
        // const SizedBox(height: 2),
        // 🔥 LOADING STATE
        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        // 🔥 EMPTY STATE (COMPACT)
        else if (_bookmarks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 56, // 🔥 LEBIH PENDEK
              child: Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Belum ada sutta yang ditandai",
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        // 🔥 LIST CONTENT
        else
          SizedBox(
            height: 130,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _bookmarks.length.clamp(0, 5),
              itemBuilder: (context, index) {
                final b = _bookmarks[index];
                final acronym = b["acronym"] ?? "";
                final nikaya = acronym.split(" ").first;
                //.toUpperCase();

                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 10),
                  child: Card(
                    elevation: 1,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        _openSuttaplex(context, b["uid"]);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start, // 🔥 Align kiri semua
                          children: [
                            // Baris pertama: Avatar + Acronym
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: getNikayaColor(nikaya),
                                  radius: 20,
                                  child: Text(
                                    acronym.split(" ").first,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  acronym,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: getNikayaColor(nikaya),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Baris kedua: Title
                            Text(
                              b["title"] ?? b["uid"],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Baris ketiga: Note (kalau ada)
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

  void _openSuttaplex(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Suttaplex(uid: uid, sourceMode: "home"),
          ),
        );
      },
    ).then((_) {
      // 🔥 REFRESH DATA PAS MODAL DITUTUP
      _refreshData();
    });
  }

  void _showAllBookmarks(BuildContext context) {
    // 🔥 Extract unique nikaya yang ada di bookmarks
    final Set<String> availableNikayas = {};
    for (var b in _bookmarks) {
      final acronym = b["acronym"] ?? "";
      final nikaya = acronym.split(" ").first;
      //.toUpperCase();
      if (nikaya.isNotEmpty) {
        availableNikayas.add(nikaya);
      }
    }

    final sortedNikayas = availableNikayas.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 🔥 BACKGROUND TRANSPARAN BIAR KELIATAN ABU-ABU DI BELAKANG
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? selectedFilter;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.8,
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
                    // 🔥 HEADER
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
                            // Chip "Semua"
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
                                ).colorScheme.onPrimaryContainer, // Ubah ini
                                labelStyle: TextStyle(
                                  color: selectedFilter == null
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            // Chip per Nikaya
                            ...sortedNikayas.map((nikaya) {
                              final count = _bookmarks.where((b) {
                                final acronym = b["acronym"] ?? "";
                                final n = acronym.split(" ").first;
                                // .toUpperCase();
                                return n == nikaya;
                              }).length;

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
                                            nikaya[0],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
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

                    // 🔥 LIST BOOKMARKS (FILTERED)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final filteredBookmarks = selectedFilter == null
                              ? _bookmarks
                              : _bookmarks.where((b) {
                                  final acronym = b["acronym"] ?? "";
                                  final nikaya = acronym.split(" ").first;
                                  //.toUpperCase();
                                  return nikaya == selectedFilter;
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

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredBookmarks.length,
                            itemBuilder: (context, index) {
                              final b = filteredBookmarks[index];
                              final acronym = b["acronym"] ?? "";
                              final nikaya = acronym.split(" ").first;
                              //.toUpperCase();

                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 8),
                                color: Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
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
                                      Navigator.pop(context);
                                      _openSuttaplex(context, b["uid"]);
                                    }
                                  },
                                  onLongPress: _isEditMode
                                      ? null
                                      : () async {
                                          final confirm =
                                              await showModalBottomSheet<bool>(
                                                context: context,
                                                builder: (ctx) => SafeArea(
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
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (_isEditMode) ...[
                                          Checkbox(
                                            value: _selectedBookmarks.contains(
                                              b["uid"],
                                            ),
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
                                          const SizedBox(width: 4),
                                        ],
                                        CircleAvatar(
                                          backgroundColor: getNikayaColor(
                                            nikaya,
                                          ),
                                          radius: 20,
                                          child: Text(
                                            acronym.split(" ").first,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
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
                                              if (b["note"] != null &&
                                                  b["note"]
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  b["note"],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.7),
                                                    fontStyle: FontStyle.italic,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          acronym,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: getNikayaColor(nikaya),
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
                        Tab(text: "Tipiṭakapp"),
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

  Widget _buildExploreSection() {
    // ✅ Ambil warna dari Theme
    //final textColor = Theme.of(context).colorScheme.onSurface;

    final exploreItems = [
      {
        "title": "Tipiṭakapp",
        "subtitle": "Berbagai aplikasi web Tipiṭaka",
        "icon": Icons.apps_rounded,
        "color": Colors.orange.shade700,
        "index": 0,
      },
      {
        "title": "Kamus & Perpus",
        "subtitle": "Aplikasi web kamus dan perpus",
        "icon": Icons.library_books_rounded,
        "color": Colors.blue.shade700,
        "index": 1,
      },
      {
        "title": "Artikel & Berita",
        "subtitle": "Kumpulan artikel dan berita",
        "icon": Icons.newspaper_rounded,
        "color": Colors.red.shade600,
        "index": 2,
      },
      {
        "title": "Unduh Sumber Daya",
        "subtitle": "Ebook, majalah, komik, materi",
        "icon": Icons.download_rounded,
        "color": Colors.green.shade700,
        "index": 3,
      },
      {
        "title": "Forum Diskusi",
        "subtitle": "Forum diskusi Buddhis",
        "icon": Icons.forum_rounded,
        "color": Colors.teal.shade600,
        "index": 4,
      },
      {
        "title": "Media Sosial",
        "subtitle": "Akun media sosial Buddhis",
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ...exploreItems.asMap().entries.map((entry) {
                final item = entry.value;
                final isLast = entry.key == exploreItems.length - 1;

                return Column(
                  children: [
                    PanjangCardBuilder(
                      title: item["title"] as String,
                      subtitle: item["subtitle"] as String,
                      icon: item["icon"] as IconData,
                      color: item["color"] as Color,
                      onTap: () => _openExplore(context, item["index"] as int),
                    ),
                    if (!isLast) const SizedBox(height: 3),
                  ],
                );
              }),
              const SizedBox(height: 3),
              PanjangCardBuilder(
                title: "Kontribusi",
                subtitle: "Ikut kembangkan aplikasi ini",
                icon: Icons.code,
                color: Colors.blueGrey,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text("Kontribusi"),
                      content: const Text(
                        "Aplikasi ini dikembangkan secara terbuka dengan mettā, karuṇā, muditā, dan upekkhā.\n\n"
                        "Anda bisa kontribusi dengan:\n"
                        "• Memberi masukan\n"
                        "• Membantu dokumentasi\n"
                        "• Menyumbang kode\n"
                        "• Menyebarkan aplikasi ini\n\n"
                        "Pilih salah satu opsi di bawah.\nTerima kasih <3",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            final uri = Uri(
                              scheme: 'mailto',
                              path: 'aluskaindonesia@gmail.com',
                              query: Uri.encodeFull(
                                'subject=Saran Aplikasi Tripitaka Indonesia'
                                '&body=--- tulis saran Anda di bawah ---',
                              ),
                            );
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          child: const Text("Kirim Email"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            launchUrl(
                              Uri.parse(
                                "https://github.com/renaldoaluska/tipitaka",
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          child: const Text("Buka GitHub"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text("Tutup"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
