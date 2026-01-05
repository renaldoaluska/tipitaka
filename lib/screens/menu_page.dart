import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/sutta.dart';
import '../models/menu.dart';
import 'suttaplex.dart';
import '../styles/nikaya_style.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:ui';

class MenuPage extends StatefulWidget {
  final String uid;
  final String parentAcronym;
  const MenuPage({super.key, required this.uid, this.parentAcronym = ""});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Map<String, dynamic>? _root;
  List<MenuItem> _items = [];
  bool _loading = true;
  String _rootAcronym = "";
  String? _errorType; // "network", "not_found", atau null

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  bool _isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    final isTablet = size.shortestSide >= 600;
    final isLandscape = orientation == Orientation.landscape;

    return isTablet && isLandscape;
  }

  Future<void> _fetchMenu() async {
    try {
      final data = await SuttaService.fetchMenu(widget.uid, language: "id");
      final root = (data is List && data.isNotEmpty) ? data[0] : null;
      final children = (root?["children"] as List? ?? []);

      List<MenuItem> items = [];
      for (var child in children) {
        //TAMBAH
        if (child["uid"] != null && child["uid"].toString().isNotEmpty) {
          items.add(MenuItem.fromJson(child));
        }
      }

      setState(() {
        _root = root;
        if (widget.parentAcronym.isNotEmpty) {
          _rootAcronym = widget.parentAcronym;
        } else {
          // 🔥 FIX: Pakai normalizeNikayaAcronym() biar konsisten
          String rawAcronym = root?["acronym"] ?? "";
          _rootAcronym = normalizeNikayaAcronym(rawAcronym);
        }

        _items = items;
        _errorType = null;
        _loading = false;
      });

      // 🔥 DEBUG LOG (Bisa dihapus kalau udah beres)
      debugPrint("📋 [MenuPage] UID yang diminta: ${widget.uid}");
      debugPrint(
        "📋 [MenuPage] Parent Acronym (Kiriman): '${widget.parentAcronym}'",
      );
      debugPrint(
        "📋 [MenuPage] Root Acronym (Dari API): '${root?["acronym"]}'",
      );
      debugPrint("📋 [MenuPage] Root Name: '${root?["root_name"]}'");
      debugPrint("📋 [MenuPage] Child Range: '${root?["child_range"]}'");
      debugPrint("📋 [MenuPage] _rootAcronym Akhir: '$_rootAcronym'");
    } catch (e) {
      debugPrint("Error fetch menu: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          // 🔥 Deteksi tipe error
          if (e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup') ||
              e.toString().contains('Network is unreachable')) {
            _errorType = "network";
          } else {
            _errorType = "not_found";
          }
        });
      }
    }
  }

  Widget _buildErrorHeader(Color cardColor, Color? iconColor, Color textColor) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: cardColor.withValues(alpha: 0.85),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: iconColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _root?["root_name"] ?? widget.uid,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }

  Widget buildMenuItem(MenuItem item) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final isTabletLandscape = _isTabletLandscape(context);

    final isLeaf = item.nodeType != "branch";
    final displayAcronym = _rootAcronym;

    return Card(
      color: cardColor,
      elevation: 1,
      margin: isTabletLandscape
          ? const EdgeInsets.symmetric(vertical: 0, horizontal: 8)
          : const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: buildNikayaAvatar(displayAcronym),
        title: Text(
          item.translatedTitle.isNotEmpty
              ? item.translatedTitle
              : item.originalTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor,
          ),
        ),
        subtitle: item.blurb.isNotEmpty
            ? Text(
                item.blurb.replaceAll(RegExp(r'<[^>]*>'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subTextColor, fontSize: 12),
              )
            : null,
        trailing: isLeaf
            ? Text(
                item.acronym.replaceFirst("Patthana", "Pat"),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: getNikayaColor(displayAcronym),
                ),
              )
            : (item.childRange.isNotEmpty
                  ? Text(
                      item.childRange,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: getNikayaColor(displayAcronym),
                      ),
                    )
                  : null),
        onTap: () {
          if (item.nodeType == "branch") {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: RouteSettings(name: '/vagga/${item.uid}'),
                builder: (_) => MenuPage(
                  uid: item.uid,
                  parentAcronym: normalizeNikayaAcronym(_rootAcronym),
                ),
              ),
            );
          } else {
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
                    uid: item.uid,
                    sourceMode: "menu_page", // ✅ Mode dari MenuPage
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final iconColor = Theme.of(context).iconTheme.color;

    final rawBlurb = _root?["blurb"] ?? "";
    final previewBlurb = rawBlurb.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final hasBlurb = previewBlurb.isNotEmpty;
    final isLong = previewBlurb.length > 60;
    final bool isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final isTabletLandscape = _isTabletLandscape(context); // ðŸ"¥ TAMBAH INI
    return Scaffold(
      appBar: null,
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 80,
                        left: 24,
                        right: 24,
                        bottom: 24,
                      ), // ✅ UBAH padding
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _errorType == "network"
                                ? Icons.wifi_off_rounded
                                : Icons.folder_off_rounded,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorType == "network"
                                ? "Tidak Ada Koneksi"
                                : "Data Tidak Tersedia",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // ✅ PAKAI RichText
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: subTextColor,
                                height: 1.5,
                              ),
                              children: _errorType == "network"
                                  ? [
                                      const TextSpan(
                                        text:
                                            "Mohon periksa koneksi internet Anda\n\n",
                                      ),
                                      const TextSpan(
                                        text:
                                            "Untuk menghemat ruang penyimpanan, data Tipiṭaka (1 GB+) tidak tersimpan secara offline.\n\n",
                                      ),
                                      TextSpan(
                                        text: "Fitur offline tersedia:\n",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: textColor.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            "Paritta • Pendahuluan Tematik • Panduan Uposatha\nAbhidhammattha-Saṅgaha • Timer Meditasi",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subTextColor.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : [
                                      const TextSpan(
                                        text:
                                            "Menu ini tidak memiliki konten atau belum tersedia",
                                      ),
                                    ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_errorType == "network")
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _loading = true);
                                _fetchMenu();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text("Coba Lagi"),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ TAMBAHIN HEADER (copy dari bawah tapi simplified)
                  _buildErrorHeader(cardColor, iconColor, textColor),
                ],
              )
            : Stack(
                children: [
                  // LIST CONTENT
                  CustomScrollView(
                    slivers: [
                      // Spacing untuk header
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: hasBlurb
                              ? isLandscape
                                    ? isTabletLandscape
                                          ? 114
                                          : 102
                                    : 120
                              : isTabletLandscape
                              ? 88
                              : 78,
                        ),
                      ),

                      // ðŸ"¥ CONDITIONAL: Grid atau List
                      isTabletLandscape
                          ? SliverMasonryGrid.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 0,
                              childCount: _items.length,
                              itemBuilder: (context, index) {
                                return buildMenuItem(_items[index]);
                              },
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return buildMenuItem(_items[index]);
                              }, childCount: _items.length),
                            ),
                    ],
                  ),

                  // FLOATING HEADER (ga diubah)
                  if (_root != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 3,
                                spreadRadius: 0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10.0,
                                sigmaY: 10.0,
                              ),
                              child: Container(
                                color: cardColor.withValues(alpha: 0.85),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ROW HEADER
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.arrow_back,
                                              color: iconColor,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _root?["root_name"] ?? "",
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_rootAcronym.isNotEmpty &&
                                            _rootAcronym.trim().toUpperCase() !=
                                                (_root?["root_name"] ?? "")
                                                    .trim()
                                                    .toUpperCase() &&
                                            (_root?["child_range"] ?? "")
                                                .isEmpty)
                                          Text(
                                            _rootAcronym,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: getNikayaColor(
                                                normalizeNikayaAcronym(
                                                  _rootAcronym,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if ((_root?["child_range"] ?? "")
                                            .isNotEmpty)
                                          Text(
                                            _root?["child_range"] ?? "",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: getNikayaColor(
                                                _rootAcronym,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // DESKRIPSI
                                    if (hasBlurb) ...[
                                      const SizedBox(height: 8),
                                      RichText(
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: subTextColor,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: isLong
                                                  ? "${previewBlurb.substring(0, 80)}... "
                                                  : previewBlurb,
                                            ),
                                            if (isLong)
                                              TextSpan(
                                                text: "Baca Selengkapnya",
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) => AlertDialog(
                                                        backgroundColor:
                                                            cardColor,
                                                        title: Text(
                                                          _root?["root_name"] ??
                                                              "",
                                                          style: TextStyle(
                                                            color: textColor,
                                                          ),
                                                        ),
                                                        content:
                                                            SingleChildScrollView(
                                                              child: Html(
                                                                data: rawBlurb,
                                                                style: {
                                                                  "body": Style(
                                                                    color:
                                                                        textColor,
                                                                  ),
                                                                },
                                                              ),
                                                            ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                ),
                                                            child: const Text(
                                                              "Tutup",
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
