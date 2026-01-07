import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_manager.dart';
import '../core/utils/system_ui_helper.dart';
import '../data/html_data.dart';
import '../widgets/audio.dart';
import '../widgets/tematik_chapter_list.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Taruh di paling atas file html.dart (di luar class)
enum ReaderTheme { light, light2, sepia, dark, dark2 }

class HtmlReaderPage extends StatefulWidget {
  final String title;
  final List<String> chapterFiles;
  final int initialIndex;
  final int? tematikChapterIndex;

  const HtmlReaderPage({
    super.key,
    required this.title,
    required this.chapterFiles,
    this.initialIndex = 0,
    this.tematikChapterIndex,
  });

  @override
  State<HtmlReaderPage> createState() => _HtmlReaderPageState();
}

class _HtmlReaderPageState extends State<HtmlReaderPage> {
  // ============================================
  // STATE VARIABLES
  // ============================================
  ReaderTheme _readerTheme = ReaderTheme.light;
  double _horizontalPadding = 12.0; // Default awal
  double _fontSize = 16.0; // Default langsung 16.0

  final double _textZoom = 100.0;
  bool _isLoading = true;
  late int _currentIndex;
  bool _isScrolled = false;
  bool _isSearchModalOpen = false;

  double _lineHeight = 1.6;
  String _fontType = 'sans'; // 'sans' (Inter) atau 'serif' (Noto)
  // ✅ 2. HELPER FONT
  String? get _currentFontFamily {
    return _fontType == 'serif'
        ? GoogleFonts.notoSerif().fontFamily
        : GoogleFonts.inter().fontFamily;
  }

  // 🔧 TAMBAH STATE UNTUK AUDIO
  bool _isOnline = true;
  bool _isLoadingAudio = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Konten HTML
  String _rawHtmlContent = '';
  String _displayHtmlContent = '';

  // Search State
  String _currentQuery = "";
  List<String> _allMatches = [];
  int _currentMatchIndex = 0;
  final Map<int, GlobalKey> _searchKeys = {};

  // Controllers
  late final ScrollController _scrollController;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isPlayerVisible = false; // Buat toggle buka/tutup
  bool _isSearchActive = false;
  String _currentAudioUrl = ""; // Buat nyimpen url audio yg aktif

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  //  (HELPER FUZZY SEARCH)
  RegExp _createPaliRegex(String query) {
    final buffer = StringBuffer();
    for (int i = 0; i < query.length; i++) {
      final char = query[i].toLowerCase();
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
          buffer.write(RegExp.escape(char));
      }
    }
    return RegExp(buffer.toString(), caseSensitive: false);
  }

  // 🔧 AUTO DETECT: File Paritta = yang ada di folder 'par/' DAN filename mulai 'p'
  bool get _isParittaPage {
    if (_currentIndex >= widget.chapterFiles.length) return false;
    final currentFile = widget.chapterFiles[_currentIndex];

    // Check: ada 'par/' di path DAN filename mulai 'p'
    final fileName = currentFile.split('/').last;
    return currentFile.contains('par/') && fileName.startsWith('p');
  }

  // ============================================
  // UPDATED THEME COLORS (WITH PALI)
  // ============================================
  Map<String, Color> get _themeColors {
    final systemScheme = Theme.of(context).colorScheme;
    final uiCardColor = systemScheme.surface;
    final uiIconColor = systemScheme.onSurface;
    final tm = ThemeManager();

    switch (_readerTheme) {
      case ReaderTheme.light:
        final t = tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': t.colorScheme.onSurface,
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFF8B4513), // Coklat Tua
        };
      case ReaderTheme.light2:
        final t = tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': const Color(0xFF424242),
          'note': const Color(0xFF9E9E9E),
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFFA1887F), // Coklat Soft
        };
      case ReaderTheme.sepia:
        return {
          'bg': const Color(0xFFF4ECD8),
          'text': const Color(0xFF5D4037),
          'note': const Color(0xFF8D6E63),
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFF795548), // Coklat Tanah
        };
      case ReaderTheme.dark:
        final t = tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': t.colorScheme.onSurface,
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFFD4A574), // Emas Pudar
        };
      case ReaderTheme.dark2:
        final t = tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': const Color(0xFFB0BEC5), // Abu Kebiruan
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

  int get displayZoom => _textZoom.round();

  // ============================================
  // LIFECYCLE METHODS
  // ============================================
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _scrollController = ScrollController();
    _loadPreferences();
    _loadHtmlContent();

    // 🔧 SETUP CONNECTIVITY LISTENER
    _initConnectivity();
    _loadAudioUrls(); // ✅ TAMBAH INI
    _setupRealtimeListener(); // ✅ TAMBAH INI
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.addListener(_onScroll);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;

    DaftarIsi.disposeRealtimeListener();
    // 🔧 DISPOSE CONNECTIVITY
    _connectivitySubscription?.cancel();

    // Tutup search modal kalau masih terbuka
    if (_isSearchModalOpen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        } catch (e) {
          debugPrint('Modal close error: $e');
        }
      });
    }

    _isSearchModalOpen = false;
    _currentQuery = "";
    _allMatches.clear();
    _searchKeys.clear();

    try {
      if (_scrollController.hasClients) {
        _scrollController.removeListener(_onScroll);
      }
      _scrollController.dispose();
    } catch (e) {
      debugPrint('Scroll dispose error: $e');
    }

    _searchController.dispose();

    super.dispose();
  }

  // 🔧 CONNECTIVITY METHODS
  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('Connectivity error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    final wasOffline = !_isOnline;
    setState(() {
      _isOnline =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
    });

    // ✅ AUTO RELOAD kalau balik online
    if (wasOffline && _isOnline) {
      debugPrint('🌐 Connection restored - reloading audio URLs...');
      _loadAudioUrls(forceRefresh: true);
    }
  }

  // 🔥 LOAD AUDIO URLS DARI FIREBASE/CACHE
  Future<void> _loadAudioUrls({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() => _isLoadingAudio = true);

    try {
      final result = await DaftarIsi.loadAudioUrls(forceRefresh: forceRefresh);
      debugPrint('✅ Audio URLs loaded: ${result.length} items');

      if (result.isNotEmpty) {
        final firstKey = result.keys.first;
        debugPrint('🎵 Sample: $firstKey → ${result[firstKey]}');
      }
    } catch (e) {
      debugPrint('❌ Error loading audio URLs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  // 🔥 SETUP REALTIME LISTENER (OPTIONAL - untuk auto-update)
  void _setupRealtimeListener() {
    DaftarIsi.setupRealtimeListener(
      onUpdate: (updatedMap) {
        if (mounted) {
          debugPrint('🔄 Audio URLs auto-updated: ${updatedMap.length} items');

          // Update UI kalau lagi di halaman yang punya audio
          if (_hasAudioForCurrentPage()) {
            setState(() {
              // Trigger rebuild untuk update audio button state
            });
          }
        }
      },
    );
  }

  // 🔧 AUDIO METHODS
  String _getCurrentFileName() {
    if (_currentIndex >= widget.chapterFiles.length) return '';
    return widget.chapterFiles[_currentIndex].split('/').last;
  }

  bool _hasAudioForCurrentPage() {
    return DaftarIsi.audioUrls.containsKey(_getCurrentFileName());
  }

  void _handleAudioButtonPress() {
    // 0. Cek loading → KASIH INFO
    if (_isLoadingAudio) {
      _showAudioMessage(
        "Memuat Data Audio...",
        "Mohon tunggu sebentar.",
        Icons.hourglass_empty_rounded,
        Colors.blue,
      );
      return;
    }

    // 1. Cek offline → KASIH INFO
    if (!_isOnline) {
      _showAudioMessage(
        "Tidak Ada Koneksi Internet",
        "Audio memerlukan koneksi internet untuk streaming.",
        Icons.wifi_off_rounded,
        Colors.orange,
      );
      return;
    }

    // 2. Ambil URL
    final fileName = _getCurrentFileName();
    final audioUrl = DaftarIsi.audioUrls[fileName];

    // 3. Cek ada audionya gak → KASIH INFO
    if (audioUrl == null || audioUrl.isEmpty) {
      _showAudioMessage(
        "Audio Tidak Tersedia",
        "Belum ada audio untuk halaman ini.",
        Icons.music_off_rounded,
        Colors.grey,
      );
      if (_isPlayerVisible) {
        setState(() => _isPlayerVisible = false);
      }
      return;
    }

    // 4. TOGGLE PLAYER (berhasil)
    setState(() {
      if (_isPlayerVisible) {
        _isPlayerVisible = false;
      } else {
        _currentAudioUrl = audioUrl;
        _isPlayerVisible = true;
      }
    });
  }

  void _showAudioMessage(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================
  // SCROLL LISTENER
  // ============================================
  void _onScroll() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    try {
      final isScrolled = _scrollController.offset > 0;
      if (isScrolled != _isScrolled) {
        setState(() => _isScrolled = isScrolled);
      }
    } catch (e) {
      debugPrint('Scroll listener error: $e');
    }
  }

  // ============================================
  // LOAD DATA METHODS
  // ============================================
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        //  _textZoom = prefs.getDouble('html_text_zoom') ?? 100.0;
        _fontSize = prefs.getDouble('html_font_size_v2') ?? 16.0;
        // Load padding, default 12.0
        _horizontalPadding = prefs.getDouble('html_horizontal_padding') ?? 12.0;
        _lineHeight = prefs.getDouble('html_line_height') ?? 1.6;
        _fontType = prefs.getString('html_font_type') ?? 'sans';
      });
    }
  }

  Future<void> _loadHtmlContent() async {
    if (widget.chapterFiles.isEmpty) {
      setState(() {
        _rawHtmlContent = "<p>Data bab kosong.</p>";
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);

    try {
      final htmlFile = widget.chapterFiles[_currentIndex];
      String content = await rootBundle.loadString(htmlFile);

      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      final themeIndex = prefs.getInt('reader_theme_index');
      ReaderTheme targetTheme;

      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < ReaderTheme.values.length) {
        targetTheme = ReaderTheme.values[themeIndex];
      } else {
        final brightness = Theme.of(context).brightness;
        targetTheme = brightness == Brightness.dark
            ? ReaderTheme.dark
            : ReaderTheme.light;
      }

      setState(() => _readerTheme = targetTheme);

      final isDarkVariant =
          targetTheme == ReaderTheme.dark || targetTheme == ReaderTheme.dark2;
      final themeClass = isDarkVariant ? 'mode-dark' : 'mode-light';
      content = content.replaceFirst('<body>', '<body class="$themeClass">');

      _rawHtmlContent = content;

      if (_currentQuery.isNotEmpty) {
        _applySearchHighlight(_currentQuery);
      } else {
        _displayHtmlContent = _rawHtmlContent;
      }
    } catch (e) {
      debugPrint('Error loading HTML: $e');
      _rawHtmlContent = '<p>Gagal memuat konten</p>';
      _displayHtmlContent = _rawHtmlContent;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  // ✅ HELPER SAVE BARU BIAR GAMPANG
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('html_font_size_v2', _fontSize);
    //  await prefs.setDouble('html_text_zoom', _textZoom);
    await prefs.setDouble('html_horizontal_padding', _horizontalPadding);
    await prefs.setDouble('html_line_height', _lineHeight);
    await prefs.setString('html_font_type', _fontType);
    await prefs.setInt('reader_theme_index', _readerTheme.index);
  }

  // ============================================
  // SEARCH LOGIC
  // ============================================
  void _performSearch(String query) {
    if (!mounted) return;
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _currentQuery = query;
    _applySearchHighlight(query);
  }

  void _applySearchHighlight(String query) {
    if (query.length < 2) return;

    final RegExp regExp = _createPaliRegex(query.trim());
    final matches = regExp.allMatches(_rawHtmlContent);

    _searchKeys.clear();
    int matchCounter = 0;

    // 🔥 LOGIC SAKTI ALA SUTTA_DETAIL
    // Kita langsung tanam warna Oren/Kuning di sini
    String highlightedHtml = _rawHtmlContent.replaceAllMapped(regExp, (match) {
      final int index = matchCounter++;

      // Cek apakah ini match yang lagi aktif (sedang dipilih user)
      // Karena ini HTML satu blok, logicnya simpel: index == current
      final bool isActive = (index == _currentMatchIndex);

      // Warna Oren kalau aktif, Kuning kalau pasif
      String bgColor = isActive ? "#FF8C00" : "#FFFF00";
      String color = isActive ? "white" : "black";

      // Attribute penanda
      String activeAttr = isActive ? 'data-active="true"' : '';

      // Bungkus pake tag <x-highlight> (sama kayak sutta_detail)
      return "<x-highlight index='$index' style='background-color: $bgColor; color: $color; font-weight: bold; border-radius: 4px; padding: 0 2px;' $activeAttr>${match.group(0)}</x-highlight>";
    });

    setState(() {
      _allMatches = matches.map((e) => e.group(0)!).toList();
      // Reset ke 0 kalau ada hasil
      if (_currentMatchIndex == -1 && matches.isNotEmpty) {
        _currentMatchIndex = 0;
        // Render ulang biar yang ke-0 jadi Oren
        _applySearchHighlight(query);
        return;
      }
      _displayHtmlContent = highlightedHtml;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (matches.isNotEmpty && _currentMatchIndex == 0) _jumpToResult(0);
    });
  }

  void _jumpToResult(int index) {
    if (_allMatches.isEmpty) return;

    int newIndex = index;
    if (newIndex < 0) newIndex = _allMatches.length - 1;
    if (newIndex >= _allMatches.length) newIndex = 0;

    setState(() {
      _currentMatchIndex = newIndex;
    });

    // 🔥 RE-RENDER HIGHLIGHT BIAR WARNA OREN PINDAH
    _applySearchHighlight(_currentQuery);

    // Scroll Logic (Tetap sama)
    final key = _searchKeys[newIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.2,
        curve: Curves.easeInOut,
      );
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();

    if (!mounted) return;

    setState(() {
      _currentQuery = "";
      _allMatches.clear();
      _searchKeys.clear();
      _currentMatchIndex = -1;
      _displayHtmlContent = _rawHtmlContent;
    });
  }

  // ============================================
  // NAVIGATION METHODS
  // ============================================
  Future<void> _handleBackNavigation() async {
    if (_currentIndex > 0) {
      _goToIndex(0);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _goToIndex(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.chapterFiles.length) {
      _currentQuery = "";
      _allMatches.clear();

      setState(() {
        _currentIndex = newIndex;

        // TAMBAHAN:
        // Kalau player lagi kebuka, kita cek halaman baru ada audionya gak?
        // Kalau mau simpel: tutup aja player tiap ganti halaman.
        _isPlayerVisible = false;

        // Tapi kalau mau canggih (tetep play), logicnya agak kompleks
        // karena harus handle stop player lama & start player baru.
        // Saran: Tutup aja dulu (_isPlayerVisible = false) biar aman.
      });

      _loadHtmlContent();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _showNavigationMessage(bool isStart) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 15),
            children: [
              TextSpan(
                text: isStart
                    ? "Ini adalah halaman awal. "
                    : "Ini adalah halaman akhir. ",
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
              const TextSpan(text: " untuk kembali."),
            ],
          ),
        ),
        backgroundColor: Colors.deepOrange.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================
  // MODAL HANDLERS
  // ============================================
  void _showTematikListModal() {
    if (widget.tematikChapterIndex == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TematikChapterList(
          chapterIndex: widget.tematikChapterIndex!,
          onChecklistChanged: () {},
        ),
      ),
    );
  }

  void _openSearchModal() {
    if (!mounted) return;
    setState(() => _isSearchActive = true);
    setState(() => _isSearchModalOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Wajib true biar keyboard gak nendang layout berantakan
      useSafeArea:
          true, // ✅ PENTING: Biar aman dari notch/status bar di landscape
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // 1. Ambil tinggi keyboard
            final double keyboardHeight = MediaQuery.of(
              context,
            ).viewInsets.bottom;

            return Padding(
              // Padding bawah ngikutin tinggi keyboard
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
                  // Radius atas doang biar manis
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  // ✅ SCROLLABLE: Kunci anti-overflow di landscape!
                  // Kalau layar kependekan, kontennya bisa digulung.
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Bungkus konten seperlunya
                      children: [
                        // Handle Bar (Garis Abu di atas)
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // --- BARIS 1: INPUT SEARCH ---
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus:
                                    true, // Langsung fokus biar keyboard naik
                                decoration: InputDecoration(
                                  hintText: "Cari kata (min. 2 huruf)...",
                                  prefixIcon: const Icon(
                                    Icons.find_in_page_outlined,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
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
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _clearSearch();
                                            if (mounted) setSheetState(() {});
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (val) {
                                  if (!mounted) return;
                                  _debounce?.cancel();

                                  if (val.isEmpty) {
                                    _clearSearch();
                                    if (mounted) setSheetState(() {});
                                    return;
                                  }

                                  // Di dalam TextField onChanged:
                                  _debounce = Timer(
                                    const Duration(milliseconds: 500),
                                    () {
                                      if (!mounted) return;
                                      if (val.trim().length >= 2) {
                                        _performSearch(val);
                                      }
                                      // ✅ FIX: Bungkus try-catch agar tidak crash jika modal sudah tutup
                                      try {
                                        setSheetState(() {});
                                      } catch (_) {}
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Tombol Tutup Text (Ganti jadi Icon X biar hemat tempat di landscape?)
                            // Tapi Text "Tutup" juga gapapa asal ada SingleChildScrollView
                            TextButton(
                              onPressed: () {
                                if (mounted) Navigator.of(context).pop();
                              },
                              child: const Text("Tutup"),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // --- BARIS 2: NAVIGASI HASIL ---
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
                                          if (mounted) setSheetState(() {});
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
                                          if (mounted) setSheetState(() {});
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Spacer bawah biar gak mepet banget sama keyboard
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
      Future.microtask(() {
        if (!mounted) return;

        // 🔥 SEMUANYA MASUKIN SINI BIAR RAPI & UI KE-UPDATE BARENGAN
        setState(() {
          _isSearchModalOpen = false;
          _isSearchActive = false; // ✅ Penting buat padding bawah

          _debounce?.cancel();
          _currentQuery = "";
          _allMatches.clear();
          _searchKeys.clear();
          _currentMatchIndex = -1;

          // Reset konten jadi polos lagi
          _displayHtmlContent = _rawHtmlContent;

          _searchController.clear();
        });
      });
    });
  }

  // ============================================
  // SETTINGS MODAL (WITH SCROLLBAR)
  // ============================================

  void _showSettingsModal() {
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
            final ScrollController modalScrollController = ScrollController();

            // Helper Style Tombol Font
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

            // Helper Header Section
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

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 4, 24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- HEADER (DRAG HANDLE) ---
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

                  // --- JUDUL UTAMA ---
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Pengaturan Baca", // ✅ Konsisten
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

                  // ===============================================
                  // 🔥 STICKY LIVE PREVIEW BOX
                  // ===============================================
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
                                  "PRATINJAU TAMPILAN", // ✅ Konsisten
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
                                  // Logic padding preview
                                  horizontal: _horizontalPadding < 16
                                      ? 16
                                      : _horizontalPadding,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Contoh Teks Pali
                                    Text(
                                      "Namo Tassa Bhagavato Arahato Sammāsambuddhassa.",
                                      style: TextStyle(
                                        fontFamily: _currentFontFamily,
                                        // Konversi zoom ke fontSize (basis 16)
                                        fontSize: _fontSize,
                                        height: _lineHeight,
                                        fontWeight: FontWeight.w600,
                                        color: readerColors['pali'],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Contoh Teks Terjemahan
                                    Text(
                                      "Terpujilah Sang Bhagavā, Yang Mahasuci, Yang Telah Mencapai Penerangan Sempurna.",
                                      style: TextStyle(
                                        fontFamily: _currentFontFamily,
                                        fontSize: 16 * (_textZoom / 100),
                                        height: _lineHeight,
                                        color: readerColors['text'],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- KONTEN SCROLLABLE ---
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
                            // 1. GAYA & WARNA
                            buildSectionHeader("Gaya & Warna"),

                            // Theme Selector
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
                                  ), // ✅ Jadi Soft
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
                                  ), // ✅ Jadi Redup
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Font Selector
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

                            // 2. TATA LETAK
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
                                  // Ukuran Teks (Zoom)
                                  // Ukuran Teks (Absolute)
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.format_size_rounded,
                                    label: "Ukuran Teks",
                                    // 🔥 Tampilkan angka bulat (16, 18, 20)
                                    valueLabel: "${_fontSize.toInt()}",
                                    onMinus: () {
                                      setState(() {
                                        // 🔥 Step 2.0, Clamp 12-40
                                        _fontSize = (_fontSize - 2).clamp(
                                          12.0,
                                          40.0,
                                        );
                                      });
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    onPlus: () {
                                      setState(() {
                                        // 🔥 Step 2.0, Clamp 12-40
                                        _fontSize = (_fontSize + 2).clamp(
                                          12.0,
                                          40.0,
                                        );
                                      });
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                  ),
                                  Divider(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    height: 16,
                                  ),

                                  // Jarak Baris
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

                                  // Jarak Sisi
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.space_bar_rounded,
                                    label: "Jarak Sisi", // ✅ Konsisten
                                    valueLabel: "${_horizontalPadding.toInt()}",
                                    onMinus: () {
                                      setState(
                                        () => _horizontalPadding =
                                            (_horizontalPadding - 4).clamp(
                                              0.0,
                                              120.0,
                                            ),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                    onPlus: () {
                                      setState(
                                        () => _horizontalPadding =
                                            (_horizontalPadding + 4).clamp(
                                              0.0,
                                              120.0,
                                            ),
                                      );
                                      _savePreferences();
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),

                            //const SizedBox(height: 24),
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
    required IconData icon,
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
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.secondary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onMinus,
                color: colorScheme.onSurfaceVariant,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                constraints: const BoxConstraints(
                  minWidth: 50,
                ), // Lebarin dikit buat "100%"
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
    VoidCallback onRefresh,
  ) {
    final bool isSelected = _readerTheme == theme;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() => _readerTheme = theme);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('reader_theme_index', theme.index);
        });
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

  // ============================================
  // BUILD METHOD
  // ============================================
  @override
  Widget build(BuildContext context) {
    final colors = _themeColors;
    final bool isFirst = _currentIndex <= 0;
    final bool isLast = _currentIndex >= widget.chapterFiles.length - 1;
    // final double topPadding = MediaQuery.of(context).padding.top + 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },

      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // 🔥 WRAP
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors['bg'],
          body: Stack(
            children: [
              // CONTENT
              SafeArea(
                bottom: false, // Biar konten bawah tembus ke navbar/FAB
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrange,
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: SingleChildScrollView(
                          key: ValueKey<int>(_currentIndex),
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            left: _horizontalPadding,
                            right: _horizontalPadding,

                            // LOGIKA PADDING DINAMIS:
                            // 1. Audio Priority (340)
                            // 2. Search Priority (300) -> Biar teks bawah gak ketutup modal
                            // 3. Normal (120)
                            bottom: _isPlayerVisible
                                ? 340
                                : (_isSearchActive ? 300 : 120),
                          ),

                          child: Column(
                            // 👈 Tambah Column biar bisa kasih Spacer
                            children: [
                              // 👇 SPACER WAJIB (Biar ga ketutupan Header)
                              const SizedBox(height: 80),

                              // KONTEN HTML (SelectionArea)
                              SelectionArea(
                                child: Html(
                                  data: _displayHtmlContent,
                                  style: _getHtmlStyles(),
                                  extensions: [
                                    TagExtension(
                                      tagsToExtend: {"x-highlight"},
                                      builder: (extensionContext) {
                                        final attrs =
                                            extensionContext.attributes;
                                        final indexStr = attrs['index'];
                                        final isGlobalActive =
                                            attrs['data-active'] == 'true';

                                        // FIX 1: NYONTEK UKURAN FONT INDUK
                                        final style = extensionContext
                                            .styledElement
                                            ?.style;
                                        double? currentFontSize =
                                            style?.fontSize?.value;
                                        // Fallback ke default font size
                                        currentFontSize ??= _fontSize;

                                        if (indexStr != null) {
                                          final int index =
                                              int.tryParse(indexStr) ?? 0;

                                          // Simpan key buat scroll
                                          final key = GlobalKey();
                                          _searchKeys[index] = key;

                                          return Container(
                                            key: key,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isGlobalActive
                                                  ? Colors.orange
                                                  : Colors.yellow,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            // 🔥 FIX 2: Pake Transform & Height 1.0 (Biar kotak rapi)
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
                                                  height:
                                                      1.0, // 👈 PENTING: Reset line height
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return Text(
                                          extensionContext.element!.text,
                                        );
                                      },
                                    ),
                                  ],

                                  onLinkTap: (url, attributes, element) {
                                    if (url != null) _handleLinkTap(url);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              // =======================

              // HEADER (Panggil fungsi yang baru diedit tadi)
              _buildHeader(),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,

          // Di dalam method build()
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min, // Biar tingginya nyesuain isi
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 1. KOTAK PEMUTARAN (Muncul cuma kalau _isPlayerVisible == true)
              if (_isPlayerVisible) ...[
                Padding(
                  // Kasih padding biar gak mepet pinggir layar
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: AudioHandlerWidget(
                    audioPath: _currentAudioUrl,
                    onClose: () {
                      // Logic kalau tombol X di player dipencet
                      setState(() => _isPlayerVisible = false);
                    },
                  ),
                ),
                // Gak perlu SizedBox lagi karena di AudioHandlerWidget kamu
                // udah ada margin bawah (margin: const EdgeInsets.fromLTRB(16, 0, 16, 24))
              ],

              // 2. TOMBOL NAVIGASI (Ikon-ikon bawah)
              _buildFloatingActions(isFirst, isLast),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // UPDATED STYLES (USE THEME COLORS)
  // ============================================
  Map<String, Style> _getHtmlStyles() {
    final mainFont = _currentFontFamily;
    final colors = _themeColors;
    final bgColor = colors['bg']!;
    final textColor = colors['text']!;
    final noteColor = colors['note']!;

    // ✅ AMBIL WARNA PALI DARI MAP (Jangan logic if-else manual lagi)
    final paliAccentColor = colors['pali']!;

    // final fontSize = _textZoom / 100.0;

    final serifFont = GoogleFonts.varta().fontFamily!;
    final sansFont = GoogleFonts.varta().fontFamily!;

    final isDarkVariant =
        _readerTheme == ReaderTheme.dark || _readerTheme == ReaderTheme.dark2;

    Color contentBoxColor;
    if (isDarkVariant) {
      contentBoxColor = const Color(0xFF252525);
    } else if (_readerTheme == ReaderTheme.sepia) {
      contentBoxColor = const Color(0xFFFFF8E1);
    } else {
      contentBoxColor = Colors.white;
    }

    return {
      "body": Style(
        backgroundColor: bgColor,
        color: textColor,
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
        padding: HtmlPaddings.zero,
        margin: Margins.zero,
      ),

      "#isi": Style(margin: Margins.zero, padding: HtmlPaddings.zero),

      // ===========================================
      // 1. HEADER UTAMA (JUDUL KITAB/BAB)
      // ===========================================
      "h1": Style(
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize * 1.6),
        fontWeight: FontWeight.w900,
        margin: Margins.only(top: 24, bottom: 8),
        color: textColor,
        border: Border(
          bottom: BorderSide(color: noteColor.withValues(alpha: 0.3), width: 1),
        ),
      ),

      // ===========================================
      // 2. SUB-HEADERS
      // ===========================================
      "h2": Style(
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize * 1.4),
        fontWeight: FontWeight.bold,
        margin: Margins.only(top: 20, bottom: 8),
        color: textColor,
      ),
      "h3": Style(
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize * 1.2),
        fontWeight: FontWeight.w700,
        margin: Margins.only(top: 16, bottom: 6),
        color: textColor,
      ),

      // 🔥 INI KUNCINYA: TARGET SEMUA SPAN.INDO DI DALAM HEADER
      "h1 span.indo, h2 span.indo, h3 span.indo": Style(
        display: Display.block, // Turun baris
        fontFamily: mainFont,
        fontWeight: FontWeight.normal,
        fontSize: FontSize(_fontSize * 0.85), // Ukuran subtitle
        color: textColor.withValues(alpha: 0.75), // Agak pudar
        fontStyle: FontStyle.italic,
        margin: Margins.only(top: 4),
      ),

      // ✅ Terapkan paliAccentColor di sini
      "p": Style(
        fontFamily: mainFont,
        // fontFamily: serifFont,
        fontWeight: _fontType == 'serif' ? FontWeight.w500 : FontWeight.w600,
        color: paliAccentColor,
        margin: Margins.only(bottom: 6),
        fontSize: FontSize(_fontSize),
      ),

      "p.indo": Style(
        fontFamily: mainFont,
        //fontFamily: serifFont,
        fontWeight: FontWeight.normal,
        color: textColor,
        margin: Margins.only(bottom: 20),
        fontSize: FontSize(_fontSize),
      ),

      "p.footnote": Style(
        fontFamily: mainFont,
        fontStyle: FontStyle.italic,
        //   fontFamily: sansFont,
        fontSize: FontSize(_fontSize * 0.85),
        color: noteColor,
        margin: Margins.only(bottom: 4),
      ),

      // ✅ Dan di border kiri kotak isi
      "div.isi": Style(
        backgroundColor: contentBoxColor,
        padding: HtmlPaddings.all(12),
        margin: Margins.symmetric(vertical: 10),
        border: Border(
          left: BorderSide(color: paliAccentColor, width: 4), // <-- SINI JUGA
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
          right: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),

      "div.daftar": Style(
        margin: Margins.only(top: 10),
        display: Display.block,
      ),

      "div.daftar-child": Style(
        backgroundColor: contentBoxColor,
        padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 10),
        margin: Margins.only(bottom: 8),
        border: Border(
          left: BorderSide(color: const Color(0xFF4CAF50), width: 3),
        ),
      ),

      ".daftar-child": Style(
        fontFamily: serifFont,
        // 🔥 15/16 ≈ 0.94
        fontSize: FontSize(_fontSize * 0.94),
        fontWeight: FontWeight.bold,
        color: textColor,
      ),

      "span.dindo": Style(
        fontFamily: sansFont,
        display: Display.block,
        margin: Margins.only(top: 2),
        // 🔥 13/16 ≈ 0.82
        fontSize: FontSize(_fontSize * 0.82),
        fontWeight: FontWeight.normal,
        color: noteColor,
      ),

      ".guide": Style(
        fontFamily: sansFont,
        display: Display.block,
        margin: Margins.only(top: 2),
        // 🔥 14/16 ≈ 0.88
        fontSize: FontSize(_fontSize * 0.88),
        fontWeight: FontWeight.normal,
        color: noteColor,
      ),

      "a": Style(
        fontFamily: sansFont,
        color: isDarkVariant
            ? const Color(0xFF80CBC4)
            : const Color(0xFF00695C),
        textDecoration: TextDecoration.none,
      ),

      "div.disabled": Style(color: noteColor.withValues(alpha: 0.4)),
    };
  }

  void _handleLinkTap(String url) {
    for (int i = 0; i < widget.chapterFiles.length; i++) {
      final fileName = widget.chapterFiles[i].split('/').last;
      // if (url.contains(fileName)) {
      if (url.endsWith(fileName) || url == fileName) {
        _goToIndex(i);
        return;
      }
    }
  }

  // ============================================
  // UI COMPONENTS
  // ============================================
  Widget _buildHeader() {
    return Positioned(
      // 👇 1. Posisi turun di bawah status bar
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Padding(
        // 👇 2. Kasih margin biar ngambang (Floating Pill)
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
                // 👇 3. Padding dalem lebih tipis karena udah ada margin luar
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // TOMBOL BACK (Bulat + Shadow)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: _handleBackNavigation, // Tetep pake logic lama
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_back,
                            // size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // JUDUL & HALAMAN
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              // Pakai warna tema biar adaptif
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Halaman ${_currentIndex + 1} / ${widget.chapterFiles.length}",
                            style: TextStyle(
                              fontSize: 11,
                              // Warna subtitle agak pudar
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 FLOATING ACTIONS WITH AUDIO BUTTON
  // ============================================
  // MODIFIED FLOATING ACTIONS (AUTO COMPACT)
  // ============================================
  Widget _buildFloatingActions(bool isPrevDisabled, bool isNextDisabled) {
    final systemScheme = Theme.of(context).colorScheme;
    final containerColor = systemScheme.surface;
    final iconColor = systemScheme.onSurface;
    final activeColor = systemScheme.primary;
    final shadowColor = Colors.black.withValues(alpha: 0.15);
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    // 🔧 1. LOGIC DETEKSI HP LANDSCAPE
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    // < 600 biasanya HP, >= 600 biasanya Tablet
    final isTablet = size.shortestSide >= 600;

    // Kalo HP dan Landscape, aktifkan mode Compact
    final isPhoneLandscape = isLandscape && !isTablet;

    // 🔧 2. SETTINGAN COMPACT VS NORMAL
    // Kalau landscape HP: Margin dikitin, Padding dikitin, Icon dikecilin dikit
    final double verticalMargin = isPhoneLandscape ? 4.0 : 20.0;
    final double internalPaddingH = isPhoneLandscape ? 4.0 : 6.0;
    final double internalPaddingV = isPhoneLandscape ? 2.0 : 4.0;
    final double iconSize = isPhoneLandscape ? 20.0 : 24.0;
    final double separatorHeight = isPhoneLandscape ? 16.0 : 24.0;

    // Logic tombol audio
    final bool showAudioButton = _isParittaPage;
    final bool hasAudioForPage = _hasAudioForCurrentPage();
    final bool isAudioButtonEnabled =
        _isOnline && !_isLoadingAudio && hasAudioForPage && !_isPlayerVisible;

    Widget buildBtn({
      required IconData icon,
      required VoidCallback? onTap,
      bool isActive = false,
      Color? customIconColor,
    }) {
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
          splashColor: activeColor.withValues(alpha: 0.1),
          child: Container(
            // Padding tombol individual juga disesuain
            padding: EdgeInsets.all(isPhoneLandscape ? 8 : 12),
            decoration: isActive
                ? BoxDecoration(
                    color: activeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Icon(icon, color: finalColor, size: iconSize),
          ),
        ),
      );
    }

    return Container(
      // Margin bawah dibuat dinamis
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: verticalMargin),
      padding: EdgeInsets.symmetric(
        horizontal: internalPaddingH,
        vertical: internalPaddingV,
      ),
      decoration: BoxDecoration(
        color: containerColor.withValues(
          alpha: isPhoneLandscape ? 0.9 : 1.0,
        ), // Agak transparan dikit kalo landscape
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isPhoneLandscape
                ? 10
                : 20, // Shadow lebih tipis biar ga makan tempat
            offset: Offset(0, isPhoneLandscape ? 4 : 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // PREV
          buildBtn(
            icon: Icons.chevron_left_rounded,
            customIconColor: isPrevDisabled ? disabledClickableColor : null,
            onTap: _isLoading
                ? null
                : () {
                    if (isPrevDisabled) {
                      _showNavigationMessage(true);
                    } else {
                      _goToIndex(_currentIndex - 1);
                    }
                  },
          ),

          Container(
            width: 1,
            height: separatorHeight, // Separator ngikutin tinggi
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          if (showAudioButton) ...[
            AnimatedOpacity(
              opacity: isAudioButtonEnabled ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: buildBtn(
                icon: Icons.headphones_rounded,
                onTap: _handleAudioButtonPress,
              ),
            ),
          ],

          if (widget.tematikChapterIndex != null &&
              widget.tematikChapterIndex != 0)
            buildBtn(icon: Icons.folder_outlined, onTap: _showTematikListModal),

          // SEARCH
          buildBtn(
            icon: Icons.search_rounded,
            onTap: _isLoading ? null : _openSearchModal,
            isActive: _isSearchModalOpen,
          ),

          // SETTINGS
          buildBtn(icon: Icons.text_fields_rounded, onTap: _showSettingsModal),

          // SCROLL TOP
          buildBtn(icon: Icons.vertical_align_top_rounded, onTap: _scrollToTop),

          Container(
            width: 1,
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // NEXT
          buildBtn(
            icon: Icons.chevron_right_rounded,
            customIconColor: isNextDisabled ? disabledClickableColor : null,
            onTap: _isLoading
                ? null
                : () {
                    if (isNextDisabled) {
                      _showNavigationMessage(false);
                    } else {
                      _goToIndex(_currentIndex + 1);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
