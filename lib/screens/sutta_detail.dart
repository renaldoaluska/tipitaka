import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import '../models/sutta_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async'; // Jangan lupa import ini

enum ViewMode { translationOnly, lineByLine, sideBySide }

class SuttaDetail extends StatefulWidget {
  final String uid;
  final String lang;
  final Map<String, dynamic>? textData;

  const SuttaDetail({
    super.key,
    required this.uid,
    required this.lang,
    required this.textData,
  });

  @override
  State<SuttaDetail> createState() => _SuttaDetailState();
}

class _SuttaDetailState extends State<SuttaDetail> {
  bool _isHtmlParsed = false;
  RegExp? _cachedSearchRegex;
  String _lastSearchQuery = "";
  ViewMode _viewMode = ViewMode.lineByLine;
  double _fontSize = 16.0;
  // List<int> _htmlMatchCounts = []; // Simpan jumlah match per segment HTML

  // Fungsi highlight khusus untuk String HTML
  String _highlightHtml(String htmlContent, int listIndex) {
    if (_lastSearchQuery.isEmpty || _cachedSearchRegex == null) {
      return htmlContent;
    }

    // Kita butuh counter global semu untuk logic "Active Match" (Orange) vs "Passive" (Kuning)
    // Tapi karena HTML string di-render sekaligus, agak tricky mendeteksi mana "Active Match" secara presisi
    // di dalam string replace.
    // Sederhananya: Kita beri warna KUNING untuk semua match.
    // Kalau mau ORANGE untuk yg aktif, logic-nya jauh lebih kompleks (harus parsing DOM).
    // Untuk sekarang, kita buat semua highlight jadi kuning biar jalan dulu.

    return htmlContent.replaceAllMapped(_cachedSearchRegex!, (match) {
      return '<span style="background-color: yellow; color: black; font-weight: bold;">${match.group(0)}</span>';
    });
  }

  // --- STATE PENCARIAN ---
  final TextEditingController _searchController = TextEditingController();

  // GANTI List<int> JADI List<SearchMatch>
  List<SearchMatch> _allMatches = [];

  int _currentMatchIndex = 0; // Posisi aktif (0 sampai total - 1)
  Timer? _debounce;

  // --- MULAI SISIPAN ---
  // 1. Controller buat fitur Loncat Indeks
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // 2. Variabel nyimpen Daftar Isi
  List<Map<String, dynamic>> _tocList = [];

  // TAMBAHAN: Key buat kontrol Scaffold dari body
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Generate TOC buat segmented
    if (widget.textData != null && widget.textData!["keys_order"] is List) {
      _generateTOC();
    }

    // Step 3: TAMBAHKAN INI - Parse HTML di initState, bukan di build
    _parseHtmlIfNeeded();
  }

  // 3. Logic Cari Heading (H1, H2, H3) buat Daftar Isi
  // 3. Logic Cari Heading (H1, H2, H3) buat Daftar Isi
  void _generateTOC() {
    final keysOrder = List<String>.from(widget.textData!["keys_order"]);

    // 1. Ambil Map Terjemahan
    final transSegs = (widget.textData!["translation_text"] is Map)
        ? (widget.textData!["translation_text"] as Map)
        : {};

    // 2. Ambil Map Root (Pali) -> INI YANG BARU
    final rootSegs = (widget.textData!["root_text"] is Map)
        ? (widget.textData!["root_text"] as Map)
        : {};

    _tocList.clear();

    for (int i = 0; i < keysOrder.length; i++) {
      final key = keysOrder[i];
      // Logic ambil nomor verse
      final verseNumRaw = key.contains(":") ? key.split(":").last : key;
      final verseNum = verseNumRaw.trim();

      // Deteksi Header
      bool isH1 = verseNum == "0.1";
      bool isH2 = verseNum == "0.2";
      bool isH3 =
          !isH1 &&
          !isH2 &&
          (verseNum.endsWith(".0") || verseNum.contains(".0."));

      if (isH1 || isH2 || isH3) {
        // 3. LOGIC CARI JUDUL (FIX)

        // Coba ambil dari terjemahan dulu
        String title =
            transSegs[key]?.toString() ?? rootSegs[key]?.toString() ?? "";

        // Bersihkan tag HTML
        title = title.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        // Fallback kalau kosong
        if (title.isEmpty) {
          title = "Bagian $verseNum";
        }

        // Simpen ke list
        _tocList.add({
          "title": title,
          "index": i,
          "type": isH1 ? 1 : (isH2 ? 2 : 3),
        });
      }
    }
  }
  // --- SELESAI SISIPAN ---

  // LOGIC SEARCH (VERSI CHROME: DETIL PER KATA)
  void _performSearch(String query) {
    _allMatches.clear();
    _currentMatchIndex = 0;

    if (query.trim().isEmpty || query.trim().length < 2) {
      _cachedSearchRegex = null; // Step 3: Clear cache
      _lastSearchQuery = "";
      setState(() {});
      return;
    }

    final lowerQuery = query.toLowerCase();

    // Step 4: TAMBAHKAN INI - Cache regex
    _lastSearchQuery = lowerQuery;
    _cachedSearchRegex = RegExp(
      RegExp.escape(lowerQuery),
      caseSensitive: false,
    );

    // --- SETUP DATA (Sama kayak sebelumnya) ---
    final segmented = SegmentedSutta.fromJson(widget.textData!);
    final translationSegs = (widget.textData!["translation_text"] is Map)
        ? (widget.textData!["translation_text"] as Map)
        : segmented.segments;
    final keysOrder = widget.textData!["keys_order"] is List
        ? List<String>.from(widget.textData!["keys_order"])
        : translationSegs.keys.toList();

    final hasTranslationMap =
        widget.textData!["translation_text"] is Map &&
        (widget.textData!["translation_text"] as Map).isNotEmpty;

    final hasRootMap =
        widget.textData!["root_text"] is Map &&
        (widget.textData!["root_text"] as Map).isNotEmpty;

    // flag tambahan untuk kasus pure Pali
    final isPurePali = hasRootMap && !hasTranslationMap;
    // definisikan rootSegs di sini
    final rootSegs = (widget.textData!["root_text"] is Map)
        ? (widget.textData!["root_text"] as Map)
        : {};

    final isSegmentedView = hasTranslationMap && keysOrder.isNotEmpty;

    // --- KASUS A: SEGMENTED (View Biasa) ---
    if (isSegmentedView) {
      final rootSegs = (widget.textData!["root_text"] is Map)
          ? (widget.textData!["root_text"] as Map)
          : {};

      for (int i = 0; i < keysOrder.length; i++) {
        final key = keysOrder[i];

        // 1. Cek Root Text (Pali)
        // Kita hitung dulu ada berapa match di sini, tapi kita gak butuh teksnya buat highlighting nanti
        // Kuncinya: Kita cuma butuh tau "Baris i punya match".
        // Tapi tunggu, highlight TextSpan butuh logic khusus.
        // Biar simpel: Kita simpan Match berdasarkan index baris.
        // Nanti _highlightText yang nentuin mana yg aktif.

        // Gabungkan teks Pali + Terjemahan dalam pikiran (atau cek satu2)
        // Disini kita harus hati-hati. _highlightText dipanggil TERPISAH untuk Pali dan Trans.
        // Jadi logic "Next" harus tau urutannya: Pali dulu, baru Trans? Atau gimana?
        // KITA SIMPLIFIKASI: Kita anggap satu baris = satu kesatuan pencarian dulu biar ga pusing.
        // TAPI user minta per KATA. Oke.

        // Strategi: Kita kumpulkan match Pali dulu, baru match Trans.
        final rootText = (rootSegs[key] ?? "").toString();
        final rootMatches = _cachedSearchRegex!
            .allMatches(rootText.toLowerCase())
            .length;

        for (int m = 0; m < rootMatches; m++) {
          // Tandai: Baris ke-i, Tipe 0 (Pali), Urutan m
          // *Hack Dikit*: Kita pake matchIndexInSeg buat nyimpen urutan global di baris itu
          // Biar gampang, kita pake logic simple:
          // Kita simpan (Baris i, Match ke-n di baris itu).
          _allMatches.add(SearchMatch(i, m));
        }

        final transText = (translationSegs[key] ?? "").toString();
        final transMatches = _cachedSearchRegex!
            .allMatches(transText.toLowerCase())
            .length;

        for (int m = 0; m < transMatches; m++) {
          // Lanjutin urutannya. Kalau pali ada 2, trans match pertama jadi urutan ke-2.
          _allMatches.add(SearchMatch(i, rootMatches + m));
        }
      }
    }
    // --- KASUS B: HTML / HTML SEGMENTS ---
    else if (_htmlSegments.isNotEmpty) {
      // SIAPIN LIST KOSONG sesuai jumlah potongan html
      //_htmlMatchCounts = List.filled(_htmlSegments.length, 0);

      for (int i = 0; i < _htmlSegments.length; i++) {
        final cleanText = _htmlSegments[i].replaceAll(RegExp(r'<[^>]*>'), '');
        final matches = _cachedSearchRegex!
            .allMatches(cleanText.toLowerCase())
            .length;

        // SIMPEN JUMLAHNYA DI SINI (biar itemBuilder ga usah ngitung ulang)
        //_htmlMatchCounts[i] = matches;

        for (int m = 0; m < matches; m++) {
          _allMatches.add(SearchMatch(i, m));
        }
      }
    } else if (isPurePali) {
      for (int i = 0; i < keysOrder.length; i++) {
        final key = keysOrder[i];
        final rootText = (rootSegs[key] ?? "").toString();
        final matches = _cachedSearchRegex!
            .allMatches(rootText.toLowerCase())
            .length;
        for (int m = 0; m < matches; m++) {
          _allMatches.add(SearchMatch(i, m));
        }
      }
    }

    if (_allMatches.isNotEmpty) {
      _jumpToResult(0);
    }

    setState(() {});
  }

  // LOGIC LONCAT (Next/Prev)
  void _jumpToResult(int index) {
    // Step 1: Tambahkan validasi lengkap
    if (_allMatches.isEmpty) {
      debugPrint('Warning: Cannot jump, no search results');
      return;
    }

    // Step 2: Normalize index dengan aman
    final maxIndex = _allMatches.length - 1;

    if (index < 0) {
      index = maxIndex;
    } else if (index > maxIndex) {
      index = 0;
    }

    // Step 3: Double check sebelum assign
    if (index >= 0 && index < _allMatches.length) {
      _currentMatchIndex = index;
      final targetRow = _allMatches[_currentMatchIndex].listIndex;

      // Step 4: Check controller attached dengan aman
      try {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: targetRow,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        }
      } catch (e) {
        debugPrint('Error scrolling to result: $e');
      }

      setState(() {});
    } else {
      debugPrint(
        'Warning: Invalid jump index $index for ${_allMatches.length} results',
      );
    }
  }

  // --- TAMBAHAN BUAT HTML NON-SEGMENTED ---
  List<String> _htmlSegments = []; // Nyimpen potongan HTML

  void _parseHtmlAndGenerateTOC(String rawHtml) {
    // Step 1: Tambahkan try-catch
    try {
      _tocList.clear();
      _htmlSegments.clear();

      // Validasi input
      if (rawHtml.trim().isEmpty) {
        debugPrint('Warning: Empty HTML content');
        return;
      }

      final RegExp headingRegex = RegExp(
        r"(<h([1-6]).*?>(.*?)<\/h\2>)",
        caseSensitive: false,
        dotAll: true,
      );

      final matches = headingRegex.allMatches(rawHtml);
      int lastIndex = 0;

      for (final match in matches) {
        // Step 2: Tambahkan null safety checks
        try {
          if (match.start > lastIndex) {
            _htmlSegments.add(rawHtml.substring(lastIndex, match.start));
          }

          String fullHeading = match.group(1) ?? "";
          String levelStr = match.group(2) ?? "3";
          String titleContent = match.group(3) ?? "";

          String cleanTitle = titleContent
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .trim();

          _htmlSegments.add(fullHeading);

          _tocList.add({
            "title": cleanTitle.isEmpty ? "Bagian" : cleanTitle,
            "index": _htmlSegments.length - 1,
            "type": int.tryParse(levelStr) ?? 3,
          });

          lastIndex = match.end;
        } catch (e) {
          // Step 3: Handle error per match
          debugPrint('Error parsing heading at position ${match.start}: $e');
          continue;
        }
      }

      if (lastIndex < rawHtml.length) {
        _htmlSegments.add(rawHtml.substring(lastIndex));
      }
    } catch (e, stackTrace) {
      // Step 4: Handle error keseluruhan
      debugPrint('Error parsing HTML: $e');
      debugPrint('Stack trace: $stackTrace');

      // Fallback: Treat as single segment
      _htmlSegments.clear();
      _htmlSegments.add(rawHtml);
      _tocList.clear();
    }
  }

  // Fungsi Helper buat Highlight Teks Pencarian
  List<TextSpan> _highlightText(
    String text,
    TextStyle baseStyle,
    int listIndex,
    int startMatchCount,
  ) {
    final query = _searchController.text;

    // Validasi lebih ketat
    if (query.isEmpty || query.length < 2 || _cachedSearchRegex == null) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    // Cek case-insensitive match (optional optimization)
    if (!text.toLowerCase().contains(query.toLowerCase())) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    // Sekarang aman pake _cachedSearchRegex!
    final matches = _cachedSearchRegex!.allMatches(text);

    int lastIndex = 0;
    List<TextSpan> spans = [];

    // Counter lokal untuk loop ini
    int localCounter = 0;

    for (var match in matches) {
      // Hitung match global untuk baris ini
      // (Misal: Pali ada 2 match, ini Trans match pertama -> berarti ini match ke-3 di baris ini)
      int currentGlobalMatchIndex = startMatchCount + localCounter;

      // Cek apakah ini match yang lagi AKTIF?
      bool isActive = false;
      if (_allMatches.isNotEmpty && _currentMatchIndex < _allMatches.length) {
        final activeMatch = _allMatches[_currentMatchIndex];
        // Aktif jika: Barisnya sama DAN Urutan match-nya sama
        isActive =
            (activeMatch.listIndex == listIndex) &&
            (activeMatch.matchIndexInSeg == currentGlobalMatchIndex);
      }

      // 1. Teks Biasa
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      // 2. Teks Highlight (ORANGE Kalo Aktif, KUNING Kalo Pasif)
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: baseStyle.copyWith(
            // --- LOGIC WARNA CHROME ---
            backgroundColor: isActive ? Colors.orange : Colors.yellow,
            color: Colors.black,
            fontWeight: isActive ? FontWeight.bold : baseStyle.fontWeight,
            // --------------------------
          ),
        ),
      );

      lastIndex = match.end;
      localCounter++; // Naikkan hitungan
    }

    // 3. Sisa Teks
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }

  void _parseHtmlIfNeeded() {
    // Cek apakah ini format HTML non-segmented
    final isHtmlFormat =
        (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"));

    if (!isHtmlFormat || _isHtmlParsed) return;

    // Ambil raw HTML
    String rawHtml = "";
    if (widget.textData!["translation_text"] is Map &&
        widget.textData!["translation_text"].containsKey("text")) {
      final transMap = Map<String, dynamic>.from(
        widget.textData!["translation_text"],
      );
      final sutta = NonSegmentedSutta.fromJson(transMap);
      rawHtml = HtmlUnescape().convert(sutta.text);
    } else if (widget.textData!["root_text"] is Map &&
        widget.textData!["root_text"].containsKey("text")) {
      final root = Map<String, dynamic>.from(widget.textData!["root_text"]);
      final sutta = NonSegmentedSutta.fromJson(root);
      rawHtml = HtmlUnescape().convert(sutta.text);
    }

    if (rawHtml.isNotEmpty) {
      _parseHtmlAndGenerateTOC(rawHtml);
      _isHtmlParsed = true;
    }
  }

  // Taruh ini di atas @override Widget build(BuildContext context)

  WidgetSpan _buildCommentSpan(
    BuildContext context,
    String comm,
    double fontSize,
  ) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Komentar"),
              // Pake SingleChildScrollView + Html biar render tag <i>, <b>, link, dll aman
              content: SingleChildScrollView(
                child: Html(
                  data: comm,
                  style: {
                    "body": Style(
                      fontSize: FontSize(fontSize),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Tutup"),
                ),
              ],
            ),
          );
        },
        child: SelectionContainer.disabled(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "*",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Step 1: Update dispose method yang sudah ada
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cachedSearchRegex = null; // Tambahkan ini
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.textData == null || widget.textData!.isEmpty) {
      return Scaffold(
        key: _scaffoldKey, // <---KEY
        appBar: AppBar(title: Text("${widget.uid} [${widget.lang}]")),
        body: const Center(child: Text("Teks tidak tersedia")),
      );
    }

    final segmented = SegmentedSutta.fromJson(widget.textData!);

    final paliSegs = (widget.textData!["root_text"] is Map)
        ? (widget.textData!["root_text"] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};

    final translationSegs = (widget.textData!["translation_text"] is Map)
        ? (widget.textData!["translation_text"] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : segmented.segments;

    final commentarySegs = (widget.textData!["comment_text"] is Map)
        ? (widget.textData!["comment_text"] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};

    final keysOrder = widget.textData!["keys_order"] is List
        ? List<String>.from(widget.textData!["keys_order"])
        : translationSegs.keys.toList();

    final hasTranslationMap =
        widget.textData!["translation_text"] is Map &&
        (widget.textData!["translation_text"] as Map).isNotEmpty;
    final isSegmented = hasTranslationMap && keysOrder.isNotEmpty;

    Widget body = const SizedBox.shrink();

    if (isSegmented) {
      switch (_viewMode) {
        case ViewMode.translationOnly:
          body = SelectionArea(
            child: ScrollablePositionedList.builder(
              // TAMBAH 2 BARIS INI:
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: keysOrder.length,
              itemBuilder: (context, index) {
                final key = keysOrder[index];
                final trans = translationSegs[key] ?? "";
                final comm = commentarySegs[key] ?? "";

                // 1. Ambil Verse Num (bersih dari spasi)
                final verseNumRaw = key.contains(":")
                    ? key.split(":").last
                    : key;
                final verseNum = verseNumRaw.trim();

                // 2. LOGIC DETEKSI HIRARKI HEADER (H1, H2, H3)
                bool isH1 = verseNum == "0.1"; // Judul Utama
                bool isH2 = verseNum == "0.2"; // Sub Judul
                // KODE BARU (FIX)
                bool isH3 =
                    !isH1 &&
                    !isH2 &&
                    (verseNum.endsWith(".0") || verseNum.contains(".0."));

                // 3. Tentukan Style & Padding (Jarak sudah dirapatkan)
                TextStyle textStyle;
                double topPadding;

                if (isH1) {
                  // STYLE H1 (Paling Besar)
                  textStyle = TextStyle(
                    fontSize: _fontSize * 1.8,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.2,
                    letterSpacing: -0.5,
                  );
                  topPadding = 16.0; // DISKON: Tadi 40.0
                } else if (isH2) {
                  // STYLE H2 (Besar)
                  textStyle = TextStyle(
                    fontSize: _fontSize * 1.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  );
                  topPadding = 8.0; // DISKON: Tadi 16.0
                } else if (isH3) {
                  // STYLE H3 (Judul Bab)
                  textStyle = TextStyle(
                    fontSize: _fontSize * 1.25,
                    fontWeight: FontWeight.w700, // Semi bold
                    color: Colors.black87,
                    height: 1.4,
                  );
                  topPadding = 16.0; // DISKON: Tadi 32.0
                } else {
                  // STYLE BODY (Ayat Biasa)
                  textStyle = TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                    height: 1.6,
                  );
                  topPadding = 0.0;
                }

                // Cek teks kosong
                final isTransEmpty = trans.trim().isEmpty;

                return Padding(
                  // Padding dinamis sesuai level header
                  padding: EdgeInsets.only(bottom: 8, top: topPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === NOMOR AYAT (Tetap Kecil & Konsisten) ===
                      SelectionContainer.disabled(
                        child: Padding(
                          // Turunin dikit kalau headernya H1/H2 biar sejajar visualnya
                          padding: EdgeInsets.only(
                            top: isH1 || isH2 ? 6.0 : 0.0,
                          ),
                          child: Text(
                            verseNum,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // === ISI TEKS (Sesuai Style H1/H2/H3) ===
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              // Teks Utama (HIGHLIGHT SUPPORT)
                              TextSpan(
                                // Ganti 'text' jadi 'children' + _highlightText
                                children: _highlightText(
                                  // 1. Teksnya
                                  isTransEmpty ? "... [pe] ..." : trans,

                                  // 2. Style-nya (Pindahin logic style ke sini)
                                  isTransEmpty
                                      ? textStyle.copyWith(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                          fontSize: _fontSize,
                                          fontWeight: FontWeight.normal,
                                        )
                                      : textStyle,
                                  index, // 3. TAMBAHKAN INI (baris ke berapa)
                                  0, // 4. TAMBAHKAN INI (mulai hitung dari 0)
                                ),
                              ),

                              // Asterisk Komentar (Pake Fungsi Helper)
                              if (comm.isNotEmpty)
                                _buildCommentSpan(
                                  context,
                                  comm,
                                  textStyle.fontSize ?? _fontSize,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
          break;
        case ViewMode.lineByLine:
          // GANTI SingleChildScrollView JADI ScrollablePositionedList
          body = SelectionArea(
            child: ScrollablePositionedList.builder(
              // Tambahin controller biar bisa jump
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: keysOrder.length,
              itemBuilder: (context, index) {
                // 1. Ambil Key by Index
                final key = keysOrder[index];

                // 2. LOGIC VARIABLE (SAMA PERSIS)
                final verseNumRaw = key.contains(":")
                    ? key.split(":").last
                    : key;
                final verseNum = verseNumRaw.trim();

                // Logic Header
                bool isH1 = verseNum == "0.1";
                bool isH2 = verseNum == "0.2";
                bool isH3 =
                    !isH1 &&
                    !isH2 &&
                    (verseNum.endsWith(".0") || verseNum.contains(".0."));

                // --- SISIPAN WARNA PALI ---
                // Cek Tema HP (Gelap/Terang)
                final isDark = Theme.of(context).brightness == Brightness.dark;
                // Gelap = Kuning Emas (Amber 200), Terang = Oren Bata (DeepOrange 900)
                final Color paliBodyColor = isDark
                    ? Colors.amber[200]!
                    : Colors.deepOrange[900]!;
                // --------------------------

                // Style Logic
                TextStyle paliStyle;
                TextStyle transStyle;
                double topPadding;

                if (isH1) {
                  topPadding = 16.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 1.6,
                    fontWeight: FontWeight.w900,
                    color: Colors.black, // Header tetap hitam biar tegas
                    height: 1.2,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize * 1.6,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.2,
                  );
                } else if (isH2) {
                  topPadding = 8.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 1.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize * 1.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  );
                } else if (isH3) {
                  topPadding = 16.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.4,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize * 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.4,
                  );
                } else {
                  // === BAGIAN BODY (AYAT BIASA) ===
                  topPadding = 0.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 0.9,
                    fontWeight: FontWeight.w500,
                    color: paliBodyColor, // <--- BERUBAH DI SINI
                    height: 1.5,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                    height: 1.5,
                  );
                }

                // Logic Teks Kosong & Komentar
                var pali = paliSegs[key] ?? "";
                if (pali.trim().isEmpty) pali = "... pe ...";

                var trans = translationSegs[key] ?? "";
                final isTransEmpty = trans.trim().isEmpty;
                final comm = commentarySegs[key] ?? "";

                final query = _searchController.text.trim();
                final int paliMatchCount =
                    (query.length >= 2 && _cachedSearchRegex != null)
                    ? _cachedSearchRegex!.allMatches(pali.toLowerCase()).length
                    : 0;

                // 3. RETURN WIDGET (SAMA PERSIS, FITUR AMAN)
                return Padding(
                  padding: EdgeInsets.only(bottom: 12, top: topPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nomor Ayat
                      SelectionContainer.disabled(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: isH1 || isH2 ? 6.0 : 0.0,
                          ),
                          child: Text(
                            verseNum,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Isi Ayat
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // === BARIS 1: PALI ===
                            Text.rich(
                              TextSpan(
                                children: _highlightText(
                                  pali,
                                  paliStyle.copyWith(
                                    fontStyle:
                                        (pali == "... pe ..." &&
                                            !isH1 &&
                                            !isH2 &&
                                            !isH3)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    color:
                                        (pali == "... pe ..." &&
                                            !isH1 &&
                                            !isH2 &&
                                            !isH3)
                                        ? Colors.grey
                                        : paliStyle.color,
                                  ),
                                  index,
                                  0,
                                ),
                              ),
                            ),

                            // === JARAK ANTARA PALI DAN TERJEMAHAN ===
                            const SizedBox(height: 4),

                            // === BARIS 2: TERJEMAHAN + ASTERISK ===
                            Text.rich(
                              TextSpan(
                                children: [
                                  // Terjemahan
                                  TextSpan(
                                    children: _highlightText(
                                      isTransEmpty ? "... [dst] ..." : trans,
                                      isTransEmpty
                                          ? transStyle.copyWith(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                              fontSize: _fontSize,
                                              fontWeight: FontWeight.normal,
                                            )
                                          : transStyle,
                                      index,
                                      paliMatchCount,
                                    ),
                                  ),

                                  // Asterisk Komentar
                                  if (comm.isNotEmpty)
                                    _buildCommentSpan(
                                      context,
                                      comm,
                                      transStyle.fontSize ?? _fontSize,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
          break;
        case ViewMode.sideBySide:
          // 1. Bungkus dengan SelectionArea (Fitur Copy-Paste Aman)
          body = SelectionArea(
            // GANTI ListView JADI ScrollablePositionedList
            child: ScrollablePositionedList.builder(
              // PASANG 2 BARIS INI BIAR FITUR JUMP JALAN
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,

              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: keysOrder.length,
              itemBuilder: (context, index) {
                final key = keysOrder[index];

                // 1. Ambil Verse Num dan bersihkan
                final verseNumRaw = key.contains(":")
                    ? key.split(":").last
                    : key;
                final verseNum = verseNumRaw.trim();

                // 2. LOGIC DETEKSI HIRARKI HEADER (SAMA PERSIS)
                bool isH1 = verseNum == "0.1";
                bool isH2 = verseNum == "0.2";
                bool isH3 =
                    !isH1 &&
                    !isH2 &&
                    (verseNum.endsWith(".0") || verseNum.contains(".0."));

                // 3. Tentukan Style & Padding (SAMA PERSIS)
                TextStyle paliStyle;
                TextStyle transStyle;
                double topPadding;

                if (isH1) {
                  topPadding = 16.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 1.6,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.2,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize * 1.6,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.2,
                  );
                } else if (isH2) {
                  topPadding = 8.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 1.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize * 1.4,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.3,
                  );
                } else if (isH3) {
                  topPadding = 16.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize * 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.4,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize * 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.4,
                  );
                } else {
                  topPadding = 0.0;
                  paliStyle = TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    height: 1.5,
                  );
                  transStyle = TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                    height: 1.5,
                  );
                }

                // 4. Logic Isi Teks
                var pali = paliSegs[key] ?? "";
                if (pali.trim().isEmpty) pali = "... pe ...";

                var trans = translationSegs[key] ?? "";
                final isTransEmpty = trans.trim().isEmpty;

                final comm = commentarySegs[key] ?? "";

                final query = _searchController.text.trim();
                final int paliMatchCount = (query.length >= 2)
                    ? RegExp(
                        RegExp.escape(query.toLowerCase()),
                      ).allMatches(pali.toLowerCase()).length
                    : 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: topPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // === SISI KIRI (PALI) ===
                          Expanded(
                            flex: 1,
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: _fontSize,
                                  color: Colors.black,
                                ),
                                children: [
                                  // Nomor Ayat (Superscript trick)
                                  WidgetSpan(
                                    child: Transform.translate(
                                      offset: const Offset(0, -6),
                                      child: SelectionContainer.disabled(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            top: isH1 || isH2 ? 6.0 : 0.0,
                                          ),
                                          child: Text(
                                            verseNum,
                                            textScaleFactor: 0.7,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: " "),
                                  // Teks Pali
                                  // Isi Teks Pali
                                  TextSpan(
                                    // Pake 'children' + fungsi highlight
                                    children: _highlightText(
                                      pali, // Teksnya
                                      // Style-nya (Pindahkan logic style kamu ke sini)
                                      paliStyle.copyWith(
                                        fontStyle:
                                            (pali == "... pe ..." &&
                                                !isH1 &&
                                                !isH2 &&
                                                !isH3)
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        color:
                                            (pali == "... pe ..." &&
                                                !isH1 &&
                                                !isH2 &&
                                                !isH3)
                                            ? Colors.grey
                                            : paliStyle
                                                  .color, // Ini otomatis ngambil warna kuning/oren
                                      ),
                                      index, // 3. TAMBAHKAN INI (baris ke berapa)
                                      0, // 4. TAMBAHKAN INI (mulai hitung dari 0)
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // === SISI KANAN (TERJEMAHAN + ASTERISK) ===
                          Expanded(
                            flex: 2,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  // Teks Terjemahan
                                  // Teks Terjemahan
                                  TextSpan(
                                    // Pake 'children' + fungsi highlight
                                    children: _highlightText(
                                      // Teksnya
                                      isTransEmpty ? "... [pe] ..." : trans,

                                      // Style-nya (Pindahkan logic style kamu ke sini)
                                      isTransEmpty
                                          ? transStyle.copyWith(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                              fontSize: _fontSize,
                                              fontWeight: FontWeight.normal,
                                            )
                                          : transStyle,
                                      index, // 3. TAMBAHKAN INI (baris ke berapa)
                                      paliMatchCount, // <-- penting: offset global
                                    ),
                                  ),
                                  // Asterisk (Pake Fungsi Helper yang baru kita buat)
                                  if (comm.isNotEmpty)
                                    _buildCommentSpan(
                                      context,
                                      comm,
                                      transStyle.fontSize ?? _fontSize,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          );
          break;
      }
      // switch ViewMode → assign body
      // ... (Bagian if isSegmented biarin aja, itu udah bener) ...
    } else if ((widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"))) {
      // Cek darurat: Kalau parsing di initState gagal atau belum selesai
      if (_htmlSegments.isEmpty) {
        // Coba ambil rawHtml lagi buat diparsing dadakan (fallback)
        String rawHtml = "";
        if (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) {
          final transMap = Map<String, dynamic>.from(
            widget.textData!["translation_text"],
          );
          final sutta = NonSegmentedSutta.fromJson(transMap);
          rawHtml = HtmlUnescape().convert(sutta.text);
        } else {
          final root = Map<String, dynamic>.from(widget.textData!["root_text"]);
          final sutta = NonSegmentedSutta.fromJson(root);
          rawHtml = HtmlUnescape().convert(sutta.text);
        }

        // Parse sekarang juga
        _parseHtmlAndGenerateTOC(rawHtml);

        // Kalau masih kosong juga setelah dipaksa parse, tampilkan loading/error
        if (_htmlSegments.isEmpty) {
          body = const Center(child: Text("Memproses tampilan..."));
        }
      }

      // Kalau _htmlSegments sudah ada isinya, render List-nya
      if (_htmlSegments.isNotEmpty) {
        body = SelectionArea(
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _htmlSegments.length,
            itemBuilder: (context, index) {
              String content = _htmlSegments[index];
              final query = _searchController.text;

              // --- LOGIC HIGHLIGHT CANGGIH (ORANGE/YELLOW) ---
              if (query.isNotEmpty &&
                  query.length >= 2 &&
                  _cachedSearchRegex != null) {
                int localMatchCounter = 0;

                content = content.replaceAllMapped(_cachedSearchRegex!, (
                  match,
                ) {
                  bool isActive = false;

                  // Cek apakah match ini adalah yang sedang difokuskan user?
                  if (_allMatches.isNotEmpty &&
                      _currentMatchIndex < _allMatches.length) {
                    final activeMatch = _allMatches[_currentMatchIndex];
                    // Logic: Barisnya sama DAN urutan ke-sekian di baris itu sama
                    isActive =
                        (activeMatch.listIndex == index &&
                        activeMatch.matchIndexInSeg == localMatchCounter);
                  }

                  localMatchCounter++; // Naikkan hitungan match di baris ini

                  String bgColor = isActive ? "orange" : "yellow";
                  // Kalau aktif teksnya ditebalkan biar kelihatan
                  String weight = isActive ? "900" : "bold";

                  return "<span style='background-color: $bgColor; color: black; font-weight: $weight'>${match.group(0)}</span>";
                });
              }

              // --- RENDER TAMPILAN ---
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Html(
                  data: content,
                  style: {
                    "body": Style(
                      fontSize: FontSize(_fontSize),
                      color: Colors.black, // Pastikan teks hitam
                      lineHeight: LineHeight(1.6),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      textAlign: TextAlign.justify, // Rata kanan-kiri biar rapi
                    ),
                    "h1": Style(
                      fontSize: FontSize(_fontSize * 1.8),
                      fontWeight: FontWeight.w900,
                      margin: Margins.only(top: 24, bottom: 12),
                    ),
                    "h2": Style(
                      fontSize: FontSize(_fontSize * 1.5),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 20, bottom: 10),
                    ),
                    "h3": Style(
                      fontSize: FontSize(_fontSize * 1.25),
                      fontWeight: FontWeight.w700,
                      margin: Margins.only(top: 16, bottom: 8),
                    ),
                  },
                ),
              );
            },
          ),
        );
      }
    } else if (widget.textData!["root_text"] is Map &&
        !(widget.textData!["root_text"].containsKey("text"))) {
      // === KASUS: SEGMENTED ROOT ONLY (PALI SAJA) ===

      final paliSegs2 = (widget.textData!["root_text"] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );

      // Pastikan urutan key konsisten
      final keysOrder2 = widget.textData!["keys_order"] is List
          ? List<String>.from(widget.textData!["keys_order"])
          : paliSegs2.keys.toList();

      // GANTI ListView JADI ScrollablePositionedList
      body = SelectionArea(
        // Bungkus biar teks bisa dicopy
        child: ScrollablePositionedList.builder(
          // 1. PASANG CONTROLLER (WAJIB BIAR BISA LONCAT)
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,

          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: keysOrder2.length,
          itemBuilder: (context, index) {
            final key = keysOrder2[index];
            final pali = paliSegs2[key] ?? "";

            // Logic ambil nomor verse
            final verseNumRaw = key.contains(":") ? key.split(":").last : key;
            final verseNum = verseNumRaw.trim();

            // 2. LOGIC DETEKSI HEADING
            bool isH1 = verseNum == "0.1";
            bool isH2 = verseNum == "0.2";
            bool isH3 =
                !isH1 &&
                !isH2 &&
                (verseNum.endsWith(".0") || verseNum.contains(".0."));

            // 3. TENTUKAN STYLE
            TextStyle currentStyle;
            double topPadding;
            double bottomPadding;

            if (isH1) {
              currentStyle = TextStyle(
                fontSize: _fontSize * 1.8,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                height: 1.2,
              );
              topPadding = 24.0;
              bottomPadding = 16.0;
            } else if (isH2) {
              currentStyle = TextStyle(
                fontSize: _fontSize * 1.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              );
              topPadding = 16.0;
              bottomPadding = 12.0;
            } else if (isH3) {
              currentStyle = TextStyle(
                fontSize: _fontSize * 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.4,
              );
              topPadding = 16.0;
              bottomPadding = 8.0;
            } else {
              currentStyle = TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.black,
                height: 1.6,
              );
              topPadding = 0.0;
              bottomPadding = 8.0;
            }

            // 4. RETURN WIDGET
            return Padding(
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    // Nomor Ayat
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Transform.translate(
                        offset: const Offset(0, 0),
                        child: Text(
                          verseNum,
                          textScaleFactor: 0.75,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: _fontSize,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: "  "),

                    // Isi Teks Pali
                    // Isi Teks Pali (HIGHLIGHT SUPPORT)
                    TextSpan(
                      // Ganti 'text' jadi 'children' + _highlightText
                      children: _highlightText(
                        pali, // Teksnya
                        // Style-nya (Pindahkan logic style ke sini)
                        currentStyle.copyWith(
                          fontStyle:
                              (pali == "... pe ..." && !isH1 && !isH2 && !isH3)
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color:
                              (pali == "... pe ..." && !isH1 && !isH2 && !isH3)
                              ? Colors.grey
                              : currentStyle.color,
                        ),
                        index, // 3. TAMBAHKAN INI (baris ke berapa)
                        0, // 4. TAMBAHKAN INI (mulai hitung dari 0)
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      // Fallback
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.textData.toString(),
          style: TextStyle(fontSize: _fontSize),
        ),
      );
    }

    return Scaffold(
      // 1. JANGAN LUPA PASANG KEY INI
      key: _scaffoldKey,

      appBar: AppBar(
        title: Text("${widget.uid} [${widget.lang}]"),
        // Wajib ditulis actions kosong gini biar Flutter gak nambahin icon otomatis
        actions: [SizedBox.shrink()],
      ),

      // 2. END DRAWER (Udah Bener)
      endDrawer: _tocList.isNotEmpty
          ? Drawer(
              child: Column(
                children: [
                  const DrawerHeader(
                    child: Center(
                      child: Text(
                        "Daftar Isi",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _tocList.length,
                      itemBuilder: (context, index) {
                        final item = _tocList[index];
                        final level = item['type'] as int;
                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: level == 1 ? 16 : (level == 2 ? 32 : 48),
                            right: 16,
                          ),
                          title: Text(
                            item['title'],
                            style: TextStyle(
                              fontWeight: level == 1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: level == 1 ? 16 : 14,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (_itemScrollController.isAttached) {
                              _itemScrollController.scrollTo(
                                index: item['index'],
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                alignment: 0.1,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          : null,

      // 3. BODY HARUS PAKE STACK (Biar ada tombol melayang di kanan)
      body: Stack(
        children: [
          // Layer Bawah: Teks
          SelectionArea(child: body),

          // Layer Atas: Tombol Daftar Isi di Kanan Tengah
          //if (isSegmented && _tocList.isNotEmpty)
          if (_tocList.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  elevation: 4,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    onTap: () {
                      // Panggil Drawer pake Key
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Icon(Icons.list, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // 4. FLOATING ACTION BUTTON (Udah Bener)
      // Posisi tetap di tengah bawah
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Bungkus 2 tombol dalam Row
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. TOMBOL PENCARIAN (VERSI KOMPLIT: NO OVERLAY + PER KATA COUNTER)
          FloatingActionButton.extended(
            heroTag: "btn_cari",
            label: const Text("Cari"),
            icon: const Icon(Icons.search),
            backgroundColor: _htmlSegments.isNotEmpty ? Colors.grey[300] : null,
            foregroundColor: _htmlSegments.isNotEmpty ? Colors.grey : null,
            onPressed: _htmlSegments.isNotEmpty
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor:
                          Colors.transparent, // Menghilangkan overlay abu-abu
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (ctx, setSheetState) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(
                                  context,
                                ).viewInsets.bottom,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor.withValues(
                                    alpha: 0.9,
                                  ), // transparan 70%
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            autofocus: true,
                                            decoration: InputDecoration(
                                              hintText:
                                                  "Cari kata (min. 2 huruf)...",
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              suffixIcon: IconButton(
                                                icon: const Icon(
                                                  Icons.backspace_outlined,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  // Tambahkan check mounted
                                                  if (mounted) {
                                                    setState(() {
                                                      _allMatches.clear();
                                                    });
                                                  }
                                                  // Update sheet state juga perlu check
                                                  if (mounted) {
                                                    setSheetState(() {});
                                                  }
                                                },
                                              ),
                                            ),
                                            onChanged: (val) {
                                              if (_debounce?.isActive ?? false)
                                                _debounce!.cancel();

                                              _debounce = Timer(
                                                const Duration(
                                                  milliseconds: 500,
                                                ),
                                                () {
                                                  // Step 2: TAMBAHKAN CHECK INI
                                                  if (!mounted)
                                                    return; // <--- PENTING!

                                                  if (val.trim().length >= 2) {
                                                    _performSearch(val);
                                                  } else {
                                                    setState(() {
                                                      _allMatches.clear();
                                                    });
                                                  }

                                                  // Step 3: TAMBAHKAN CHECK di setSheetState juga
                                                  if (mounted) {
                                                    setSheetState(() {});
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // COUNTER PER KATA (Misal: 1 dari 10)
                                        Text(
                                          _allMatches.isEmpty
                                              ? "0 hasil"
                                              : "${_currentMatchIndex + 1} dari ${_allMatches.length} kata",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.arrow_upward,
                                              ),
                                              onPressed: _allMatches.isEmpty
                                                  ? null
                                                  : () {
                                                      _jumpToResult(
                                                        _currentMatchIndex - 1,
                                                      );
                                                      setSheetState(() {});
                                                    },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.arrow_downward,
                                              ),
                                              onPressed: _allMatches.isEmpty
                                                  ? null
                                                  : () {
                                                      _jumpToResult(
                                                        _currentMatchIndex + 1,
                                                      );
                                                      setSheetState(() {});
                                                    },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ).whenComplete(() {
                      // AUTO CLEAR: Hapus highlight saat pencarian ditutup
                      _debounce
                          ?.cancel(); // cancel timer biar nggak nembak lagi
                      setState(() {
                        _searchController.clear();
                        _allMatches.clear();
                      });
                    });
                  },
          ),
          const SizedBox(width: 12), // Jarak antar tombol
          // 2. TOMBOL MENU (YANG LAMA)
          FloatingActionButton.extended(
            heroTag: "btn_tampilan", // Ganti tag biar rapi (opsional)
            label: const Text("Tampilan"), // Ganti Teks
            icon: const Icon(Icons.visibility), // Ganti Ikon Mata
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSegmented && widget.lang != "pli")
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(
                                      () => _viewMode = ViewMode.lineByLine,
                                    ),
                                    child: const Text("Baris-per-baris"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(
                                      () => _viewMode = ViewMode.sideBySide,
                                    ),
                                    child: const Text("Kiri-kanan"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(
                                      () =>
                                          _viewMode = ViewMode.translationOnly,
                                    ),
                                    child: const Text("Terjemahan saja"),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.text_decrease),
                                label: const Text("Kecil"),
                                onPressed: () => setState(
                                  () => _fontSize = (_fontSize - 2).clamp(
                                    12.0,
                                    30.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text("Reset"),
                                onPressed: () =>
                                    setState(() => _fontSize = 16.0),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.text_increase),
                                label: const Text("Besar"),
                                onPressed: () => setState(
                                  () => _fontSize = (_fontSize + 2).clamp(
                                    12.0,
                                    30.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Helper Class buat nyimpen alamat kata
class SearchMatch {
  final int listIndex; // Index Baris (Segment)
  final int matchIndexInSeg; // Urutan kata di dalam baris itu (ke-1, ke-2, dst)

  SearchMatch(this.listIndex, this.matchIndexInSeg);
}
