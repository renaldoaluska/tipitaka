import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import '../services/dpd.dart';
import 'package:url_launcher/url_launcher.dart';

class PaliDictionaryManager {
  static void show(
    BuildContext context, {
    String text = "",
    bool showHistory = true,
    bool isTier1 = true,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
  }) {
    final cleanText = text.trim();

    // Pecah kata hanya jika teks tidak kosong
    final words = cleanText.isEmpty
        ? <String>[]
        : cleanText
              .split(RegExp(r'[^\p{L}\p{M}]+', unicode: true))
              .where((w) => w.length > 1)
              .toList();

    // 2. Sekarang kita selalu panggil picker supaya histori kelihatan
    _showWordPicker(
      context,
      words,
      showHistory,
      isTier1,
      fontSize,
      lineHeight,
      fontFamily,
    );
  }

  static void _showWordPicker(
    BuildContext context,
    List<String> words,
    bool showHistory,
    bool isTier1,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF001520),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF003a4e))),
              ),
              // Cari di bagian Row judul "Pilih Kata" / "Riwayat Kamus DPD"
              child: Row(
                children: [
                  const Icon(Icons.book_outlined, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    words.isNotEmpty ? "Pilih Kata" : "Riwayat Kamus DPD",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- BAGIAN 1: KATA TERPILIH (Dari Sutta) ---
                    if (words.isNotEmpty) ...[
                      const Text(
                        "KATA TERPILIH",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: words
                            .map(
                              (w) => ActionChip(
                                label: Text(w),
                                backgroundColor: const Color(0xFF001a2e),
                                labelStyle: const TextStyle(color: Colors.cyan),
                                side: const BorderSide(
                                  color: Color(0xFF003a4e),
                                ),
                                // Pakai !isTier1 supaya kalau dari Sutta (Tier 1) dia GAK pop
                                onPressed: () => _openWord(
                                  sheetContext,
                                  w,
                                  // shouldPop: !isTier1,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                    ],

                    // --- BAGIAN 2: HISTORI (Maksimal 10 Kata) ---
                    if (showHistory) ...[
                      const Text(
                        "RIWAYAT TERAKHIR",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ValueListenableBuilder<List<String>>(
                        valueListenable: DpdService().historyNotifier,
                        // 🔥 Ganti 'context' jadi '_' atau 'innerCtx' agar tidak shadowing
                        builder: (innerCtx, liveHistory, _) {
                          if (liveHistory.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                "Belum ada riwayat pencarian",
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: liveHistory
                                .map(
                                  (w) => ActionChip(
                                    label: Text(w),

                                    backgroundColor: const Color(0xFF001a2e),
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.white10,
                                    ),
                                    // Pakai sheetContext supaya yang di-pop itu DIALOG-nya, bukan HALAMAN-nya
                                    onPressed: () => _openWord(
                                      sheetContext,
                                      w,
                                      //   shouldPop: !isTier1,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ), // --- BAGIAN 3: KATA FAVORIT (Di bawah Histori) ---
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      const Text(
                        "KATA FAVORIT",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ValueListenableBuilder<List<String>>(
                        valueListenable: DpdService().favoritesNotifier,
                        builder: (innerCtx, favorites, _) {
                          if (favorites.isEmpty) {
                            return const Text(
                              "Belum ada kata favorit",
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: favorites
                                .map(
                                  (w) => InputChip(
                                    label: Text(w),
                                    backgroundColor: const Color(0xFF001a2e),
                                    labelStyle: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF003a4e),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.cancel,
                                      size: 16,
                                      color: Colors.white38,
                                    ),
                                    // 🔥 FITUR APUS SATUAN
                                    // Di dalam InputChip pada baris 180-an
                                    onDeleted: () {
                                      showDialog(
                                        context: context,
                                        builder: (confirmCtx) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF001520,
                                          ),
                                          title: const Text(
                                            "Hapus Favorit?",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          content: Text(
                                            "Yakin ingin menghapus '$w' dari daftar favorit?",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(confirmCtx),
                                              child: const Text(
                                                "Batal",
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                DpdService().toggleFavorite(
                                                  w,
                                                ); // Eksekusi hapus
                                                Navigator.pop(confirmCtx);
                                              },
                                              child: const Text(
                                                "Hapus",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onPressed: () => _openWord(
                                      sheetContext,
                                      w,
                                      // shouldPop: false,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.only(top: 40, bottom: 16),
                      child: Center(
                        child: Text(
                          "Didukung oleh Digital Pāli Dictionary",
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openWord(BuildContext context, String word) {
    // Hapus parameter yang gak kepake
    if (!context.mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (ctx) => DictionaryWrapper(word: word)));
  }
}

class DictionaryWrapper extends StatelessWidget {
  final String word;
  const DictionaryWrapper({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000e16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001520),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          word,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          ValueListenableBuilder<List<String>>(
            valueListenable: DpdService().favoritesNotifier,
            builder: (context, favorites, _) {
              final isFav = favorites.contains(word);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav ? Colors.amber : Colors.white38,
                ),
                onPressed: () => DpdService().toggleFavorite(word),
              );
            },
          ),
          const SizedBox(width: 8),
        ],

        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF003a4e), height: 1),
        ),
      ),
      body: DictionaryContent(word: word, scrollController: ScrollController()),
    );
  }
}

class DictionaryContent extends StatefulWidget {
  final String word;
  final ScrollController scrollController;

  const DictionaryContent({
    super.key,
    required this.word,
    required this.scrollController,
  });

  @override
  State<DictionaryContent> createState() => _DictionaryContentState();
}

class _DictionaryContentState extends State<DictionaryContent> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final _expandedSections = <String, bool>{};
  final _sectionKeys = <String, GlobalKey>{};
  String _selectedText = '';

  Widget? _cachedSummaryWidget;
  List<_SectionData>?
  _cachedSectionData; // Kita simpan datanya, bukan widget-nya

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await DpdService().lookup(widget.word);
      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
          if (result == null) {
            _error = "kata tidak ditemukan";
          } else {
            _preRenderWidgets();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "error: $e";
        });
      }
    }
  }

  // 3. UPDATE _preRenderWidgets
  void _preRenderWidgets() {
    if (_data == null) return;

    if (_data!['summary_html'] != null) {
      _cachedSummaryWidget = Html(
        data: _cleanSummaryHtml(_data!['summary_html']),
        style: {
          "body": Style(color: Colors.white, fontSize: FontSize(14)),
          "b": Style(
            color: const Color(0xFF64B5F6),
            fontWeight: FontWeight.bold,
          ),
          "a": Style(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
            textDecoration: TextDecoration.none,
          ),
          ".summary": Style(margin: Margins.only(bottom: 8)),
        },
        onLinkTap: (url, _, _) => _handleLinkTap(url),
      );
    }

    final String dpdHtml = _data!['dpd_html'] ?? '';
    // Panggil fungsi parsing yang baru (return data, bukan widget)
    _cachedSectionData = _parseHtmlToSectionData(dpdHtml);
  }

  void _scrollToSection(String sectionId) {
    final cleanId = Uri.decodeComponent(sectionId);
    if (cleanId == 'top' ||
        cleanId == widget.word ||
        cleanId.contains(widget.word)) {
      widget.scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    final key = _sectionKeys[cleanId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _expandedSections[cleanId] = true);
    }
  }

  Future<void> _handleLinkTap(String? url) async {
    if (url == null) return;
    if (url.startsWith('lookup:')) {
      PaliDictionaryManager.show(
        context,
        text: url.replaceFirst('lookup:', ''),
        showHistory: false,
        isTier1: false,
      );
    } else if (url.startsWith('#')) {
      _scrollToSection(url.substring(1));
    } else {
      final uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint("Gagal buka link: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              _error ?? "data kosong",
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return SelectionArea(
      onSelectionChanged: (value) {
        _selectedText = value?.plainText ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final buttonItems = selectableRegionState.contextMenuButtonItems;

        buttonItems.insert(
          0,
          ContextMenuButtonItem(
            label: 'Kamus',
            onPressed: () {
              ContextMenuController.removeAny();
              if (_selectedText.isNotEmpty && context.mounted) {
                PaliDictionaryManager.show(
                  context,
                  text: _selectedText,
                  showHistory: false,
                  isTier1: false,
                );
              }
            },
          ),
        );

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_cachedSummaryWidget != null) ...[
            _cachedSummaryWidget!,
            const Divider(color: Colors.white10, height: 32),
          ], // DISINI MAGICNYA: Kita generate widget baru tiap rebuild,
          // tapi isinya (html widget berat) tetep pake yang dicache di data.
          if (_cachedSectionData != null)
            ..._cachedSectionData!.map((data) {
              if (data is _MainSectionData) {
                return _MainSection(
                  key: data
                      .key, // PENTING: Pake key yang sama biar scroll position aman
                  sectionId: data.sectionId,
                  rawTitle: data.rawTitle,
                  summaryWidget: data.summaryWidget,
                  cachedSubSections: data.cachedSubSections,
                  expandedSections: _expandedSections,
                  onToggle: (sectionKey) {
                    setState(() {
                      _expandedSections[sectionKey] =
                          !(_expandedSections[sectionKey] ?? false);
                    });
                  },
                );
              } else if (data is _StaticSectionData) {
                return _StaticCollapsibleSection(
                  key: data.key,
                  title: data.title,
                  sectionId: data.sectionId,
                  widgets: data.widgets,
                  expandedSections: _expandedSections,
                  onToggle: () {
                    setState(() {
                      _expandedSections[data.sectionId] =
                          !(_expandedSections[data.sectionId] ?? false);
                    });
                  },
                );
              }
              return const SizedBox.shrink();
            }),
          const Padding(
            padding: EdgeInsets.only(top: 32, bottom: 24),
            child: Center(
              child: Text(
                "Didukung oleh Digital Pāḷi Dictionary",
                style: TextStyle(
                  color: Colors.white24, // Warna redup biar gak mencolok
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ], // <--- Ini penutup children ListView
      ),
    );
  }

  // 5. GANTI _buildSectionsFromHtml JADI INI
  // 5. PERBAIKAN FUNGSI PARSING
  List<_SectionData> _parseHtmlToSectionData(String html) {
    final sections = <_SectionData>[];

    // GANTI LOGIC SPLIT:
    // Jangan split berdasarkan '<h3 id="', tapi split berdasarkan tag '<h3' saja
    // agar tidak peduli urutan attribute (class duluan atau id duluan).
    final h3Splits = html.split('<h3');

    // Loop mulai dari 1 karena index 0 biasanya kosong atau komentar sebelum header pertama
    for (var i = 1; i < h3Splits.length; i++) {
      // Kita susun ulang stringnya karena split menghilangkan '<h3'
      final sectionContent = '<h3${h3Splits[i]}';

      // 1. Ambil ID (bisa ada di posisi mana saja dalam tag)
      final idMatch = RegExp(
        r'''id=["']([^"']+)["']''',
      ).firstMatch(sectionContent);

      // 2. Ambil Judul (teks di antara > dan </h3>)
      final titleMatch = RegExp(
        r'''<h3[^>]*>([^<]+)</h3>''',
      ).firstMatch(sectionContent);

      if (idMatch == null || titleMatch == null) continue;

      final sectionId = idMatch.group(1)!;
      final rawTitle = titleMatch.group(1)!;

      // --- LOGIC DI BAWAH INI TETAP SAMA SEPERTI SEBELUMNYA ---

      // Handle Static Sections (Deconstructor etc)
      if (sectionId.contains(':')) {
        final divMatch = RegExp(
          r'''<div[^>]*class=["']dpd["'][^>]*>([\s\S]*?)</div>''',
        ).firstMatch(sectionContent);
        if (divMatch != null) {
          String content = divMatch.group(1)!;
          if (sectionId.startsWith('deconstructor')) {
            content = _enhanceDeconstructorHtml(content);
          }

          if (!_sectionKeys.containsKey(sectionId)) {
            _sectionKeys[sectionId] = GlobalKey();
          }

          sections.add(
            _StaticSectionData(
              key: _sectionKeys[sectionId]!,
              title: rawTitle,
              sectionId: sectionId,
              widgets: _splitContent(content),
            ),
          );
        }
        continue;
      }

      // Handle Main Sections (Grammar etc)
      final summaryMatch = RegExp(
        r'<div class="dpd summary">(.*?)</div>',
        dotAll: true,
      ).firstMatch(sectionContent);
      final summary = summaryMatch?.group(1) ?? '';
      final contentSections = _parseContentSections(sectionContent, sectionId);

      if (contentSections.isEmpty && summary.isEmpty) continue;

      final key = GlobalKey();
      _sectionKeys[sectionId] = key;

      Widget? summaryWidget;
      if (summary.isNotEmpty) {
        summaryWidget = Html(
          data: _cleanSummaryHtml(summary),
          style: _getBaseHtmlStyle(),
          onLinkTap: (url, _, _) => _handleLinkTap(url),
        );
      }

      final List<_CachedSubSection> cachedSubSections = contentSections
          .map(
            (cs) => _CachedSubSection(
              title: cs['title']!,
              id: cs['id']!,
              sectionKey: '${sectionId}_${cs['id']}',
              widgets: _splitContent(cs['content']!),
            ),
          )
          .toList();

      sections.add(
        _MainSectionData(
          key: key,
          sectionId: sectionId,
          rawTitle: rawTitle,
          summaryWidget: summaryWidget,
          cachedSubSections: cachedSubSections,
        ),
      );
    }
    return sections;
  }

  String _enhanceDeconstructorHtml(String html) {
    return html.replaceAllMapped(
      RegExp(r'(\b[\p{L}\p{M}]+\b)', unicode: true),
      (match) {
        final word = match.group(0)!;
        if (word.length > 1 &&
            word != 'dpd' &&
            word != 'content' &&
            word != 'footer') {
          return '<a href="lookup:$word">$word</a>';
        }
        return word;
      },
    );
  }

  List<Map<String, String>> _parseContentSections(
    String html,
    String parentId,
  ) {
    final sections = <Map<String, String>>[];
    final patterns = {
      'Grammar': RegExp(
        r'<div id="grammar_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
      'Examples': RegExp(
        r'<div id="examples?_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
      'Declension': RegExp(
        r'<div id="declension_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
      'Word Family': RegExp(
        r'<div id="family_word_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
      'Compound Family': RegExp(
        r'<div id="family_compound_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
      'Idioms': RegExp(
        r'<div id="family_idiom_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
      'Frequency': RegExp(
        r'<div id="frequency_[^"]*"[^>]*>(.*?)</div>',
        dotAll: true,
      ),
    };

    patterns.forEach((title, regex) {
      final match = regex.firstMatch(html);
      if (match != null) {
        sections.add({
          'title': title,
          'id': title.toLowerCase().replaceAll(' ', '_'),
          'content': match.group(1)!,
        });
      }
    });
    return sections;
  }

  List<Widget> _splitContent(String html) {
    final cleanedHtml = _cleanContentHtml(html);
    if (!cleanedHtml.contains('<table')) {
      return [
        Html(
          data: cleanedHtml,
          style: _getBaseHtmlStyle(),
          onLinkTap: (url, _, _) => _handleLinkTap(url),
        ),
      ];
    }

    final parts = cleanedHtml.split(RegExp(r'(?=<table)|(?<=</table>)'));

    return parts
        .map((part) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) return const SizedBox.shrink();

          if (trimmed.startsWith('<table')) {
            return Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Html(
                  data: trimmed,
                  extensions: const [TableHtmlExtension()],
                  style: _getBaseHtmlStyle(),
                  onLinkTap: (url, _, _) => _handleLinkTap(url),
                ),
              ),
            );
          }
          return Html(
            data: trimmed,
            style: _getBaseHtmlStyle(),
            onLinkTap: (url, _, _) => _handleLinkTap(url),
          );
        })
        .where((widget) => widget is! SizedBox)
        .toList();
  }

  Map<String, Style> _getBaseHtmlStyle() {
    return {
      "body": Style(
        color: Colors.white70,
        fontSize: FontSize(14),
        margin: Margins.zero,
      ),
      "p": Style(margin: Margins.only(bottom: 8)),
      "b": Style(color: const Color(0xFF64B5F6), fontWeight: FontWeight.bold),
      "a": Style(
        color: Colors.cyanAccent,
        fontWeight: FontWeight.bold,
        textDecoration: TextDecoration.none,
      ),
      "table": Style(
        display: Display.table,
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFF003a4e)),
        ),
        margin: Margins.zero,
        backgroundColor: const Color(0xFF000a10),
      ),
      "th": Style(
        color: Colors.cyan,
        backgroundColor: const Color(0xFF001a2e),
        padding: HtmlPaddings.all(8),
        fontSize: FontSize(12),
      ),
      "td": Style(
        color: Colors.white70,
        padding: HtmlPaddings.all(8),
        border: const Border(bottom: BorderSide(color: Color(0xFF002a3e))),
        fontSize: FontSize(12),
      ),
      "hr": Style(
        margin: Margins.symmetric(vertical: 4),
        color: const Color(0xFF003a4e),
      ),
    };
  }

  String _cleanSummaryHtml(String html) {
    return html
        .replaceAll(RegExp(r'''<a[^>]*>[\s]*[►↑][\s]*</a>'''), '')
        .replaceAll('►', '')
        .replaceAll('↑', '')
        .replaceAllMapped(
          RegExp(
            r'(adj\.|masc\.|fem\.|nt\.|ind\.|verb\.|prp\.|ptp\.|pron\.)\s+([^<]+)',
          ),
          (match) => '${match.group(1)} <b>${match.group(2)}</b>',
        );
  }

  String _cleanContentHtml(String html) {
    return html
        .replaceAll(
          RegExp(
            r'''<p[^>]*class=["']footer["'][^>]*>[\s\S]*?</p>''',
            dotAll: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'''<td>\s*<hr>\s*</td>'''), '<td></td>')
        .replaceAll('hidden', '');
  }
}

class _StaticCollapsibleSection extends StatefulWidget {
  final String title;
  final String sectionId;
  final List<Widget> widgets;
  final Map<String, bool> expandedSections;
  final VoidCallback onToggle;

  const _StaticCollapsibleSection({
    super.key,
    required this.title,
    required this.sectionId,
    required this.widgets,
    required this.expandedSections,
    required this.onToggle,
  });

  @override
  State<_StaticCollapsibleSection> createState() =>
      _StaticCollapsibleSectionState();
}

class _StaticCollapsibleSectionState extends State<_StaticCollapsibleSection> {
  bool _isLocalLoading = false;

  void _handleTap() async {
    final isExpanded = widget.expandedSections[widget.sectionId] ?? false;

    // Kalau mau collapse (tutup), langsung aja gak usah loading
    if (isExpanded) {
      widget.onToggle();
      return;
    }

    // Kalau mau expand (buka), tampilkan loading dulu
    setState(() => _isLocalLoading = true);

    // Kasih napas 50ms biar UI sempat render spinner-nya
    await Future.delayed(const Duration(milliseconds: 50));

    // Jalankan toggle yang asli
    widget.onToggle();

    // Matikan loading (cek mounted biar aman)
    if (mounted) {
      setState(() => _isLocalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.expandedSections[widget.sectionId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF001520),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF003a4e), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _isLocalLoading
                ? null
                : _handleTap, // Disable tap pas loading
            child: Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Row(
                children: [
                  if (_isLocalLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyanAccent,
                      ),
                    )
                  else
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.cyanAccent,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.widgets,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// BAGIAN BAWAH FILE (Models & Helper Widgets)
// Copas ini untuk menimpa semua class helper di bawah
// ==========================================

// 1. Model Data
class _CachedSubSection {
  final String title;
  final String id;
  final String sectionKey;
  final List<Widget> widgets;

  const _CachedSubSection({
    required this.title,
    required this.id,
    required this.sectionKey,
    required this.widgets,
  });
}

abstract class _SectionData {}

// INI YANG TADI HILANG
class _MainSectionData extends _SectionData {
  final String sectionId;
  final String rawTitle;
  final Widget? summaryWidget;
  final List<_CachedSubSection> cachedSubSections;
  final GlobalKey key;

  _MainSectionData({
    required this.sectionId,
    required this.rawTitle,
    this.summaryWidget,
    required this.cachedSubSections,
    required this.key,
  });
}

class _StaticSectionData extends _SectionData {
  final String title;
  final String sectionId;
  final List<Widget> widgets;
  final GlobalKey key;

  _StaticSectionData({
    required this.title,
    required this.sectionId,
    required this.widgets,
    required this.key,
  });
}

// 2. Widget _MainSection (Versi Stateless Baru)
class _MainSection extends StatelessWidget {
  final String sectionId;
  final String rawTitle;
  final Widget? summaryWidget;
  final List<_CachedSubSection> cachedSubSections;
  final Map<String, bool> expandedSections;
  final void Function(String) onToggle;

  // Perhatikan: kita pakai super.key agar GlobalKey yang dikirim dari data
  // nempel ke Widget ini. Ini penting buat fitur auto-scroll.
  const _MainSection({
    super.key,
    required this.sectionId,
    required this.rawTitle,
    required this.summaryWidget,
    required this.cachedSubSections,
    required this.expandedSections,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF001520),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF003a4e), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF001a2e),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              rawTitle,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (summaryWidget != null)
            Padding(padding: const EdgeInsets.all(12), child: summaryWidget),

          // Looping baris sub-section
          ...cachedSubSections.map((cs) {
            return _SubSectionRow(
              key: ValueKey(cs.sectionKey),
              subSection: cs,
              isExpanded: expandedSections[cs.sectionKey] ?? false,
              onToggle: () => onToggle(cs.sectionKey),
            );
          }),
        ],
      ),
    );
  }
}

// 3. Widget SubSectionRow (Row per item Grammar, Example, dll)
class _SubSectionRow extends StatefulWidget {
  final _CachedSubSection subSection;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SubSectionRow({
    super.key,
    required this.subSection,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_SubSectionRow> createState() => _SubSectionRowState();
}

class _SubSectionRowState extends State<_SubSectionRow> {
  bool _isLocalLoading = false;

  void _handleTap() async {
    if (widget.isExpanded) {
      widget.onToggle(); // Kalau mau tutup, langsung aja
      return;
    }

    // Kalau mau buka, loading dulu dikit
    setState(() => _isLocalLoading = true);
    await Future.delayed(const Duration(milliseconds: 50));

    widget.onToggle(); // Trigger render berat

    if (mounted) {
      setState(() => _isLocalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Colors.white10, height: 1),
        InkWell(
          onTap: _isLocalLoading ? null : _handleTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (_isLocalLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.cyan,
                    ),
                  )
                else
                  Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.cyan,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  widget.subSection.title,
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: widget.isExpanded
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.subSection.widgets,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
