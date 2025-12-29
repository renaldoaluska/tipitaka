import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/sutta.dart';
import '../models/menu.dart';
import 'suttaplex.dart';
import '../styles/nikaya_style.dart';
import 'package:flutter_html/flutter_html.dart';

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
        // simpan acronym kitab utama sekali
        if (widget.parentAcronym.isNotEmpty) {
          _rootAcronym = widget.parentAcronym;
        } else {
          _rootAcronym = root?["acronym"] ?? "";
        }
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetch menu: $e");
      setState(() => _loading = false);
    }
  }

  Widget buildMenuItem(MenuItem item) {
    // ✅ Ambil warna tema
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final isLeaf = item.nodeType != "branch";
    final displayAcronym = _rootAcronym;

    return Card(
      color: cardColor, // ✅ Ganti Colors.white
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
            // ✅ Hapus const
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: textColor, // ✅ Warna judul ikut tema
          ),
        ),
        subtitle: item.blurb.isNotEmpty
            ? Text(
                item.blurb.replaceAll(RegExp(r'<[^>]*>'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subTextColor, // ✅ Ganti Colors.grey
                  fontSize: 12,
                ),
              )
            : null,
        trailing: isLeaf
            ? Text(
                item.acronym.replaceFirst("Patthana", "Pat"),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
              backgroundColor: cardColor, // ✅ Background sheet ikut tema
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => FractionallySizedBox(
                heightFactor: 0.85,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Suttaplex(uid: item.uid),
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
    // ✅ Setup variabel tema di sini
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // Khusus icon button back:
    final iconColor = Theme.of(context).iconTheme.color;

    final rawBlurb = _root?["blurb"] ?? "";
    final previewBlurb = rawBlurb.replaceAll(RegExp(r'<[^>]*>'), '');
    final isLong = previewBlurb.length > 60;

    return Scaffold(
      appBar: null,
      backgroundColor: bgColor, // ✅ Scaffold background dinamis
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Text(
                "Data tidak tersedia (menu_page)",
                style: TextStyle(color: textColor), // ✅ Text error dinamis
              ),
            )
          : Container(
              color: bgColor, // ✅ Container background dinamis
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  if (_root != null)
                    Card(
                      color: cardColor, // ✅ Header card dinamis
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 👉 Row: tombol back + judul + acronym + range
                              Row(
                                children: [
                                  // Tombol back bulat
                                  Container(
                                    decoration: BoxDecoration(
                                      color: cardColor, // ✅ Background tombol
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ), // ✅ Shadow lebih soft
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.arrow_back,
                                        color:
                                            iconColor, // ✅ Icon color ikut tema
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Judul kitab utama
                                  Expanded(
                                    child: Text(
                                      _root?["root_name"] ?? "",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textColor, // ✅ Judul dinamis
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Akronim
                                  if (_rootAcronym.isNotEmpty &&
                                      _rootAcronym.trim().toUpperCase() !=
                                          (_root?["root_name"] ?? "")
                                              .trim()
                                              .toUpperCase() &&
                                      (_root?["child_range"] ?? "").isEmpty)
                                    Text(
                                      _rootAcronym,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: getNikayaColor(
                                          normalizeNikayaAcronym(_rootAcronym),
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                  // Range anak
                                  if ((_root?["child_range"] ?? "").isNotEmpty)
                                    Text(
                                      _root?["child_range"] ?? "",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: getNikayaColor(_rootAcronym),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: subTextColor, // ✅ Deskripsi dinamis
                                  ),
                                  children: [
                                    TextSpan(
                                      text: isLong
                                          ? previewBlurb.substring(0, 60) +
                                                "... "
                                          : previewBlurb,
                                    ),
                                    if (isLong)
                                      TextSpan(
                                        text: "Baca selengkapnya",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                backgroundColor:
                                                    cardColor, // ✅ Dialog bg dinamis
                                                title: Text(
                                                  _root?["root_name"] ?? "",
                                                  style: TextStyle(
                                                    color: textColor,
                                                  ), // ✅ Title dialog
                                                ),
                                                content: SingleChildScrollView(
                                                  child: Html(
                                                    data: rawBlurb,
                                                    style: {
                                                      "body": Style(
                                                        color:
                                                            textColor, // ✅ Isi HTML dinamis
                                                      ),
                                                    },
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return buildMenuItem(item);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
