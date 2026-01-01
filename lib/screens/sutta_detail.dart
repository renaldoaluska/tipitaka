import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipitaka/screens/menu_page.dart';
import 'package:tipitaka/screens/suttaplex.dart';
import 'package:tipitaka/services/sutta.dart';
import 'package:tipitaka/styles/nikaya_style.dart';
import '../core/theme/theme_manager.dart';
import '../models/sutta_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import '../services/history.dart';

enum ViewMode { translationOnly, lineByLine, sideBySide }

class SuttaDetail extends StatefulWidget {
  final String uid;
  final String lang;
  final Map<String, dynamic>? textData;

  final bool openedFromSuttaDetail;
  final String? originalSuttaUid;

  // ✅ Flag untuk tracking "entry point" (dari mana user masuk pertama kali)
  final String? entryPoint; // "menu_page" | "tematik" | "search" | null
  // ✅ 1. TAMBAH INI (Parameter pembawa pesan)
  final bool isNavigated;

  const SuttaDetail({
    super.key,
    required this.uid,
    required this.lang,
    required this.textData,
    this.openedFromSuttaDetail = false,
    this.originalSuttaUid,
    this.entryPoint, // Default null = dari SuttaDetail sendiri (via book button)// ✅ 2. TAMBAH INI (Default false buat yg pertama dibuka)
    this.isNavigated = false,
  });

  @override
  State<SuttaDetail> createState() => _SuttaDetailState();
}

enum SuttaSnackType {
  translatorFallback,
  firstText,
  lastText,
  disabledForTematik, // ✅ TAMBAH INI
}

enum ReaderTheme { light, light2, sepia, dark, dark2 }

class _SuttaDetailState extends State<SuttaDetail> {
  // --- NAV CONTEXT & STATE ---
  late bool _hasNavigatedBetweenSuttas; // ✅ 3. Ubah jadi 'late' (hapus = false)
  String? _parentVaggaId;

  bool _isFirst = false;
  bool _isLast = false;
  bool _isLoading = false;
  bool _connectionError = false;

  bool _isHtmlParsed = false;
  RegExp? _cachedSearchRegex;
  ViewMode _viewMode = ViewMode.lineByLine;
  double _fontSize = 16.0;

  // ✅ Variabel info Footer
  String _footerInfo = "";

  // --- STATE PENCARIAN ---
  final TextEditingController _searchController = TextEditingController();
  final List<SearchMatch> _allMatches = [];
  int _currentMatchIndex = 0;
  Timer? _debounce;

  // --- SCROLL CONTROLLER ---
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Default awal kita set Light dulu (cuma placeholder)
  // Nanti di _loadPreferences kita timpa sesuai logika kamu
  ReaderTheme _readerTheme = ReaderTheme.light;

  // Helper biar kodingan di build bersih & sinkron sama ThemeManager
  Map<String, Color> get _themeColors {
    // 1. Ambil warna System HP (Buat UI App Bar & Drawer biar gak aneh)
    final systemScheme = Theme.of(context).colorScheme;
    final uiCardColor = systemScheme.surface;
    final uiIconColor = systemScheme.onSurface;

    // 2. Panggil ThemeManager buat nyontek warna background asli
    final tm = ThemeManager();

    switch (_readerTheme) {
      // --- TERANG 1 (Standard: Full ThemeManager) ---
      case ReaderTheme.light:
        final t = tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': t.colorScheme.onSurface, // ✅ Hitam (Standard)
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
        };

      // --- TERANG 2 (Soft: Bg ThemeManager, Teks Abu) ---
      case ReaderTheme.light2:
        final t = tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': const Color(0xFF424242), // ✨ Custom: Abu Tua Soft
          'note': Colors.grey[500]!,
          'card': uiCardColor,
          'icon': uiIconColor,
        };

      // --- SEPIA (Full Custom) ---
      case ReaderTheme.sepia:
        return {
          'bg': const Color(0xFFF4ECD8), // ✨ Custom: Krem
          'text': const Color(0xFF5D4037), // ✨ Custom: Coklat
          'note': const Color(0xFF8D6E63),
          'card': uiCardColor,
          'icon': uiIconColor,
        };

      // --- GELAP 1 (Standard: Full ThemeManager) ---
      case ReaderTheme.dark:
        final t = tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': t.colorScheme.onSurface, // ✅ Putih (Standard)
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
        };

      // --- GELAP 2 (Soft: Bg ThemeManager, Teks Abu) ---
      case ReaderTheme.dark2:
        final t = tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': const Color(0xFFB0BEC5), // ✨ Custom: Abu Kebiruan
          'note': Colors.grey[600]!,
          'card': uiCardColor,
          'icon': uiIconColor,
        };
    }
  }

  // --- DAFTAR ISI ---
  final List<Map<String, dynamic>> _tocList = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _hasNavigatedBetweenSuttas = widget.isNavigated;
    _loadPreferences();

    final bool isSegmented = widget.textData?["segmented"] == true;
    if (isSegmented &&
        widget.textData != null &&
        widget.textData!["keys_order"] is List) {
      _generateTOC();
    }

    _parseHtmlIfNeeded();
    _initNavigationContext();

    _saveToHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearMaterialBanners();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 1. Coba ambil settingan user
    int? savedIndex = prefs.getInt('reader_theme_index');

    // 2. Tentukan tema
    ReaderTheme targetTheme;

    if (savedIndex != null) {
      // ✅ KASUS A: User udah pernah setting, ikutin maunya user
      if (savedIndex >= 0 && savedIndex < ReaderTheme.values.length) {
        targetTheme = ReaderTheme.values[savedIndex];
      } else {
        targetTheme = ReaderTheme.light;
      }
    } else {
      // ✅ KASUS B: Belum pernah setting (Default)
      // Cek tema HP sekarang (Gelap/Terang)
      final brightness = Theme.of(context).brightness;

      if (brightness == Brightness.dark) {
        targetTheme = ReaderTheme.dark; // Kalau HP gelap -> Mode Baca Gelap
      } else {
        targetTheme = ReaderTheme.light; // Kalau HP terang -> Mode Baca Terang
      }
    }

    setState(() {
      _fontSize = prefs.getDouble('sutta_font_size') ?? 16.0;
      final savedMode = prefs.getInt('sutta_view_mode');
      if (savedMode != null && savedMode < ViewMode.values.length) {
        _viewMode = ViewMode.values[savedMode];
      }

      // Update tema baca
      _readerTheme = targetTheme;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sutta_font_size', _fontSize);
    await prefs.setInt('sutta_view_mode', _viewMode.index);

    // Simpan index enum
    await prefs.setInt('reader_theme_index', _readerTheme.index);
  }

  bool get _isRootOnly {
    final trans = widget.textData?["translation_text"];
    return trans == null || (trans is Map && trans.isEmpty);
  }

  void _generateTOC() {
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

        if (title.isEmpty) title = "Bagian $verseNum";

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
      setState(() {});
      return;
    }

    final lowerQuery = query.toLowerCase();
    _cachedSearchRegex = RegExp(
      RegExp.escape(lowerQuery),
      caseSensitive: false,
    );

    final bool isSegmented = widget.textData!["segmented"] == true;

    if (isSegmented) {
      final translationSegs = (widget.textData!["translation_text"] is Map)
          ? (widget.textData!["translation_text"] as Map)
          : {};
      final rootSegs = (widget.textData!["root_text"] is Map)
          ? (widget.textData!["root_text"] as Map)
          : {};

      final keysOrder = widget.textData!["keys_order"] is List
          ? List<String>.from(widget.textData!["keys_order"])
          : [];

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

      for (int i = 0; i < filteredKeys.length; i++) {
        final key = filteredKeys[i];

        final rootText = (rootSegs[key] ?? "").toString();
        final cleanRoot = rootText.replaceAll(RegExp(r'<[^>]*>'), '');
        final rootMatches = _cachedSearchRegex!
            .allMatches(cleanRoot.toLowerCase())
            .length;

        for (int m = 0; m < rootMatches; m++) {
          _allMatches.add(SearchMatch(i, m));
        }

        final transText = (translationSegs[key] ?? "").toString();
        final cleanTrans = transText.replaceAll(RegExp(r'<[^>]*>'), '');
        final transMatches = _cachedSearchRegex!
            .allMatches(cleanTrans.toLowerCase())
            .length;

        for (int m = 0; m < transMatches; m++) {
          _allMatches.add(SearchMatch(i, rootMatches + m));
        }
      }
    } else if (_htmlSegments.isNotEmpty) {
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

  void _jumpToResult(int index) {
    if (_allMatches.isEmpty) return;
    final maxIndex = _allMatches.length - 1;
    if (index < 0) {
      index = maxIndex;
    } else if (index > maxIndex) {
      index = 0;
    }

    if (index >= 0 && index < _allMatches.length) {
      _currentMatchIndex = index;
      final targetRow = _allMatches[_currentMatchIndex].listIndex;
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
        debugPrint('Error scrolling: $e');
      }
      setState(() {});
    }
  }

  final List<String> _htmlSegments = [];

  void _parseHtmlAndGenerateTOC(String rawHtml) {
    // ✅ 1. Ekstrak konten <footer> dan HAPUS dari rawHtml
    _footerInfo = "";
    try {
      final footerRegex = RegExp(
        r'<footer>(.*?)</footer>',
        caseSensitive: false,
        dotAll: true,
      );
      final match = footerRegex.firstMatch(rawHtml);
      if (match != null) {
        _footerInfo = match.group(1)?.trim() ?? "";
        // 🔥 HAPUS FOOTER DARI TEXT UTAMA BIAR GAK NONGOL
        rawHtml = rawHtml.replaceFirst(footerRegex, "");
      }
    } catch (e) {
      debugPrint("Gagal ekstrak footer: $e");
    }

    // 2. Parsing HTML "Pintar" (Memecah h1-6 DAN p)
    try {
      _tocList.clear();
      _htmlSegments.clear();
      if (rawHtml.trim().isEmpty) return;

      final RegExp blockRegex = RegExp(
        r'''<(h[1-6]|p)[^>]*>(.*?)<\/\1>''',
        caseSensitive: false,
        dotAll: true,
      );

      final matches = blockRegex.allMatches(rawHtml);
      int lastIndex = 0;

      for (final match in matches) {
        try {
          if (match.start > lastIndex) {
            String gap = rawHtml.substring(lastIndex, match.start);
            if (gap.trim().isNotEmpty) _htmlSegments.add(gap);
          }

          String fullTag = match.group(0) ?? "";
          String tagName = match.group(1)?.toLowerCase() ?? "";
          String content = match.group(2) ?? "";

          _htmlSegments.add(fullTag);

          if (tagName.startsWith("h")) {
            String levelStr = tagName.substring(1);
            String cleanTitle = content
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .trim();

            _tocList.add({
              "title": cleanTitle.isEmpty ? "Bagian" : cleanTitle,
              "index": _htmlSegments.length - 1,
              "type": int.tryParse(levelStr) ?? 3,
            });
          }

          lastIndex = match.end;
        } catch (e) {
          continue;
        }
      }

      if (lastIndex < rawHtml.length) {
        String tail = rawHtml.substring(lastIndex);
        if (tail.trim().isNotEmpty) _htmlSegments.add(tail);
      }

      if (_htmlSegments.isEmpty) {
        _htmlSegments.add(rawHtml);
      }
    } catch (e) {
      _htmlSegments.clear();
      _htmlSegments.add(rawHtml);
      _tocList.clear();
    }
  }

  String _injectSearchHighlights(
    String content,
    int listIndex,
    int startMatchCount,
  ) {
    if (_searchController.text.length < 2 || _cachedSearchRegex == null) {
      return content;
    }

    int localMatchCounter = 0;
    return content.replaceAllMapped(_cachedSearchRegex!, (match) {
      bool isActive = false;
      int globalMatchIndex = startMatchCount + localMatchCounter;
      if (_allMatches.isNotEmpty && _currentMatchIndex < _allMatches.length) {
        final activeMatch = _allMatches[_currentMatchIndex];
        isActive =
            (activeMatch.listIndex == listIndex &&
            activeMatch.matchIndexInSeg == globalMatchIndex);
      }
      localMatchCounter++;
      String bgColor = isActive ? "orange" : "yellow";
      return "<span style='background-color: $bgColor; color: black; font-weight: bold'>${match.group(0)}</span>";
    });
  }

  void _parseHtmlIfNeeded() {
    final isHtmlFormat =
        (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"));

    if (!isHtmlFormat || _isHtmlParsed) return;

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

  Future<void> _initNavigationContext() async {
    final root = widget.textData?["root_text"];
    if (root is Map) {
      _parentVaggaId =
          root["vagga_uid"]?.toString() ??
          widget.textData?["resolved_vagga_uid"]?.toString();

      if (_parentVaggaId == null) {
        final resolved = await _resolveVaggaUid(widget.uid);
        if (resolved != null && mounted) {
          setState(() {
            _parentVaggaId = resolved;
          });
        }
      }
      final prev = root["previous"];
      final next = root["next"];

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
    } else {
      _isFirst = true;
      _isLast = true;
    }

    setState(() {});
  }

  // ✅ HELPER BARU: SATU PINTU UNTUK SEMUA NAVIGASI MENU
  // Fungsi ini otomatis ngitung Acronym "Bu Pj" dkk sebelum buka halaman.
  void _openMenuPage(String targetUid) {
    String derivedAcronym = "";
    final uid = targetUid.toLowerCase().trim();

    // --- FILTER 1: KHUSUS VINAYA (Manual Mapping) ---
    if (uid.startsWith("pli-tv-")) {
      if (uid.contains("bu-vb-pj")) {
        derivedAcronym = "Bu Pj";
      } else if (uid.contains("bu-vb-ss")) {
        derivedAcronym = "Bu Ss";
      } else if (uid.contains("bu-vb-ay")) {
        derivedAcronym = "Bu Ay";
      } else if (uid.contains("bu-vb-np")) {
        derivedAcronym = "Bu Np";
      } else if (uid.contains("bu-vb-pc")) {
        derivedAcronym = "Bu Pc";
      } else if (uid.contains("bu-vb-pd")) {
        derivedAcronym = "Bu Pd";
      } else if (uid.contains("bu-vb-sk")) {
        derivedAcronym = "Bu Sk";
      } else if (uid.contains("bu-vb-as")) {
        derivedAcronym = "Bu As";
      } else if (uid.contains("bi-vb-pj")) {
        derivedAcronym = "Bi Pj";
      } else if (uid.contains("bi-vb-ss")) {
        derivedAcronym = "Bi Ss";
      } else if (uid.contains("bi-vb-np")) {
        derivedAcronym = "Bi Np";
      } else if (uid.contains("bi-vb-pc")) {
        derivedAcronym = "Bi Pc";
      } else if (uid.contains("bi-vb-pd")) {
        derivedAcronym = "Bi Pd";
      } else if (uid.contains("bi-vb-sk")) {
        derivedAcronym = "Bi Sk";
      } else if (uid.contains("bi-vb-as")) {
        derivedAcronym = "Bi As";
      } else if (uid.contains("kd")) {
        derivedAcronym = "Kd";
      } else if (uid.contains("pvr")) {
        derivedAcronym = "Pvr";
      } else if (uid.contains("bu-pm")) {
        derivedAcronym = "Bu";
      } else if (uid.contains("bi-pm")) {
        derivedAcronym = "Bi";
      }
    }
    // --- FILTER 2: 4 NIKAYA UTAMA ---
    else if (uid.startsWith("dn") ||
        uid.startsWith("mn") ||
        uid.startsWith("sn") ||
        uid.startsWith("an")) {
      if (uid.length >= 2) {
        derivedAcronym = uid.substring(0, 2).toUpperCase();
      }
    }
    // --- FILTER 3: KHUDDAKA & LAINNYA ---
    else {
      // 🔥 FIX: Regex yang lebih robust untuk handle berbagai format
      // Misal: "tha-ap-1.1" → "tha-ap"
      //        "thag-1-upalivagga" → "thag"
      //        "thig-2.1" → "thig"
      final match = RegExp(r'^([a-z]+(?:-[a-z]+)?)').firstMatch(uid);
      if (match != null) {
        String raw = match.group(1)!.replaceAll("-", " ").trim();
        derivedAcronym = raw
            .split(" ")
            .map(
              (str) =>
                  str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : "",
            )
            .join(" ");
      }
    }

    // 🔥 NORMALIZE hasilnya buat konsistensi
    derivedAcronym = normalizeNikayaAcronym(derivedAcronym);

    debugPrint("🚀 [OPEN MENU] UID: $targetUid → ACRONYM: '$derivedAcronym'");

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/vagga/$targetUid'),
        builder: (_) => MenuPage(uid: targetUid, parentAcronym: derivedAcronym),
      ),
    );
  }

  Future<bool> _handleBackReplace() async {
    // 1. Resolve Parent Vagga (Logika Backend)
    if (_parentVaggaId == null) {
      final resolved = await _resolveVaggaUid(widget.uid);
      if (mounted && resolved != null) {
        setState(() {
          _parentVaggaId = resolved;
        });
      }
    }

    if (!mounted) return false;

    // 2. Tampilkan Dialog Konfirmasi (UI Baru)
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Judul dengan Icon
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  "Sudahi sesi baca?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Anda akan kembali ke menu utama dan riwayat navigasi saat ini akan direset.",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),

              // ✅ KOTAK TIPS PINTAR
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Warna background tipis banget biar gak norak
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: "Ingin ganti penerjemah? Gunakan tombol ",
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Icon(
                                  Icons.translate_rounded, // Icon Buku
                                  size: 16,
                                  // ✅ WARNA OTOMATIS (Hitam di Light, Putih di Dark)
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const TextSpan(
                              text: " di menu bawah tanpa perlu keluar.",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Batal"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),

                      // ✅ GANTI JADI INI:
                      // Pake 'primary' biar warnanya Oren ngikut tema aplikasi
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text("Keluar"),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    // Cek hasil dialog
    if (shouldLeave != true) return false;
    if (!mounted) return false;

    // ---------------------------------------------------------
    // 🔥 LOGIC NAVIGASI UTAMA (Sesuai kode sebelumnya)
    // ---------------------------------------------------------

    // SKENARIO 1: Belum pindah-pindah sutta, langsung pop aja
    if (!_hasNavigatedBetweenSuttas) {
      return true;
    }

    // SKENARIO 2: Udah navigasi jauh, kita reset stack-nya

    // A. Reset sampai Home
    Navigator.of(context).popUntil((route) => route.isFirst);

    // B. Buka ulang Menu Page (Vagga) kalau entry point-nya dari Menu
    if (widget.entryPoint == "menu_page") {
      final rootPrefix = widget.uid.replaceAll(RegExp(r'\d.*$'), '');
      if (rootPrefix.isNotEmpty && rootPrefix != _parentVaggaId) {
        _openMenuPage(rootPrefix);
      }
      if (_parentVaggaId != null) {
        _openMenuPage(_parentVaggaId!);
      }
    }

    // C. Tampilin Modal Suttaplex lagi (Biar user gak bingung tiba-tiba ilang)
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        settings: RouteSettings(name: '/suttaplex/${widget.uid}'),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: Suttaplex(
                        uid: widget.uid,
                        sourceMode: "sutta_detail",
                        initialData:
                            widget.textData?["suttaplex"]
                                as Map<String, dynamic>?,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    return false; // Kita handle navigasi manual, jadi return false
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
    setState(() {
      _isLoading = true;
      _connectionError = false;
    });

    try {
      final data =
          textData ??
          await SuttaService.fetchFullSutta(
            uid: newUid,
            authorUid: authorUid,
            lang: lang,
            segmented: segmented,
            siteLanguage: "id",
          );

      final Map<String, dynamic> mergedData;

      if (textData != null) {
        mergedData = data;
      } else {
        mergedData = {...data, "suttaplex": widget.textData?["suttaplex"]};
      }

      await _processVaggaTracking(mergedData, newUid);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: '/sutta/$newUid'),
          pageBuilder: (_, _, _) => SuttaDetail(
            uid: newUid,
            lang: lang,
            textData: mergedData,
            openedFromSuttaDetail: true,
            originalSuttaUid: null,
            entryPoint: widget.entryPoint, // ✅ Forward entry point
          ),
          transitionsBuilder: (_, animation, _, child) {
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
    } catch (e) {
      debugPrint("❌ Error _replaceToSutta: $e");
      if (e is SocketException || e.toString().contains("SocketException")) {
        if (mounted) setState(() => _connectionError = true);
      } else {
        _replaceToRoute('/suttaplex/$newUid', slideFromLeft: slideFromLeft);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _resolveVaggaUid(String suttaUid) async {
    try {
      final regex = RegExp(r'^([a-z]+(?:-[a-z]+)?)(\d+)(?:\.(\d+))?');
      final match = regex.firstMatch(suttaUid.toLowerCase());

      if (match == null) {
        return null;
      }

      final collection = match.group(1)!;
      final bookNum = int.parse(match.group(2)!);
      final suttaNum = match.group(3) != null
          ? int.parse(match.group(3)!)
          : null;

      String currentParent = collection;
      String? lastValidParent;

      for (int level = 0; level < 5; level++) {
        final menuData = await SuttaService.fetchMenu(
          currentParent,
          language: "id",
        );
        if (menuData is! List || menuData.isEmpty) break;

        final root = menuData[0];
        final children = root["children"] as List?;
        if (children == null || children.isEmpty) {
          if (currentParent != collection) {
            lastValidParent = currentParent;
          }
          break;
        }

        String? nextParent;

        for (var child in children) {
          final childUid = child["uid"]?.toString() ?? "";
          final rangeStr = child["child_range"]?.toString() ?? "";

          if (rangeStr.isEmpty) continue;

          final nums = RegExp(
            r'(\d+)',
          ).allMatches(rangeStr).map((m) => int.parse(m.group(1)!)).toList();

          if (nums.isEmpty) continue;

          bool isMatch = false;

          if (level == 0 && (collection == 'sn' || collection == 'an')) {
            int start = nums.first;
            int end = nums.last;
            if (bookNum >= start && bookNum <= end) isMatch = true;
          } else if (nums.length == 2 && suttaNum == null) {
            int start = nums[0];
            int end = nums[1];
            if (bookNum >= start && bookNum <= end) isMatch = true;
          } else if (nums.length == 3 && suttaNum != null) {
            int rangeBook = nums[0];
            int start = nums[1];
            int end = nums[2];

            if (rangeBook == bookNum && suttaNum >= start && suttaNum <= end) {
              isMatch = true;
            }
          } else if (nums.length == 1 && suttaNum == null) {
            if (nums.first == bookNum &&
                childUid.contains(bookNum.toString())) {
              isMatch = true;
            }
          } else if (nums.length == 2 && suttaNum != null) {
            if (childUid.contains('$collection$bookNum')) {
              int start = nums[0];
              int end = nums[1];
              if (suttaNum >= start && suttaNum <= end) isMatch = true;
            }
          } else if (suttaNum != null &&
              nums.length >= 3 &&
              (collection == 'sn' || collection == 'an')) {
            if (nums[0] == bookNum) {
              int start = nums[nums.length - 2];
              int end = nums.last;
              if (suttaNum >= start && suttaNum <= end) isMatch = true;
            }
          }

          if (isMatch) {
            nextParent = child["uid"];
            break;
          }
        }

        if (nextParent != null) {
          if (currentParent != collection) {
            lastValidParent = currentParent;
          }
          currentParent = nextParent;
        } else {
          if (currentParent != collection) {
            lastValidParent = currentParent;
          }
          break;
        }
      }

      if (currentParent != collection) {
        return currentParent;
      } else if (lastValidParent != null) {
        return lastValidParent;
      }

      return collection;
    } catch (e) {
      debugPrint("Error resolving vagga: $e");
      return null;
    }
  }

  Future<void> _processVaggaTracking(
    Map<String, dynamic> mergedData,
    String targetUid,
  ) async {
    final vaggaBeforeNavigate = _parentVaggaId;

    _updateParentAnchorOnMove(
      mergedData["root_text"] as Map<String, dynamic>?,
      mergedData["suttaplex"] as Map<String, dynamic>?,
    );

    if (widget.textData?["initial_vagga_uid"] != null) {
      mergedData["initial_vagga_uid"] = widget.textData!["initial_vagga_uid"];
    } else {
      mergedData["initial_vagga_uid"] = vaggaBeforeNavigate;
    }

    final rootMeta = mergedData["root_text"];
    if (rootMeta is Map &&
        rootMeta["vagga_uid"] != null &&
        rootMeta["vagga_uid"].toString().trim().isNotEmpty) {
      final vaggaUid = rootMeta["vagga_uid"].toString();
      if (mounted) setState(() => _parentVaggaId = vaggaUid);
      mergedData["resolved_vagga_uid"] = vaggaUid;
    } else {
      final resolvedVagga = await _resolveVaggaUid(targetUid);
      if (resolvedVagga != null) {
        if (mounted) setState(() => _parentVaggaId = resolvedVagga);
        mergedData["resolved_vagga_uid"] = resolvedVagga;
      }
    }
  }

  Future<void> _navigateToSutta({required bool isPrevious}) async {
    // ✅ Set flag di awal fungsi
    setState(() {
      _hasNavigatedBetweenSuttas = true;
    });

    final segmented = widget.textData?["segmented"] == true;
    final key = isPrevious ? "previous" : "next";

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

    if (navTarget == null || navTarget["uid"] == null) return;
    final targetUid = navTarget["uid"].toString();
    if (targetUid.trim().isEmpty) return;

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
      return;
    }

    final targetLang = segmented
        ? widget.lang
        : navTarget["lang"]?.toString() ?? widget.lang;

    setState(() {
      _isLoading = true;
      _connectionError = false; // Reset error
    });
    try {
      final data = await SuttaService.fetchFullSutta(
        uid: targetUid,
        authorUid: authorUid,
        lang: targetLang,
        segmented: segmented,
        siteLanguage: "id",
      );

      final hasTranslation = segmented
          ? (data["translation_text"] != null || data["root_text"] != null)
          : (data["translation"] != null || data["root_text"] != null);
      if (!hasTranslation) {
        _showSuttaSnackBar(
          SuttaSnackType.translatorFallback,
          uid: targetUid,
          lang: targetLang,
          author: authorUid,
        );
        return;
      }

      final mergedData = {
        ...data,
        "segmented": segmented,
        "suttaplex": data["suttaplex"] ?? widget.textData?["suttaplex"],
      };

      await _processVaggaTracking(mergedData, targetUid);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: '/sutta/$targetUid'),
          pageBuilder: (_, _, _) => SuttaDetail(
            uid: targetUid,
            lang: targetLang,
            textData: mergedData,
            openedFromSuttaDetail: true,
            originalSuttaUid: null,
            entryPoint: widget.entryPoint, // ✅ Forward entry point
            isNavigated: true, // Biar Sutta B tau kalau dia bukan Sutta pertama
          ),
          transitionsBuilder: (_, animation, _, child) {
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
      if (e is SocketException || e.toString().contains("SocketException")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal memuat halaman. Periksa koneksi internet."),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        _replaceToRoute('/suttaplex/$targetUid', slideFromLeft: isPrevious);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuttaSnackBar(
    SuttaSnackType type, {
    String? uid,
    String? lang,
    String? author,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    List<InlineSpan> contentSpans = [];
    Color bgColor = Theme.of(context).colorScheme.inverseSurface;

    // ✅ AMBIL AKRONIM (Misal: "DN", "MN", "Dhp", dll)
    // Kalau gak ada, fallback ke UID atau "kitab ini"
    String acronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        uid ??
        "kitab ini";

    switch (type) {
      case SuttaSnackType.translatorFallback:
        bgColor = Colors.deepOrange.shade400;
        contentSpans = [
          TextSpan(
            text:
                "Teks $uid ($lang) oleh $author tak tersedia. Ganti versi terjemahan melalui ",
          ),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.translate_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const TextSpan(text: " di menu bawah."),
        ];
        break;

      case SuttaSnackType.firstText:
        bgColor = Colors.deepOrange.shade400;
        contentSpans = [
          // ✅ TEXT DENGAN AKRONIM
          TextSpan(text: "Anda berada di awal ($acronym). Gunakan tombol "),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_back_rounded, // Icon Back
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const TextSpan(text: " untuk kembali ke menu."),
        ];
        break;

      case SuttaSnackType.lastText:
        bgColor = Colors.deepOrange.shade400;
        contentSpans = [
          // ✅ TEXT DENGAN AKRONIM
          TextSpan(
            text: "Anda telah mencapai akhir ($acronym). Gunakan tombol ",
          ),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_back_rounded, // Icon Back
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const TextSpan(text: " untuk kembali ke menu."),
        ];
        break;

      case SuttaSnackType.disabledForTematik:
        bgColor = Colors.grey.shade800;
        contentSpans = [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.block_rounded, color: Colors.white, size: 18),
            ),
          ),
          const TextSpan(text: "Navigasi dimatikan pada mode Tematik."),
        ];
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            children: contentSpans,
          ),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _goToPrevSutta() {
    // _hasNavigatedBetweenSuttas = true; // ← Set true
    // Cek kalau dari Tematik
    if (widget.entryPoint == "tematik") {
      _showSuttaSnackBar(SuttaSnackType.disabledForTematik);
      return;
    }
    _navigateToSutta(isPrevious: true);
  }

  void _goToNextSutta() {
    //_hasNavigatedBetweenSuttas = true; // ← Set true
    // Cek kalau dari Tematik
    if (widget.entryPoint == "tematik") {
      _showSuttaSnackBar(SuttaSnackType.disabledForTematik);
      return;
    }
    _navigateToSutta(isPrevious: false);
  }

  void _updateParentAnchorOnMove(
    Map<String, dynamic>? root,
    Map<String, dynamic>? suttaplex,
  ) {
    final prev = root?["previous"] ?? suttaplex?["previous"];
    final next = root?["next"] ?? suttaplex?["next"];

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

    if (widget.textData != oldWidget.textData) {
      setState(() {
        _htmlSegments.clear();
        _tocList.clear();

        final hasTranslationMap =
            widget.textData?["translation_text"] is Map &&
            (widget.textData!["translation_text"] as Map).isNotEmpty;
        final keysOrder = widget.textData?["keys_order"] is List
            ? List<String>.from(widget.textData!["keys_order"])
            : (widget.textData?["segments"] as Map?)?.keys.toList() ?? [];

        final isSegmented = hasTranslationMap && keysOrder.isNotEmpty;

        if (!isSegmented) {
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
            final root = Map<String, dynamic>.from(
              widget.textData!["root_text"],
            );
            final sutta = NonSegmentedSutta.fromJson(root);
            rawHtml = HtmlUnescape().convert(sutta.text);
          }

          if (rawHtml.isNotEmpty) {
            _parseHtmlAndGenerateTOC(rawHtml);
          }
        }
      });
    }
  }

  // ✅ FIX: Replace '|' with double break line for readability

  WidgetSpan _buildCommentSpan(
    BuildContext context,
    String comm,
    double fontSize,
  ) {
    // Format baris baru di komentar
    final formattedComm = comm.replaceAll('|', '<br><br>');

    return WidgetSpan(
      // Alignment middle biar widget-nya dianggap sebaris dulu
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                "Komentar",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SingleChildScrollView(
                child: Html(
                  data: formattedComm,
                  style: {
                    "body": Style(
                      fontFamily: GoogleFonts.notoSerif().fontFamily,
                      fontSize: FontSize(fontSize),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: Theme.of(context).colorScheme.onSurface,
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
            // Padding kiri dikit aja (2.0) biar ga nempel banget sama huruf terakhir,
            // tapi tetep keliatan "nyatu"
            padding: const EdgeInsets.only(left: 0.1),
            child: Transform.translate(
              // ✅ INI DIA: Geser ke atas (Superscript)
              offset: const Offset(0, -6),
              child: Text(
                "[note]",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  // Ukuran font kecil (60% dari font utama)
                  fontSize: fontSize * 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cachedSearchRegex = null;
    super.dispose();
  }

  SuttaHeaderConfig _getHeaderConfig(String key, {bool isPaliOnly = false}) {
    final verseNumRaw = key.contains(":") ? key.split(":").last : key;
    final verseNum = verseNumRaw.trim();

    final isH1 = verseNum == "0.1";
    final isH2 = verseNum == "0.2";
    final headerRegex = RegExp(r'^(?:\d+\.)*0(?:\.\d+)*$');
    final isHeader = headerRegex.hasMatch(verseNum);
    final isH3 = isHeader && !isH1 && !isH2;

    // ✅ FIX: AMBIL WARNA DARI _themeColors (JANGAN DARI CONTEXT/SYSTEM)
    final colors = _themeColors; // Panggil getter sakti kita

    // Warna Pali: Kalau Dark Mode/Sepia pake warna emas/coklat, kalau Light pake coklat tua
    // Kita bisa ambil logika simpel: Text Color utama
    final mainTextColor = colors['text']!;

    // Warna Pali (Body Text)
    // Kalau Sepia/Light -> Coklat (ambil dari _themeColors['text'])
    // Kalau Dark -> Emas pudar (Hardcode dikit gapapa buat variasi)
    final isDarkReader = _readerTheme == ReaderTheme.dark;
    final paliBodyColor = isDarkReader
        ? const Color(0xFFD4A574)
        : const Color(0xFF8B4513);

    final headerColor = mainTextColor; // Judul ngikut warna teks utama
    final paliColor = isPaliOnly ? headerColor : paliBodyColor;
    final transBodyColor = mainTextColor; // Terjemahan ngikut warna teks utama

    TextStyle paliStyle, transStyle;
    double topPadding, bottomPadding;

    if (isH1) {
      topPadding = 16.0;
      bottomPadding = 16.0;
      paliStyle = TextStyle(
        fontFamily: GoogleFonts.notoSerif().fontFamily,
        fontSize: _fontSize * 1.10, // ← H1 jadi 1.3
        fontWeight: FontWeight.w900,
        color: headerColor,
        height: 1.2,
        letterSpacing: -0.5,
      );
      transStyle = paliStyle;
    } else if (isH2) {
      topPadding = 8.0;
      bottomPadding = 12.0;
      paliStyle = TextStyle(
        fontFamily: GoogleFonts.notoSerif().fontFamily,
        fontSize: _fontSize * 1.05, // ← H2 jadi 1.2
        fontWeight: FontWeight.bold,
        color: headerColor.withValues(alpha: 0.87),
        height: 1.3,
      );
      transStyle = paliStyle;
    } else if (isH3) {
      topPadding = 16.0;
      bottomPadding = 8.0;
      paliStyle = TextStyle(
        fontFamily: GoogleFonts.notoSerif().fontFamily,
        fontSize: _fontSize * 1, // ← H3 jadi 1.1
        fontWeight: FontWeight.w700,
        color: headerColor.withValues(alpha: 0.87),
        height: 1.4,
      );
      transStyle = paliStyle;
    } else {
      topPadding = 0.0;
      bottomPadding = 8.0;
      paliStyle = TextStyle(
        fontFamily: GoogleFonts.notoSerif().fontFamily,
        fontSize: isPaliOnly ? _fontSize : _fontSize * 0.8, // ← CONDITIONAL
        fontWeight: FontWeight.w500,
        color: paliColor,
        height: 1.5,
      );
      transStyle = TextStyle(
        fontFamily: GoogleFonts.notoSerif().fontFamily,
        fontSize: _fontSize,
        fontWeight: FontWeight.normal,
        color: transBodyColor,
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

  // ✅ WIDGET UTAMA RENDER SEGMENTED (Sekarang Support HTML)
  Widget _buildSegmentedItem(
    BuildContext context,
    int index,
    String key,
    Map<String, String> paliSegs,
    Map<String, String> translationSegs,
    Map<String, String> commentarySegs,
  ) {
    final config = _getHeaderConfig(key, isPaliOnly: _isRootOnly);

    var pali = paliSegs[key] ?? "";
    if (pali.trim().isEmpty) pali = "...";

    var trans = translationSegs[key] ?? "";
    final isTransEmpty = trans.trim().isEmpty;
    final comm = commentarySegs[key] ?? "";

    final query = _searchController.text.trim();
    final int paliMatchCount = (query.length >= 2 && _cachedSearchRegex != null)
        ? _cachedSearchRegex!
              .allMatches(pali.replaceAll(RegExp(r'<[^>]*>'), '').toLowerCase())
              .length
        : 0;

    // ✅ FIX: Kalau Teks Pali Only tapi user pilih Translation Only,
    // Paksa pindah ke LineByLine biar tetep kebaca
    ViewMode effectiveViewMode = _viewMode;
    if (_isRootOnly) {
      effectiveViewMode = ViewMode.lineByLine;
    }

    switch (effectiveViewMode) {
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

  // ✅ HELPER RENDER HTML DENGAN HIGHLIGHT
  Widget _buildHtmlText(
    String text,
    TextStyle baseStyle,
    int listIndex,
    int startMatchCount,
  ) {
    // Inject highlight span ke dalam string HTML source
    final contentWithHighlight = _injectSearchHighlights(
      text,
      listIndex,
      startMatchCount,
    );

    return Html(
      data: contentWithHighlight,
      style: {
        "body": Style(
          fontFamily: GoogleFonts.notoSerif().fontFamily,
          fontSize: FontSize(baseStyle.fontSize ?? _fontSize),
          fontWeight: baseStyle.fontWeight,
          color: baseStyle.color,
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          lineHeight: LineHeight(1.5),
          fontStyle: baseStyle.fontStyle,
        ),
        // ✅ STYLING .REF BIAR RAPI (Border, Radius, Margin)
        ".ref": Style(
          fontSize: FontSize.smaller,
          color: Colors.grey,
          textDecoration: TextDecoration.none,
          verticalAlign: VerticalAlign.sup,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          //margin: Margins.symmetric(horizontal: 4),
          margin: Margins.only(right: 4),
          padding: HtmlPaddings.symmetric(horizontal: 2, vertical: 0),
          display: Display.inlineBlock,
        ),

        // ✅ HEADER LIST ITEM (DIVISION & SUTTA NAME)
        "header": Style(
          display: Display.block,
          margin: Margins.only(bottom: 20),
        ),
        "header ul": Style(
          // Hapus titik & indentasi
          listStyleType: ListStyleType.none,
          padding: HtmlPaddings.zero,
          margin: Margins.zero,
        ),
        "header li": Style(
          // Rata tengah & Abu-abu
          textAlign: TextAlign.center,
          color: Colors.grey,
          fontSize: FontSize.medium,
          fontWeight: FontWeight.bold,
          display: Display.block,
          margin: Margins.only(bottom: 4),
        ),

        // Division juga di-style sama (rata tengah, abu)
        ".division": Style(
          textAlign: TextAlign.center,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          display: Display.block,
          margin: Margins.symmetric(vertical: 12),
        ),

        // ✅ HIDE FOOTER
        "footer": Style(display: Display.none),
      },
    );
  }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Gabungkan terjemahan + note jadi satu Text.rich
                Text.rich(
                  TextSpan(
                    text: isTransEmpty ? "..." : trans,
                    style: isTransEmpty
                        ? config.transStyle.copyWith(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          )
                        : config.transStyle,
                    children: [
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

  Widget _buildLayoutLineByLine(
    SuttaHeaderConfig config,
    int index,
    String pali,
    String trans,
    bool isTransEmpty,
    String comm,
    int paliMatchCount,
  ) {
    final isPe = pali == "..." && !config.isH1 && !config.isH2 && !config.isH3;
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
                _buildHtmlText(pali, finalPaliStyle, index, 0),
                const SizedBox(height: 4),
                if (!_isRootOnly)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Gabungkan trans + note jadi satu Text.rich
                      Text.rich(
                        TextSpan(
                          text: isTransEmpty ? "..." : trans,
                          style: isTransEmpty
                              ? config.transStyle.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                )
                              : config.transStyle,
                          children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutSideBySide(
    SuttaHeaderConfig config,
    int index,
    String pali,
    String trans,
    bool isTransEmpty,
    String comm,
    int paliMatchCount,
  ) {
    final isPe = pali == "..." && !config.isH1 && !config.isH2 && !config.isH3;
    final finalPaliStyle = config.paliStyle.copyWith(
      fontStyle: isPe ? FontStyle.italic : FontStyle.normal,
      color: isPe ? Colors.grey : config.paliStyle.color,
    );

    // ✅ FIX: Kalau Root Only, paksa LineByLine biar gak ada kolom kosong
    if (_isRootOnly || config.isH1 || config.isH2 || config.isH3) {
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
              Expanded(
                flex: 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVerseNumber(config), // Verse Number di kiri
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildHtmlText(pali, finalPaliStyle, index, 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Gabungkan trans + note jadi satu Text.rich
                    Text.rich(
                      TextSpan(
                        text: isTransEmpty ? "..." : trans,
                        style: isTransEmpty
                            ? config.transStyle.copyWith(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              )
                            : config.transStyle,
                        children: [
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
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildVerseNumber(SuttaHeaderConfig config) {
    // ✅ FIX: Ambil warna note/nomor dari tema
    final noteColor = _themeColors['note'];

    return SelectionContainer.disabled(
      child: Padding(
        padding: EdgeInsets.only(top: config.isH1 || config.isH2 ? 6.0 : 0.0),
        child: Text(
          config.verseNum,
          style: TextStyle(
            fontSize: 12,
            //color: Theme.of(context).colorScheme.onSurfaceVariant,
            color: noteColor, // ✅ Pake warna yang bener
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getMetadata() {
    final isSegmented = widget.textData?["segmented"] == true;
    final translations =
        widget.textData?["suttaplex"]?["translations"] as List?;

    String author = "";
    String langName = "";

    if (isSegmented) {
      if (translations != null) {
        try {
          final currentTrans = translations.firstWhere(
            (t) =>
                t["author_uid"] == widget.textData?["author_uid"] &&
                t["lang"] == widget.lang,
            orElse: () => null,
          );
          author = currentTrans?["author"]?.toString() ?? "";
          langName = currentTrans?["lang_name"]?.toString() ?? "";
        } catch (e) {
          author = "";
        }
      }
    } else {
      author = widget.textData?["translation"]?["author"]?.toString() ?? "";
      if (translations != null) {
        final currentTrans = translations.firstWhere(
          (t) => t["lang"] == widget.lang,
          orElse: () => null,
        );
        langName = currentTrans?["lang_name"]?.toString() ?? "";
      }
    }

    if (langName.isEmpty) {
      langName = isSegmented
          ? (widget.textData?["bilara_translated_text"]?["lang_name"] ??
                widget.textData?["translation_text"]?["lang_name"] ??
                widget.textData?["root_text"]?["lang_name"] ??
                widget.lang.toUpperCase())
          : (widget.textData?["translation"]?["lang_name"] ??
                widget.textData?["root_text"]?["lang_name"] ??
                widget.lang.toUpperCase());
    }

    final pubDate = translations?.firstWhere(
      (t) =>
          t["author_uid"] == widget.textData?["author_uid"] &&
          t["lang"] == widget.lang,
      orElse: () => null,
    )?["publication_date"];

    return {
      "isSegmented": isSegmented,
      "author": author,
      "langName": langName,
      "pubDate": pubDate,
    };
  }

  Future<void> _saveToHistory() async {
    final metadata = _getMetadata();

    final rawAcronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        "";
    final normalizedAcronym = normalizeNikayaAcronym(rawAcronym);

    // 🔥 DEBUG LOG
    debugPrint("💾 [SAVE HISTORY] Raw Acronym: '$rawAcronym'");
    debugPrint("💾 [SAVE HISTORY] Normalized: '$normalizedAcronym'");

    final historyItem = {
      'uid': widget.uid,
      'title':
          widget.textData?["suttaplex"]?["translated_title"] ??
          widget.textData?["suttaplex"]?["original_title"] ??
          widget.textData?["root_text"]?["title"] ??
          widget.uid,
      'original_title':
          widget.textData?["suttaplex"]?["original_title"] ??
          widget.textData?["root_text"]?["title"] ??
          "",
      'acronym': normalizedAcronym,
      'author': metadata["author"],
      'lang_name': metadata["langName"],
      'timestamp': DateTime.now().toIso8601String(),
    };

    await HistoryService.addToHistory(historyItem);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    // ✅ FIX: Ambil warna dari tema baca, bukan System HP
    final colors = _themeColors;
    final mainColor = colors['text']!;
    final subColor = colors['note']!; // atau colors['icon']

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: subColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: subColor),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: mainColor,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ WIDGET NO INTERNET (ELEGAN)
  Widget _buildNoInternetView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              "Koneksi Terputus",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Gagal memuat teks sutta.\nSilakan periksa internet Anda.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // Retry logic: Refresh halaman
                setState(() => _isLoading = true);
                _replaceToSutta(
                  widget.uid,
                  widget.lang,
                  authorUid: widget.textData?["author_uid"] ?? "",
                  segmented: widget.textData?["segmented"] == true,
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Ambil palet warna dari tema baca saat ini
    final colors = _themeColors;

    // 2. Assign ke variabel (pake ! karena kita yakin datanya ada)
    final bgColor = colors['bg']!;
    final textColor = colors['text']!;
    // 👉 Buat UI (Header, Card, Drawer) -> PAKSA Pake System Theme (Theme.of(context))
    // Jadi walaupun Reader-nya Sepia, Header-nya tetep Putih/Hitam standar HP.
    final cardColor = colors['card']!; // Otomatis ikut System
    final iconColor = colors['icon']!; // Otomatis ikut System

    final metadata = _getMetadata();

    // ... lanjut ke bawah (Scaffold dll)
    final String suttaTitle =
        widget.textData?["root_text"]?["title"] ??
        widget.textData?["translation"]?["title"] ??
        widget.uid;

    final String rawAcronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        "";
    final String acronym = normalizeNikayaAcronym(rawAcronym);
    debugPrint("🎨 [SuttaDetail] Raw: '$rawAcronym' → Normalized: '$acronym'");

    final String rawBlurb = widget.textData?["suttaplex"]?["blurb"] ?? "";
    bool shouldShowBlurb = rawBlurb.isNotEmpty;

    final bool isError = widget.textData == null || widget.textData!.isEmpty;
    final bool isSegmented =
        !isError && (widget.textData!["segmented"] == true);

    final Map<String, String> paliSegs;
    final Map<String, String> translationSegs;
    final Map<String, String> commentarySegs;
    final List<String> keysOrder;

    if (!isError && isSegmented) {
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

    Widget body;

    // ✅ LOGIC BODY UTAMA
    if (_connectionError) {
      body = _buildNoInternetView();
    } else if (isError) {
      body = Center(
        child: Text("Teks tidak tersedia", style: TextStyle(color: textColor)),
      );
    } else if (isSegmented) {
      body = SelectionArea(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
    } else if ((widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"))) {
      // CASE B: NON-SEGMENTED HTML
      if (_htmlSegments.isEmpty) {
        String rawHtml = "";
        if (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) {
          final transMap = Map<String, dynamic>.from(
            widget.textData!["translation_text"],
          );
          rawHtml = HtmlUnescape().convert(
            NonSegmentedSutta.fromJson(transMap).text,
          );
        } else if (widget.textData!["root_text"] is Map) {
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
            // Inject Highlight
            String content = _injectSearchHighlights(
              _htmlSegments[index],
              index,
              0,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Html(
                data: content,
                style: {
                  "body": Style(
                    fontFamily: GoogleFonts.notoSerif().fontFamily,
                    fontSize: FontSize(_fontSize),
                    lineHeight: LineHeight(1.6),
                    margin: Margins.only(left: 10, right: 10),
                    color: textColor,
                  ),
                  "h1": Style(
                    fontSize: FontSize(_fontSize * 1.8),
                    fontWeight: FontWeight.w900,
                    margin: Margins.only(top: 24, bottom: 12),
                    color: textColor,
                  ),
                  "h2": Style(
                    fontSize: FontSize(_fontSize * 1.5),
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(top: 20, bottom: 10),
                    color: textColor,
                  ),
                  "h3": Style(
                    fontSize: FontSize(_fontSize * 1.25),
                    fontWeight: FontWeight.w700,
                    margin: Margins.only(top: 16, bottom: 8),
                    color: textColor,
                  ),
                  // ✅ FEATURE: Style khusus untuk Referensi Legacy (a class='ref')
                  ".ref": Style(
                    fontSize: FontSize.smaller,
                    color: Colors.grey,
                    textDecoration: TextDecoration.none,
                    verticalAlign: VerticalAlign.sup,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    //margin: Margins.symmetric(horizontal: 4),
                    margin: Margins.only(right: 4),
                    padding: HtmlPaddings.symmetric(horizontal: 2, vertical: 0),
                    display: Display.inlineBlock,
                  ),

                  // ✅ HEADER LIST ITEM (DIVISION & SUTTA NAME)
                  "header": Style(
                    display: Display.block,
                    margin: Margins.only(bottom: 20),
                  ),
                  "header ul": Style(
                    // Hapus titik & indentasi
                    listStyleType: ListStyleType.none,
                    padding: HtmlPaddings.zero,
                    margin: Margins.zero,
                  ),
                  "header li": Style(
                    // Rata tengah & Abu-abu
                    textAlign: TextAlign.center,
                    color: Colors.grey,
                    fontSize: FontSize.medium,
                    fontWeight: FontWeight.bold,
                    display: Display.block,
                    margin: Margins.only(bottom: 4),
                  ),

                  // ✅ HIDE FOOTER
                  "footer": Style(display: Display.none),
                },
              ),
            );
          },
        ),
      );
    } else if (widget.textData!["root_text"] is Map &&
        !(widget.textData!["root_text"] as Map).containsKey("text")) {
      // CASE C: PALI ONLY
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
    } else {
      body = Center(
        child: Text(
          "Kesalahan format teks.",
          style: TextStyle(color: textColor),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          if (widget.textData != null) {
            widget.textData!.remove("initial_vagga_uid");
          }
          return;
        }

        // ✅ LOGIC BARU: CEK DRAWER (DAFTAR ISI) DULU
        // Kalau Daftar Isi lagi kebuka, tombol Back fungsinya cuma buat nutup drawer
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          Navigator.of(context).pop(); // Tutup drawer
          return; // Stop, jangan lanjut tampilin dialog exit
        }

        // Kalau Drawer GAK kebuka, baru jalanin logic dialog exit yang lama
        final navigator = Navigator.of(context);
        final allow = await _handleBackReplace();

        if (allow && widget.textData != null) {
          widget.textData!.remove("initial_vagga_uid");
        }
        if (allow && mounted) {
          navigator.pop(result);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        // ... sisa kode Scaffold ke bawah gak usah diubah ...
        appBar: null,
        backgroundColor: bgColor,
        // INI WARNA BODY
        //backgroundColor: Theme.of(context).brightness == Brightness.dark
        //  ? Colors.grey[800]
        //: Colors.grey[100],
        endDrawer: _tocList.isNotEmpty
            ? Drawer(
                // Drawer background otomatis ngikut tema App (bukan Sepia)
                child: Column(
                  children: [
                    DrawerHeader(
                      child: Center(
                        child: Text(
                          "Daftar Isi",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            // ✅ GANTI INI: Biar ngikut tema HP (Hitam/Putih), bukan Sepia
                            color: Theme.of(context).colorScheme.onSurface,
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
                                // ✅ GANTI INI JUGA:
                                color: Theme.of(context).colorScheme.onSurface,
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
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 70,
                ), // Spacing untuk header
                Expanded(child: body),
              ],
            ),

            // TRANSPARENT HEADER dengan shadow konsisten
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    // ✅ FIX 1: Warna langsung ditaruh di sini (SOLID), tanpa transparansi
                    color: Theme.of(context).colorScheme.surface,

                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.1,
                        ), // lebih pekat
                        blurRadius: 4, // lebih besar biar soft
                        offset: const Offset(0, 2), // geser biar keliatan
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        color: cardColor.withValues(alpha: 0.85),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Tombol back dengan shadow kecil
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(Icons.arrow_back, color: iconColor),
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        final navigator = Navigator.of(context);
                                        final allow =
                                            await _handleBackReplace();
                                        if (allow && mounted) {
                                          navigator.pop();
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.textData?["suttaplex"]?["original_title"] ??
                                    suttaTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight
                                      .bold, // ✅ FIX 2: Pastikan warna teks kontras
                                  color: iconColor,
                                  //color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: cardColor,
                                    title: Text(
                                      widget.textData?["suttaplex"]?["original_title"] ??
                                          suttaTitle,
                                      style: TextStyle(color: textColor),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (shouldShowBlurb &&
                                              rawBlurb.isNotEmpty) ...[
                                            Html(
                                              data: rawBlurb,
                                              style: {
                                                "body": Style(color: textColor),
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            const Divider(),
                                            const SizedBox(height: 12),
                                          ],
                                          Text(
                                            "Tentang",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (metadata["author"]
                                              .toString()
                                              .isNotEmpty) ...[
                                            _buildInfoRow(
                                              Icons.person_outline,
                                              "Author",
                                              metadata["author"],
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                          _buildInfoRow(
                                            Icons.language,
                                            "Bahasa",
                                            metadata["langName"],
                                          ),
                                          const SizedBox(height: 10),
                                          if (metadata["pubDate"] != null &&
                                              metadata["pubDate"]
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            _buildInfoRow(
                                              Icons.calendar_today_outlined,
                                              "Tahun Terbit",
                                              metadata["pubDate"],
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                          _buildInfoRow(
                                            metadata["isSegmented"]
                                                ? Icons.format_align_left
                                                : Icons.archive_outlined,
                                            "Format",
                                            metadata["isSegmented"]
                                                ? "Aligned (Segmented JSON)"
                                                : "Legacy (HTML)",
                                          ),
                                          if (_footerInfo.isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            const Divider(),
                                            const SizedBox(height: 12),
                                            Text(
                                              "Informasi",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Html(
                                              data: _footerInfo,
                                              style: {
                                                "body": Style(color: textColor),
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Tutup"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (acronym.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                rawAcronym,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: getNikayaColor(
                                    normalizeNikayaAcronym(acronym),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _connectionError || isError
            ? null
            : _buildFloatingActions(isSegmented),
      ),
    );
  }

  Widget _buildFloatingActions(bool isSegmented) {
    // 1. Cek Logic (Hanya loading yang bener-bener matikan tombol)
    final isTematik = widget.entryPoint == "tematik";

    // Kita hapus isPrevDisabled/isNextDisabled buat onTap
    // Jadi tombol tetap clickable meski di awal/akhir (buat nampilin pesan)

    final bool showToc = _tocList.isNotEmpty && !_connectionError;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warna
    final containerColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final shadowColor = Colors.black.withValues(alpha: 0.15);
    final activeColor = Theme.of(context).colorScheme.primary;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    // Warna khusus buat tombol mentok (tetep keliatan tapi agak pudar)
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    Widget buildBtn({
      required IconData icon,
      required VoidCallback? onTap,
      bool isActive = false,
      String tooltip = "",
      // Parameter baru buat override warna kalau tombol "mentok"
      Color? customIconColor,
    }) {
      // Tentukan warna icon:
      // 1. Kalau Loading (onTap null) -> Abu mati
      // 2. Kalau Custom (Mentok) -> Abu pudar (disabledClickableColor)
      // 3. Normal -> Hitam/Putih (iconColor)
      Color finalColor;
      if (onTap == null) {
        finalColor = Colors.grey.withValues(alpha: 0.3);
      } else if (customIconColor != null) {
        finalColor = customIconColor;
      } else if (isActive) {
        finalColor = activeColor;
      } else {
        finalColor = iconColor;
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: isActive
                  ? BoxDecoration(
                      color: activeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Icon(icon, color: finalColor, size: 24),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // --- TOMBOL PREV ---
          buildBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: "Sebelumnya",
            // Kalau mentok (_isFirst/Tematik), warnanya pudar. Tapi tetep bisa diklik!
            customIconColor: (_isFirst || isTematik)
                ? disabledClickableColor
                : null,
            // Cuma disable kalau lagi LOADING
            onTap: _isLoading
                ? null
                : () {
                    if (isTematik) {
                      _showSuttaSnackBar(SuttaSnackType.disabledForTematik);
                    } else if (_isFirst) {
                      _showSuttaSnackBar(
                        SuttaSnackType.firstText,
                        uid: widget.uid,
                      );
                    } else {
                      _goToPrevSutta();
                    }
                  },
          ),

          Container(
            width: 1,
            height: 24,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- TENGAH (TOOLS) ---
          buildBtn(
            icon: Icons.translate_rounded,
            tooltip: "Info Sutta & Terjemahan",
            onTap: _isLoading ? null : _openSuttaplexModal,
          ),
          buildBtn(
            icon: Icons.search_rounded,
            tooltip: "Cari Teks",
            onTap: _isLoading ? null : _openSearchModal,
          ),

          buildBtn(
            icon: Icons.text_fields_rounded,
            tooltip: "Tampilan",
            onTap: () => _openViewSettingsModal(isSegmented),
          ),

          if (showToc)
            buildBtn(
              icon: Icons.list_alt_rounded,
              tooltip: "Daftar Isi",
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- TOMBOL NEXT ---
          buildBtn(
            icon: Icons.chevron_right_rounded,
            tooltip: "Selanjutnya",
            // Kalau mentok (_isLast/Tematik), warnanya pudar.
            customIconColor: (_isLast || isTematik)
                ? disabledClickableColor
                : null,
            onTap: _isLoading
                ? null
                : () {
                    if (isTematik) {
                      _showSuttaSnackBar(SuttaSnackType.disabledForTematik);
                    } else if (_isLast) {
                      _showSuttaSnackBar(
                        SuttaSnackType.lastText,
                        uid: widget.uid,
                      );
                    } else {
                      _goToNextSutta();
                    }
                  },
          ),
        ],
      ),
    );
  }

  void _openSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      // ✅ INI DIA JUARANYA: Kasih warna hitam transparan (Overlay)
      // Jadi user tau kalo belakangnya lagi "dikunci"
      barrierColor: Colors.black.withValues(alpha: 0.4),

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
                  // Warna kotak search-nya ngikutin tema (Putih/Gelap)
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20), // Radius makin tumpul makin manis
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header kecil biar manis (Opsional, kayak handle pintu)
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: "Cari kata (min. 2 huruf)...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              // Warna kolom input dikit beda biar kontras
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        if (mounted) {
                                          setState(() => _allMatches.clear());
                                        }
                                        if (mounted) setSheetState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) {
                              if (_debounce?.isActive ?? false) {
                                _debounce!.cancel();
                              }
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
                        // Tombol Close Text ganti jadi Cancel biar jelas
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Batal"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Baris Kontrol Navigasi (Panah Atas Bawah)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _allMatches.isEmpty
                              ? "Belum ada hasil"
                              : "${_currentMatchIndex + 1} dari ${_allMatches.length} hasil",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _allMatches.isEmpty
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              tooltip: "Sebelumnya",
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      _jumpToResult(_currentMatchIndex - 1);
                                      setSheetState(() {});
                                    },
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              tooltip: "Selanjutnya",
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
      _debounce?.cancel();
      setState(() {
        _searchController.clear();
        _allMatches.clear();
      });
    });
  }

  void _openSuttaplexModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Suttaplex(
            uid: widget.uid,
            sourceMode: "sutta_detail",
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
      ),
    );
  }

  void _openViewSettingsModal(bool isSegmented) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Biar modalnya gak ketutup keyboard/ui lain
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Helper Style Tombol (Tetap sama kayak sebelumnya)
            ButtonStyle getBtnStyle(bool isActive) {
              final scheme = Theme.of(context).colorScheme;
              return OutlinedButton.styleFrom(
                backgroundColor: isActive ? scheme.primaryContainer : null,
                side: BorderSide(
                  color: isActive ? scheme.primary : Colors.grey.shade400,
                  width: 1.0,
                ),
                foregroundColor: isActive
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24,
                ), // Bottom agak gedean dikit
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ HEADER BARU: Judul + Tombol Close (X)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Pengaturan Tampilan",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          // Biar area sentuhnya pas
                          splashRadius: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24), // Jarak ke konten

                    Text(
                      "Tema Baca",

                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),

                    // ... (Kode Text "Tema Baca" di atasnya) ...
                    const SizedBox(height: 12),

                    // ✅ GANTI ROW LAMA DENGAN INI (Bisa discroll)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // 1. Terang (Full Black)
                          _buildThemeOption(
                            context,
                            ReaderTheme.light,
                            Colors.white,
                            Colors.black,
                            "Terang",
                            () => setModalState(() {}),
                          ),
                          const SizedBox(width: 16), // Jarak antar tombol
                          // 2. Terang 2 (Soft)
                          _buildThemeOption(
                            context,
                            ReaderTheme.light2,
                            Colors.grey[50]!,
                            const Color(0xFF424242), // Preview Text Abu Tua
                            "Terang 2",
                            () => setModalState(() {}),
                          ),
                          const SizedBox(width: 16),

                          // 3. Sepia
                          _buildThemeOption(
                            context,
                            ReaderTheme.sepia,
                            const Color(0xFFF4ECD8),
                            const Color(0xFF5D4037),
                            "Sepia",
                            () => setModalState(() {}),
                          ),
                          const SizedBox(width: 16),

                          // 4. Gelap (Full White)
                          _buildThemeOption(
                            context,
                            ReaderTheme.dark,
                            const Color(0xFF212121),
                            Colors.white,
                            "Gelap",
                            () => setModalState(() {}),
                          ),
                          const SizedBox(width: 16),

                          // 5. Gelap 2 (Dimmed)
                          _buildThemeOption(
                            context,
                            ReaderTheme.dark2,
                            const Color(0xFF212121),
                            const Color(0xFFB0BEC5), // Preview Text Abu
                            "Gelap 2",
                            () => setModalState(() {}),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20), // Jarak ke konten
                    // Opsi Tampilan Segmen
                    if (isSegmented && widget.lang != "pli") ...[
                      Text(
                        "Mode Baca",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: getBtnStyle(
                                _viewMode == ViewMode.lineByLine,
                              ),
                              onPressed: () {
                                setState(() => _viewMode = ViewMode.lineByLine);
                                setModalState(() {});
                                _savePreferences();
                              },
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("Atas-Bawah"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: getBtnStyle(
                                _viewMode == ViewMode.sideBySide,
                              ),
                              onPressed: () {
                                setState(() => _viewMode = ViewMode.sideBySide);
                                setModalState(() {});
                                _savePreferences();
                              },
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("Kiri-Kanan"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: getBtnStyle(
                                _viewMode == ViewMode.translationOnly,
                              ),
                              onPressed: () {
                                setState(
                                  () => _viewMode = ViewMode.translationOnly,
                                );
                                setModalState(() {});
                                _savePreferences();
                              },
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("Tanpa Pāli"),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Opsi Ukuran Font
                    Text(
                      "Ukuran Teks",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: getBtnStyle(false),
                            icon: const Icon(Icons.remove, size: 18),
                            label: const Text("Kecil"),
                            onPressed: () {
                              setState(
                                () => _fontSize = (_fontSize - 2).clamp(
                                  12.0,
                                  30.0,
                                ),
                              );
                              _savePreferences();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: getBtnStyle(false),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Reset"),
                            onPressed: () {
                              setState(() => _fontSize = 16.0);
                              _savePreferences();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: getBtnStyle(false),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Besar"),
                            onPressed: () {
                              setState(
                                () => _fontSize = (_fontSize + 2).clamp(
                                  12.0,
                                  30.0,
                                ),
                              );
                              _savePreferences();
                            },
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
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ReaderTheme theme,
    Color previewColor,
    Color textColor,
    String label,
    VoidCallback onRefresh, // ✅ PARAMETER BARU
  ) {
    final bool isSelected = _readerTheme == theme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        // 1. Update State Halaman Utama (Background berubah)
        setState(() => _readerTheme = theme);
        _savePreferences();

        // 2. Update State Modal (Biar Ceklis muncul/pindah!)
        onRefresh();
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: previewColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: isSelected
                ? Icon(Icons.check, color: textColor, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? primaryColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchMatch {
  final int listIndex;
  final int matchIndexInSeg;
  SearchMatch(this.listIndex, this.matchIndexInSeg);
}

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
