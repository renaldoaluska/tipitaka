import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipitaka/screens/menu_page.dart';
import 'package:tipitaka/screens/suttaplex.dart';
import 'package:tipitaka/services/sutta.dart';
import 'package:tipitaka/styles/nikaya_style.dart';
import '../core/theme/theme_manager.dart';
import '../core/utils/system_ui_helper.dart';
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
  final ThemeManager _tm = ThemeManager();
  double _horizontalPadding = 16.0;
  // --- NAV CONTEXT & STATE ---
  late bool _hasNavigatedBetweenSuttas; // ✅ 3. Ubah jadi 'late' (hapus = false)
  String? _parentVaggaId;
  bool _isSearchActive = false; // 🔥 TAMBAH INI BUAT DETEKSI SEARCH

  bool _isFirst = false;
  bool _isLast = false;
  bool _isLoading = false;
  bool _connectionError = false;

  bool _isHtmlParsed = false;
  RegExp? _cachedSearchRegex;
  ViewMode _viewMode = ViewMode.lineByLine;
  double _fontSize = 16.0;

  double _lineHeight = 1.6; // Default enak baca
  String _fontType = 'sans'; // 'sans' (Varta) atau 'serif' (Lora)
  String? get _currentFontFamily {
    return _fontType == 'serif'
        ? GoogleFonts.notoSerif().fontFamily
        : GoogleFonts.inter().fontFamily;
  }

  // 🔥 FUNGSI SAKTI BUAT PALI FUZZY SEARCH
  RegExp _createPaliRegex(String query) {
    // 🔥 FIX: Hapus simbol < dan > biar user gak bisa search tag HTML
    final cleanQuery = query.replaceAll(RegExp(r'[<>]'), '');

    final buffer = StringBuffer();
    for (int i = 0; i < cleanQuery.length; i++) {
      // Pakai cleanQuery
      final char = cleanQuery[i].toLowerCase();
      switch (char) {
        case 'a':
          buffer.write('(?:a|ā)');
          break;
        case 'i':
          buffer.write('(?:i|ī)');
          break;
        case 'u':
          buffer.write('(?:u|ū)');
          break;
        case 'm':
          buffer.write('(?:m|ṁ|ṃ)');
          break;
        case 'n':
          buffer.write('(?:n|ṇ|ñ|ṅ)');
          break;
        case 't':
          buffer.write('(?:t|ṭ)');
          break;
        case 'd':
          buffer.write('(?:d|ḍ)');
          break;
        case 'l':
          buffer.write('(?:l|ḷ)');
          break;
        default:
          // 🔥 INI PENYELAMATNYA:
          // Mengubah simbol regex kayak '(', '[', '*', '?' jadi teks biasa.
          // Jadi kalau user ketik '(', aplikasi gak crash.
          buffer.write(RegExp.escape(char));
      }
    }
    return RegExp(buffer.toString(), caseSensitive: false);
  }

  // ✅ Variabel info Footer

  final Map<int, GlobalKey> _searchKeys = {}; // 🔥 SIMPAN KEY DISINI

  // --- STATE PENCARIAN ---
  final TextEditingController _searchController = TextEditingController();
  final List<SearchMatch> _allMatches = [];
  int _currentMatchIndex = 0;
  Timer? _debounce;

  // --- SCROLL CONTROLLER ---
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // 🔥 AUTO-HIDE UI STATE
  bool _isBottomMenuVisible = true;
  //Timer? _autoHideTimer;

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
    //final tm = ThemeManager();

    switch (_readerTheme) {
      // --- TERANG 1 (Standard: Full ThemeManager) ---
      case ReaderTheme.light:
        final t = _tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': t.colorScheme.onSurface, // ✅ Hitam (Standard)
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor, // 👇 WARNA PALI (Coklat Tua Klasik)
          'pali': const Color(0xFF8B4513),
        };

      // --- TERANG 2 (Soft: Bg ThemeManager, Teks Abu) ---
      case ReaderTheme.light2:
        final t = _tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': const Color(0xFF424242), // ✨ Custom: Abu Tua Soft
          'note': const Color(0xFF9E9E9E),
          'card': uiCardColor,
          'icon': uiIconColor, // 👇 WARNA PALI (Coklat Kemerahan Soft)
          'pali': const Color(0xFFA1887F),
        };

      // --- SEPIA (Full Custom) ---
      case ReaderTheme.sepia:
        return {
          'bg': const Color(0xFFF4ECD8), // ✨ Custom: Krem
          'text': const Color(0xFF5D4037), // ✨ Custom: Coklat
          'note': const Color(0xFF8D6E63),
          'card': uiCardColor,
          'icon': uiIconColor, // 👇 WARNA PALI (Coklat Tanah - Kontras di Krem)
          'pali': const Color(0xFF795548),
        };

      // --- GELAP 1 (Standard: Full ThemeManager) ---
      case ReaderTheme.dark:
        final t = _tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': t.colorScheme.onSurface, // ✅ Putih (Standard)
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor, // 👇 WARNA PALI (Emas Pudar - Elegan di Gelap)
          'pali': const Color(0xFFD4A574),
        };

      // --- GELAP 2 (Soft: Bg ThemeManager, Teks Abu) ---
      case ReaderTheme.dark2:
        final t = _tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor, // ✅ Ngikut ThemeManager
          'text': const Color(0xFFB0BEC5), // ✨ Custom: Abu Kebiruan
          'note': const Color(0xFF757575),
          'card': uiCardColor,
          'icon': uiIconColor,
          // ✅ WARNA BARU: Dusty Sand
          // Tetap nuansa coklat, tapi kadar saturasi-nya diturunin biar "dingin"
          // Mirip transisi Light1 -> Light2.
          'pali': const Color(0xFFC5B6A6),
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

    // 🔥 DISABLE AUTO-HIDE (Pakai Tap-to-Toggle aja)
    // _itemPositionsListener.itemPositions.addListener(_handleScrollChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearMaterialBanners();

      // 🔥 HINT: Tap to hide UI (cuma muncul sekali)
      /*Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text("Ketuk layar untuk sembunyikan kontrol"),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      });*/
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
      _horizontalPadding = prefs.getDouble('horizontal_padding') ?? 16.0;
      // ✅ 3. LOAD LINE HEIGHT & FONT
      _lineHeight = prefs.getDouble('line_height') ?? 1.6;
      _fontType = prefs.getString('font_type') ?? 'sans';

      // 🔥 LOAD BOTTOM MENU VISIBILITY
      _isBottomMenuVisible = prefs.getBool('bottom_menu_visible') ?? true;

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
    await prefs.setDouble('horizontal_padding', _horizontalPadding);
    // Simpan index enum
    await prefs.setInt('reader_theme_index', _readerTheme.index);
    await prefs.setDouble('line_height', _lineHeight);
    await prefs.setString('font_type', _fontType);
    // 🔥 SIMPAN BOTTOM MENU STATE
    await prefs.setBool('bottom_menu_visible', _isBottomMenuVisible);
  }

  List<InlineSpan> _parseHtmlToSpansWithHighlight(
    String htmlText,
    TextStyle baseStyle,
    int listIndex,
    bool isPali,
  ) {
    if (htmlText.isEmpty) return [];

    // ❌ HAPUS INI: Jangan inject di string mentah lagi
    // final htmlWithHighlight = _injectSearchHighlights(...)

    // ✅ PAKAI RAW HTML LANGSUNG
    final unescape = HtmlUnescape();
    final spans = <InlineSpan>[];

    // Regex Tag (Sama kayak tadi)
    final tagRegex = RegExp(
      r'<(/)?(em|i|b|strong|span)([^>]*)>', // Note: x-highlight udah gak perlu dideteksi di sini
      caseSensitive: false,
    );

    int lastIndex = 0;
    List<TextStyle> styleStack = [baseStyle];

    // Kita butuh counter lokal untuk sinkronisasi dengan SearchMatch
    int localMatchCounter = 0;

    for (final match in tagRegex.allMatches(htmlText)) {
      if (match.start > lastIndex) {
        final plainText = htmlText.substring(lastIndex, match.start);

        // 🔥 DISINI MAGIC-NYA:
        // Kita decode dulu teksnya, BARU kita cari highlight-nya
        if (plainText.isNotEmpty) {
          final decodedText = unescape.convert(plainText);

          // Helper function buat mecah teks jadi (Normal - Highlight - Normal)
          final highlightedSpans = _buildHighlightedSpans(
            decodedText,
            styleStack.last, // Pakai style tumpukan saat ini (misal lagi Bold)
            listIndex,
            isPali,
            localMatchCounter, // Oper counter saat ini
          );

          spans.addAll(highlightedSpans.spans);
          localMatchCounter = highlightedSpans.newCounter; // Update counter
        }
      }

      // --- LOGIC PARSING TAG (Sama kayak sebelumnya) ---
      final isClosing = match.group(1) == '/';
      final tagName = match.group(2)?.toLowerCase();

      if (!isClosing) {
        final parentStyle = styleStack.last;
        TextStyle newStyle = parentStyle;

        if (tagName == 'b' || tagName == 'strong') {
          newStyle = parentStyle.copyWith(fontWeight: FontWeight.bold);
        } else if (tagName == 'em' || tagName == 'i') {
          newStyle = parentStyle.copyWith(fontStyle: FontStyle.italic);
        }
        // Note: span/color logic bisa ditambah disini kalau perlu

        styleStack.add(newStyle);
      } else {
        if (styleStack.length > 1) {
          styleStack.removeLast();
        }
      }

      lastIndex = match.end;
    }

    // Render sisa teks
    if (lastIndex < htmlText.length) {
      final remainingText = htmlText.substring(lastIndex);
      final decodedText = unescape.convert(remainingText);

      final highlightedSpans = _buildHighlightedSpans(
        decodedText,
        styleStack.last,
        listIndex,
        isPali,
        localMatchCounter,
      );
      spans.addAll(highlightedSpans.spans);
    }

    return spans;
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

  void _jumpToResult(int index) {
    if (!mounted || _allMatches.isEmpty) return;

    final safeIndex = index.clamp(0, _allMatches.length - 1);
    setState(() {
      _currentMatchIndex = safeIndex;
    });

    final targetRow = _allMatches[safeIndex].listIndex;
    final isSegmented = widget.textData?["segmented"] == true;

    if (_itemScrollController.isAttached) {
      if (isSegmented) {
        // --- MODE SEGMENTED (Tetap Scroll Biasa) ---
        // Karena item pendek, scroll biasa udah enak & kebaca semua
        _itemScrollController.scrollTo(
          index: targetRow,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.2, // Posisi agak atas (sweet spot)
        );
      } else {
        // --- MODE HTML / NON-SEGMENTED (Jururs Sat-Set) ---

        // 1. JUMP (Teleport): Langsung pindah ke paragraf target tanpa animasi.
        // Ini ngilangin efek "scroll panjang" yang bikin pusing.
        _itemScrollController.jumpTo(
          index: targetRow,
          alignment: 0.1, // Taruh di bagian atas layar
        );

        // 2. ADJUST (Geser Halus): Langsung pas-in kata ke tengah layar.
        // Delay dikit banget (50ms) cuma buat nunggu rendering kelar.
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          final key = _searchKeys[safeIndex];

          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 300), // Geser haluuus
              alignment: 0.5, // Pas-in di tengah-tengah mata
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  final List<String> _htmlSegments = [];

  void _parseHtmlAndGenerateTOC(String rawHtml) {
    // ✅ 1. Ekstrak konten <footer> dan HAPUS dari rawHtml
    try {
      final footerRegex = RegExp(
        r'<footer>(.*?)</footer>',
        caseSensitive: false,
        dotAll: true,
      );
      final match = footerRegex.firstMatch(rawHtml);
      if (match != null) {
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

  // 🔥 FINAL FIX: Handle "melihat</span> Dhamma" (tags di tengah search phrase)
  String _injectSearchHighlights(
    String content,
    int listIndex,
    bool isPaliTarget,
  ) {
    if (_searchController.text.length < 2) return content;
    final searchRegex = _cachedSearchRegex;
    if (searchRegex == null) return content;

    try {
      // 1. Decode HTML entities (& nbsp; → spasi, & amp; → &, dll)
      final unescape = HtmlUnescape();
      final decoded = unescape.convert(content);

      // 2. Strip tags untuk matching
      final cleanText = decoded.replaceAll(RegExp(r'<[^>]+>'), '');

      // 3. Find all matches di clean text
      final matches = searchRegex.allMatches(cleanText).toList();
      if (matches.isEmpty) return content;

      // 4. Build position map: clean index → original index
      final Map<int, int> cleanToOriginal = {};
      int cleanIdx = 0;
      bool insideTag = false;

      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] == '<') {
          insideTag = true;
        } else if (decoded[i] == '>') {
          insideTag = false;
          continue;
        }

        if (!insideTag) {
          cleanToOriginal[cleanIdx] = i;
          cleanIdx++;
        }
      }

      // 🔥 ADD: Map untuk end position (next character after last match char)
      // Ini biar kita bisa akurat ambil sampai akhir match
      cleanToOriginal[cleanIdx] = decoded.length;

      // 5. Inject highlights (dari belakang agar posisi tidak bergeser)
      String result = decoded;

      for (int i = matches.length - 1; i >= 0; i--) {
        final match = matches[i];

        // Check if active
        bool isActive = false;
        if (_allMatches.isNotEmpty && _currentMatchIndex < _allMatches.length) {
          final activeMatch = _allMatches[_currentMatchIndex];
          if (activeMatch.listIndex == listIndex &&
              activeMatch.isPali == isPaliTarget &&
              activeMatch.localIndex == i) {
            isActive = true;
          }
        }

        // Map clean positions ke original positions
        final origStart = cleanToOriginal[match.start] ?? 0;
        // 🔥 FIX: match.end sudah exclusive, jadi langsung ambil posisi tersebut
        final origEnd = cleanToOriginal[match.end] ?? decoded.length;

        // Extract segment (termasuk tag HTML di dalamnya jika ada)
        final segment = result.substring(origStart, origEnd);

        // Build highlight wrapper
        final bgColor = isActive ? "#FF8C00" : "#FFFF00";
        final color = isActive ? "white" : "black";
        final activeAttr = isActive ? 'data-active="true"' : '';

        final wrapper =
            "<x-highlight style='background-color: $bgColor; "
            "color: $color; font-weight: bold; border-radius: 4px; "
            "padding: 0 2px;' $activeAttr>$segment</x-highlight>";

        // Replace (inject dari belakang jadi posisi depan tidak berubah)
        result =
            result.substring(0, origStart) +
            wrapper +
            result.substring(origEnd);
      }

      return result;
    } catch (e) {
      debugPrint("❌ Highlight error: $e");
      return content; // Fallback: return original
    }
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
        // ✅ Use 'ctx' NOT 'context'
        final colorScheme = Theme.of(ctx).colorScheme; // ✅ FIXED

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
                              text: "Ingin ganti versi teks? Gunakan ",
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

    if (authorUid == null) return;

    final targetLang = segmented
        ? widget.lang
        : navTarget["lang"]?.toString() ?? widget.lang;

    if (!mounted) return; // ✅ Check sebelum setState

    setState(() {
      _isLoading = true;
      _connectionError = false;
    });

    try {
      final data = await SuttaService.fetchFullSutta(
        uid: targetUid,
        authorUid: authorUid,
        lang: targetLang,
        segmented: segmented,
        siteLanguage: "id",
      );

      if (!mounted) return; // ✅ CRITICAL: Check after async

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

      // _navigateToSutta() - Line ~1048
      await _processVaggaTracking(mergedData, targetUid);

      if (!mounted) return; // ✅ ADD THIS
      if (!context.mounted) return; // ✅ ADD THIS

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
            entryPoint: widget.entryPoint,
            isNavigated: true,
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
      if (!mounted) return;

      if (e is SocketException || e.toString().contains("SocketException")) {
        // 🔥 FIX SNACKBAR ERROR KONEKSI
        final bottomMargin = _getSnackBarBottomMargin();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Gagal memuat halaman. Periksa koneksi internet.",
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            // Margin dinamis juga
            margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
          ),
        );
      } else {
        _replaceToRoute('/suttaplex/$targetUid', slideFromLeft: isPrevious);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 HELPER BARU: Hitung posisi notif biar gak ketutupan menu
  double _getSnackBarBottomMargin() {
    // Margin dasar dari bawah layar
    double margin = 20.0;

    // Cek Menu Bawah
    if (_isBottomMenuVisible) {
      // Tinggi Menu (~60px) + Toggle (16px) + Buffer
      margin += 80.0;
    } else {
      // Tinggi Toggle doang (Super Ceper 16px)
      margin += 16.0;
    }

    return margin;
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
          TextSpan(text: "Anda berada di awal ($acronym). Gunakan tombol "),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_back_rounded,
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
          TextSpan(
            text: "Anda telah mencapai akhir ($acronym). Gunakan tombol ",
          ),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_back_rounded,
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

    // 🔥 AMBIL MARGIN DINAMIS
    final bottomMargin = _getSnackBarBottomMargin();

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

        // 🔥 UPDATE MARGIN BIAR GAK KETUTUP MENU
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin, // <--- INI KUNCINYA
        ),

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
    // final bool isLandscape =
    //    MediaQuery.orientationOf(context) == Orientation.landscape;
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
                      fontFamily: _currentFontFamily,
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
            //  child:
            // Transform.translate(
            // ✅ INI DIA: Geser ke atas (Superscript)
            //  offset: const Offset(0, -1),
            child: Text(
              "[note]",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w100,
                // Ukuran font kecil (60% dari font utama)
                fontSize: fontSize * 0.6,
              ),
              //),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    //_autoHideTimer?.cancel();
    _searchController.dispose();
    _cachedSearchRegex = null;
    //_itemPositionsListener.itemPositions.removeListener(_handleScrollChange);
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

    // ✅ AMBIL WARNA DARI _themeColors YANG BARU DIUPDATE
    final colors = _themeColors;

    final mainTextColor = colors['text']!;

    // 👇 INI DIA PERUBAHANNYA: Ambil langsung dari key 'pali'
    final paliBodyColor = colors['pali']!;

    final headerColor = mainTextColor;

    // Kalau mode "Pali Only", judulnya pake warna teks biasa biar tegas.
    // Tapi kalau ada terjemahan, teks Pali-nya pake warna khusus Pali.
    final paliColor = isPaliOnly ? headerColor : paliBodyColor;

    final transBodyColor = mainTextColor;
    TextStyle paliStyle, transStyle;
    double topPadding, bottomPadding;

    if (isH1) {
      topPadding = 16.0;
      bottomPadding = 16.0;
      paliStyle = TextStyle(
        fontFamily: _currentFontFamily,
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
        fontFamily: _currentFontFamily,
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
        fontFamily: _currentFontFamily,
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
        fontFamily: _currentFontFamily,
        fontSize: isPaliOnly ? _fontSize : _fontSize * 0.8, // ← CONDITIONAL
        fontWeight: FontWeight.w500,
        color: paliColor,
        height: _lineHeight,
      );
      transStyle = TextStyle(
        fontFamily: _currentFontFamily,
        fontSize: _fontSize,
        fontWeight: FontWeight.normal,
        color: transBodyColor,
        height: _lineHeight,
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
    bool isPali, // ✅ Pastikan parameternya bool isPali
  ) {
    // 1. Inject tag <x-highlight>
    final contentWithHighlight = _injectSearchHighlights(
      text,
      listIndex,
      isPali,
    );

    return Html(
      data: contentWithHighlight,

      // 2. Extension buat render <x-highlight> jadi kotak warna
      extensions: [
        TagExtension(
          tagsToExtend: {"x-highlight"},
          builder: (extensionContext) {
            final attrs = extensionContext.attributes;
            final isGlobalActive = attrs['data-active'] == 'true';

            final key = GlobalKey();
            if (isGlobalActive) {
              if (_allMatches.isNotEmpty &&
                  _currentMatchIndex < _allMatches.length) {
                _searchKeys[_currentMatchIndex] = key;
              }
            }

            // 🔥 FIX: AMBIL UKURAN FONT DARI ELEMENT INDUKNYA (H1/H2/P)
            // Biar gak mengecil pas di-highlight di judul
            final style = extensionContext.styledElement?.style;
            double? currentFontSize = style?.fontSize?.value;

            // Fallback kalau null, pake ukuran default body
            currentFontSize ??= _fontSize;

            return Container(
              key: isGlobalActive ? key : null,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isGlobalActive ? Colors.orange : Colors.yellow,
                borderRadius: BorderRadius.circular(4),
              ),
              // Gunakan Transform buat benerin posisi teks yang kadang agak turun
              child: Transform.translate(
                offset: const Offset(0, 1),
                child: Text(
                  extensionContext.element!.text,
                  style: TextStyle(
                    color: isGlobalActive ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize:
                        currentFontSize, // 👈 PENTING: Ikutin ukuran induk
                    height: 1.0, // Reset line height biar kotaknya pas
                  ),
                ),
              ),
            );
          },
        ),
      ],

      // 3. Style standar (Header, Body, dll)
      style: {
        "body": Style(
          fontFamily: _currentFontFamily,
          fontSize: FontSize(baseStyle.fontSize ?? _fontSize),
          fontWeight: baseStyle.fontWeight,
          color: baseStyle.color,
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          lineHeight: LineHeight(_lineHeight),
          fontStyle: baseStyle.fontStyle,
        ),
        ".ref": Style(
          fontSize: FontSize.smaller,
          color: Colors.grey,
          textDecoration: TextDecoration.none,
          verticalAlign: VerticalAlign.sup,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          margin: Margins.only(right: 4),
          padding: HtmlPaddings.symmetric(horizontal: 2, vertical: 0),
          display: Display.inlineBlock,
        ),
        "header": Style(
          display: Display.block,
          margin: Margins.only(bottom: 20),
        ),
        "header ul": Style(
          listStyleType: ListStyleType.none,
          padding: HtmlPaddings.zero,
          margin: Margins.zero,
        ),
        "header li": Style(
          textAlign: TextAlign.center,
          color: Colors.grey,
          fontSize: FontSize.medium,
          fontWeight: FontWeight.bold,
          display: Display.block,
          margin: Margins.only(bottom: 4),
        ),
        ".division": Style(
          textAlign: TextAlign.center,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          display: Display.block,
          margin: Margins.symmetric(vertical: 12),
        ),
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
    final baseStyle = isTransEmpty
        ? config.transStyle.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          )
        : config.transStyle;

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
                Text.rich(
                  TextSpan(
                    style: baseStyle,
                    children: [
                      // ✅ FIX: Gunakan helper baru
                      if (isTransEmpty)
                        TextSpan(text: "...", style: baseStyle)
                      else
                        ..._parseHtmlToSpansWithHighlight(
                          trans,
                          baseStyle,
                          index,
                          false, // Translation only, jadi start dari 0
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

    final baseTransStyle = isTransEmpty
        ? config.transStyle.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          )
        : config.transStyle;

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
                // Pali text (sudah OK)
                _buildHtmlText(pali, finalPaliStyle, index, true),
                const SizedBox(height: 4),

                // Translation text
                if (!_isRootOnly)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: baseTransStyle,
                          children: [
                            // ✅ FIX: Gunakan helper baru yang support highlight
                            if (isTransEmpty)
                              TextSpan(text: "...", style: baseTransStyle)
                            else
                              ..._parseHtmlToSpansWithHighlight(
                                trans,
                                baseTransStyle,
                                index,
                                false, // ✅ Offset dari pali matches
                              ),

                            // Comment span (tidak berubah)
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
    // 1. CEK ORIENTASI
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    // 2. TENTUKAN FLEX
    final int paliFlex = 1;
    final int transFlex = isLandscape ? 1 : 2; // Landscape 50-50, Portrait 1:2

    final baseTransStyle = isTransEmpty
        ? config.transStyle.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          )
        : config.transStyle;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: config.topPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: paliFlex,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVerseNumber(config),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildHtmlText(pali, finalPaliStyle, index, true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: transFlex,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: baseTransStyle,
                        children: [
                          // ✅ FIX: Gunakan helper baru
                          if (isTransEmpty)
                            TextSpan(text: "...", style: baseTransStyle)
                          else
                            ..._parseHtmlToSpansWithHighlight(
                              trans,
                              baseTransStyle,
                              index,
                              true, // ✅ Offset dari pali matches
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
    //final mainColor = colors['text']!;
    //final subColor = colors['note']!; // atau colors['icon']
    final iconColor = colors['icon']!; // atau colors['icon']

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: iconColor),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
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
                // ✅ Validate data dulu
                final authorUid = widget.textData?["author_uid"]?.toString();
                if (authorUid == null || authorUid.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Data tidak lengkap untuk mencoba lagi"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _isLoading = true;
                  _connectionError = false;
                });

                _replaceToSutta(
                  widget.uid,
                  widget.lang,
                  authorUid: authorUid,
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
    if (widget.textData == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: const Center(child: Text("Data tidak tersedia")),
        ),
      );
    }

    // 1. Ambil palet warna
    final colors = _themeColors;
    final bgColor = colors['bg']!; // Ini warna dasar (Putih/Sepia/Hitam)
    final textColor = colors['text']!;
    final cardColor = Theme.of(context).colorScheme.surface;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    final metadata = _getMetadata();

    final String suttaTitle =
        widget.textData?["root_text"]?["title"] ??
        widget.textData?["translation"]?["title"] ??
        widget.uid;

    final String rawAcronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        "";
    final String acronym = normalizeNikayaAcronym(rawAcronym);

    final String rawBlurb = widget.textData?["suttaplex"]?["blurb"] ?? "";
    bool shouldShowBlurb = rawBlurb.isNotEmpty;

    final bool isError = widget.textData == null || widget.textData!.isEmpty;
    final bool isSegmented =
        !isError && (widget.textData!["segmented"] == true);

    // --- LOGIC SETUP DATA ---
    final Map<String, String> paliSegs;
    final Map<String, String> translationSegs;
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
      keysOrder = [];
    }

    Widget body;

    // Hitung Padding Atas
    final double topContentPadding = MediaQuery.of(context).padding.top + 80;

    // ✅ LOGIC BODY BUILDER
    if (_connectionError) {
      body = _buildNoInternetView();
    } else if (isError) {
      body = Center(
        child: Text("Teks tidak tersedia", style: TextStyle(color: textColor)),
      );
    } else if (isSegmented) {
      final commentarySegs = (widget.textData!["comment_text"] is Map)
          ? (widget.textData!["comment_text"] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : <String, String>{};

      body = RepaintBoundary(
        child: SelectionArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => notification.depth != 0,
            child: Scrollbar(
              thumbVisibility: false,
              thickness: 4,
              radius: const Radius.circular(8),
              child: ScrollablePositionedList.builder(
                physics: const BouncingScrollPhysics(),
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  topContentPadding,
                  _horizontalPadding,
                  (_isSearchActive ? 250 : (_isBottomMenuVisible ? 100 : 40)) +
                      MediaQuery.of(context).viewInsets.bottom,
                ),
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
            ),
          ),
        ),
      );
    } else if ((widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"))) {
      // NON-SEGMENTED HTML
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
      body = RepaintBoundary(
        child: SelectionArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => notification.depth != 0,
            child: Scrollbar(
              thumbVisibility: false,
              thickness: 4,
              radius: const Radius.circular(8),
              child: ScrollablePositionedList.builder(
                physics: const BouncingScrollPhysics(),
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  topContentPadding,
                  _horizontalPadding,
                  _isBottomMenuVisible ? 100 : 40,
                ),
                itemCount: _htmlSegments.length,
                itemBuilder: (context, index) {
                  String content = _injectSearchHighlights(
                    _htmlSegments[index],
                    index,
                    false,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Html(
                      data: content,
                      extensions: [
                        TagExtension(
                          tagsToExtend: {"x-highlight"},
                          builder: (extensionContext) {
                            final attrs = extensionContext.attributes;
                            final isGlobalActive =
                                attrs['data-active'] == 'true';
                            final key = GlobalKey();
                            if (isGlobalActive) {
                              if (_allMatches.isNotEmpty &&
                                  _currentMatchIndex < _allMatches.length) {
                                _searchKeys[_currentMatchIndex] = key;
                              }
                            }
                            final style = extensionContext.styledElement?.style;
                            double? currentFontSize = style?.fontSize?.value;
                            currentFontSize ??= _fontSize;

                            return Container(
                              key: isGlobalActive ? key : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isGlobalActive
                                    ? Colors.orange
                                    : Colors.yellow,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Transform.translate(
                                offset: const Offset(0, 1),
                                child: Text(
                                  extensionContext.element!.text,
                                  style: TextStyle(
                                    color: isGlobalActive
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: currentFontSize,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      style: {
                        "body": Style(
                          fontFamily: _currentFontFamily,
                          fontSize: FontSize(_fontSize),
                          lineHeight: LineHeight(_lineHeight),
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
                        ".ref": Style(
                          fontSize: FontSize.smaller,
                          color: Colors.grey,
                          textDecoration: TextDecoration.none,
                          verticalAlign: VerticalAlign.sup,
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          margin: Margins.only(right: 4),
                          padding: HtmlPaddings.symmetric(
                            horizontal: 2,
                            vertical: 0,
                          ),
                          display: Display.inlineBlock,
                        ),
                        "header": Style(
                          display: Display.block,
                          margin: Margins.only(bottom: 20),
                        ),
                        "header ul": Style(
                          listStyleType: ListStyleType.none,
                          padding: HtmlPaddings.zero,
                          margin: Margins.zero,
                        ),
                        "header li": Style(
                          textAlign: TextAlign.center,
                          color: Colors.grey,
                          fontSize: FontSize.medium,
                          fontWeight: FontWeight.bold,
                          display: Display.block,
                          margin: Margins.only(bottom: 4),
                        ),
                        "footer": Style(display: Display.none),
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    } else if (widget.textData!["root_text"] is Map &&
        !(widget.textData!["root_text"] as Map).containsKey("text")) {
      // PALI ONLY
      final paliOnlyMap = (widget.textData!["root_text"] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      final paliKeys = widget.textData!["keys_order"] is List
          ? List<String>.from(widget.textData!["keys_order"])
          : paliOnlyMap.keys.toList();

      body = RepaintBoundary(
        child: SelectionArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => notification.depth != 0,
            child: Scrollbar(
              thumbVisibility: false,
              thickness: 4,
              radius: const Radius.circular(8),
              child: ScrollablePositionedList.builder(
                physics: const BouncingScrollPhysics(),
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  topContentPadding,
                  _horizontalPadding,
                  _isBottomMenuVisible ? 100 : 40,
                ),
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
            ),
          ),
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
        if (didPop) return;
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          Navigator.of(context).pop();
          return;
        }
        final navigator = Navigator.of(context);
        final allow = await _handleBackReplace();
        if (allow && mounted) {
          navigator.pop(result);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          key: _scaffoldKey,
          appBar: null,
          backgroundColor: bgColor,
          endDrawer: _tocList.isNotEmpty
              ? Drawer(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(24),
                    ),
                  ),
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          MediaQuery.of(context).padding.top + 20,
                          16,
                          20,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Daftar Isi",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          itemCount: _tocList.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = _tocList[index];
                            final level = item['type'] as int;
                            final isH1 = level == 1;
                            final isH2 = level == 2;
                            final double indent = isH1
                                ? 4.0
                                : (isH2 ? 16.0 : 32.0);
                            final FontWeight weight = isH1
                                ? FontWeight.w800
                                : (isH2 ? FontWeight.w600 : FontWeight.normal);
                            final Color textColor = isH1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (!mounted) return;
                                  final targetIndex = item['index'] as int;

                                  int maxIndex;
                                  if (isSegmented && keysOrder.isNotEmpty) {
                                    maxIndex = keysOrder.length - 1;
                                  } else if (_htmlSegments.isNotEmpty) {
                                    maxIndex = _htmlSegments.length - 1;
                                  } else {
                                    return;
                                  }

                                  if (targetIndex < 0 ||
                                      targetIndex > maxIndex) {
                                    return;
                                  }
                                  if (!mounted ||
                                      !_itemScrollController.isAttached) {
                                    return;
                                  }

                                  try {
                                    _itemScrollController.scrollTo(
                                      index: targetIndex,
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    );
                                  } catch (e) {
                                    debugPrint('❌ TOC scroll error: $e');
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    indent + 12,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isH1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 7,
                                            right: 12,
                                          ),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.4),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          item['title'],
                                          style: TextStyle(
                                            fontSize: isH1 ? 16 : 14,
                                            fontWeight: weight,
                                            color: textColor,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
              // 1. KONTEN UTAMA (Full Screen)
              body,

              // 🔥 STATUS BAR COVER (PENUTUP SOLID)
              // Ini biar teks gak kelihatan "jalan" di belakang jam/baterai.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).padding.top,
                child: Container(
                  color: bgColor, // Pake warna tema halaman (Sepia/Dark/Light)
                ),
              ),

              // 2. HEADER: Floating Pill Style
              // 2. HEADER: Floating Pill Style
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.85),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: _isLoading
                                      ? null
                                      : () async {
                                          final navigator = Navigator.of(
                                            context,
                                          );
                                          final allow =
                                              await _handleBackReplace();
                                          if (allow && mounted) navigator.pop();
                                        },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_back,
                                      size: 20,
                                      color: iconColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.textData?["suttaplex"]?["original_title"] ??
                                      suttaTitle,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: iconColor,
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
                                        style: TextStyle(color: iconColor),
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
                                                  "body": Style(
                                                    color: iconColor,
                                                  ),
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
                                                color: iconColor,
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
                                          ],
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
                              ),
                              if (acronym.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  //decoration: BoxDecoration(
                                  //color: Theme.of(context)
                                  // .colorScheme
                                  // .surfaceContainerHighest
                                  //   .withValues(alpha: 0.5),
                                  // 🔥 UPDATE DISINI: Dulu 4, sekarang 8 biar melengkung manis
                                  // borderRadius: BorderRadius.circular(10),
                                  // ),
                                  child: Text(
                                    rawAcronym,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: getNikayaColor(
                                        normalizeNikayaAcronym(acronym),
                                      ),
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

              // 3. BOTTOM MENU: Integrated Glass Style (Layar - 48)
              if (!_connectionError && !isError)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: MediaQuery.of(context).size.width > 600
                          ? 500
                          : MediaQuery.of(context).size.width - 48,

                      margin: EdgeInsets.zero,

                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                          bottom: Radius.zero,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),

                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                          bottom: Radius.zero,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                          child: Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.85),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isBottomMenuVisible =
                                            !_isBottomMenuVisible;
                                      });
                                      _savePreferences();
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 16,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        _isBottomMenuVisible
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.keyboard_arrow_up_rounded,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  height: _isBottomMenuVisible ? null : 0,
                                  child: SingleChildScrollView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: _buildFloatingActions(isSegmented),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: null,
        ),
      ),
    );
  }

  // ============================================
  // UPDATED FLOATING ACTIONS (CONSISTENT DISABLED STATE)
  // ============================================
  Widget _buildFloatingActions(bool isSegmented) {
    // 1. Cek Logic Navigasi
    final isTematik = widget.entryPoint == "tematik";
    final showToc = _tocList.isNotEmpty && !_connectionError;

    // 2. Deteksi Layout
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.shortestSide >= 600;
    final isPhoneLandscape = isLandscape && !isTablet;

    // 3. Styling Variabel
    final systemScheme = Theme.of(context).colorScheme;
    final iconColor = systemScheme.onSurface;
    final activeColor = systemScheme.primary;
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    // Styling Compact vs Normal
    final double internalPaddingH = isPhoneLandscape ? 4.0 : 6.0;
    final double internalPaddingV = isPhoneLandscape ? 2.0 : 4.0;
    final double iconSize = isPhoneLandscape ? 20.0 : 24.0;
    final double separatorHeight = isPhoneLandscape ? 16.0 : 24.0;

    Widget buildBtn({
      required IconData icon,
      required VoidCallback? onTap,
      bool isActive = false,
      String tooltip = "",
      Color? customIconColor,
    }) {
      Color finalColor;
      // 🔥 LOGIC VISUAL DISABLED: Kalau onTap NULL, warnanya jadi abu pudar
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
              padding: EdgeInsets.symmetric(
                horizontal: isPhoneLandscape ? 8 : 12,
                vertical: isPhoneLandscape ? 8 : 12,
              ),
              decoration: isActive
                  ? BoxDecoration(
                      color: activeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Icon(icon, color: finalColor, size: iconSize),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: internalPaddingH,
        vertical: internalPaddingV,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // --- PREV ---
          buildBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: "Sebelumnya",
            customIconColor: (_isFirst || isTematik)
                ? disabledClickableColor
                : null,
            // Logic prev sudah benar (cek _isLoading)
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
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- TOOLS ---
          buildBtn(
            icon: Icons.translate_rounded,
            tooltip: "Info Sutta & Terjemahan",
            // Translate sudah benar
            onTap: _isLoading ? null : _openSuttaplexModal,
          ),
          buildBtn(
            icon: Icons.search_rounded,
            tooltip: "Cari Teks",
            // Search sudah benar
            onTap: _isLoading ? null : _openSearchModal,
          ),

          // 🔥 FIX: SETTINGS (Tt)
          buildBtn(
            icon: Icons.text_fields_rounded,
            tooltip: "Tampilan",
            // SEKARANG CEK _isLoading JUGA
            onTap: _isLoading
                ? null
                : () => _openViewSettingsModal(isSegmented),
          ),

          // 🔥 FIX: DAFTAR ISI (List)
          if (showToc)
            buildBtn(
              icon: Icons.list_alt_rounded,
              tooltip: "Daftar Isi",
              // SEKARANG CEK _isLoading JUGA
              onTap: _isLoading
                  ? null
                  : () => _scaffoldKey.currentState?.openEndDrawer(),
            ),

          Container(
            width: 1,
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- NEXT ---
          buildBtn(
            icon: Icons.chevron_right_rounded,
            tooltip: "Selanjutnya",
            customIconColor: (_isLast || isTematik)
                ? disabledClickableColor
                : null,
            // Logic next sudah benar
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

  // ============================================
  // UPDATED SEARCH MODAL (KEYBOARD SAFE)
  // ============================================
  void _openSearchModal() {
    setState(() {
      _isSearchActive = true;
      // 🔥 Paksa show UI saat search
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Wajib true buat handle keyboard
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Ambil tinggi keyboard
            final double keyboardHeight = MediaQuery.of(
              context,
            ).viewInsets.bottom;

            return Padding(
              // Padding bawah responsif keyboard
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // --- BARIS INPUT & NAVIGASI (YANG HILANG KEMAREN) ---
                        Row(
                          children: [
                            // 1. INPUT TEXT FIELD (DIBALIKIN)
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus:
                                    true, // Biar pas dibuka langsung ngetik
                                decoration: InputDecoration(
                                  hintText: "Cari kata...",
                                  prefixIcon: const Icon(Icons.search),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // Tombol X buat hapus text
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _cachedSearchRegex = null;
                                              _allMatches.clear();
                                            });
                                            setSheetState(() {});
                                          },
                                        )
                                      : null,
                                ),
                                // Di dalam TextField onChanged:
                                onChanged: (val) {
                                  if (_debounce?.isActive ?? false) {
                                    _debounce!.cancel();
                                  }
                                  _debounce = Timer(
                                    const Duration(milliseconds: 500),
                                    () {
                                      if (!mounted) return;

                                      // 1. Reset
                                      _allMatches.clear();
                                      _currentMatchIndex = 0;

                                      if (val.trim().length < 2) {
                                        setState(
                                          () => _cachedSearchRegex = null,
                                        );
                                        setSheetState(() {});
                                        return;
                                      }

                                      // 2. Bikin Regex
                                      // final regex = RegExp(
                                      //   RegExp.escape(val.trim()),
                                      // caseSensitive: false,
                                      //);
                                      //setState(
                                      //  () => _cachedSearchRegex = regex,
                                      //);
                                      // 🔥 BARU: Pake Helper Fuzzy Pali
                                      final regex = _createPaliRegex(
                                        val.trim(),
                                      );

                                      setState(
                                        () => _cachedSearchRegex = regex,
                                      );

                                      // 3. SCAN LOGIC
                                      final isSegmented =
                                          widget.textData?["segmented"] == true;

                                      if (isSegmented &&
                                          widget.textData?["keys_order"]
                                              is List) {
                                        final keys = List<String>.from(
                                          widget.textData!["keys_order"],
                                        );
                                        final transMap =
                                            widget.textData?["translation_text"]
                                                as Map? ??
                                            {};
                                        final rootMap =
                                            widget.textData?["root_text"]
                                                as Map? ??
                                            {};

                                        // 🔥 1. TENTUKAN EFFECTIVE VIEW MODE
                                        // (Logika ini meniru _buildSegmentedItem biar sinkron sama yang dilihat mata)
                                        ViewMode effectiveViewMode = _viewMode;
                                        // Kalau teks ini cuma punya Pali (Gak ada terjemahan), paksa mode LineByLine biar Pali tetep dicari
                                        if (_isRootOnly) {
                                          effectiveViewMode =
                                              ViewMode.lineByLine;
                                        }

                                        for (int i = 0; i < keys.length; i++) {
                                          final key = keys[i];

                                          // 🔥 2. BUNGKUS PENCARIAN PALI
                                          // Cuma cari di Pali kalau modenya BUKAN Translation Only
                                          if (effectiveViewMode !=
                                              ViewMode.translationOnly) {
                                            // A. Pali
                                            String paliTxt =
                                                rootMap[key]?.toString() ?? "";
                                            paliTxt = paliTxt.replaceAll(
                                              RegExp(r'<[^>]*>'),
                                              '',
                                            );
                                            int localPali = 0;
                                            for (final _ in regex.allMatches(
                                              paliTxt,
                                            )) {
                                              _allMatches.add(
                                                SearchMatch(i, localPali, true),
                                              ); // isPali: true
                                              localPali++;
                                            }
                                          }

                                          // B. Trans (Selalu dicari kecuali kasus aneh tertentu, tapi defaultnya cari aja)
                                          String transTxt =
                                              transMap[key]?.toString() ?? "";
                                          transTxt = transTxt.replaceAll(
                                            RegExp(r'<[^>]*>'),
                                            '',
                                          );
                                          int localTrans = 0;
                                          for (final _ in regex.allMatches(
                                            transTxt,
                                          )) {
                                            _allMatches.add(
                                              SearchMatch(i, localTrans, false),
                                            ); // isPali: false
                                            localTrans++;
                                          }
                                        }
                                      } else {
                                        // Logic Legacy
                                        for (
                                          int i = 0;
                                          i < _htmlSegments.length;
                                          i++
                                        ) {
                                          String txt = _htmlSegments[i]
                                              .replaceAll(
                                                RegExp(r'<[^>]*>'),
                                                '',
                                              );
                                          int localCounter = 0;
                                          for (final _ in regex.allMatches(
                                            txt,
                                          )) {
                                            _allMatches.add(
                                              SearchMatch(
                                                i,
                                                localCounter,
                                                false,
                                              ),
                                            );
                                            localCounter++;
                                          }
                                        }
                                      }

                                      // 4. Update UI (VERSI BERSIH, HAPUS DUPLIKAT DI BAWAHNYA)
                                      setState(() {});
                                      setSheetState(() {});

                                      if (_allMatches.isNotEmpty) {
                                        _jumpToResult(0);
                                      }
                                    },
                                  );

                                  setSheetState(() {});
                                },
                              ),
                            ),

                            const SizedBox(width: 8),

                            // 2. TOMBOL NAVIGASI (UP/DOWN)
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              tooltip: "Sebelumnya",
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      int newIndex = _currentMatchIndex - 1;
                                      if (newIndex < 0) {
                                        newIndex = _allMatches.length - 1;
                                      }
                                      _jumpToResult(newIndex);
                                      setSheetState(() {});
                                    },
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              tooltip: "Selanjutnya",
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      int newIndex = _currentMatchIndex + 1;
                                      if (newIndex >= _allMatches.length) {
                                        newIndex = 0;
                                      }
                                      _jumpToResult(newIndex);
                                      setSheetState(() {});
                                    },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // --- INDIKATOR HASIL ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _allMatches.isEmpty
                                  ? (_searchController.text.trim().length < 2
                                        ? "Menunggu input..." // Kalau belum ngetik / kurang dari 2 huruf
                                        : "Tidak ditemukan") // Kalau udah ngetik tapi gak ada hasil
                                  : "${_currentMatchIndex + 1} dari ${_allMatches.length} hasil",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                // Warnain merah dikit kalau not found biar jelas
                                color:
                                    (_allMatches.isEmpty &&
                                        _searchController.text.trim().length >=
                                            2)
                                    ? Theme.of(context).colorScheme.error
                                    : (_allMatches.isEmpty
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary),
                              ),
                            ),

                            // Info tambahan (Opsional)
                            if (_allMatches.isNotEmpty)
                              Text(
                                "Tekan panah untuk navigasi",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _debounce?.cancel();
      // Jangan clear controller text disini kalau mau user balik lagi search-nya masih ada
      // Tapi biasanya di clear biar bersih:
      setState(() {
        _isSearchActive = false; // Balik normal
        _searchController.clear();
        _allMatches.clear();
        _cachedSearchRegex = null; // Hapus highlight pas modal ditutup
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

  // ============================================
  // SETTINGS MODAL (WITH SCROLL INDICATOR)
  // ============================================
  void _openViewSettingsModal(bool isSegmented) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final readerColors = _themeColors;

            // 🔥 1. DETEKSI LAYAR
            final size = MediaQuery.of(context).size;
            final isLandscape = size.width > size.height;
            final isTablet = size.shortestSide >= 600;

            // Tampilkan preview HANYA JIKA: (Portrait) ATAU (Tablet Landscape)
            final bool showPreview = !isLandscape || isTablet;

            final ScrollController modalScrollController = ScrollController();

            ButtonStyle getFontBtnStyle(bool isActive) {
              return OutlinedButton.styleFrom(
                backgroundColor: isActive ? colorScheme.primaryContainer : null,
                side: BorderSide(
                  color: isActive
                      ? colorScheme.primary
                      : Colors.grey.withValues(alpha: 0.3),
                ),
                foregroundColor: isActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              );
            }

            Widget buildSectionHeader(String title) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            // --- LOGIC BUILD PREVIEW CONTENT ---
            Widget buildPreviewContent() {
              final paliText =
                  "Namo tassa bhagavato arahato sammāsambuddhassa.";
              final transText =
                  "Terpujilah Sang Bhagavā, Yang Mahasuci, Yang Telah Mencapai Penerangan Sempurna.";

              final paliStyle = TextStyle(
                fontFamily: _currentFontFamily,
                fontSize: _fontSize * 0.8,
                height: _lineHeight,
                fontWeight: FontWeight.w500,
                color: readerColors['pali'],
              );

              final transStyle = TextStyle(
                fontFamily: _currentFontFamily,
                fontSize: _fontSize,
                height: _lineHeight,
                color: readerColors['text'],
              );

              if (_isRootOnly) {
                return Text(paliText, style: transStyle);
              }

              if (!isSegmented) {
                return Text(transText, style: transStyle);
              }

              switch (_viewMode) {
                case ViewMode.translationOnly:
                  return Text(transText, style: transStyle);
                case ViewMode.sideBySide:
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(paliText, style: paliStyle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(transText, style: transStyle),
                      ),
                    ],
                  );
                case ViewMode.lineByLine:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paliText, style: paliStyle),
                      const SizedBox(height: 4),
                      Text(transText, style: transStyle),
                    ],
                  );
              }
            }

            return Container(
              // 🔥 FIX: Padding Bawah dikurangi (24 -> 16) biar gak bolong
              padding: const EdgeInsets.fromLTRB(24, 12, 4, 0),
              constraints: BoxConstraints(
                // Max height disamain sama html.dart (0.85)
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- HEADER (FIXED/STICKY) ---
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Pengaturan Baca",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            color: colorScheme.onSurface,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔥 STICKY LIVE PREVIEW BOX
                  if (showPreview) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 20, bottom: 16),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: readerColors['bg'],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    top: 12,
                                  ),
                                  child: Text(
                                    "PRATINJAU TAMPILAN",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: readerColors['note'],
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: _horizontalPadding < 16
                                        ? 16
                                        : _horizontalPadding,
                                  ),
                                  child: buildPreviewContent(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // --- KONTEN SCROLLABLE (SETTINGS) ---
                  Flexible(
                    fit: FlexFit.loose,
                    child: Scrollbar(
                      controller: modalScrollController,
                      thumbVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 4,
                      child: SingleChildScrollView(
                        controller: modalScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(right: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. MODE TAMPILAN
                            if (isSegmented && widget.lang != "pli") ...[
                              buildSectionHeader("Segmen Pāli"),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return ToggleButtons(
                                    isSelected: [
                                      _viewMode == ViewMode.lineByLine,
                                      _viewMode == ViewMode.sideBySide,
                                      _viewMode == ViewMode.translationOnly,
                                    ],
                                    onPressed: (int index) {
                                      setState(() {
                                        if (index == 0) {
                                          _viewMode = ViewMode.lineByLine;
                                        } else if (index == 1) {
                                          _viewMode = ViewMode.sideBySide;
                                        } else {
                                          _viewMode = ViewMode.translationOnly;
                                        }
                                      });
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    borderColor: Colors.grey.withValues(
                                      alpha: 0.2,
                                    ),
                                    selectedBorderColor: colorScheme.primary,
                                    fillColor: colorScheme.primaryContainer,
                                    selectedColor:
                                        colorScheme.onPrimaryContainer,
                                    color: colorScheme.onSurfaceVariant,
                                    constraints: BoxConstraints(
                                      minWidth: (constraints.maxWidth - 4) / 3,
                                      minHeight: 48,
                                    ),
                                    children: const [
                                      Tooltip(
                                        message: "Atas Bawah",
                                        child: Icon(
                                          Icons.horizontal_split_outlined,
                                        ),
                                      ),
                                      Tooltip(
                                        message: "Kiri Kanan",
                                        child: Icon(
                                          Icons.vertical_split_outlined,
                                        ),
                                      ),
                                      Tooltip(
                                        message: "Tanpa Pāli",
                                        child: Icon(Icons.block),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  _viewMode == ViewMode.lineByLine
                                      ? "Atas-Bawah"
                                      : _viewMode == ViewMode.sideBySide
                                      ? "Kiri-Kanan"
                                      : "Terjemahan Saja",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 2. GAYA & WARNA
                            buildSectionHeader("Gaya & Warna"),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildThemeOption(
                                    context,
                                    ReaderTheme.light,
                                    Colors.white,
                                    Colors.black,
                                    "Terang",
                                    () => setModalState(() {}),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildThemeOption(
                                    context,
                                    ReaderTheme.light2,
                                    const Color(0xFFFAFAFA),
                                    const Color(0xFF424242),
                                    "Lembut",
                                    () => setModalState(() {}),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildThemeOption(
                                    context,
                                    ReaderTheme.sepia,
                                    const Color(0xFFF4ECD8),
                                    const Color(0xFF5D4037),
                                    "Sepia",
                                    () => setModalState(() {}),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildThemeOption(
                                    context,
                                    ReaderTheme.dark,
                                    const Color(0xFF212121),
                                    Colors.white,
                                    "Gelap",
                                    () => setModalState(() {}),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildThemeOption(
                                    context,
                                    ReaderTheme.dark2,
                                    const Color(0xFF212121),
                                    const Color(0xFFB0BEC5),
                                    "Redup",
                                    () => setModalState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: getFontBtnStyle(_fontType == 'sans'),
                                    onPressed: () {
                                      setState(() => _fontType = 'sans');
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    child: Text(
                                      "Sans",
                                      style: GoogleFonts.inter(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    style: getFontBtnStyle(
                                      _fontType == 'serif',
                                    ),
                                    onPressed: () {
                                      setState(() => _fontType = 'serif');
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    child: Text(
                                      "Serif",
                                      style: GoogleFonts.notoSerif(),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // 3. TATA LETAK
                            buildSectionHeader("Tata Letak"),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.format_size_rounded,
                                    label: "Ukuran Teks",
                                    valueLabel: "${_fontSize.toInt()}",
                                    onMinus: () {
                                      setState(
                                        () => _fontSize = (_fontSize - 2).clamp(
                                          12.0,
                                          40.0,
                                        ),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    onPlus: () {
                                      setState(
                                        () => _fontSize = (_fontSize + 2).clamp(
                                          12.0,
                                          40.0,
                                        ),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                  ),
                                  Divider(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    height: 16,
                                  ),
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.format_line_spacing_rounded,
                                    label: "Jarak Baris",
                                    valueLabel: _lineHeight.toStringAsFixed(1),
                                    onMinus: () {
                                      setState(
                                        () => _lineHeight = (_lineHeight - 0.1)
                                            .clamp(1.0, 3.0),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    onPlus: () {
                                      setState(
                                        () => _lineHeight = (_lineHeight + 0.1)
                                            .clamp(1.0, 3.0),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                  ),
                                  Divider(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    height: 16,
                                  ),
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.space_bar_rounded,
                                    label: "Jarak Sisi",
                                    valueLabel: "${_horizontalPadding.toInt()}",
                                    onMinus: () {
                                      setState(
                                        () => _horizontalPadding =
                                            (_horizontalPadding - 8).clamp(
                                              0.0,
                                              128.0,
                                            ),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    onPlus: () {
                                      setState(
                                        () => _horizontalPadding =
                                            (_horizontalPadding + 8).clamp(
                                              0.0,
                                              128.0,
                                            ),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepperRow(
    BuildContext context, {
    required IconData icon, // ✅ Tambah parameter Icon
    required String label,
    required String valueLabel,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // KIRI: Icon + Label
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.secondary,
              ), // Ikon kecil warna sekunder
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight:
                      FontWeight.w500, // Medium weight, jangan terlalu bold
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),

          // KANAN: Controls (Tanpa border kotak, cuma tombol dan angka)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onMinus,
                color: colorScheme.onSurfaceVariant,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(), // Hapus default padding
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                alignment: Alignment.center,
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onPlus,
                color: colorScheme.onSurfaceVariant,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
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

  // 🔥 FUNGSI UTAMA PEMBUAT HIGHLIGHT
  HighlightResult _buildHighlightedSpans(
    String text,
    TextStyle currentStyle,
    int listIndex,
    bool isPaliTarget,
    int startCounter,
  ) {
    // Kalau gak ada search, balikin teks polos
    if (_cachedSearchRegex == null || _searchController.text.length < 2) {
      return HighlightResult([
        TextSpan(text: text, style: currentStyle),
      ], startCounter);
    }

    final matches = _cachedSearchRegex!.allMatches(text);
    if (matches.isEmpty) {
      return HighlightResult([
        TextSpan(text: text, style: currentStyle),
      ], startCounter);
    }

    final spans = <InlineSpan>[];
    int textCursor = 0;
    int currentCounter = startCounter;

    for (final match in matches) {
      // 1. Teks sebelum highlight
      if (match.start > textCursor) {
        spans.add(
          TextSpan(
            text: text.substring(textCursor, match.start),
            style: currentStyle,
          ),
        );
      }

      // 2. Cek apakah highlight ini AKTIF?
      bool isActive = false;
      // Cek di daftar _allMatches global
      if (_allMatches.isNotEmpty && _currentMatchIndex < _allMatches.length) {
        final activeMatch = _allMatches[_currentMatchIndex];
        // Syarat: Index Baris sama, Tipe sama (Pali/Indo), dan Urutan Counter sama
        if (activeMatch.listIndex == listIndex &&
            activeMatch.isPali == isPaliTarget &&
            activeMatch.localIndex == currentCounter) {
          isActive = true;
        }
      }

      // 3. Render HIGHLIGHT (Gabungin style sekarang + Warna Background)
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: currentStyle.copyWith(
            backgroundColor: isActive ? Colors.orange : Colors.yellow,
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold, // Opsional: biar lebih jelas
          ),
        ),
      );

      textCursor = match.end;
      currentCounter++; // Nambah counter setiap ketemu kata
    }

    // 4. Sisa teks setelah highlight terakhir
    if (textCursor < text.length) {
      spans.add(
        TextSpan(text: text.substring(textCursor), style: currentStyle),
      );
    }

    return HighlightResult(spans, currentCounter);
  }
}

// Helper class buat return 2 nilai sekaligus
class HighlightResult {
  final List<InlineSpan> spans;
  final int newCounter;
  HighlightResult(this.spans, this.newCounter);
}

class SearchMatch {
  final int listIndex;
  final int localIndex; // Urutan ke-berapa di dalam teks tersebut
  final bool isPali; // 🔥 PENANDA: Apakah ini teks Pali?

  SearchMatch(this.listIndex, this.localIndex, this.isPali);
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
