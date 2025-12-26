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
    final displayAcronym = normalizeNikayaAcronym(_rootAcronym);

    return ListTile(
      leading: buildNikayaAvatar(displayAcronym),
      title: Text(
        item.translatedTitle.isNotEmpty
            ? item.translatedTitle
            : item.originalTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w500, // agak tebal
          fontSize: 16, // opsional, biar lebih jelas
        ),
      ),
      subtitle: item.blurb.isNotEmpty
          ? Text(
              // strip semua tag HTML biar aman
              item.blurb.replaceAll(RegExp(r'<[^>]*>'), ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            )
          : null,

      trailing: isLeaf
          ? Text(
              // === CASE KHUSUS ===
              // CASE KHUSUS: ganti "Patthana" jadi "Pat", tapi sisanya tetap
              item.acronym.replaceFirst("Patthana", "Pat"),
              // item.acronym.contains("Patthana") ? "Pat" : item.acronym,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: getNikayaColor(displayAcronym),
              ),
            )
          : (item.childRange.isNotEmpty
                ? Text(
                    item.childRange,
                    style: TextStyle(
                      fontSize: 14,
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
              builder: (_) => MenuPage(
                uid: item.uid,
                //parentAcronym: _rootAcronym, // teruskan acronym utama
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
              child: Suttaplex(uid: item.uid),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawBlurb = _root?["blurb"] ?? "";
    final previewBlurb = rawBlurb.replaceAll(RegExp(r'<[^>]*>'), '');
    final isLong = previewBlurb.length > 60;
    return Scaffold(
      appBar: AppBar(title: Text(widget.uid)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text("Data tidak tersedia (menu_page)"))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_root != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _root?["root_name"] ?? "",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLong
                                  ? previewBlurb.substring(0, 60) + "..."
                                  : previewBlurb,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            if (isLong)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text(_root?["root_name"] ?? ""),
                                      content: SingleChildScrollView(
                                        child: Html(
                                          data: rawBlurb,
                                          style: {
                                            "body": Style(
                                              fontSize: FontSize(14),
                                              lineHeight: LineHeight(1.5),
                                              margin: Margins.zero,
                                              padding: HtmlPaddings.zero,
                                              color: Colors.black87,
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
                                child: const Text(
                                  "Selengkapnya",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const Divider(height: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return buildMenuItem(item);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
