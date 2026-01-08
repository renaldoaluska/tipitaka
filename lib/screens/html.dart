import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
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
  //final ThemeManager _tm = ThemeManager();
  // ============================================
  // STATE VARIABLES
  // ============================================
  bool _isBottomMenuVisible = true;

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

  // 🔥 TAMBAH INI: Notifier untuk index aktif agar tidak perlu render ulang HTML
  final ValueNotifier<int> _activeSearchIndex = ValueNotifier<int>(-1);

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

    // 🔥 SOLUSI ANTI-CRASH:
    // Kita gak usah pake _tm.lightTheme atau _tm.darkTheme yang bikin error.
    // Kita panggil langsung ThemeData.light() / dark() dari Flutter. Aman 100%.

    switch (_readerTheme) {
      case ReaderTheme.light:
        final t = ThemeData.light(); // ✅ Langsung panggil ini
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': t.colorScheme.onSurface,
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFF8B4513),
        };

      case ReaderTheme.light2:
        final t = ThemeData.light(); // ✅ Langsung panggil ini
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': const Color(0xFF424242),
          'note': const Color(0xFF9E9E9E),
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFFA1887F),
        };

      case ReaderTheme.sepia:
        // Sepia emang hardcode, jadi aman sentosa
        return {
          'bg': const Color(0xFFF4ECD8),
          'text': const Color(0xFF5D4037),
          'note': const Color(0xFF8D6E63),
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFF795548),
        };

      case ReaderTheme.dark:
        final t = ThemeData.dark(); // ✅ Langsung panggil ini
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': t.colorScheme.onSurface,
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
          'pali': const Color(0xFFD4A574),
        };

      case ReaderTheme.dark2:
        final t = ThemeData.dark(); // ✅ Langsung panggil ini
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': const Color(0xFFB0BEC5),
          'note': const Color(0xFF757575),
          'card': uiCardColor,
          'icon': uiIconColor,
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
    _activeSearchIndex.dispose();
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
      // debugPrint('✅ Audio URLs loaded: ${result.length} items');

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
          // debugPrint('🔄 Audio URLs auto-updated: ${updatedMap.length} items');

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
        _fontSize = prefs.getDouble('html_font_size_v2') ?? 16.0;
        _horizontalPadding = prefs.getDouble('html_horizontal_padding') ?? 12.0;
        _lineHeight = prefs.getDouble('html_line_height') ?? 1.6;
        _fontType = prefs.getString('html_font_type') ?? 'sans';
        _isBottomMenuVisible =
            prefs.getBool('html_bottom_menu_visible') ?? true; // ✅ TAMBAH INI
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

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('html_font_size_v2', _fontSize);
    await prefs.setDouble('html_horizontal_padding', _horizontalPadding);
    await prefs.setDouble('html_line_height', _lineHeight);
    await prefs.setString('html_font_type', _fontType);
    await prefs.setInt('reader_theme_index', _readerTheme.index);
    await prefs.setBool(
      'html_bottom_menu_visible',
      _isBottomMenuVisible,
    ); // ✅ TAMBAH INI
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

  // ============================================
  // 🔥 FIX SEARCH LOGIC: ANTI JEBOL HTML TAG
  // ============================================
  void _applySearchHighlight(String query) {
    if (query.length < 2) return;

    final RegExp paliRegExp = _createPaliRegex(query.trim());
    final String pattern = '(<[^>]+>)|(${paliRegExp.pattern})';
    final RegExp combinedRegex = RegExp(pattern, caseSensitive: false);

    // 🔥 Reset Keys di sini (Hanya saat QUERY berubah/search baru)
    _searchKeys.clear();
    int matchCounter = 0;
    final List<String> foundMatches = [];

    String highlightedHtml = _rawHtmlContent.replaceAllMapped(combinedRegex, (
      match,
    ) {
      final String fullMatch = match.group(0)!;

      if (match.group(1) != null) return fullMatch; // Ini tag HTML, skip

      if (match.group(2) != null) {
        final int index = matchCounter++;
        foundMatches.add(fullMatch);

        // 🔥 SIMPELKAN: Cukup kasih index saja. Style & Warna kita atur di Widget Builder nanti.
        return "<x-highlight index='$index'>$fullMatch</x-highlight>";
      }
      return fullMatch;
    });

    setState(() {
      _allMatches = foundMatches;
      _currentMatchIndex = 0; // Reset ke awal
      _displayHtmlContent = highlightedHtml;

      // Update notifier juga ke 0
      _activeSearchIndex.value = 0;
    });

    // Auto scroll ke hasil pertama setelah render selesai
    if (_allMatches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToResult(0));
    }
  }

  void _jumpToResult(int index) {
    if (_allMatches.isEmpty) return;

    int newIndex = index;
    if (newIndex < 0) newIndex = _allMatches.length - 1;
    if (newIndex >= _allMatches.length) newIndex = 0;

    // 🔥 UPDATE STATE TANPA RE-RENDER HTML
    setState(() {
      _currentMatchIndex = newIndex;
    });

    // 🔥 Update Notifier biar warnanya berubah (kuning -> oranye)
    _activeSearchIndex.value = newIndex;

    // 🔥 JALANKAN SCROLL
    // Karena HTML tidak dihancurkan, Key-nya masih ada dan valid!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _searchKeys[newIndex];
      // Cek apakah key ada dan punya context
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment:
              0.3, // 0.3 artinya posisi agak di sepertiga atas layar (enak dibaca)
          curve: Curves.easeInOutCubic,
        );
      } else {
        debugPrint("⚠️ Key not found or not attached for index $newIndex");
      }
    });
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

  // 🔥 HELPER BARU: Hitung posisi notif biar gak ketutupan menu
  double _getSnackBarBottomMargin() {
    // Margin dasar dari bawah layar
    double margin = 20.0;

    // 1. Cek Tinggi Menu Bawah
    if (_isBottomMenuVisible) {
      // Tinggi Menu (Icons + Padding) + Toggle (~75px)
      margin += 75.0;
    } else {
      // Tinggi Toggle doang (Super Ceper 16px)
      margin += 16.0;
    }

    // 2. Cek Audio Player (kalau lagi nongol)
    if (_isPlayerVisible) {
      // Tinggi Player (~80px) + Padding bawah (16px)
      margin += 96.0;
    }

    return margin;
  }

  // 🔥 UPDATE 1: AUDIO MESSAGE
  void _showAudioMessage(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Ambil margin dinamis
    final bottomMargin = _getSnackBarBottomMargin();

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
        // 🔥 UPDATE MARGIN DISINI
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin, // <-- Ini kuncinya!
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 🔥 UPDATE 2: NAVIGATION MESSAGE (Mentok Kiri/Kanan)
  void _showNavigationMessage(bool isStart) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Ambil margin dinamis
    final bottomMargin = _getSnackBarBottomMargin();

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
        // 🔥 UPDATE MARGIN DISINI JUGA
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin, // <-- Ini kuncinya!
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

  // ============================================
  // SETTINGS MODAL (WITH SCROLLBAR) - HTML.DART
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
            // Ambil warna tema terbaru
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

            return Container(
              // 🔥 FIX: Padding Bawah dikurangi (24 -> 16) biar gak bolong
              padding: const EdgeInsets.fromLTRB(24, 12, 4, 0),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- HEADER HANDLE ---
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

                  // --- JUDUL ---
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

                  // ===============================================
                  // 🔥 LIVE PREVIEW BOX (html.dart version)
                  // ===============================================
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // TEKS PALI
                                      Text(
                                        "Namo Tassa Bhagavato Arahato Sammāsambuddhassa.",
                                        style: TextStyle(
                                          fontFamily: _currentFontFamily,
                                          fontSize: _fontSize,
                                          height: _lineHeight,
                                          fontWeight: _fontType == 'serif'
                                              ? FontWeight.w400
                                              : FontWeight.w500,
                                          color: readerColors['pali'],
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // TEKS TERJEMAHAN
                                      Text(
                                        "Terpujilah Sang Bhagavā, Yang Mahasuci, Yang Telah Mencapai Penerangan Sempurna.",
                                        style: TextStyle(
                                          fontFamily: _currentFontFamily,
                                          fontSize: _fontSize,
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
                  ],

                  // --- KONTEN SETTINGS ---
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
                                  // UKURAN TEKS
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.format_size_rounded,
                                    label: "Ukuran Teks",
                                    valueLabel: "${_fontSize.toInt()}",
                                    onMinus: () {
                                      setState(() {
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

                                  // JARAK BARIS
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

                                  // JARAK SISI
                                  _buildStepperRow(
                                    context,
                                    icon: Icons.space_bar_rounded,
                                    label: "Jarak Sisi",
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
    //final bool isFirst = _currentIndex <= 0;
    //final bool isLast = _currentIndex >= widget.chapterFiles.length - 1;
    // final double topPadding = MediaQuery.of(context).padding.top + 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors['bg'],
          body: Stack(
            children: [
              // CONTENT (TIDAK BERUBAH)
              SafeArea(
                bottom: false,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrange,
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: false,
                        thickness: 4,
                        radius: const Radius.circular(8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: SingleChildScrollView(
                            key: ValueKey<int>(_currentIndex),
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: _horizontalPadding,
                              right: _horizontalPadding,
                              bottom: _isPlayerVisible
                                  ? 340
                                  : (_isSearchActive
                                        ? 300
                                        : (_isBottomMenuVisible ? 120 : 50)),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 80),
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
                                          final style = extensionContext
                                              .styledElement
                                              ?.style;
                                          double? currentFontSize =
                                              style?.fontSize?.value;
                                          currentFontSize ??= _fontSize;

                                          if (indexStr != null) {
                                            final int index =
                                                int.tryParse(indexStr) ?? 0;
                                            final key = _searchKeys.putIfAbsent(
                                              index,
                                              () => GlobalKey(),
                                            );

                                            return ValueListenableBuilder<int>(
                                              valueListenable:
                                                  _activeSearchIndex,
                                              builder: (context, activeIndex, child) {
                                                final bool isActive =
                                                    (activeIndex == index);

                                                return Container(
                                                  key: key,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? Colors.orange
                                                        : Colors.yellow,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: isActive
                                                        ? Border.all(
                                                            color: Colors
                                                                .deepOrange,
                                                            width: 2,
                                                          )
                                                        : null,
                                                  ),
                                                  child: Transform.translate(
                                                    offset: const Offset(0, 1),
                                                    child: Text(
                                                      extensionContext
                                                          .element!
                                                          .text,
                                                      style: TextStyle(
                                                        color: isActive
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            currentFontSize,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
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
              ),

              // HEADER (TIDAK BERUBAH)
              _buildHeader(),
              // 🔥 UPDATE TERBARU: BOTTOM MENU (GLASSMORPHISM)
              // 🔥 UPDATE TERBARU: AUDIO PLAYER LEBIH NAIK
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 1. AUDIO PLAYER
                    if (_isPlayerVisible) ...[
                      Padding(
                        // 🔥 UBAH DISINI BANG:
                        // 'bottom: 16' -> Biar dia kedorong naik, gak nempel menu kaca.
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: AudioHandlerWidget(
                          audioPath: _currentAudioUrl,
                          onClose: () =>
                              setState(() => _isPlayerVisible = false),
                        ),
                      ),
                    ],

                    // 2. WADAH KACA UTAMA (MENU) - (TETAP SAMA KAYAK SEBELUMNYA)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        // Logic Lebar
                        width: MediaQuery.of(context).size.width > 600
                            ? 500
                            : MediaQuery.of(context).size.width - 48,

                        margin: EdgeInsets.zero, // Napak Tanah
                        // DEKORASI LUAR (Shadow doang)
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

                        // EFEK KACA (Blur + Transparan)
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                            bottom: Radius.zero,
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 10.0,
                              sigmaY: 10.0,
                            ),
                            // ... di dalam BackdropFilter -> Container ...
                            child: Container(
                              // Warna "Tipis-tipis" (85% opacity)
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.85),

                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ===============================================
                                  // 🔥 DRAG HANDLE / GARIS (SAMA KAYAK SUTTA DETAIL)
                                  // ===============================================
                                  GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    // Fitur Swipe buat tutup/buka
                                    onVerticalDragEnd: (details) {
                                      if (details.primaryVelocity! > 0 &&
                                          _isBottomMenuVisible) {
                                        setState(
                                          () => _isBottomMenuVisible = false,
                                        );
                                        _savePreferences();
                                      } else if (details.primaryVelocity! < 0 &&
                                          !_isBottomMenuVisible) {
                                        setState(
                                          () => _isBottomMenuVisible = true,
                                        );
                                        _savePreferences();
                                      }
                                    },
                                    // Fitur Tap buat toggle
                                    onTap: () {
                                      setState(
                                        () => _isBottomMenuVisible =
                                            !_isBottomMenuVisible,
                                      );
                                      _savePreferences();
                                    },
                                    // Container Area Sentuh
                                    child: Container(
                                      width: double.infinity,
                                      // Padding atas dikit aja (8), bawah (4) biar mepet sama tombol
                                      padding: const EdgeInsets.fromLTRB(
                                        0,
                                        8,
                                        0,
                                        4,
                                      ),
                                      child: Center(
                                        // Tambahin Center biar pasti di tengah
                                        // VISUAL GARISNYA (SAMA PERSIS SUTTA DETAIL)
                                        child: Container(
                                          width: 40, // Lebar disamain (tadi 48)
                                          height: 3,
                                          decoration: BoxDecoration(
                                            // Warna disamain (pake onSurface + 0.15)
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ===============================================
                                  // MENU CONTENT
                                  // ===============================================
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves
                                        .easeInOutCubic, // Pakai Cubic biar lebih smooth
                                    height: _isBottomMenuVisible ? null : 0,
                                    child: SingleChildScrollView(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: SizedBox(
                                        width: double.infinity,
                                        // Padding bawah dikit biar gak mepet
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8.0,
                                          ),
                                          child: _buildFloatingActions(
                                            _currentIndex <= 0,
                                            _currentIndex >=
                                                widget.chapterFiles.length - 1,
                                          ),
                                        ),
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
                  ],
                ),
              ),
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
    final paliAccentColor = colors['pali']!;

    // 🔥 FORMULA WARNA PINTAR (Biar Reader Theme Konsisten)
    // Kita gak pake warna sistem (noteColor), tapi nurunin dari textColor.
    // Jadi kalau Sepia -> Abu-nya kecoklatan. Kalau Dark -> Abu-nya keperakan.
    final subtleColor = textColor.withValues(alpha: 0.6); // Buat teks sekunder
    final buttonFillColor = textColor.withValues(
      alpha: 0.04,
    ); // Buat background tombol (tipis)
    final buttonBorderColor = textColor.withValues(
      alpha: 0.12,
    ); // Buat garis pinggir tombol

    final serifFont = GoogleFonts.varta().fontFamily!;
    final sansFont = GoogleFonts.varta().fontFamily!;

    final isDarkVariant =
        _readerTheme == ReaderTheme.dark || _readerTheme == ReaderTheme.dark2;

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
      // 1. HEADER UTAMA
      // ===========================================
      "h1": Style(
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize * 1.6),
        fontWeight: FontWeight.w800,
        margin: Margins.only(top: 32, bottom: 12),
        color: textColor,
      ),

      "h2": Style(
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize * 1.35),
        fontWeight: FontWeight.w700,
        margin: Margins.only(top: 28, bottom: 10),
        color: textColor,
      ),
      "h3": Style(
        fontFamily: mainFont,
        fontSize: FontSize(_fontSize * 1.15),
        fontWeight: FontWeight.w600,
        margin: Margins.only(top: 24, bottom: 8),
        color: textColor,
      ),

      // Subtitle Header (Terjemahan Judul)
      "h1 span.indo, h2 span.indo, h3 span.indo": Style(
        display: Display.block,
        fontFamily: mainFont,
        fontWeight: FontWeight.normal,
        fontSize: FontSize(_fontSize * 0.75),
        color: subtleColor, // ✅ Pake warna turunan teks
        fontStyle: FontStyle.normal,
        margin: Margins.only(top: 4),
        lineHeight: LineHeight(1.3),
      ),

      // ===========================================
      // 3. TEKS PALI (FOKUS UTAMA)
      // ===========================================
      "p": Style(
        fontFamily: mainFont,
        fontWeight: _fontType == 'serif' ? FontWeight.w400 : FontWeight.w500,
        color: paliAccentColor,

        // 🔥 UBAH BAGIAN INI:
        // Tambahin 'top: 16' biar ada jarak dari teks terjemahan di atasnya.
        // 'bottom: 8' tetep ada biar jarak ke terjemahan di bawahnya rapet.
        margin: Margins.only(top: 16, bottom: 8),

        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight * 1.1),
      ),

      // ===========================================
      // 4. TEKS TERJEMAHAN (SEKUNDER)
      // ===========================================
      "p.indo": Style(
        fontFamily: mainFont,
        fontWeight: FontWeight.normal,
        color: textColor.withValues(alpha: 0.9),

        // 🔥 UBAH BAGIAN INI:
        // Kasih jarak bawah 12 biar antar paragraf Indo ada napasnya.
        // Kalau ketemu Pali di bawahnya, jaraknya bakal nambah (jadi pemisah ayat yang tegas).
        margin: Margins.only(bottom: 12),

        fontSize: FontSize(_fontSize),
        // Tambahin dikit line-height biar teks panjang lebih enak dibaca
        lineHeight: LineHeight(1.5),
      ),

      "p.footnote": Style(
        fontFamily: mainFont,
        fontStyle: FontStyle.italic,
        fontSize: FontSize(_fontSize * 0.85),
        color: subtleColor, // ✅ Konsisten
        margin: Margins.only(bottom: 4),
      ),

      // ===========================================
      // 3. KOTAK ISI (CLEAN)
      // ===========================================
      "div.isi": Style(
        backgroundColor: Colors.transparent,
        border: Border(
          left: BorderSide(
            color: paliAccentColor.withValues(alpha: 0.3),
            width: 3,
          ),
        ),
        padding: HtmlPaddings.only(left: 16, top: 4, bottom: 4),
        margin: Margins.only(bottom: 24),
      ),

      // ===========================================
      // 4. DAFTAR ISI (TOMBOL "SOFT BUTTON")
      // ===========================================
      "div.daftar": Style(
        margin: Margins.only(top: 10, bottom: 32),
        display: Display.block,
      ),

      // 🔥 INI DIA: Tampilan "Bisa Dipencet" tapi Gak Norak
      "div.daftar-child": Style(
        // Background: Warna teks tapi opacity 4% (Soft banget)
        backgroundColor: buttonFillColor,

        // Border: Warna teks opacity 12% (Garis halus penegas)
        border: Border.all(color: buttonBorderColor, width: 1),

        // Radius: Biar modern & ramah (bukan kotak tajam)
        // Note: Flutter HTML pake 'radius' via css style logic,
        // tapi properti border di Style object gak support radius langsung di semua versi.
        // Triknya di padding & margin yang pas. Kalau mau radius di flutter_html lama susah,
        // tapi tampilan kotak halus dengan warna fill udah cukup ngasih sinyal "tombol".
        // (Versi flutter_html baru support, tapi kalau error, hapus properti yang gak support).
        padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 12),
        margin: Margins.only(bottom: 8),
      ),

      // Judul Bab: Pake Warna Aksen (Pali) biar kerasa Link Aktif
      ".daftar-child": Style(
        fontFamily: serifFont,
        fontSize: FontSize(_fontSize * 1.05),
        fontWeight: FontWeight.bold,
        color: paliAccentColor, // Warna "Link"
        lineHeight: LineHeight(1.3),
      ),

      // Subtitle Bab
      "span.dindo": Style(
        fontFamily: sansFont,
        display: Display.block,
        margin: Margins.only(top: 4),
        fontSize: FontSize(_fontSize * 0.85),
        fontWeight: FontWeight.normal,
        color: subtleColor, // Warna abu turunan
        lineHeight: LineHeight(1.4),
      ),

      // ===========================================
      // 5. LAIN-LAIN
      // ===========================================
      ".nomor": Style(
        display: Display.block,
        textAlign: TextAlign.center,
        fontFamily: serifFont,
        fontSize: FontSize(_fontSize * 0.9),
        fontWeight: FontWeight.bold,
        color: subtleColor, // ✅ Konsisten
        margin: Margins.only(top: 32, bottom: 8),
      ),

      // ===========================================
      // 7. GUIDE / INSTRUKSI (EMPHASIZED)
      // ===========================================
      ".guide": Style(
        fontFamily: sansFont,
        display: Display.block,

        // Jarak: Kasih napas atas bawah biar gak nempel ayat
        margin: Margins.only(top: 24, bottom: 8),

        // Font: Agak kecil tapi TEBAL & MIRING (Standar instruksi)
        fontSize: FontSize(_fontSize * 0.85),
        fontWeight: FontWeight.w700, // Bold biar kebaca jelas
        fontStyle: FontStyle.italic, // Miring biar beda sama ayat
        // Warna: Pake warna Aksen (Pali) biar senada tapi tegas
        // Atau kalau mau beda banget, bisa pake textColor.withOpacity(0.7)
        color: paliAccentColor,

        // Opsional: Rata tengah biar kayak instruksi formal
        // textAlign: TextAlign.center,
      ),
      "a": Style(
        fontFamily: sansFont,
        color: isDarkVariant
            ? const Color(0xFF80CBC4)
            : const Color(0xFF00695C),
        textDecoration: TextDecoration.none,
      ),

      "div.disabled": Style(color: subtleColor.withValues(alpha: 0.4)),

      ".ref": Style(
        fontSize: FontSize.smaller,
        color: subtleColor,
        textDecoration: TextDecoration.none,
        verticalAlign: VerticalAlign.sup,
        border: Border.all(color: buttonBorderColor),
        margin: Margins.only(right: 4),
        padding: HtmlPaddings.symmetric(horizontal: 2, vertical: 0),
        display: Display.inlineBlock,
      ),
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
    // final containerColor = systemScheme.surface; // Gak dipake lagi
    final iconColor = systemScheme.onSurface;
    final activeColor = systemScheme.primary;
    // final shadowColor = Colors.black.withValues(alpha: 0.15); // Gak dipake lagi
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.shortestSide >= 600;
    final isPhoneLandscape = isLandscape && !isTablet;

    final double internalPaddingH = isPhoneLandscape ? 4.0 : 6.0;
    final double internalPaddingV = isPhoneLandscape ? 2.0 : 4.0;
    final double iconSize = isPhoneLandscape ? 20.0 : 24.0;
    final double separatorHeight = isPhoneLandscape ? 16.0 : 24.0;

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
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: internalPaddingH,
        vertical: internalPaddingV,
      ),
      // 🔥 UPDATE: Border DIHAPUS total biar nyatu sama kaca
      decoration: const BoxDecoration(
        color: Colors.transparent,
        // border: Border(...)  <-- INI DIHAPUS AJA
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
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
            height: separatorHeight,
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

          buildBtn(
            icon: Icons.search_rounded,
            onTap: _isLoading ? null : _openSearchModal,
            isActive: _isSearchModalOpen,
          ),
          // SETTINGS
          buildBtn(
            icon: Icons.text_fields_rounded,
            // 🔥 UPDATE: Matikan kalau lagi loading
            onTap: _isLoading ? null : _showSettingsModal,
          ),

          // SCROLL TOP
          buildBtn(
            icon: Icons.vertical_align_top_rounded,
            // 🔥 UPDATE: Matikan juga biar konsisten (atau biarin nyala terserah lu)
            onTap: _isLoading ? null : _scrollToTop,
          ),
          Container(
            width: 1,
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

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
