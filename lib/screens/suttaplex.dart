import 'package:flutter/material.dart';
import '../services/sutta.dart';
import 'sutta_detail.dart';

const Color kLockedColor = Colors.grey;

class Suttaplex extends StatefulWidget {
  final String uid;
  const Suttaplex({super.key, required this.uid});

  @override
  State<Suttaplex> createState() => _SuttaplexState();
}

class _SuttaplexState extends State<Suttaplex> {
  Map<String, dynamic>? _sutta;
  bool _loading = true;
  bool _fetchingText = false;

  @override
  void initState() {
    super.initState();
    _fetchSuttaplex();
  }

  Future<void> _fetchSuttaplex() async {
    try {
      final raw = await SuttaService.fetchSuttaplex(widget.uid, language: "id");
      final data = (raw is List && raw.isNotEmpty) ? raw[0] : null;

      if (data == null) {
        setState(() {
          _sutta = null;
          _loading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> translations =
          List<Map<String, dynamic>>.from(data["translations"] ?? []);

      final langs = translations.map((t) => t["lang"]).toSet();

      // ensure pali exists
      if (!langs.contains("pli")) {
        translations.insert(0, {
          "lang": "pli",
          "author": "Teks Pāli",
          "author_uid": "ms",
          "segmented": true,
        });
      }

      // ensure indonesian exists (disabled if missing)
      if (!langs.contains("id")) {
        translations.add({
          "lang": "id",
          "author": "Belum tersedia",
          "author_uid": "",
          "segmented": false,
          "disabled": true,
        });
      }

      final filtered = translations
          .where((t) => ["id", "en", "pli"].contains(t["lang"]))
          .toList();

      filtered.sort((a, b) {
        const order = {"pli": 0, "id": 1, "en": 2};
        return (order[a["lang"]] ?? 99).compareTo(order[b["lang"]] ?? 99);
      });

      data["filtered_translations"] = filtered;

      setState(() {
        _sutta = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint("error fetch suttaplex: $e");
      setState(() => _loading = false);
    }
  }

  // 🔒 helpers (single source of truth)
  Widget lockIcon() {
    return const Icon(Icons.lock_outline, size: 18, color: kLockedColor);
  }

  Text lockedText(String text, {FontWeight? weight}) {
    return Text(
      text,
      style: TextStyle(color: kLockedColor, fontWeight: weight),
    );
  }

  Widget buildTranslationList(List<dynamic> translations) {
    return Column(
      children: translations.map((t) {
        final String lang = t["lang"] ?? "";
        final String author = t["author"] ?? "";
        final String authorUid = t["author_uid"] ?? "";
        final bool segmented = t["segmented"] ?? false;
        final bool disabled = t["disabled"] ?? false;

        final label = lang == "id"
            ? "Bahasa Indonesia"
            : lang == "en"
            ? "Bahasa Inggris"
            : "Bahasa Pāli";

        final icon = lang == "pli" ? Icons.menu_book : Icons.translate;

        return ListTile(
          leading: Icon(icon, color: disabled ? kLockedColor : null),
          title: disabled ? lockedText(label) : Text(label),
          subtitle: disabled ? lockedText(author) : Text(author),
          trailing: disabled ? lockIcon() : null,
          enabled: !disabled && !_fetchingText,
          onTap: disabled || _fetchingText
              ? null
              : () async {
                  final safeAuthorUid = authorUid.isNotEmpty ? authorUid : "ms";

                  setState(() => _fetchingText = true);

                  try {
                    final textData = await SuttaService.fetchTextForTranslation(
                      uid: _sutta?["uid"] ?? widget.uid,
                      authorUid: safeAuthorUid,
                      lang: lang,
                      segmented: segmented,
                    );

                    if (!mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SuttaDetail(
                          uid: widget.uid,
                          lang: lang,
                          textData: textData,
                        ),
                      ),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("gagal memuat teks $label")),
                    );
                  } finally {
                    if (mounted) setState(() => _fetchingText = false);
                  }
                },
        );
      }).toList(),
    );
  }

  Widget lockedSection({required String title, required String subtitle}) {
    return ListTile(
      leading: const Icon(Icons.menu_book, color: kLockedColor),
      title: lockedText(title, weight: FontWeight.w600),
      subtitle: lockedText(subtitle),
      trailing: lockIcon(),
      enabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _sutta?["translated_title"] ?? _sutta?["original_title"] ?? widget.uid;
    final blurb = _sutta?["blurb"] ?? "";
    final translations = _sutta?["filtered_translations"] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.uid.toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sutta == null
          ? const Center(child: Text("Data tidak tersedia"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(blurb),

                  const Divider(height: 32),

                  const Text(
                    "Pilih Bahasa:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  buildTranslationList(translations),

                  const Divider(height: 32),

                  const Text(
                    "Tafsiran (Coming Soon)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),

                  lockedSection(
                    title: "Aṭṭhakathā",
                    subtitle: "Belum tersedia",
                  ),

                  lockedSection(title: "Ṭīkā", subtitle: "Belum tersedia"),
                ],
              ),
            ),
    );
  }
}
