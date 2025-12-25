import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/sutta.dart';
import '../models/menu.dart';
import 'suttaplex.dart';
import '../styles/nikaya_style.dart';

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
      ),
      subtitle: Text(
        item.blurb.isNotEmpty ? item.blurb : "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isLeaf
          ? Text(
              item.acronym,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: getNikayaColor(displayAcronym),
              ),
            )
          : (item.childRange.isNotEmpty
                ? Text(
                    item.childRange,
                    style: TextStyle(
                      fontSize: 16,
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.uid.toUpperCase())),
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
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              TextSpan(
                                text: (_root?["blurb"] ?? "").length > 180
                                    ? (_root?["blurb"] ?? "").substring(
                                            0,
                                            180,
                                          ) +
                                          "..."
                                    : (_root?["blurb"] ?? ""),
                              ),
                              if ((_root?["blurb"] ?? "").length > 180)
                                TextSpan(
                                  text: " Selengkapnya",
                                  style: const TextStyle(
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
                                            child: Text(_root?["blurb"] ?? ""),
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
                        const Divider(height: 16),
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
