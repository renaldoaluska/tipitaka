import 'package:flutter/material.dart';
import '../services/sutta.dart';
import 'sutta_detail.dart';
import 'package:flutter_html/flutter_html.dart';
import '../styles/nikaya_style.dart';

const Color kLockedColor = Colors.grey;

class Suttaplex extends StatefulWidget {
  final String uid;

  final void Function(
    String newUid,
    String lang,
    String authorUid,
    Map<String, dynamic> textData,
  )?
  onSelect;

  final Map<String, dynamic>? initialData; // ✅ terima data awal

  const Suttaplex({
    super.key,
    required this.uid,
    this.onSelect,
    this.initialData,
  });
  @override
  State<Suttaplex> createState() => _SuttaplexState();
}

class _SuttaplexState extends State<Suttaplex> {
  Map<String, dynamic>? _sutta;
  bool _loading = true;
  bool _fetchingText = false;

  bool _showAllTranslations = false;

  List<Map<String, dynamic>> _extraTranslations = [];

  static const List<String> PRIORITY_LANGS = ["pli", "id", "en"];

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _setupSuttaFromData(widget.initialData!);
    } else {
      _fetchSuttaplex();
    }
  }

  // ✅ Process translations: filter & sort (zero data manipulation)
  ({List<Map<String, dynamic>> filtered, List<Map<String, dynamic>> extra})
  _processTranslations(List<Map<String, dynamic>> translations) {
    final filtered = translations
        .where((t) => PRIORITY_LANGS.contains(t["lang"]))
        .toList();

    final extra = translations
        .where((t) => !PRIORITY_LANGS.contains(t["lang"]))
        .toList();

    filtered.sort((a, b) {
      final orderA = PRIORITY_LANGS.indexOf(a["lang"] ?? "");
      final orderB = PRIORITY_LANGS.indexOf(b["lang"] ?? "");
      return orderA.compareTo(orderB);
    });

    return (filtered: filtered, extra: extra);
  }

  void _setupSuttaFromData(dynamic data) {
    // kalau API balikin list, ambil item pertama
    final suttaplexData = (data is List && data.isNotEmpty) ? data[0] : data;

    debugPrint('>>> suttaplexData resolved: $suttaplexData');
    debugPrint(
      '>>> raw translations: ${suttaplexData?["translations"]} (${suttaplexData?["translations"]?.runtimeType})',
    );

    if (suttaplexData == null) {
      setState(() {
        _sutta = null;
        _loading = false;
      });
      return;
    }

    // parsing translations lebih aman
    final translations = <Map<String, dynamic>>[];
    final rawTrans = suttaplexData["translations"];
    if (rawTrans is List) {
      for (var item in rawTrans) {
        if (item is Map) {
          translations.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final processed = _processTranslations(translations);
    suttaplexData["filtered_translations"] = processed.filtered;

    setState(() {
      _sutta = suttaplexData;
      _extraTranslations = processed.extra;
      _loading = false;
    });
  }

  Future<void> _fetchSuttaplex() async {
    try {
      final raw = await SuttaService.fetchSuttaplex(widget.uid, language: "id");

      if (!mounted) return;

      _setupSuttaFromData(raw);
    } catch (e) {
      debugPrint("error fetch suttaplex: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget lockIcon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100], // background abu-abu muda
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.hourglass_empty, size: 18, color: kLockedColor),
    );
  }

  Text lockedText(String text, {FontWeight? weight}) {
    return Text(
      text,
      style: TextStyle(color: kLockedColor, fontWeight: weight),
    );
  }

  Widget buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // segmented == true → ✓ aligned
  // segmented == false → legacy
  // has_comment == true → ✓ annotated
  // segmented == true → ✓ aligned
  // segmented == false → legacy
  // has_comment == true → ✓ annotated
  Widget buildBadges(Map<String, dynamic> t) {
    final List<Widget> badges = [];

    final lang = t["lang"];
    final isRoot = t["is_root"] == true; // Cek flag is_root

    if (isRoot) {
      // 1. Kalo ini teks asli (Pali MS), labelnya "asli"
      //badges.add(buildTag("asli"));

      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.history_edu_outlined,
            // Icons.history_edu , // ✅ ganti jadi ikon gembok
            size: 18, // samain dengan lockIcon()
            color: kLockedColor, // pakai warna referensi
          ),
        ),
      );
    } else if (t["segmented"] == true) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.format_align_left, // ✅ ganti jadi ikon gembok
            size: 18, // samain dengan lockIcon()
            color: kLockedColor, // pakai warna referensi
          ),
        ),
      );

      //buildTag( const Icon(Icons.drag_handle, size: 16, color: Colors.green), ),
    } else if (lang != "pli") {
      // 3. Sisanya warisan (legacy)
      //badges.add(buildTag("warisan"));

      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.archive_outlined, // ✅ ganti jadi ikon gembok
            size: 18, // samain dengan lockIcon()
            color: kLockedColor, // pakai warna referensi
          ),
        ),
      );
    }

    //if (t["has_comment"] == true) {
    //  badges.add(buildTag("✓ anotasi"));
    // }

    return Wrap(spacing: 6, children: badges);
  }

  Widget buildTranslationItem(Map<String, dynamic> t) {
    final String lang = t["lang"] ?? "";
    final String label = t["lang_name"] ?? lang.toUpperCase();
    final String author = t["author"] ?? "";
    final bool disabled = t["disabled"] ?? false;

    final pubYear = t["publication_date"];
    final authorWithYear = pubYear != null && pubYear.toString().isNotEmpty
        ? "$author ($pubYear)"
        : author;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: disabled || _fetchingText
            ? null
            : () async {
                final String safeAuthorUid =
                    (t["author_uid"] != null &&
                        t["author_uid"].toString().isNotEmpty)
                    ? t["author_uid"].toString()
                    : ""; // jangan hardcode "ms" di sini kalau mau akurat

                setState(() => _fetchingText = true);

                try {
                  final targetUid = _sutta?["uid"]?.toString() ?? widget.uid;

                  final textData = await SuttaService.fetchFullSutta(
                    uid: targetUid,
                    authorUid: safeAuthorUid, // pakai authorUid yang benar
                    lang: lang,
                    segmented: t["segmented"] == true,
                  );

                  if (!mounted) return;

                  if (widget.onSelect != null) {
                    // Dibuka dari dalam SuttaDetail → refresh halaman aktif
                    widget.onSelect!(targetUid, lang, safeAuthorUid, textData);
                    Navigator.pop(context); // tutup modal
                  } else {
                    // Dibuka dari MenuPage → push halaman baru
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => SuttaDetail(
                          uid: targetUid,
                          lang: lang,
                          textData: textData,
                          openedFromSuttaDetail: false,
                          originalSuttaUid: null,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error loading sutta: $e");
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Gagal memuat teks $label: ${e.toString()}",
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _fetchingText = false);
                }
              },

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: disabled ? kLockedColor : Colors.black,
                      ),
                    ),
                    Text(
                      authorWithYear,
                      style: TextStyle(
                        fontSize: 13,
                        color: disabled ? kLockedColor : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              disabled ? lockIcon() : buildBadges(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTranslationList(List<dynamic> translations) {
    return Column(
      children: translations.map((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3), // jarak antar item
          child: buildTranslationItem(t),
        );
      }).toList(),
    );
  }

  Widget lockedSectionLang(String lang, {String subtitle = "Belum tersedia"}) {
    final label = lang == "pli" ? "Pāli" : "Bahasa Indonesia";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: kLockedColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: kLockedColor),
                  ),
                ],
              ),
            ),
            lockIcon(), // 👉 konsisten trailing lock
          ],
        ),
      ),
    );
  }

  Widget lockedSectionGroup(String title, List<String> langs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...langs.asMap().entries.map((entry) {
          final index = entry.key;
          final lang = entry.value;
          final isLast = index == langs.length - 1;

          return Padding(
            padding: EdgeInsets.only(
              // ❌ item pertama nggak dikasih top
              bottom: isLast ? 8 : 4, // ✅ jarak antar item & ekstra di last
            ),
            child: lockedSectionLang(lang),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _sutta?["translated_title"] ?? _sutta?["original_title"] ?? widget.uid;
    final paliTitle = _sutta?["original_title"];

    final blurb = _sutta?["blurb"] ?? "";
    final translations = _sutta?["filtered_translations"] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _fetchingText ? null : () => Navigator.pop(context),
        ),
        title: null,
      ),
      body: Stack(
        children: [
          // Body utama
          _loading
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
                      if (paliTitle != null) ...[
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "${_sutta?["acronym"] ?? ""} ",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: getNikayaColor(
                                    normalizeNikayaAcronym(
                                      (_sutta?["acronym"] ?? "")
                                          .split(" ")
                                          .first,
                                    ),
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: paliTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      Html(
                        data: blurb,
                        style: {
                          "body": Style(
                            fontSize: FontSize(14.0),
                            margin: Margins.zero,
                          ),
                          "p": Style(
                            fontSize: FontSize(14.0),
                            margin: Margins.only(bottom: 8),
                          ),
                        },
                      ),

                      const Divider(height: 32),

                      const Text(
                        "Akar (Mūla)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildTranslationList(translations),

                      if (_extraTranslations.isNotEmpty)
                        TextButton.icon(
                          onPressed:
                              _fetchingText // ✅ disable pas loading
                              ? null
                              : () => setState(
                                  () => _showAllTranslations =
                                      !_showAllTranslations,
                                ),
                          icon: Icon(
                            _showAllTranslations
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            _showAllTranslations
                                ? "Sembunyikan terjemahan lainnya"
                                : "${_extraTranslations.length} terjemahan bahasa lainnya",
                          ),
                        ),

                      if (_showAllTranslations)
                        buildTranslationList(_extraTranslations),

                      const Divider(height: 32),
                      lockedSectionGroup("Tafsiran (Aṭṭhakathā)", [
                        "pli",
                        "id",
                      ]),
                      const Divider(height: 32),
                      lockedSectionGroup("Subtafsiran (Ṭīkā)", ["pli", "id"]),
                    ],
                  ),
                ),

          // ✅ Overlay loading pas fetch text
          if (_fetchingText)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Memuat teks...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
