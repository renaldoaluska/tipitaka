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

class Home extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const Home({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<Map<String, String>> _dhammapadaQuotes = [
    {
      "verse": "183",
      "pali": "SabbapÄpassa akaraṇaṃ, kusalassa upasampadÄ...",
      "trans":
          "Tidak berbuat kejahatan, mengembangkan kebajikan, memurnikan pikiran—inilah ajaran para Buddha.",
    },
    {
      "verse": "1",
      "pali": "ManopubbaṅgamÄ dhammÄ...",
      "trans":
          "Pikiran adalah pelopor dari segala hal, pikiran adalah pemimpin, pikiran adalah pembentuk.",
    },
    {
      "verse": "223",
      "pali": "Akkodhena jine kodhaṃ...",
      "trans":
          "Kalahkan amarah dengan tidak marah, kalahkan kejahatan dengan kebaikan.",
    },
    {
      "verse": "103",
      "pali": "Yo sahassaṃ sahassena...",
      "trans":
          "Lebih baik menaklukkan diri sendiri daripada menaklukkan ribuan orang dalam pertempuran.",
    },
  ];
  Map<String, String>? _todayQuote;

  final List<Map<String, String>> _recentlyViewed = [
    {"uid": "mn1", "title": "MN 1 MÅ«lapariyÄya Sutta", "kitab": "MN"},
    {"uid": "sn56.11", "title": "SN 56.11 Dhammacakka", "kitab": "SN"},
    {"uid": "an3.65", "title": "AN 3.65 KÄlÄma", "kitab": "AN"},
  ];

  final List<Map<String, dynamic>> _bookmarks = [
    {"uid": "sn56.11", "title": "SN 56.11 Dhammacakka", "kitab": "SN"},
    {"uid": "an3.65", "title": "AN 3.65 KÄlÄma", "kitab": "AN"},
    {"uid": "dhp183", "title": "Dhp 183 SabbapÄpassa", "kitab": "Dhp"},
  ];

  @override
  void initState() {
    super.initState();
    _loadTodayQuote();
  }

  void _loadTodayQuote() {
    final seed = DateTime.now().day + DateTime.now().month * 100;
    final random = Random(seed);
    setState(() {
      _todayQuote = _dhammapadaQuotes[random.nextInt(_dhammapadaQuotes.length)];
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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildQuoteCard()),
          SliverToBoxAdapter(child: _buildQuickAccess()),
          if (_recentlyViewed.isNotEmpty)
            SliverToBoxAdapter(child: _buildRecentlyViewed()),
          if (_bookmarks.isNotEmpty)
            SliverToBoxAdapter(child: _buildBookmarks()),
          SliverToBoxAdapter(child: _buildExploreSection()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: HeaderDepan(
        isDarkMode: widget.isDarkMode,
        onThemeToggle: widget.onThemeToggle,
        title: "Sotthi Hotu",
        subtitle: "Namo Ratanattayā",
      ),
    );
  }

  Widget _buildQuoteCard() {
    if (_todayQuote == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        elevation: 1,
        color: _cardColor(widget.isDarkMode),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: widget.isDarkMode
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
                    color: widget.isDarkMode ? Colors.amber : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Dhammapada ${_todayQuote!["verse"]}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDarkMode
                          ? Colors.amber
                          : Colors.orange.shade800,
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
                  color: widget.isDarkMode
                      ? Colors.grey[300]
                      : Colors.grey[800],
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _todayQuote!["trans"]!,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDarkMode
                      ? Colors.grey[400]
                      : Colors.grey[700],
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
        "color": const Color(0xFF283593),
      },
      {
        "label": "Paritta",
        "icon": Icons.book_rounded,
        "color": const Color(0xFFFDD835),
      },
      {
        "label": "Uposatha",
        "icon": Icons.nightlight_round,
        "color": const Color(0xFFD84315),
      },
      {
        "label": "Meditasi",
        "icon": Icons.self_improvement_rounded,
        "color": const Color(0xFFFF9800),
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Akses Cepat",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _textColor(widget.isDarkMode),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final f = features[index];
                return IconButtonBuilder(
                  label: f["label"] as String,
                  icon: f["icon"] as IconData,
                  color: f["color"] as Color,
                  onTap: () {
                    // TODO: Navigate
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Terakhir Dilihat",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _textColor(widget.isDarkMode),
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _recentlyViewed.length.clamp(0, 3),
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8), // spacing antar card
            itemBuilder: (context, index) {
              final rv = _recentlyViewed[index];
              return Card(
                elevation: 1,
                margin:
                    EdgeInsets.zero, // hilangin margin bawaan biar konsisten
                color: _cardColor(widget.isDarkMode),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: getNikayaColor(rv["kitab"]!),
                    radius: 18,
                    child: Text(
                      rv["kitab"]!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    rv["title"]!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textColor(widget.isDarkMode),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  //trailing: Icon(
                  //  Icons.arrow_forward_ios,
                  //  size: 16,
                  //  color: _subtextColor(widget.isDarkMode),
                  // ),
                  onTap: () {
                    // TODO: Navigate ke detail rv["uid"]
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Penanda",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textColor(widget.isDarkMode),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Show all
                },
                child: const Text(
                  "Lihat Semua",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _bookmarks.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final b = _bookmarks[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 10),
                  child: Card(
                    elevation: 1,
                    color: _cardColor(widget.isDarkMode),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        // TODO: Navigate ke detail b["uid"]
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: getNikayaColor(b["kitab"]),
                              radius: 18,
                              child: Text(
                                b["kitab"],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b["title"],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _textColor(widget.isDarkMode),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
      ),
    );
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Eksplor",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _textColor(widget.isDarkMode),
            ),
          ),
          const SizedBox(height: 12),

          // Loop explore items dengan spacing
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
                  isDarkMode: widget.isDarkMode,
                  onTap: () => _openExplore(context, item["index"] as int),
                ),
                if (!isLast) const SizedBox(height: 3),
              ],
            );
          }),

          const SizedBox(height: 3),

          // Kontribusi card
          PanjangCardBuilder(
            title: "Kontribusi",
            subtitle: "Ikut kembangkan aplikasi ini",
            icon: Icons.code,
            color: Colors.blueGrey,
            isDarkMode: widget.isDarkMode,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text("Kontribusi"),
                  content: const Text(
                    "Aplikasi ini dikembangkan secara terbuka dengan mettÄ, karuṇÄ, muditÄ, dan upekkhÄ.\n\n"
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
                        launchUrl(uri, mode: LaunchMode.externalApplication);
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
    );
  }
}
