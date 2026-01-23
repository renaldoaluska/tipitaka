import 'dart:async';
import 'dart:ui';
import '../models/reader_enums.dart';
import '../widgets/sutta_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/system_ui_helper.dart';
import '../data/html_data.dart';
import '../widgets/audio.dart';
import '../widgets/tematik_chapter_list.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  // --- STATE SCROLLBAR (PERSIS SUTTA_DETAIL) ---
  final ValueNotifier<double> _scrollProgressVN = ValueNotifier(0.0);
  final ValueNotifier<double> _viewportRatioVN = ValueNotifier(0.1);
  bool _isUserDragging = false;

  //final ThemeManager _tm = ThemeManager();
  // ============================================
  // STATE VARIABLES
  // ============================================
  // --- STATE GESTURE SWIPE ---
  double _dragStartX = 0.0;
  double _currentDragX = 0.0;
  final double _minDragDistance = 100.0; // Threshold minimal swipe (100px)

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

  //  TAMBAH INI: Notifier untuk index aktif agar tidak perlu render ulang HTML
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

  Color _customBgColor = Colors.white;
  Color _customTextColor = Colors.black;
  Color _customPaliColor = const Color(
    0xFF8B4513,
  ); // Warna Pali default (coklat)

  // Getter pusat (pastikan ReaderThemeStyle.getStyle sudah diupdate terima 3 warna)
  ReaderThemeStyle get _currentStyle => ReaderThemeStyle.getStyle(
    _readerTheme,
    customBg: _customBgColor,
    customText: _customTextColor,
    customPali: _customPaliColor,
  );

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

    _scrollController.addListener(_updateScrollMetrics); // Tambahkan ini
    _loadPreferences();
  }

  void _updateScrollMetrics() {
    if (!mounted || _isUserDragging || !_scrollController.hasClients) return;

    final pos = _scrollController.positions.last;
    if (pos.maxScrollExtent <= 0) return;

    // HANYA update progress posisi, jangan update rasionya di sini
    _scrollProgressVN.value = (pos.pixels / pos.maxScrollExtent).clamp(
      0.0,
      1.0,
    );
  }

  // 1. Fungsi khusus hitung rasio (Set di awal saja)
  void _updateViewportRatio() {
    // Gunakan postFrameCallback agar maxScrollExtent sudah akurat setelah render
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔥 TAMBAHKAN DELAY KECIL (100-200ms)
      // Memberi waktu bagi widget Html untuk menyelesaikan layouting
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted || !_scrollController.hasClients) return;

      final pos = _scrollController.positions.last;

      // 1. Hitung Rasio (Tinggi Jempol)
      if (pos.maxScrollExtent > 0) {
        final double totalContentHeight =
            pos.maxScrollExtent + pos.viewportDimension;
        double targetRatio = pos.viewportDimension / totalContentHeight;
        _viewportRatioVN.value = targetRatio.clamp(0.1, 1.0);

        // 2. 🔥 PAKSA UPDATE PROGRESS (Posisi Jempol)
        // Agar jempol langsung berada di paling atas (0.0)
        _scrollProgressVN.value = (pos.pixels / pos.maxScrollExtent).clamp(
          0.0,
          1.0,
        );
      } else {
        // Jika konten sangat pendek (tidak bisa discroll)
        _viewportRatioVN.value = 1.0;
        _scrollProgressVN.value = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollMetrics); // Tambahkan ini
    _scrollController.dispose();

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

  //  LOAD AUDIO URLS DARI FIREBASE/CACHE
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

  //  SETUP REALTIME LISTENER (OPTIONAL - untuk auto-update)
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

        // Load Warna Kustom
        // Gunakan key universal tanpa prefix biar sinkron
        _customBgColor = Color(
          prefs.getInt('custom_bg_color') ?? Colors.white.toARGB32(),
        );
        _customTextColor = Color(
          prefs.getInt('custom_text_color') ?? Colors.black.toARGB32(),
        );
        _customPaliColor = Color(
          prefs.getInt('custom_pali_color') ??
              const Color(0xFF8B4513).toARGB32(),
        );

        // Load Theme Index
        int themeIdx = prefs.getInt('reader_theme_index') ?? 0;
        _readerTheme = ReaderTheme
            .values[themeIdx.clamp(0, ReaderTheme.values.length - 1)];
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
        //   final brightness = Theme.of(context).brightness;
        // ambil brightness langsung dari sistem/window, gak butuh context tree
        final brightness = View.of(
          context,
        ).platformDispatcher.platformBrightness;
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
      _updateViewportRatio(); //  Tambahkan ini untuk set panjang awal bab
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
    await prefs.setBool('html_bottom_menu_visible', _isBottomMenuVisible);

    await prefs.setInt('custom_bg_color', _customBgColor.toARGB32());
    await prefs.setInt('custom_text_color', _customTextColor.toARGB32());
    await prefs.setInt('custom_pali_color', _customPaliColor.toARGB32());
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
  //  FIX SEARCH LOGIC: ANTI JEBOL HTML TAG
  // ============================================
  void _applySearchHighlight(String query) {
    if (query.length < 2) return;

    final RegExp paliRegExp = _createPaliRegex(query.trim());
    final String pattern = '(<[^>]+>)|(${paliRegExp.pattern})';
    final RegExp combinedRegex = RegExp(pattern, caseSensitive: false);

    //  Reset Keys di sini (Hanya saat QUERY berubah/search baru)
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

        //  SIMPELKAN: Cukup kasih index saja. Style & Warna kita atur di Widget Builder nanti.
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

    //  UPDATE STATE TANPA RE-RENDER HTML
    setState(() {
      _currentMatchIndex = newIndex;
    });

    //  Update Notifier biar warnanya berubah (kuning -> oranye)
    _activeSearchIndex.value = newIndex;

    //  JALANKAN SCROLL
    // Karena HTML tidak dihancurkan, Key-nya masih ada dan valid!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _searchKeys[newIndex];
      // Cek apakah key ada dan punya context
      // SESUDAH (Ganti Baris 626-633):
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
          curve: Curves.easeInOutCubic,
        );
      } else {
        debugPrint("Context tidak ditemukan untuk index $newIndex");
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

  //  HELPER BARU: Hitung posisi notif biar gak ketutupan menu
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

  //  UPDATE 1: AUDIO MESSAGE
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
        //  UPDATE MARGIN DISINI
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin, // <-- Ini kuncinya!
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  //  UPDATE 2: NAVIGATION MESSAGE (Mentok Kiri/Kanan)
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
        //  UPDATE MARGIN DISINI JUGA
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

        //  SEMUANYA MASUKIN SINI BIAR RAPI & UI KE-UPDATE BARENGAN
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SuttaSettingsSheet(
          isSegmented: false, // HTML reader bukan segmented
          lang: 'id',
          isRootOnly: false,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          horizontalPadding: _horizontalPadding,
          fontType: _fontType,
          viewMode: ViewMode.translationOnly, // Default untuk HTML
          readerTheme: _readerTheme,

          // 1. Tambahkan parameter warna ketiga
          customBgColor: _customBgColor,
          customTextColor: _customTextColor,
          customPaliColor: _customPaliColor, // <--- Tambahkan ini

          onFontSizeChanged: (val) {
            setState(() => _fontSize = val);
            _savePreferences();
            _updateViewportRatio(); //  Hitung ulang karena teks membesar/mengecil
          },
          onLineHeightChanged: (val) {
            setState(() => _lineHeight = val);
            _savePreferences();
          },
          onPaddingChanged: (val) {
            setState(() => _horizontalPadding = val);
            _savePreferences();
          },
          onFontTypeChanged: (val) {
            setState(() => _fontType = val);
            _savePreferences();
          },
          onViewModeChanged: (val) {}, // Tidak berpengaruh di HTML reader
          onThemeChanged: (val) {
            setState(() => _readerTheme = val);
            _savePreferences();
          },

          // 2. Ubah callback agar menerima 3 argumen (bg, txt, pali)
          onCustomColorsChanged: (bg, txt, pali) {
            // <--- Tambahkan 'pali'
            setState(() {
              _customBgColor = bg;
              _customTextColor = txt;
              _customPaliColor = pali; // <--- Simpan warna pali juga
            });
            _savePreferences();
          },
        );
      },
    );
  }

  // ============================================
  // BUILD METHOD
  // ============================================
  @override
  Widget build(BuildContext context) {
    final colors = _currentStyle;
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
          backgroundColor: colors.bg,
          body: GestureDetector(
            //  TAMBAH WRAPPER INI
            onHorizontalDragStart: (details) {
              setState(() {
                _dragStartX = details.globalPosition.dx;
                _currentDragX = details.globalPosition.dx;
              });
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _currentDragX = details.globalPosition.dx;
              });
            },
            onHorizontalDragEnd: (details) {
              final double distance = _currentDragX - _dragStartX;

              // Cek apakah gerakannya cukup jauh
              if (distance.abs() > _minDragDistance) {
                if (distance > 0) {
                  // ➡️ SWIPE KANAN (PREV)
                  if (!_isLoading && _currentIndex > 0) {
                    _goToIndex(_currentIndex - 1);
                  } else if (_currentIndex <= 0) {
                    _showNavigationMessage(true); // Notif "Halaman awal"
                  }
                } else {
                  // ⬅️ SWIPE KIRI (NEXT)
                  if (!_isLoading &&
                      _currentIndex < widget.chapterFiles.length - 1) {
                    _goToIndex(_currentIndex + 1);
                  } else if (_currentIndex >= widget.chapterFiles.length - 1) {
                    _showNavigationMessage(false); // Notif "Halaman akhir"
                  }
                }
              }

              // RESET posisi
              setState(() {
                _dragStartX = 0.0;
                _currentDragX = 0.0;
              });
            },

            child: SizedBox.expand(
              child: Stack(
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
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    scrollbars: false,
                                  ), // 👈 MATIIN SCROLLBAR OS
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
                                            : (_isBottomMenuVisible
                                                  ? 120
                                                  : 50)),
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

                                              // 1. AMANKAN ELEMENT & TEKS (Pake ? dan ??)
                                              final element =
                                                  extensionContext.element;
                                              final text = element?.text ?? "";

                                              // Kalau teks kosong, jangan render apa-apa
                                              if (text.isEmpty) {
                                                return const SizedBox.shrink();
                                              }

                                              final style = extensionContext
                                                  .styledElement
                                                  ?.style;
                                              double? currentFontSize =
                                                  style?.fontSize?.value;
                                              currentFontSize ??= _fontSize;

                                              if (indexStr != null) {
                                                final int index =
                                                    int.tryParse(indexStr) ?? 0;
                                                final key = _searchKeys
                                                    .putIfAbsent(
                                                      index,
                                                      () => GlobalKey(),
                                                    );

                                                return ValueListenableBuilder<
                                                  int
                                                >(
                                                  valueListenable:
                                                      _activeSearchIndex,
                                                  builder: (context, activeIndex, child) {
                                                    final bool isActive =
                                                        (activeIndex == index);

                                                    return Container(
                                                      key: key,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 0,
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
                                                                width: 1,
                                                              )
                                                            : null,
                                                      ),
                                                      child: Transform.translate(
                                                        offset: const Offset(
                                                          0,
                                                          0,
                                                        ),
                                                        child: Text(
                                                          text,
                                                          style: TextStyle(
                                                            color: isActive
                                                                ? Colors.white
                                                                : Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize:
                                                                currentFontSize,
                                                            height: _lineHeight,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              }
                                              return Text(
                                                text,
                                                style: TextStyle(
                                                  fontSize: currentFontSize,
                                                  height: _lineHeight,
                                                ),
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

                  //  INDIKATOR SWIPE VISUAL (PANAH ANIMASI)
                  if (_dragStartX != 0.0 && _currentDragX != 0.0)
                    Builder(
                      builder: (context) {
                        final delta = _currentDragX - _dragStartX;
                        final isSwipeRight = delta > 0;
                        final isSwipeLeft = delta < 0;

                        // Progress 0.0 - 1.0 (berapa persen dari threshold)
                        final progress = (delta.abs() / _minDragDistance).clamp(
                          0.0,
                          1.0,
                        );

                        // Jangan render kalau gesernya masih dikit banget
                        if (progress < 0.05) return const SizedBox.shrink();

                        // CEK KALAU MENTOK (Gak ada halaman prev/next)
                        if (isSwipeRight && _currentIndex <= 0) {
                          return const SizedBox.shrink();
                        }
                        if (isSwipeLeft &&
                            _currentIndex >= widget.chapterFiles.length - 1) {
                          return const SizedBox.shrink();
                        }

                        return Positioned(
                          top: 0,
                          bottom: 0,
                          left: isSwipeRight
                              ? 24
                              : null, // Kalau tarik kanan, muncul di kiri
                          right: isSwipeLeft
                              ? 24
                              : null, // Kalau tarik kiri, muncul di kanan
                          child: Center(
                            child: Opacity(
                              opacity:
                                  progress, // Makin jauh tarik, makin jelas
                              child: Transform.scale(
                                scale:
                                    0.5 +
                                    (0.5 * progress), // Efek membesar (Pop)
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .inverseSurface
                                        .withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 16,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isSwipeRight
                                        ? Icons.arrow_back_rounded
                                        : Icons.arrow_forward_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onInverseSurface,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  //  UPDATE TERBARU: BOTTOM MENU (GLASSMORPHISM)
                  //  UPDATE TERBARU: AUDIO PLAYER LEBIH NAIK
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Align(
                      // ✅ TAMBAHIN INI
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // 1. AUDIO PLAYER
                          if (_isPlayerVisible) ...[
                            Padding(
                              //  UBAH DISINI BANG:
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
                          //   Align(
                          //    alignment: Alignment.bottomCenter,
                          //    child:
                          Container(
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
                                      //  DRAG HANDLE / GARIS (SAMA KAYAK SUTTA DETAIL)
                                      // ===============================================
                                      GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        // Fitur Swipe buat tutup/buka
                                        onVerticalDragEnd: (details) {
                                          final velocity =
                                              details.primaryVelocity ?? 0;
                                          if (velocity > 0 &&
                                              _isBottomMenuVisible) {
                                            setState(
                                              () =>
                                                  _isBottomMenuVisible = false,
                                            );
                                            _savePreferences();
                                          } else if (velocity < 0 &&
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
                                              width:
                                                  40, // Lebar disamain (tadi 48)
                                              height: 3,
                                              decoration: BoxDecoration(
                                                // Warna disamain (pake onSurface + 0.15)
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ===============================================
                                      // MENU CONTENT
                                      // ===============================================
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
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
                                                    widget.chapterFiles.length -
                                                        1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  //  REAL DRAGGABLE SCROLLBAR (PERSIS SUTTA_DETAIL)
                  if (!_isLoading)
                    ValueListenableBuilder<double>(
                      valueListenable: _viewportRatioVN,
                      builder: (context, ratio, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _scrollProgressVN,
                          builder: (context, progress, _) {
                            return Positioned(
                              right: 0,
                              top:
                                  MediaQuery.of(context).padding.top +
                                  80, // Jarak dari atas
                              bottom: _isBottomMenuVisible
                                  ? 100
                                  : 20, // Jarak dari bawah (adaptif menu)
                              width: 30,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final double trackHeight =
                                      constraints.maxHeight;
                                  final double thumbHeight =
                                      (trackHeight * ratio).clamp(
                                        40.0,
                                        trackHeight,
                                      );
                                  final double scrollableArea =
                                      trackHeight - thumbHeight;
                                  final double thumbTop =
                                      (progress * scrollableArea).clamp(
                                        0.0,
                                        scrollableArea,
                                      );

                                  return GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onVerticalDragStart: (_) =>
                                        setState(() => _isUserDragging = true),
                                    onVerticalDragUpdate: (details) {
                                      final double fingerY =
                                          details.localPosition.dy;
                                      final double targetThumbTop =
                                          fingerY - (thumbHeight / 2);
                                      final double newProgress =
                                          (targetThumbTop / scrollableArea)
                                              .clamp(0.0, 1.0);

                                      // Update UI langsung
                                      _scrollProgressVN.value = newProgress;

                                      //  Pake positions.last.maxScrollExtent biar nggak crash
                                      final maxScroll = _scrollController
                                          .positions
                                          .last
                                          .maxScrollExtent;
                                      _scrollController.jumpTo(
                                        newProgress * maxScroll,
                                      );
                                    },
                                    onVerticalDragEnd: (_) =>
                                        setState(() => _isUserDragging = false),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: thumbTop,
                                          right: 2,
                                          child: Container(
                                            width: 6,
                                            height: thumbHeight,
                                            decoration: BoxDecoration(
                                              color: _isUserDragging
                                                  ? _currentStyle.pali
                                                        .withValues(
                                                          alpha: 0.8,
                                                        ) // Warna saat ditarik
                                                  : _currentStyle.text
                                                        .withValues(
                                                          alpha: 0.4,
                                                        ), // Warna diam
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
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
    final colors = _currentStyle;

    final bgColor = colors.bg;
    final textColor = colors.text;
    final paliAccentColor = colors.pali;

    //  FORMULA WARNA PINTAR (Biar Reader Theme Konsisten)
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

        //  UBAH BAGIAN INI:
        // Tambahin 'top: 16' biar ada jarak dari teks terjemahan di atasnya.
        // 'bottom: 8' tetep ada biar jarak ke terjemahan di bawahnya rapet.
        margin: Margins.only(top: 16, bottom: 8),

        fontSize: FontSize(_fontSize),
        lineHeight: LineHeight(_lineHeight),
      ),

      // ===========================================
      // 4. TEKS TERJEMAHAN (SEKUNDER)
      // ===========================================
      "p.indo": Style(
        fontFamily: mainFont,
        fontWeight: FontWeight.normal,
        color: textColor.withValues(alpha: 0.9),

        //  UBAH BAGIAN INI:
        // Kasih jarak bawah 12 biar antar paragraf Indo ada napasnya.
        // Kalau ketemu Pali di bawahnya, jaraknya bakal nambah (jadi pemisah ayat yang tegas).
        margin: Margins.only(bottom: 12),

        fontSize: FontSize(_fontSize),
        // Tambahin dikit line-height biar teks panjang lebih enak dibaca
        //   lineHeight: LineHeight(1.5),
        lineHeight: LineHeight(_lineHeight),
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
        // border: Border(
        //  left: BorderSide(
        //     color: textColor.withValues(alpha: 0.6), // Ngikut warna tema
        //     width: 1,
        //   ),
        // ),
        padding: HtmlPaddings.only(left: 0, top: 4, bottom: 4),
        margin: Margins.only(bottom: 24),
      ),

      // ===========================================
      // 4. DAFTAR ISI (TOMBOL "SOFT BUTTON")
      // ===========================================
      "div.daftar": Style(
        margin: Margins.only(top: 10, bottom: 32),
        display: Display.block,
      ),

      //  INI DIA: Tampilan "Bisa Dipencet" tapi Gak Norak
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
      String tooltip = "",
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
          child: Tooltip(
            message: tooltip,
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
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: internalPaddingH,
        vertical: internalPaddingV,
      ),
      //  UPDATE: Border DIHAPUS total biar nyatu sama kaca
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          buildBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: "Sebelumnya",
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
            tooltip: "Pencarian",
            icon: Icons.search_rounded,
            onTap: _isLoading ? null : _openSearchModal,
            isActive: _isSearchModalOpen,
          ),
          // SETTINGS
          buildBtn(
            tooltip: "Tampilan",
            icon: Icons.text_fields_rounded,
            //  UPDATE: Matikan kalau lagi loading
            onTap: _isLoading ? null : _showSettingsModal,
          ),

          // SCROLL TOP
          buildBtn(
            tooltip: "Menu Atas",
            icon: Icons.vertical_align_top_rounded,
            //  UPDATE: Matikan juga biar konsisten (atau biarin nyala terserah lu)
            onTap: _isLoading ? null : _scrollToTop,
          ),
          Container(
            width: 1,
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          buildBtn(
            tooltip: "Selanjutnya",
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
