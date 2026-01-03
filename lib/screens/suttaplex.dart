import 'package:flutter/material.dart';
import '../services/sutta.dart';
import 'sutta_detail.dart';
import 'package:flutter_html/flutter_html.dart';
import '../styles/nikaya_style.dart';
import '../services/history.dart';

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

  final Map<String, dynamic>? initialData;

  final String sourceMode;

  const Suttaplex({
    super.key,
    required this.uid,
    this.onSelect,
    this.initialData,
    this.sourceMode = "sutta_detail", // ✅ TAMBAH INI (default dari book button)
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

  String? _errorType; // "network", "not_found", atau null

  static const List<String> priorityLangs = ["pli", "id", "en"];

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _setupSuttaFromData(widget.initialData!);
    } else {
      _fetchSuttaplex();
    }
  }

  Future<String?> _showBookmarkDialog(BuildContext context) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tambah Penanda"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tambahkan catatan (opsional, max 100 karakter):"),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 100, // 🔥 MAX 100 KARAKTER
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Contoh: Favorit saya... (atau kosongkan)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null), // Cancel
            child: const Text("Batal"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // ✅ Process translations: filter & sort (zero data manipulation)
  ({List<Map<String, dynamic>> filtered, List<Map<String, dynamic>> extra})
  _processTranslations(List<Map<String, dynamic>> translations) {
    final filtered = translations
        .where((t) => priorityLangs.contains(t["lang"]))
        .toList();

    final extra = translations
        .where((t) => !priorityLangs.contains(t["lang"]))
        .toList();

    filtered.sort((a, b) {
      final orderA = priorityLangs.indexOf(a["lang"] ?? "");
      final orderB = priorityLangs.indexOf(b["lang"] ?? "");
      return orderA.compareTo(orderB);
    });

    return (filtered: filtered, extra: extra);
  }

  void _setupSuttaFromData(dynamic data) {
    final suttaplexData = (data is List && data.isNotEmpty) ? data[0] : data;

    debugPrint('>>> suttaplexData resolved: $suttaplexData');
    debugPrint(
      '>>> raw translations: ${suttaplexData?["translations"]} (${suttaplexData?["translations"]?.runtimeType})',
    );

    // 🔥 CEK: Data benar-benar kosong/null (not found)
    if (suttaplexData == null || suttaplexData is! Map) {
      setState(() {
        _sutta = null;
        _errorType = "not_found";
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

    // 📥 CEK: Kalau translations kosong DAN tidak ada title, anggap not found
    final hasTitle =
        suttaplexData["translated_title"] != null ||
        suttaplexData["original_title"] != null;

    // 📥 CEK: Ada minimal 1 translasi yang valid (tidak disabled)
    final hasValidTranslation = translations.any((t) => t["disabled"] != true);

    if (!hasTitle && translations.isEmpty) {
      setState(() {
        _sutta = null;
        _errorType = "not_found";
        _loading = false;
      });
      return;
    }

    // 📥 TAMBAHAN: Kalau semua translasi disabled/locked (root text kosong)
    if (!hasValidTranslation) {
      setState(() {
        _sutta = null;
        _errorType = "not_found";
        _loading = false;
      });
      return;
    }
    final processed = _processTranslations(translations);
    suttaplexData["filtered_translations"] = processed.filtered;

    setState(() {
      _sutta = Map<String, dynamic>.from(suttaplexData); // Cast ke Map
      _extraTranslations = processed.extra;
      _errorType = null;
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

  Widget lockIcon() {
    // ✅ Background icon dinamis (terang di light mode, gelap di dark mode)
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : Colors.grey[100];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          // ✅ Pastikan teks tag kelihatan di dark mode
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget buildBadges(Map<String, dynamic> t) {
    final List<Widget> badges = [];

    // ✅ Background badge dinamis
    final badgeBgColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : Colors.grey[100];

    final lang = t["lang"];
    final isRoot = t["is_root"] == true;

    if (isRoot) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBgColor, // ✅ Ganti
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.history_edu_outlined,
            size: 18,
            color: kLockedColor,
          ),
        ),
      );
    } else if (t["segmented"] == true) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBgColor, // ✅ Ganti
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.format_align_left,
            size: 18,
            color: kLockedColor,
          ),
        ),
      );
    } else if (lang != "pli") {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBgColor, // ✅ Ganti
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.archive_outlined,
            size: 18,
            color: kLockedColor,
          ),
        ),
      );
    }

    return Wrap(spacing: 6, children: badges);
  }

  Widget buildTranslationItem(Map<String, dynamic> t) {
    // ✅ Setup Warna Item List (ini yang bikin ondel-ondel kalau salah)
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

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
      color: cardColor, // ✅ Jangan Colors.white
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: disabled || _fetchingText
            ? null
            : () async {
                final String safeAuthorUid =
                    (t["author_uid"] != null &&
                        t["author_uid"].toString().isNotEmpty)
                    ? t["author_uid"].toString()
                    : "";

                setState(() => _fetchingText = true);

                try {
                  final targetUid = _sutta?["uid"]?.toString() ?? widget.uid;

                  final textData = await SuttaService.fetchFullSutta(
                    uid: targetUid,
                    authorUid: safeAuthorUid,
                    lang: lang,
                    segmented: t["segmented"] == true,
                  );

                  if (!mounted) return;

                  if (widget.onSelect != null) {
                    // Mode: Callback (ganti versi dari SuttaDetail)
                    widget.onSelect!(targetUid, lang, safeAuthorUid, textData);
                    Navigator.pop(context);
                  } else {
                    // Mode: Buka SuttaDetail baru
                    if (widget.sourceMode == "sutta_detail") {
                      // ✅ Dari SuttaDetail → REPLACE (cegah dobel screen)
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SuttaDetail(
                            uid: targetUid,
                            lang: lang,
                            textData: textData,
                            entryPoint:
                                null, // Gak ada entry point (dari SuttaDetail sendiri)
                          ),
                        ),
                      );
                    } else {
                      // 🔥 FIX: Tutup modal Suttaplex dulu, baru push SuttaDetail
                      //Navigator.pop(context); // ✅ Tutup modal bottomsheet
                      // 1. Tambah 'await'. Ini bikin Suttaplex "nunggu" sampai SuttaDetail ditutup.
                      await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => SuttaDetail(
                            uid: targetUid,
                            lang: lang,
                            textData: textData,
                            entryPoint: widget.sourceMode,
                          ),
                        ),
                      );

                      // 2. Begitu SuttaDetail ditutup (kode lanjut jalan ke sini),
                      // panggil setState buat refresh tampilan Suttaplex (termasuk ikon bookmark).
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  }
                } catch (e) {
                  debugPrint("Error loading sutta: $e");
                  if (!mounted) return;

                  // 🔥 Deteksi tipe error
                  String errorMessage;
                  if (e.toString().contains('SocketException') ||
                      e.toString().contains('Failed host lookup') ||
                      e.toString().contains('Network is unreachable')) {
                    errorMessage =
                        "Tidak ada koneksi internet. Periksa koneksi Anda.";
                  } else {
                    errorMessage = "Gagal memuat teks $label: ${e.toString()}";
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
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
                        // ✅ Warna teks label dinamis
                        color: disabled ? kLockedColor : textColor,
                      ),
                    ),
                    Text(
                      authorWithYear,
                      style: TextStyle(
                        fontSize: 13,
                        // ✅ Warna teks author dinamis
                        color: disabled ? kLockedColor : subTextColor,
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
          padding: const EdgeInsets.only(bottom: 3),
          child: buildTranslationItem(t),
        );
      }).toList(),
    );
  }

  Widget lockedSectionLang(String lang, {String subtitle = "Belum tersedia"}) {
    final label = lang == "pli" ? "Pāli" : "Bahasa Indonesia";
    // ✅ Ambil warna card dinamis
    final cardColor = Theme.of(context).colorScheme.surface;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor, // ✅ Jangan Colors.white
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
            lockIcon(),
          ],
        ),
      ),
    );
  }

  Widget lockedSectionGroup(String title, List<String> langs) {
    // ✅ Judul group perlu warna dinamis
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor, // ✅ Ganti default
          ),
        ),
        const SizedBox(height: 8),
        ...langs.asMap().entries.map((entry) {
          final index = entry.key;
          final lang = entry.value;
          final isLast = index == langs.length - 1;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 8 : 4),
            child: lockedSectionLang(lang),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SETUP WARNA UTAMA DISINI
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final iconColor = Theme.of(context).iconTheme.color;

    final titleStr =
        _sutta?["translated_title"] ?? _sutta?["original_title"] ?? widget.uid;
    final paliTitle = _sutta?["original_title"];

    final blurb = _sutta?["blurb"] ?? "";
    final translations = _sutta?["filtered_translations"] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: iconColor),
          onPressed: _fetchingText ? null : () => Navigator.pop(context),
        ),
        title: null,
        actions: [
          // 🔥 HIDE kalau _sutta kosong (error state)
          if (_sutta != null) // 👈 TAMBAH INI
            StatefulBuilder(
              builder: (context, setBookmarkState) {
                return FutureBuilder<bool>(
                  future: HistoryService.isBookmarked(widget.uid),
                  builder: (context, snapshot) {
                    final isBookmarked = snapshot.data ?? false;

                    return TextButton.icon(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                      label: Text(
                        isBookmarked ? "Hapus Penanda" : "Tambah Penanda",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      onPressed: _fetchingText
                          ? null
                          : () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );

                              if (isBookmarked) {
                                await HistoryService.removeBookmark(widget.uid);
                              } else {
                                if (!context.mounted) return;
                                final note = await _showBookmarkDialog(context);
                                if (note == null) return;

                                final bookmarkItem = {
                                  'uid': widget.uid,
                                  'title':
                                      _sutta?["original_title"] ??
                                      _sutta?["translated_title"] ??
                                      widget.uid,
                                  'acronym': _sutta?["acronym"] ?? "",
                                  //'acronym': normalizeNikayaAcronym(
                                  // _sutta?["acronym"] ?? "",
                                  // ),
                                  'note': note,
                                };

                                await HistoryService.toggleBookmark(
                                  bookmarkItem,
                                );
                              }

                              if (!mounted) return;

                              setBookmarkState(() {});

                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isBookmarked
                                        ? 'Dihapus dari Penanda'
                                        : 'Ditambahkan ke Penanda',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                    );
                  },
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Body utama
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _sutta == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _errorType == "network"
                              ? Icons.wifi_off_rounded
                              : Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorType == "network"
                              ? "Tidak Ada Koneksi"
                              : "Kode Tidak Ditemukan",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // ✅ PAKAI RichText BIAR BISA ATUR STYLE PER BAGIAN
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
                                        color: textColor.withValues(alpha: 0.9),
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
                                    TextSpan(
                                      text:
                                          "Kode \"${widget.uid}\" tidak ditemukan.\nPeriksa ejaan atau coba kode lain.\n\n",
                                    ),
                                    const TextSpan(
                                      text:
                                          "Mungkin kode yang dicari adalah bagian dari suatu range\n(mis. 'Bi Pj 2' dalam 'Bi Pj 1-4').",
                                    ),
                                  ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_errorType == "network")
                          FilledButton.icon(
                            onPressed: () {
                              setState(() => _loading = true);
                              _fetchSuttaplex();
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // const SizedBox(height: 6),
                      Text(
                        titleStr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor, // ✅ Judul
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
                                      _sutta?["acronym"] ?? "",
                                    ),
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: paliTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ✅ HANYA render Html kalau blurb ada isinya
                      if (blurb.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Html(
                          data: blurb,
                          style: {
                            "body": Style(
                              fontSize: FontSize(14.0),
                              margin: Margins.zero,
                              color: textColor,
                            ),
                            "p": Style(
                              fontSize: FontSize(14.0),
                              margin: Margins.only(bottom: 8),
                              color: textColor,
                            ),
                          },
                        ),
                      ],

                      // ✅ Divider dengan jarak yang lebih rapi
                      Opacity(
                        opacity: 0.15,
                        child: Divider(
                          height: blurb.isNotEmpty
                              ? 32
                              : 24, // Lebih rapat kalau gaada blurb
                        ),
                      ),

                      Text(
                        "Akar (Mūla)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildTranslationList(translations),

                      if (_extraTranslations.isNotEmpty)
                        TextButton.icon(
                          onPressed: _fetchingText
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

                      Opacity(
                        opacity:
                            0.15, // nilai antara 0.0 (transparan) sampai 1.0 (solid)
                        child: const Divider(height: 32),
                      ),
                      lockedSectionGroup("Tafsiran (Aṭṭhakathā)", [
                        "pli",
                        "id",
                      ]),
                      Opacity(
                        opacity:
                            0.15, // nilai antara 0.0 (transparan) sampai 1.0 (solid)
                        child: const Divider(height: 32),
                      ),
                      lockedSectionGroup("Subtafsiran (Ṭīkā)", ["pli", "id"]),

                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 10, height: 1.2),
                          children: [
                            const TextSpan(
                              text: 'Didukung oleh ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextSpan(
                              text: 'SuttaCentral',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: ' dan ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextSpan(
                              text: 'Tipitaka Pali Reader',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

          // ✅ Overlay loading pas fetch text
          if (_fetchingText)
            Container(
              color:
                  Colors.black54, // Overlay tetap gelap transparan biar fokus
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
