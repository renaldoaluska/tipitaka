import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:tipitaka/screens/menu_page.dart';
import 'package:tipitaka/screens/suttaplex.dart';
import 'package:tipitaka/services/sutta.dart';
import '../models/sutta_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async';

enum ViewMode { translationOnly, lineByLine, sideBySide }

class SuttaDetail extends StatefulWidget {
  final String uid;
  final String lang;
  final Map<String, dynamic>? textData;

  final bool openedFromSuttaDetail;
  final String? originalSuttaUid;

  const SuttaDetail({
    super.key,
    required this.uid,
    required this.lang,
    required this.textData,
    this.openedFromSuttaDetail = false, // ✅ Default false
    this.originalSuttaUid, // ✅ Nullable
  });

  @override
  State<SuttaDetail> createState() => _SuttaDetailState();
}

class _SuttaDetailState extends State<SuttaDetail> {
  // --- NAV CONTEXT & STATE ---
  String? _parentVaggaId; // anchor back ke Vagga/Nikaya aktif

  // Tambahin variable di class state (bagian atas)
  //bool _hasNavigated = false; // ✅ Track apakah user pernah next/prev
  bool _isFirst = false; // disable Prev jika true
  bool _isLast = false; // disable Next jika true
  bool _isLoading = false;

  bool _isHtmlParsed = false;
  RegExp? _cachedSearchRegex;
  //String _lastSearchQuery = "";
  ViewMode _viewMode = ViewMode.lineByLine;
  double _fontSize = 16.0;
  // List<int> _htmlMatchCounts = []; // Simpan jumlah match per segment HTML

  // Fungsi highlight khusus untuk String HTML
  /*String _highlightHtml(String htmlContent, int listIndex) {
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
  }*/

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

    print("=== WIDGET INFO ===");
    print("uid: ${widget.uid}");
    print("lang: ${widget.lang}");
    print("segmented: ${widget.textData?["segmented"]}");
    print("keys_order: ${widget.textData?["keys_order"]?.runtimeType}");

    // ✅ CEK SEGMENTED DULU
    final bool isSegmented = widget.textData?["segmented"] == true;

    // Generate TOC buat segmented
    if (isSegmented &&
        widget.textData != null &&
        widget.textData!["keys_order"] is List) {
      _generateTOC();
    }

    // Parse HTML untuk non-segmented
    _parseHtmlIfNeeded();
    _initNavigationContext();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearMaterialBanners();
    });
  }

  // 3. Logic Cari Heading (H1, H2, H3) buat Daftar Isi
  void _generateTOC() {
    // ✅ CEK DULU ADA keys_order GA
    if (widget.textData!["keys_order"] == null) return;

    final keysOrder = List<String>.from(widget.textData!["keys_order"]);

    final transSegs = (widget.textData!["translation_text"] is Map)
        ? (widget.textData!["translation_text"] as Map)
        : {};

    final rootSegs = (widget.textData!["root_text"] is Map)
        ? (widget.textData!["root_text"] as Map)
        : {};

    _tocList.clear();

    for (int i = 0; i < keysOrder.length; i++) {
      final key = keysOrder[i];
      final verseNumRaw = key.contains(":") ? key.split(":").last : key;
      final verseNum = verseNumRaw.trim();

      bool isH1 = verseNum == "0.1";
      bool isH2 = verseNum == "0.2";
      final headerRegex = RegExp(r'^(?:\d+\.)*0(?:\.\d+)*$');
      final isHeader = headerRegex.hasMatch(verseNum);
      bool isH3 = isHeader && !isH1 && !isH2;

      if (isH1 || isH2 || isH3) {
        String title =
            transSegs[key]?.toString() ?? rootSegs[key]?.toString() ?? "";
        title = title.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        if (title.isEmpty) {
          title = "Bagian $verseNum";
        }

        _tocList.add({
          "title": title,
          "index": i,
          "type": isH1 ? 1 : (isH2 ? 2 : 3),
        });
      }
    }
  }

  void _performSearch(String query) {
    _allMatches.clear();
    _currentMatchIndex = 0;

    if (query.trim().isEmpty || query.trim().length < 2) {
      _cachedSearchRegex = null;
      //_lastSearchQuery = "";
      setState(() {});
      return;
    }

    final lowerQuery = query.toLowerCase();
    //_lastSearchQuery = lowerQuery;
    _cachedSearchRegex = RegExp(
      RegExp.escape(lowerQuery),
      caseSensitive: false,
    );

    // ✅ DETEKSI MODE DARI FLAG
    final bool isSegmented = widget.textData!["segmented"] == true;

    if (isSegmented) {
      // ✅ AMBIL DATA LANGSUNG DARI textData
      final translationSegs = (widget.textData!["translation_text"] is Map)
          ? (widget.textData!["translation_text"] as Map)
          : {};

      final rootSegs = (widget.textData!["root_text"] is Map)
          ? (widget.textData!["root_text"] as Map)
          : {};

      // ✅ AMBIL keysOrder DARI FLAG
      final keysOrder = widget.textData!["keys_order"] is List
          ? List<String>.from(widget.textData!["keys_order"])
          : [];

      // Filter metadata keys
      final metadataKeys = {
        'previous',
        'next',
        'author_uid',
        'vagga_uid',
        'lang',
        'title',
        'acronym',
        'text',
      };

      final filteredKeys = keysOrder
          .where((k) => !metadataKeys.contains(k))
          .toList();

      // Scan setiap baris
      for (int i = 0; i < filteredKeys.length; i++) {
        final key = filteredKeys[i];

        // 1. Match di Root (Pali)
        final rootText = (rootSegs[key] ?? "").toString();
        final rootMatches = _cachedSearchRegex!
            .allMatches(rootText.toLowerCase())
            .length;

        for (int m = 0; m < rootMatches; m++) {
          _allMatches.add(SearchMatch(i, m));
        }

        // 2. Match di Translation
        final transText = (translationSegs[key] ?? "").toString();
        final transMatches = _cachedSearchRegex!
            .allMatches(transText.toLowerCase())
            .length;

        for (int m = 0; m < transMatches; m++) {
          _allMatches.add(SearchMatch(i, rootMatches + m));
        }
      }
    }
    // HTML mode
    else if (_htmlSegments.isNotEmpty) {
      for (int i = 0; i < _htmlSegments.length; i++) {
        final cleanText = _htmlSegments[i].replaceAll(RegExp(r'<[^>]*>'), '');
        final matches = _cachedSearchRegex!
            .allMatches(cleanText.toLowerCase())
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

  void _initNavigationContext() {
    print("=== INIT NAVIGATION ===");
    print("root_text: ${widget.textData?["root_text"]}");
    print("vagga_uid: ${widget.textData?["root_text"]?["vagga_uid"]}");
    print("resolved_vagga_uid: ${widget.textData?["resolved_vagga_uid"]}");
    print("previous: ${widget.textData?["root_text"]?["previous"]}");
    print("next: ${widget.textData?["root_text"]?["next"]}");

    final root = widget.textData?["root_text"];
    if (root is Map) {
      _parentVaggaId =
          root["vagga_uid"]?.toString() ??
          widget.textData?["resolved_vagga_uid"]?.toString();

      final prev = root["previous"];
      final next = root["next"];

      // ✅ Cek: null, Map kosong, uid null, ATAU uid string kosong
      _isFirst =
          prev == null ||
          (prev is Map &&
              (prev.isEmpty ||
                  prev["uid"] == null ||
                  prev["uid"].toString().trim().isEmpty));
      _isLast =
          next == null ||
          (next is Map &&
              (next.isEmpty ||
                  next["uid"] == null ||
                  next["uid"].toString().trim().isEmpty));

      print("_isFirst: $_isFirst, _isLast: $_isLast");
    } else {
      _isFirst = true;
      _isLast = true;
    }

    setState(() {});
  }

  Future<bool> _handleBackReplace() async {
    // 🛑 SATPAM: Cek dulu ini Sutta hasil Next/Prev atau bukan?
    // Kalau ini hasil Next/Prev (openedFromSuttaDetail == true),
    // biarkan dia BACK NORMAL (mundur history) tanpa dialog.
    if (widget.openedFromSuttaDetail) {
      return true; // true = izinkan Navigator.pop jalan
    }

    print("=== BACK HANDLER (ROOT SUTTA) ===");
    print("Mencari induk untuk kembali...");

    // 1. Kalau ini Sutta PERTAMA (openedFromSuttaDetail == false),
    // Kita cari induknya buat siap-siap "Exit to Menu"
    if (_parentVaggaId == null) {
      final resolved = await _resolveVaggaUid(widget.uid);
      if (mounted && resolved != null) {
        setState(() {
          _parentVaggaId = resolved;
        });
      }
    }

    // 2. Kalau Induk ketemu, TAMPILKAN DIALOG "TINGGALKAN MODE BACA?"
    if (_parentVaggaId != null) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  "Tinggalkan mode baca?",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            "Posisi bacaan akan kembali ke daftar awal.",
            style: TextStyle(color: Colors.grey),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false), // JANGAN KELUAR
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Batal"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true), // YAKIN KELUAR
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Ya, Keluar"),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (shouldLeave != true) return false; // Batal back
      if (!mounted) return false;
      // ✅ OPTIMASI BARU:
      // Kalau user GAK pernah Next/Prev (stack masih murni),
      // Cukup pop biasa aja. Ini lebih mulus & posisi scroll menu terjaga.
      // if (!_hasNavigated) {
      //  Navigator.pop(context, true);
      //  return false;
      // }

      // --- EKSEKUSI KELUAR KE MENU (Hanya kalau Stack sudah "kotor" karena Next/Prev) ---

      // OPTIONAL: Bersihkan cache SuttaService biar RAM lega lagi setelah sesi baca selesai
      // (Api cache tetep jalan, jadi kalau user masuk lagi tetep cepet, cuma perlu parsing ulang dikit)
      SuttaService.clearCache();
      print("Cleared SuttaService memory cache.");
      // Bersihkan tumpukan Sutta, sisakan root
      Navigator.of(context).popUntil((route) => route.isFirst);

      // (Opsional) Push Root Prefix (misal DN/MN) kalau perlu biar breadcrumb rapi
      final rootPrefix =
          RegExp(r'^[A-Za-z]+(?:-[A-Za-z]+)?').stringMatch(widget.uid) ?? "";
      if (rootPrefix.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: RouteSettings(name: '/$rootPrefix'),
            builder: (_) => MenuPage(uid: rootPrefix),
          ),
        );
      }

      // Format Acronym buat judul header menu
      String rawAcronym =
          widget.textData?["root_text"]?["acronym"]?.toString() ?? "";
      if (rawAcronym.isEmpty) {
        rawAcronym =
            RegExp(r'^[A-Za-z]+(?:-[A-Za-z]+)?').stringMatch(widget.uid) ?? "";
      }
      rawAcronym = rawAcronym.replaceAll("-", " ");
      const fullUpperSet = {"DN", "MN", "SN", "AN"};
      String formattedAcronym = fullUpperSet.contains(rawAcronym.toUpperCase())
          ? rawAcronym.toUpperCase()
          : rawAcronym.isNotEmpty
          ? rawAcronym[0].toUpperCase() + rawAcronym.substring(1)
          : "";

      // Push ke Halaman Menu (Vagga)
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/vagga/$_parentVaggaId'),
          builder: (_) =>
              MenuPage(uid: _parentVaggaId!, parentAcronym: formattedAcronym),
        ),
      );

      return false; // Kita handle navigasi sendiri, jadi return false
    }

    // 3. Fallback kalau gak punya parent (misal teks lepas/error), back normal aja
    print("No dialog, back normal");
    Navigator.pop(context);
    return true;
  }

  void _replaceToRoute(String route, {bool slideFromLeft = false}) {
    Widget targetPage;

    if (route.startsWith('/vagga/')) {
      final vaggaId = route.split('/').last;
      targetPage = MenuPage(uid: vaggaId);
    } else if (route.startsWith('/suttaplex/')) {
      final suttaId = route.split('/').last;
      targetPage = Suttaplex(uid: suttaId);
    } else {
      targetPage = const Scaffold(
        body: Center(child: Text("Route belum dihubungkan")),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  Future<void> _replaceToSutta(
    String newUid,
    String lang, {
    required String authorUid,
    required bool segmented,
    Map<String, dynamic>? textData,
    bool slideFromLeft = false,
  }) async {
    setState(() => _isLoading = true);

    try {
      // Kalau data sudah ada (dari Suttaplex modal), langsung pakai
      final data =
          textData ??
          await SuttaService.fetchFullSutta(
            uid: newUid,
            authorUid: authorUid,
            lang: lang,
            segmented: segmented,
            siteLanguage: "id",
          );

      print("=== _replaceToSutta DEBUG ===");
      print("Source: ${textData != null ? '🔵 Suttaplex' : '🟢 API'}");
      print("UID: $newUid | Lang: $lang | Segmented: $segmented");
      print("Data keys: ${data.keys}");

      if (data["root_text"] is Map) {
        final rootMap = data["root_text"] as Map;
        print("root_text: ${rootMap.keys.length} keys");
        // Sample beberapa key
        final sampleKeys = rootMap.keys.take(5).toList();
        print("  sample keys: $sampleKeys");
      }

      if (data["translation_text"] is Map) {
        final transMap = data["translation_text"] as Map;
        print("translation_text: ${transMap.keys.length} keys");
        final sampleKeys = transMap.keys.take(5).toList();
        print("  sample keys: $sampleKeys");
      }

      print("keys_order: ${data["keys_order"]}");
      print("=============================\n");

      // ✅ SIMPLE MERGE - Service sudah handle semua normalisasi
      final mergedData = {...data, "suttaplex": widget.textData?["suttaplex"]};

      // Update navigation state
      _updateParentAnchorOnMove(
        mergedData["root_text"] as Map<String, dynamic>?,
        mergedData["suttaplex"] as Map<String, dynamic>?,
      );

      // Resolve vagga
      final root = mergedData["root_text"];
      if (root is Map && root["vagga_uid"] != null) {
        setState(() => _parentVaggaId = root["vagga_uid"].toString());
      } else {
        final resolvedVagga = await _resolveVaggaUid(newUid);
        if (resolvedVagga != null) {
          setState(() => _parentVaggaId = resolvedVagga);
          mergedData["resolved_vagga_uid"] = resolvedVagga;
        }
      }

      if (!mounted) return;

      // Navigate
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: '/sutta/$newUid'),
          pageBuilder: (_, __, ___) => SuttaDetail(
            uid: newUid,
            lang: lang,
            textData: mergedData,
            openedFromSuttaDetail: true,
            originalSuttaUid: null,
          ),
          transitionsBuilder: (_, animation, __, child) {
            final offsetBegin = slideFromLeft
                ? const Offset(-1, 0)
                : const Offset(1, 0);
            final tween = Tween(
              begin: offsetBegin,
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeInOut));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("❌ Error _replaceToSutta: $e");
      debugPrint("Stack: $stackTrace");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: '/suttaplex/$newUid'),
          builder: (_) => Suttaplex(uid: newUid),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TODO: ganti ke sumber data kamu
  /*Future<_Avail> _checkAvailability(Map<String, dynamic>? nav) async {
    if (nav == null) return const _Avail("pli", false);
    final lang = nav["lang"]?.toString() ?? "pli";
    final hasTranslation = (lang == "id" || lang == "en");
    return _Avail(lang, hasTranslation);
  }*/

  /// Helper untuk resolve vagga_uid dari sutta uid
  /// Contoh: mn61 -> cari di menu/mn, ketemu di range MN 51-100 -> return "mn-majjhimapannasa"
  /// Helper untuk resolve vagga_uid dari sutta uid
  /// FIXED: Sekarang support format 3 angka (misal: SN 3.11-20 -> [3, 11, 20])
  // ✅ LOGIC PENCARI ORANG TUA KANDUNG (DRILL DOWN - FINAL)
  // Menangani struktur dalam kayak SN & AN (Collection -> Book -> Vagga -> Sutta)
  Future<String?> _resolveVaggaUid(String suttaUid) async {
    try {
      print("=== 🕵️ START DRILL DOWN: $suttaUid ===");

      // 1. Parsing UID (sn12.10 -> coll: sn, book: 12, sutta: 10)
      final regex = RegExp(r'^([a-z]+)(\d+)(?:\.(\d+))?');
      final match = regex.firstMatch(suttaUid.toLowerCase());

      if (match == null) return null;

      final collection = match.group(1)!; // sn
      final bookNum = int.parse(match.group(2)!); // 12
      final suttaNum = match.group(3) != null
          ? int.parse(match.group(3)!)
          : null; // 10

      print("🎯 Target: $collection Book:$bookNum Sutta:$suttaNum");

      // Mulai dari Root Koleksi
      String currentParent = collection;

      // Loop maksimal 5 level (SN -> SN 12-21 -> SN 12 -> SN 12.1-10)
      for (int level = 0; level < 5; level++) {
        // print("🔍 Level $level Checking: $currentParent");

        final menuData = await SuttaService.fetchMenu(
          currentParent,
          language: "id",
        );
        if (menuData is! List || menuData.isEmpty) break;

        final root = menuData[0];
        final children = root["children"] as List?;
        if (children == null || children.isEmpty) break;

        String? nextParent;

        // Scan anak-anak di level ini
        for (var child in children) {
          final rangeStr = child["child_range"]?.toString() ?? "";
          if (rangeStr.isEmpty) continue;

          // Parsing Angka dari Range
          // Contoh "SN 1–11" -> [1, 11]
          // Contoh "SN 12" -> [12]
          // Contoh "SN 12.1-10" -> [12, 1, 10] (Book, Start, End)
          final nums = RegExp(
            r'(\d+)',
          ).allMatches(rangeStr).map((m) => int.parse(m.group(1)!)).toList();
          if (nums.isEmpty) continue;

          // LOGIC PENCOCOKAN YANG LEBIH PINTAR
          bool isMatch = false;

          // 1. Cek Level Buku Range (SN 1-11)
          if (level == 0 && (collection == 'sn' || collection == 'an')) {
            int start = nums.first;
            int end = nums.last;
            if (bookNum >= start && bookNum <= end) isMatch = true;
          }
          // 2. Cek Level Buku Tunggal (SN 12)
          // Range biasanya cuma 1 angka = NOMOR BUKU
          else if (nums.length == 1 && nums.first == bookNum) {
            // Pastikan UID child mengandung bookNum kita (biar gak salah tangkap angka lain)
            if (child['uid'].toString().contains(bookNum.toString()))
              isMatch = true;
          }
          // 3. Cek Level Sutta Range (SN 12.1-10) -> [12, 1, 10]
          // Ini logic khusus buat SN/AN yang punya range sutta di dalam buku
          else if (suttaNum != null && nums.length >= 3) {
            // Pastikan Buku-nya cocok dulu (Angka Pertama)
            if (nums[0] == bookNum) {
              int start =
                  nums[nums.length -
                      2]; // Angka ke-2 dari belakang (Start Sutta)
              int end = nums.last; // Angka terakhir (End Sutta)

              if (suttaNum >= start && suttaNum <= end) {
                isMatch = true;
              }
            }
          }
          // 4. Cek Level Sutta Range tanpa Buku (1-10) -> [1, 10]
          // Kadang range-nya ga bawa nomor buku kalau parent-nya udah jelas buku
          else if (suttaNum != null && nums.length == 2) {
            // Cek apakah currentParent adalah Buku yang benar (misal sn12)
            if (currentParent.contains(bookNum.toString())) {
              int start = nums[0];
              int end = nums[1];
              if (suttaNum >= start && suttaNum <= end) isMatch = true;
            }
          }

          if (isMatch) {
            nextParent = child["uid"];
            // print("   ✅ Match found: $nextParent (Range: $rangeStr)");
            break;
          }
        }

        if (nextParent != null) {
          currentParent = nextParent;
        } else {
          // Kalau gak ada anak yang lebih dalam, STOP. Kita udah di ujung.
          // print("🛑 No deeper match found. Stop at $currentParent");
          break;
        }
      }

      print("🏁 Final Resolved Vagga: $currentParent");
      // Safety: Jangan balikin collection root ('sn') sebagai parent vagga
      if (currentParent == collection) return null;

      return currentParent;
    } catch (e) {
      debugPrint("Error resolving vagga: $e");
      return null;
    }
  }

  // ✅ LOGIC NAVIGASI UTAMA (GABUNGAN PREV & NEXT)
  Future<void> _navigateToSutta({required bool isPrevious}) async {
    final segmented = widget.textData?["segmented"] == true;

    // 1. Tentukan Key ("previous" atau "next")
    final key = isPrevious ? "previous" : "next";

    // 2. Cari Target Data (Sama persis logic lu)
    Map<String, dynamic>? navTarget;
    if (segmented) {
      final root = widget.textData?["root_text"];
      navTarget = (root is Map) ? root[key] : null;
    } else {
      final trans = widget.textData?["translation"];
      final root = widget.textData?["root_text"];
      final suttaplex = widget.textData?["suttaplex"];

      if (trans is Map && trans[key] != null) {
        navTarget = trans[key];
      } else if (root is Map && root[key] != null) {
        navTarget = root[key];
      } else if (suttaplex is Map) {
        navTarget = suttaplex[key];
      }
    }

    // 3. Validasi UID
    if (navTarget == null || navTarget["uid"] == null) return;
    final targetUid = navTarget["uid"].toString();
    if (targetUid.trim().isEmpty) return;

    // 4. Ambil Author UID (Fitur Fallback Lu Dijaga Disini)
    String? authorUid = widget.textData?["author_uid"]?.toString();

    if (authorUid == null) {
      if (segmented) {
        authorUid =
            widget.textData?["translation"]?["author_uid"]?.toString() ??
            widget.textData?["comment_text"]?["author_uid"]?.toString();
      } else {
        authorUid =
            navTarget["author_uid"]?.toString() ??
            widget.textData?["translation"]?["author_uid"]?.toString();
      }
    }

    if (authorUid == null) {
      debugPrint("ERROR: authorUid is null for $targetUid");
      return;
    }

    // 5. Tentukan Bahasa
    final targetLang = segmented
        ? widget.lang
        : navTarget["lang"]?.toString() ?? widget.lang;

    setState(() {
      _isLoading = true;
      //_hasNavigated = true;
    });

    try {
      final data = await SuttaService.fetchFullSutta(
        uid: targetUid,
        authorUid: authorUid,
        lang: targetLang,
        segmented: segmented,
        siteLanguage: "id",
      );

      // Merge Data
      final mergedData = {
        ...data,
        "segmented": segmented,
        "suttaplex": widget.textData?["suttaplex"],
      };

      // Update Anchor
      _updateParentAnchorOnMove(
        mergedData["root_text"] as Map<String, dynamic>?,
        mergedData["suttaplex"] as Map<String, dynamic>?,
      );

      // 6. Resolve Vagga (Fitur Penting Lu)
      final rootMeta = mergedData["root_text"];
      if (rootMeta is Map &&
          rootMeta["vagga_uid"] != null &&
          rootMeta["vagga_uid"].toString().trim().isNotEmpty) {
        setState(() => _parentVaggaId = rootMeta["vagga_uid"].toString());
      } else {
        final resolvedVagga = await _resolveVaggaUid(targetUid);
        if (resolvedVagga != null) {
          setState(() => _parentVaggaId = resolvedVagga);
          mergedData["resolved_vagga_uid"] =
              resolvedVagga; // Disimpan biar persist
        }
      }

      if (!mounted) return;

      // 7. Navigasi dengan Animasi Arah yang Benar
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: '/sutta/$targetUid'),
          pageBuilder: (_, __, ___) => SuttaDetail(
            uid: targetUid,
            lang: targetLang,
            textData: mergedData,
            openedFromSuttaDetail: true,
            originalSuttaUid: null,
          ),
          transitionsBuilder: (_, animation, __, child) {
            // Kalau Prev: Slide dari Kiri (-1), Kalau Next: Slide dari Kanan (1)
            final offsetBegin = isPrevious
                ? const Offset(-1, 0)
                : const Offset(1, 0);
            final tween = Tween(
              begin: offsetBegin,
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeInOut));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );

      if (targetLang == "en") _showEnFallbackBanner();
    } catch (e) {
      // Fallback ke Suttaplex kalau gagal
      _replaceToRoute(
        '/suttaplex/$targetUid',
        slideFromLeft: isPrevious, // Animasi fallback juga ngikutin arah
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Trigger Singkat (Tinggal panggil ini di tombol)
  void _goToPrevSutta() => _navigateToSutta(isPrevious: true);
  void _goToNextSutta() => _navigateToSutta(isPrevious: false);

  void _updateParentAnchorOnMove(
    Map<String, dynamic>? root,
    Map<String, dynamic>? suttaplex,
  ) {
    final prev = root?["previous"] ?? suttaplex?["previous"];
    final next = root?["next"] ?? suttaplex?["next"];

    // ✅ CEK LENGKAP: null, Map kosong, uid null, ATAU uid string kosong
    _isFirst =
        prev == null ||
        (prev is Map &&
            (prev.isEmpty ||
                prev["uid"] == null ||
                prev["uid"].toString().trim().isEmpty));
    _isLast =
        next == null ||
        (next is Map &&
            (next.isEmpty ||
                next["uid"] == null ||
                next["uid"].toString().trim().isEmpty));

    setState(() {});
  }

  void _showEnFallbackBanner() {
    // MaterialBanner agar persisten
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
          "Bahasa Indonesia tidak tersedia, menampilkan versi Inggris.",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SuttaDetail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Kalau textData berubah, parse ulang
    if (widget.textData != oldWidget.textData) {
      setState(() {
        _htmlSegments.clear();
        _tocList.clear();

        // segmented
        final hasTranslationMap =
            widget.textData?["translation_text"] is Map &&
            (widget.textData!["translation_text"] as Map).isNotEmpty;
        final keysOrder = widget.textData?["keys_order"] is List
            ? List<String>.from(widget.textData!["keys_order"])
            : (widget.textData?["segments"] as Map?)?.keys.toList() ?? [];

        final isSegmented = hasTranslationMap && keysOrder.isNotEmpty;

        if (!isSegmented) {
          // non‑segmented → parse HTML langsung
          String rawHtml = "";
          if (widget.textData?["translation_text"] is Map &&
              widget.textData!["translation_text"].containsKey("text")) {
            final transMap = Map<String, dynamic>.from(
              widget.textData!["translation_text"],
            );
            final sutta = NonSegmentedSutta.fromJson(transMap);
            rawHtml = HtmlUnescape().convert(sutta.text);
          } else if (widget.textData?["root_text"] is Map &&
              widget.textData!["root_text"].containsKey("text")) {
            final rootMap = Map<String, dynamic>.from(
              widget.textData!["root_text"],
            );
            final sutta = NonSegmentedSutta.fromJson(rootMap);
            rawHtml = HtmlUnescape().convert(sutta.text);
          }

          if (rawHtml.isNotEmpty) {
            _parseHtmlAndGenerateTOC(rawHtml);
          }
        }
        // kalau segmented, builder di build() udah handle sendiri
      });
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
            padding: const EdgeInsets.only(left: 0),
            child: Transform.translate(
              offset: const Offset(0, -6), // geser ke atas
              child: Text(
                "[note]", // teks superscript
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize * 0.5, // kecilkan biar mirip superscript
                ),
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

  // METHOD DI DALAM _SuttaDetailState
  SuttaHeaderConfig _getHeaderConfig(String key, {bool isPaliOnly = false}) {
    // 1. Bersihkan Verse Num
    final verseNumRaw = key.contains(":") ? key.split(":").last : key;
    final verseNum = verseNumRaw.trim();

    // 2. Deteksi Header
    final isH1 = verseNum == "0.1";
    final isH2 = verseNum == "0.2";
    final headerRegex = RegExp(r'^(?:\d+\.)*0(?:\.\d+)*$');
    final isHeader = headerRegex.hasMatch(verseNum);
    final isH3 = isHeader && !isH1 && !isH2;

    // 3. Tentukan Warna Pali (Sesuai Tema)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paliBodyColor = isDark ? Colors.amber[200]! : Colors.deepOrange[900]!;
    final paliColor = isPaliOnly ? Colors.black : paliBodyColor;

    // 4. Setup Style & Padding
    TextStyle paliStyle, transStyle;
    double topPadding, bottomPadding;

    if (isH1) {
      topPadding = 16.0; // Diskon dari 40
      bottomPadding = 16.0;
      paliStyle = TextStyle(
        fontSize: _fontSize * 1.6,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        height: 1.2,
        letterSpacing: -0.5,
      );
      transStyle = paliStyle; // H1 Trans sama style-nya
    } else if (isH2) {
      topPadding = 8.0;
      bottomPadding = 12.0;
      paliStyle = TextStyle(
        fontSize: _fontSize * 1.4,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        height: 1.3,
      );
      transStyle = paliStyle;
    } else if (isH3) {
      topPadding = 16.0;
      bottomPadding = 8.0;
      paliStyle = TextStyle(
        fontSize: _fontSize * 1.2,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        height: 1.4,
      );
      transStyle = paliStyle;
    } else {
      topPadding = 0.0;
      bottomPadding = 8.0; // Default spacing antar ayat
      paliStyle = TextStyle(
        fontSize: _fontSize * 0.9,
        fontWeight: FontWeight.w500,
        color: paliColor, // <-- Pake warna dynamic tadi
        height: 1.5,
      );
      transStyle = TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.normal,
        color: Colors.black,
        height: 1.5,
      );
    }

    return SuttaHeaderConfig(
      isH1: isH1,
      isH2: isH2,
      isH3: isH3,
      verseNum: verseNum,
      paliStyle: paliStyle,
      transStyle: transStyle,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
    );
  }

  // Method Utama untuk ngerender 1 Item Segmented
  Widget _buildSegmentedItem(
    BuildContext context,
    int index,
    String key,
    Map<String, String> paliSegs,
    Map<String, String> translationSegs,
    Map<String, String> commentarySegs,
  ) {
    // 1. Ambil Config Header (Pake fungsi step 1)
    final config = _getHeaderConfig(key);

    // 2. Ambil Content
    var pali = paliSegs[key] ?? "";
    if (pali.trim().isEmpty) pali = "... pe ...";

    var trans = translationSegs[key] ?? "";
    final isTransEmpty = trans.trim().isEmpty;
    final comm = commentarySegs[key] ?? "";

    // 3. Logic Search Match Count (Global offset buat highlighting)
    final query = _searchController.text.trim();
    final int paliMatchCount = (query.length >= 2 && _cachedSearchRegex != null)
        ? _cachedSearchRegex!.allMatches(pali.toLowerCase()).length
        : 0;

    // 4. Return Widget Berdasarkan ViewMode
    // Kita passing data yg udah "mateng" ke sub-widget
    switch (_viewMode) {
      case ViewMode.translationOnly:
        return _buildLayoutTransOnly(config, index, trans, isTransEmpty, comm);
      case ViewMode.lineByLine:
        return _buildLayoutLineByLine(
          config,
          index,
          pali,
          trans,
          isTransEmpty,
          comm,
          paliMatchCount,
        );
      case ViewMode.sideBySide:
        return _buildLayoutSideBySide(
          config,
          index,
          pali,
          trans,
          isTransEmpty,
          comm,
          paliMatchCount,
        );
    }
  }

  // Layout 1: Translation Only
  Widget _buildLayoutTransOnly(
    SuttaHeaderConfig config,
    int index,
    String trans,
    bool isTransEmpty,
    String comm,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: config.topPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerseNumber(config),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    children: _highlightText(
                      isTransEmpty ? "... [pe] ..." : trans,
                      isTransEmpty
                          ? config.transStyle.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            )
                          : config.transStyle,
                      index,
                      0, // Start match index 0 karena gak ada Pali sebelumnya
                    ),
                  ),
                  if (comm.isNotEmpty)
                    _buildCommentSpan(
                      context,
                      comm,
                      config.transStyle.fontSize ?? _fontSize,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Layout 2: Line by Line (Atas Bawah)
  Widget _buildLayoutLineByLine(
    SuttaHeaderConfig config,
    int index,
    String pali,
    String trans,
    bool isTransEmpty,
    String comm,
    int paliMatchCount,
  ) {
    // Logic style khusus utk "... pe ..." (Pali ellipsis)
    final isPe =
        pali == "... pe ..." && !config.isH1 && !config.isH2 && !config.isH3;
    final finalPaliStyle = config.paliStyle.copyWith(
      fontStyle: isPe ? FontStyle.italic : FontStyle.normal,
      color: isPe ? Colors.grey : config.paliStyle.color,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: config.topPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerseNumber(config),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Pali
                Text.rich(
                  TextSpan(
                    children: _highlightText(pali, finalPaliStyle, index, 0),
                  ),
                ),
                const SizedBox(height: 4),
                // Baris Trans
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        children: _highlightText(
                          isTransEmpty ? "... [dst] ..." : trans,
                          isTransEmpty
                              ? config.transStyle.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                )
                              : config.transStyle,
                          index,
                          paliMatchCount, // Offset match count setelah Pali
                        ),
                      ),
                      if (comm.isNotEmpty)
                        _buildCommentSpan(
                          context,
                          comm,
                          config.transStyle.fontSize ?? _fontSize,
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
  }

  // Layout 3: Side by Side (Kiri Kanan)
  Widget _buildLayoutSideBySide(
    SuttaHeaderConfig config,
    int index,
    String pali,
    String trans,
    bool isTransEmpty,
    String comm,
    int paliMatchCount,
  ) {
    final isPe =
        pali == "... pe ..." && !config.isH1 && !config.isH2 && !config.isH3;
    final finalPaliStyle = config.paliStyle.copyWith(
      fontStyle: isPe ? FontStyle.italic : FontStyle.normal,
      color: isPe ? Colors.grey : config.paliStyle.color,
    );

    // Kalau Header (H1/H2/H3), layoutnya balik ke Atas-Bawah biar ga aneh
    if (config.isH1 || config.isH2 || config.isH3) {
      // Reuse layout line-by-line khusus buat header
      return _buildLayoutLineByLine(
        config,
        index,
        pali,
        trans,
        isTransEmpty,
        comm,
        paliMatchCount,
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: config.topPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KIRI: Pali + No Ayat
              Expanded(
                flex: 1,
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      // No Ayat Superscript Manual
                      WidgetSpan(
                        child: Transform.translate(
                          offset: const Offset(0, -6),
                          child: SelectionContainer.disabled(
                            child: Text(
                              config.verseNum,
                              textScaleFactor: 0.7,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: " "),
                      ..._highlightText(pali, finalPaliStyle, index, 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // KANAN: Trans + Comm
              Expanded(
                flex: 2,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        children: _highlightText(
                          isTransEmpty ? "... [pe] ..." : trans,
                          isTransEmpty
                              ? config.transStyle.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                )
                              : config.transStyle,
                          index,
                          paliMatchCount,
                        ),
                      ),
                      if (comm.isNotEmpty)
                        _buildCommentSpan(
                          context,
                          comm,
                          config.transStyle.fontSize ?? _fontSize,
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
  }

  // Widget kecil buat Nomor Ayat biar konsisten
  Widget _buildVerseNumber(SuttaHeaderConfig config) {
    return SelectionContainer.disabled(
      child: Padding(
        padding: EdgeInsets.only(top: config.isH1 || config.isH2 ? 6.0 : 0.0),
        child: Text(
          config.verseNum,
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. CEK DATA KOSONG
    if (widget.textData == null || widget.textData!.isEmpty) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final allow = await _handleBackReplace();
          if (allow) Navigator.pop(context, result);
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(title: Text("${widget.uid} [${widget.lang}]")),
          body: const Center(child: Text("Teks tidak tersedia")),
        ),
      );
    }

    final bool isSegmented = widget.textData!["segmented"] == true;

    // 2. PERSIAPAN DATA (Map & Keys)
    final Map<String, String> paliSegs;
    final Map<String, String> translationSegs;
    final Map<String, String> commentarySegs;
    final List<String> keysOrder;

    if (isSegmented) {
      // ... Logic parsing data Segmented lu yang lama ...
      paliSegs = (widget.textData!["root_text"] is Map)
          ? (widget.textData!["root_text"] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : {};
      translationSegs = (widget.textData!["translation_text"] is Map)
          ? (widget.textData!["translation_text"] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : {};
      commentarySegs = (widget.textData!["comment_text"] is Map)
          ? (widget.textData!["comment_text"] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : {};

      if (widget.textData!["keys_order"] is List) {
        keysOrder = List<String>.from(widget.textData!["keys_order"]);
      } else {
        // Fallback generate keys manually
        final metadataKeys = {
          'previous',
          'next',
          'author_uid',
          'vagga_uid',
          'lang',
          'title',
          'acronym',
          'text',
        };
        final source = translationSegs.isNotEmpty ? translationSegs : paliSegs;
        keysOrder = source.keys
            .where((k) => !metadataKeys.contains(k))
            .toList();
      }
    } else {
      paliSegs = {};
      translationSegs = {};
      commentarySegs = {};
      keysOrder = [];
    }

    // 3. MENENTUKAN ISI BODY
    Widget body;

    // CASE A: SEGMENTED (Pakai Unified Builder yang kita buat)
    if (isSegmented) {
      body = SelectionArea(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            80,
          ), // Bottom padding buat FAB
          itemCount: keysOrder.length,
          itemBuilder: (context, index) {
            return _buildSegmentedItem(
              context,
              index,
              keysOrder[index],
              paliSegs,
              translationSegs,
              commentarySegs,
            );
          },
        ),
      );
    }
    // CASE B: NON-SEGMENTED HTML
    else if ((widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"))) {
      // Parse HTML jika belum
      if (_htmlSegments.isEmpty) {
        String rawHtml = "";
        if (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) {
          // ... logic unescape html trans ...
          final transMap = Map<String, dynamic>.from(
            widget.textData!["translation_text"],
          );
          rawHtml = HtmlUnescape().convert(
            NonSegmentedSutta.fromJson(transMap).text,
          );
        } else if (widget.textData!["root_text"] is Map) {
          // ... logic unescape html root ...
          final rootMap = Map<String, dynamic>.from(
            widget.textData!["root_text"],
          );
          rawHtml = HtmlUnescape().convert(
            NonSegmentedSutta.fromJson(rootMap).text,
          );
        }
        if (rawHtml.isNotEmpty) _parseHtmlAndGenerateTOC(rawHtml);
      }

      body = SelectionArea(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: _htmlSegments.length,
          itemBuilder: (context, index) {
            String content = _htmlSegments[index];
            // Highlight Logic untuk HTML
            if (_searchController.text.length >= 2 &&
                _cachedSearchRegex != null) {
              int localMatchCounter = 0;
              content = content.replaceAllMapped(_cachedSearchRegex!, (match) {
                bool isActive = false;
                if (_allMatches.isNotEmpty &&
                    _currentMatchIndex < _allMatches.length) {
                  final activeMatch = _allMatches[_currentMatchIndex];
                  isActive =
                      (activeMatch.listIndex == index &&
                      activeMatch.matchIndexInSeg == localMatchCounter);
                }
                localMatchCounter++;
                String bgColor = isActive ? "orange" : "yellow";
                return "<span style='background-color: $bgColor; color: black; font-weight: bold'>${match.group(0)}</span>";
              });
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Html(
                data: content,
                style: {
                  "body": Style(
                    fontSize: FontSize(_fontSize),
                    lineHeight: LineHeight(1.6),
                    margin: Margins.only(left: 10, right: 10),
                    //textAlign: TextAlign.justify,
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
    // CASE C: PALI ONLY (Fallback Logic lama lu)
    else if (widget.textData!["root_text"] is Map &&
        !(widget.textData!["root_text"] as Map).containsKey("text")) {
      // Kita reuse logic segmented item aja biar gak repetitif!
      final paliOnlyMap = (widget.textData!["root_text"] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      final paliKeys = widget.textData!["keys_order"] is List
          ? List<String>.from(widget.textData!["keys_order"])
          : paliOnlyMap.keys.toList();

      body = SelectionArea(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: paliKeys.length,
          itemBuilder: (context, index) {
            // Panggil _buildSegmentedItem dengan map kosong buat trans & comm
            return _buildSegmentedItem(
              context,
              index,
              paliKeys[index],
              paliOnlyMap,
              {},
              {},
            );
          },
        ),
      );
    }
    // CASE D: ERROR
    else {
      body = const Center(child: Text("Format data tidak dikenali"));
    }

    // 4. RETURN SCAFFOLD DENGAN FAB CLEAN
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final allow = await _handleBackReplace();
        if (allow) Navigator.pop(context, result);
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("${widget.uid} [${widget.lang}]"),
          actions: const [SizedBox.shrink()],
        ),
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
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              if (_itemScrollController.isAttached) {
                                _itemScrollController.scrollTo(
                                  index: item['index'],
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
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
        body: Stack(
          children: [
            body,
            // Tombol TOC Overlay
            if (_tocList.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
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
            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildFloatingActions(isSegmented), // <-- BERSIH!
      ),
    );
  }

  // ✅ 1. BUILDER UTAMA TOMBOL (FAB ROW)
  Widget _buildFloatingActions(bool isSegmented) {
    // Helper kecil biar gak repetitif nulis warna
    Color getBgColor(bool isDisabled) => isDisabled
        ? (Colors.grey[300]?.withValues(alpha: 0.9) ?? Colors.grey)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.9);

    Color getFgColor(bool isDisabled) =>
        isDisabled ? Colors.grey : Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // TOMBOL PREV
        FloatingActionButton(
          heroTag: "btn_prev",
          backgroundColor: getBgColor(_isFirst || _isLoading),
          foregroundColor: getFgColor(_isFirst || _isLoading),
          onPressed: _isFirst || _isLoading ? null : _goToPrevSutta,
          child: const Icon(Icons.arrow_back_ios_new),
        ),
        const SizedBox(width: 12),

        // TOMBOL PENCARIAN
        FloatingActionButton(
          heroTag: "btn_cari",
          backgroundColor: (_isLoading || _htmlSegments.isNotEmpty)
              ? (Colors.grey[300]?.withValues(alpha: 0.9) ?? Colors.grey)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
          foregroundColor: (_isLoading || _htmlSegments.isNotEmpty)
              ? Colors.grey
              : Colors.white,
          // Kalau HTML mode (non-segmented), disable search (sesuai kode lama)
          onPressed: (_htmlSegments.isNotEmpty) ? null : _openSearchModal,
          child: const Icon(Icons.search),
        ),
        const SizedBox(width: 12),

        // TOMBOL SUTTAPLEX
        FloatingActionButton(
          heroTag: "btn_suttaplex",
          backgroundColor: _isLoading
              ? (Colors.grey[300]?.withValues(alpha: 0.9) ?? Colors.grey)
              : Colors.deepOrange.withValues(alpha: 0.9),
          foregroundColor: _isLoading ? Colors.grey : Colors.white,
          onPressed: _isLoading ? null : _openSuttaplexModal,
          child: const Icon(Icons.menu_book),
        ),
        const SizedBox(width: 12),

        // TOMBOL TAMPILAN (VIEW MODE)
        FloatingActionButton(
          heroTag: "btn_tampilan",
          backgroundColor: getBgColor(_isLoading),
          foregroundColor: getFgColor(_isLoading),
          onPressed: () => _openViewSettingsModal(isSegmented),
          child: const Icon(Icons.visibility),
        ),
        const SizedBox(width: 12),

        // TOMBOL NEXT
        FloatingActionButton(
          heroTag: "btn_next",
          backgroundColor: getBgColor(_isLast || _isLoading),
          foregroundColor: getFgColor(_isLast || _isLoading),
          onPressed: _isLast || _isLoading ? null : _goToNextSutta,
          child: const Icon(Icons.arrow_forward_ios),
        ),
      ],
    );
  }

  // ✅ 2. LOGIC MODAL SEARCH (NO OVERLAY + COUNTER)
  void _openSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent, // Fitur "No Overlay"
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                  boxShadow: const [
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
                              hintText: "Cari kata (min. 2 huruf)...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.backspace_outlined),
                                onPressed: () {
                                  _searchController.clear();
                                  if (mounted)
                                    setState(() => _allMatches.clear());
                                  if (mounted) setSheetState(() {});
                                },
                              ),
                            ),
                            onChanged: (val) {
                              if (_debounce?.isActive ?? false)
                                _debounce!.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  if (!mounted) return;
                                  if (val.trim().length >= 2) {
                                    _performSearch(val);
                                  } else {
                                    setState(() => _allMatches.clear());
                                  }
                                  if (mounted) setSheetState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Counter & Navigasi Search
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _allMatches.isEmpty
                              ? "0 hasil"
                              : "${_currentMatchIndex + 1} dari ${_allMatches.length} kata",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward),
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      _jumpToResult(_currentMatchIndex - 1);
                                      setSheetState(() {});
                                    },
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      _jumpToResult(_currentMatchIndex + 1);
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
      // Auto Clear pas tutup
      _debounce?.cancel();
      setState(() {
        _searchController.clear();
        _allMatches.clear();
      });
    });
  }

  // ✅ 3. LOGIC MODAL SUTTAPLEX
  void _openSuttaplexModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Suttaplex(
          uid: widget.uid,
          onSelect: (newUid, lang, authorUid, textData) {
            _replaceToSutta(
              newUid,
              lang,
              authorUid: authorUid,
              segmented: textData["segmented"] == true,
              textData: textData,
            );
          },
        ),
      ),
    );
  }

  // ✅ 4. LOGIC MODAL TAMPILAN (VIEW SETTINGS)
  void _openViewSettingsModal(bool isSegmented) {
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
                          onPressed: () =>
                              setState(() => _viewMode = ViewMode.lineByLine),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text("Atas-bawah"),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _viewMode = ViewMode.sideBySide),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text("Kiri-kanan"),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(
                            () => _viewMode = ViewMode.translationOnly,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text("Tanpa Pāli"),
                          ),
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
                        () => _fontSize = (_fontSize - 2).clamp(12.0, 30.0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Reset"),
                      onPressed: () => setState(() => _fontSize = 16.0),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.text_increase),
                      label: const Text("Besar"),
                      onPressed: () => setState(
                        () => _fontSize = (_fontSize + 2).clamp(12.0, 30.0),
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
  }
}

// Helper Class buat nyimpen alamat kata
class SearchMatch {
  final int listIndex; // Index Baris (Segment)
  final int matchIndexInSeg; // Urutan kata di dalam baris itu (ke-1, ke-2, dst)

  SearchMatch(this.listIndex, this.matchIndexInSeg);
}

// Struktur hasil cek
/*class _Avail {
  final String targetLang; // "id" | "en" | "pli"
  final bool hasTranslation; // true untuk id/en
  const _Avail(this.targetLang, this.hasTranslation);
}*/

// Helper Class kecil biar return-nya rapi (bisa taruh di paling bawah file atau file terpisah)
class SuttaHeaderConfig {
  final bool isH1;
  final bool isH2;
  final bool isH3;
  final String verseNum;
  final TextStyle paliStyle;
  final TextStyle transStyle;
  final double topPadding;
  final double bottomPadding;

  SuttaHeaderConfig({
    required this.isH1,
    required this.isH2,
    required this.isH3,
    required this.verseNum,
    required this.paliStyle,
    required this.transStyle,
    required this.topPadding,
    required this.bottomPadding,
  });
}
