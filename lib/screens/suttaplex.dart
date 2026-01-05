import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/utils/system_ui_helper.dart';
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
    this.sourceMode = "sutta_detail",
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

  // ✅ ERROR TYPE DITAMBAH: "server_error"
  String? _errorType; // "network", "not_found", "server_error", atau null

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
        scrollable: true,
        title: const Text("Tambah Penanda"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tambahkan catatan (opsional, max 100 karakter):"),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.pop(ctx, controller.text.trim());
              },
              maxLength: 100,
              maxLines: 3,
              scrollPadding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const InputDecoration(
                hintText: "Contoh: Favorit saya... (atau kosongkan)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
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

    if (suttaplexData == null || suttaplexData is! Map) {
      setState(() {
        _sutta = null;
        _errorType = "not_found";
        _loading = false;
      });
      return;
    }

    final translations = <Map<String, dynamic>>[];
    final rawTrans = suttaplexData["translations"];
    if (rawTrans is List) {
      for (var item in rawTrans) {
        if (item is Map) {
          try {
            translations.add(Map<String, dynamic>.from(item));
          } catch (e) {
            debugPrint("⚠️ Error parsing translation item: $e");
            // Skip translation yang error, lanjut
          }
        }
      }
    }

    final hasTitle =
        suttaplexData["translated_title"] != null ||
        suttaplexData["original_title"] != null;

    final hasValidTranslation = translations.any((t) => t["disabled"] != true);

    if (!hasTitle && translations.isEmpty) {
      setState(() {
        _sutta = null;
        _errorType = "not_found";
        _loading = false;
      });
      return;
    }

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
      _sutta = Map<String, dynamic>.from(suttaplexData);
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
          final errString = e.toString().toLowerCase();

          // 🔥 LOGIC ERROR HANDLING YANG LEBIH CERDAS
          if (errString.contains('socket') ||
              errString.contains('lookup') ||
              errString.contains('unreachable')) {
            _errorType = "network"; // Internet mati
          } else if (errString.contains('404') ||
              errString.contains('not found')) {
            _errorType = "not_found"; // Beneran gak ketemu
          } else {
            _errorType = "server_error"; // Server bengek / error lain
          }
        });
      }
    }
  }

  Widget lockIcon() {
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

  Widget buildBadges(Map<String, dynamic> t) {
    final List<Widget> badges = [];
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
            color: badgeBgColor,
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
            color: badgeBgColor,
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
            color: badgeBgColor,
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
      color: cardColor,
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
                    widget.onSelect!(targetUid, lang, safeAuthorUid, textData);
                    Navigator.pop(context);
                  } else {
                    if (widget.sourceMode == "sutta_detail") {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SuttaDetail(
                            uid: targetUid,
                            lang: lang,
                            textData: textData,
                            entryPoint: null,
                          ),
                        ),
                      );
                    } else {
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

                      if (mounted) {
                        setState(() {});
                      }
                    }
                  }
                } catch (e) {
                  debugPrint("Error loading sutta: $e");
                  if (!mounted) return;

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
                        color: disabled ? kLockedColor : textColor,
                      ),
                    ),
                    Text(
                      authorWithYear,
                      style: TextStyle(
                        fontSize: 13,
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

  Widget lockedSectionGroup(String title, List<String> langs) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        ...langs.map((lang) {
          final label = lang == "pli" ? "Pāli" : "Bahasa Indonesia";
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                          const Text(
                            "Belum tersedia",
                            style: TextStyle(fontSize: 13, color: kLockedColor),
                          ),
                        ],
                      ),
                    ),
                    lockIcon(),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ✅ HELPER UNTUK KONTEN ERROR BIAR GAK DUPLIKAT KODE
  Widget _buildErrorContent() {
    String title;
    IconData icon;
    List<InlineSpan> details;
    bool showRetry = false;

    if (_errorType == "network") {
      title = "Tidak Ada Koneksi";
      icon = Icons.wifi_off_rounded;
      showRetry = true;
      details = [
        const TextSpan(text: "Mohon periksa koneksi internet Anda\n\n"),
        const TextSpan(
          text:
              "Untuk menghemat ruang penyimpanan, data Tipiṭaka (1 GB+) tidak tersimpan secara offline.\n\n",
        ),
        TextSpan(
          text: "Fitur offline tersedia:\n",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        TextSpan(
          text:
              "Paritta • Pendahuluan Tematik • Panduan Uposatha\nAbhidhammattha-Saṅgaha • Timer Meditasi",
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ];
    } else if (_errorType == "not_found") {
      title = "Kode Tidak Ditemukan";
      icon = Icons.search_off_rounded;
      details = [
        TextSpan(
          text:
              "Kode \"${widget.uid}\" tidak ditemukan.\nPeriksa ejaan atau coba kode lain.\n\n",
        ),
        const TextSpan(
          text:
              "Mungkin kode yang dicari adalah bagian dari suatu range\n(mis. 'Bi Pj 2' dalam 'Bi Pj 1-4').",
        ),
      ];
    } else {
      // ✅ SERVER ERROR / LAINNYA
      title = "Gangguan Teknis";
      icon = Icons.dns_rounded;
      showRetry = true;
      details = [
        const TextSpan(
          text: "Terjadi kesalahan saat menghubungi server SuttaCentral.\n",
        ),
        const TextSpan(text: "Silakan coba lagi beberapa saat lagi."),
      ];
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                children: details,
              ),
            ),
            const SizedBox(height: 24),
            if (showRetry)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final iconColor = Theme.of(context).iconTheme.color;

    final titleStr =
        _sutta?["translated_title"] ?? _sutta?["original_title"] ?? widget.uid;
    final paliTitle = _sutta?["original_title"];

    final blurb = _sutta?["blurb"] ?? "";
    final translations = _sutta?["filtered_translations"] ?? [];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 🔥 WRAP
      value: SystemUIHelper.getStyle(context),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: iconColor),
            onPressed: _fetchingText ? null : () => Navigator.pop(context),
          ),
          title: null,
          actions: [
            if (_sutta != null)
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
                                  await HistoryService.removeBookmark(
                                    widget.uid,
                                  );
                                } else {
                                  if (!context.mounted) return;
                                  final note = await _showBookmarkDialog(
                                    context,
                                  );
                                  if (note == null) return;

                                  final bookmarkItem = {
                                    'uid': widget.uid,
                                    'title':
                                        _sutta?["original_title"] ??
                                        _sutta?["translated_title"] ??
                                        widget.uid,
                                    'acronym': _sutta?["acronym"] ?? "",
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
        body: SafeArea(
          // 🔥 TAMBAH INI
          top: false, // AppBar udah handle top
          child: Stack(
            children: [
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sutta == null
                  ? Center(child: _buildErrorContent()) // ✅ PANGGIL HELPER BARU
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleStr,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
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
                          Opacity(
                            opacity: 0.15,
                            child: Divider(height: blurb.isNotEmpty ? 32 : 24),
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
                            opacity: 0.15,
                            child: const Divider(height: 32),
                          ),
                          lockedSectionGroup("Tafsiran (Aṭṭhakathā)", [
                            "pli",
                            "id",
                          ]),
                          Opacity(
                            opacity: 0.15,
                            child: const Divider(height: 32),
                          ),
                          lockedSectionGroup("Subtafsiran (Ṭīkā)", [
                            "pli",
                            "id",
                          ]),

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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              if (_fetchingText)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
        ),
      ),
    );
  }
}
