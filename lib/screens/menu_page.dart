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
    final isLeaf = item.nodeType != "branch";
    final displayAcronym = _rootAcronym;

    // Cek apakah childRange udah include acronym
    /*final childRangeHasAcronym = item.childRange.toUpperCase().contains(
      displayAcronym.toUpperCase(),
    );*/
    return Card(
      color: Colors.white,
      elevation: 1, // ✅ tambah shadow
      margin: const EdgeInsets.symmetric(
        vertical: 5,
        horizontal: 16,
      ), // ✅ vertical 6→4
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(
          // ✅ tambah ini biar hover rounded
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          // ✅ tambah ini
          horizontal: 16,
          vertical: 0,
        ),
        leading: buildNikayaAvatar(displayAcronym),
        title: Text(
          item.translatedTitle.isNotEmpty
              ? item.translatedTitle
              : item.originalTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ), // ✅ 16→14
        ),
        subtitle: item.blurb.isNotEmpty
            ? Text(
                item.blurb.replaceAll(RegExp(r'<[^>]*>'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ), // ✅ 13→12
              )
            : null,
        trailing: isLeaf
            ? Text(
                item.acronym.replaceFirst("Patthana", "Pat"),
                style: TextStyle(
                  fontSize: 12, // ✅ 14→12
                  fontWeight: FontWeight.w600,
                  color: getNikayaColor(displayAcronym),
                ),
              )
            : // ... dst (trailing juga 14→12)
              (item.childRange.isNotEmpty
                  ? Text(
                      item.childRange, // langsung pake childRange aja, udah lengkap
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
              backgroundColor: Colors.white,
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
    final rawBlurb = _root?["blurb"] ?? "";
    final previewBlurb = rawBlurb.replaceAll(RegExp(r'<[^>]*>'), '');
    final isLong = previewBlurb.length > 60;

    return Scaffold(
      appBar: null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text("Data tidak tersedia (menu_page)"))
          : Container(
              color: Colors.grey[50], // 👉 background abu-abu muda
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).padding.top,
                  ), // 👉 jarak aman
                  if (_root != null)
                    Card(
                      color: Colors.white,
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
                                  // Tombol back bulat putih
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.black,
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Judul kitab utama
                                  Expanded(
                                    child: Text(
                                      _root?["root_name"] ?? "",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Akronim: tampilkan HANYA kalau child_range kosong
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

                                  // Range anak kalau ada (udah include akronim di dalemnya)
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
                                    fontSize: 16, // 👈 ini yang bikin konsisten
                                    color: Colors
                                        .grey[700], // 👈 warna sama kayak sebelumnya
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
                                          fontSize: 16, // 👈  biar gak beda
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: Text(
                                                  _root?["root_name"] ?? "",
                                                ),
                                                content: SingleChildScrollView(
                                                  child: Html(data: rawBlurb),
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
                      padding: EdgeInsets.zero, // 👉 rapetin list ke header
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
