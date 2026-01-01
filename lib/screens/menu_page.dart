import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  Future<void> _fetchMenu() async {
    try {
      final data = await SuttaService.fetchMenu(widget.uid, language: "id");
      final root = (data is List && data.isNotEmpty) ? data[0] : null;
      final children = (root?["children"] as List? ?? []);

      List<MenuItem> items = [];
      for (var child in children) {
        items.add(MenuItem.fromJson(child));
      }

      setState(() {
        _root = root;
        if (widget.parentAcronym.isNotEmpty) {
          _rootAcronym = widget.parentAcronym;
        } else {
          _rootAcronym = root?["acronym"] ?? "";
        }
        _items = items;
        _errorType = null; // 🔥 Clear error
        _loading = false;
      });

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

  Widget buildMenuItem(MenuItem item) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final isLeaf = item.nodeType != "branch";
    final displayAcronym = _rootAcronym;

    return Card(
      color: cardColor,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
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

    // --- PASANG INI (Mulai) ---
    if (_root != null) {
      bool condition1 = _rootAcronym.isNotEmpty;
      bool condition2 =
          _rootAcronym.trim().toUpperCase() !=
          (_root?["root_name"] ?? "").trim().toUpperCase();
      bool condition3 = (_root?["child_range"] ?? "").isEmpty;

      debugPrint("🔍 [MenuPage Logic] Acronym Not Empty? $condition1");
      debugPrint("🔍 [MenuPage Logic] Beda sama Root Name? $condition2");
      debugPrint("🔍 [MenuPage Logic] Child Range Empty? $condition3");
      debugPrint(
        "🔍 [MenuPage Logic] KESIMPULAN: Tampil Header Kecil? ${condition1 && condition2 && condition3}",
      );
    }
    // --- PASANG INI (Selesai) ---

    return Scaffold(
      appBar: null,
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        // 🔥 Icon sesuai error type
                        _errorType == "network"
                            ? Icons.wifi_off_rounded
                            : Icons.folder_off_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        // 🔥 Judul sesuai error type
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
                      Text(
                        // 🔥 Pesan sesuai error type
                        _errorType == "network"
                            ? "Periksa koneksi internet Anda\ndan silakan coba lagi"
                            : "Menu ini tidak memiliki konten atau belum tersedia",
                        style: TextStyle(fontSize: 14, color: subTextColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // 🔥 Tombol retry hanya untuk network error
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
              )
            : Stack(
                children: [
                  // LIST CONTENT
                  CustomScrollView(
                    slivers: [
                      // Spacing untuk header
                      SliverToBoxAdapter(
                        child: SizedBox(height: hasBlurb ? 130 : 80),
                      ),

                      // LIST ITEM
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return buildMenuItem(_items[index]);
                        }, childCount: _items.length),
                      ),
                    ],
                  ),
                  // FLOATING TRANSPARENT HEADER
                  if (_root != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
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
