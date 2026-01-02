import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_manager.dart';
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
  double _textZoom = 100.0;
  bool _isLoading = true;
  late int _currentIndex;
  bool _isScrolled = false;
  bool _isSearchModalOpen = false;

  // 🔧 TAMBAH STATE UNTUK AUDIO
  bool _isOnline = true;
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
  String _currentAudioUrl = ""; // Buat nyimpen url audio yg aktif

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // 🔧 AUTO DETECT: File Paritta = yang ada di folder 'par/' DAN filename mulai 'p'
  bool get _isParittaPage {
    if (_currentIndex >= widget.chapterFiles.length) return false;
    final currentFile = widget.chapterFiles[_currentIndex];

    // Check: ada 'par/' di path DAN filename mulai 'p'
    final fileName = currentFile.split('/').last;
    return currentFile.contains('par/') && fileName.startsWith('p');
  }

  // ============================================
  // THEME COLORS GETTER
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
        };
      case ReaderTheme.light2:
        final t = tm.lightTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': const Color(0xFF424242),
          'note': const Color(0xFF9E9E9E),
          'card': uiCardColor,
          'icon': uiIconColor,
        };
      case ReaderTheme.sepia:
        return {
          'bg': const Color(0xFFF4ECD8),
          'text': const Color(0xFF5D4037),
          'note': const Color(0xFF8D6E63),
          'card': uiCardColor,
          'icon': uiIconColor,
        };
      case ReaderTheme.dark:
        final t = tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': t.colorScheme.onSurface,
          'note': t.colorScheme.onSurfaceVariant,
          'card': uiCardColor,
          'icon': uiIconColor,
        };
      case ReaderTheme.dark2:
        final t = tm.darkTheme;
        return {
          'bg': t.scaffoldBackgroundColor,
          'text': const Color(0xFFB0BEC5),
          'note': const Color(0xFF757575),
          'card': uiCardColor,
          'icon': uiIconColor,
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

    _loadZoomPreference();
    _loadHtmlContent();

    // 🔧 SETUP CONNECTIVITY LISTENER
    _initConnectivity();
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
    setState(() {
      _isOnline =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
    });
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
    // 1. Cek Koneksi dulu (copy logic lama kamu)
    if (!_isOnline) {
      _showAudioMessage(
        "Tidak Ada Koneksi Internet",
        "Mohon periksa koneksi internet Anda...",
        Icons.wifi_off_rounded,
        Colors.orange,
      );
      return;
    }

    // 2. Ambil URL audio halaman ini
    final fileName = _getCurrentFileName();
    final audioUrl = DaftarIsi.audioUrls[fileName];

    // 3. Cek ada audionya gak
    if (audioUrl == null || audioUrl.isEmpty) {
      _showAudioMessage(
        "Audio Tidak Tersedia",
        "Belum ada audio untuk halaman ini.",
        Icons.music_off_rounded,
        Colors.grey,
      );
      // Kalau player lagi kebuka tapi ternyata file ini gak ada audio, tutup aja
      if (_isPlayerVisible) {
        setState(() => _isPlayerVisible = false);
      }
      return;
    }

    // 4. LOGIC TOGGLE (SAKELAR)
    setState(() {
      if (_isPlayerVisible) {
        // Kalau lagi kebuka -> TUTUP
        _isPlayerVisible = false;
      } else {
        // Kalau lagi ketutup -> BUKA & SET URL BARU
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
  Future<void> _loadZoomPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _textZoom = prefs.getDouble('html_text_zoom') ?? 100.0);
    }
  }

  Future<void> _loadHtmlContent() async {
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

  Future<void> _saveZoomPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('html_text_zoom', _textZoom);
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

    final RegExp regExp = RegExp(query, caseSensitive: false);
    final matches = regExp.allMatches(_rawHtmlContent);

    _searchKeys.clear();
    int matchCounter = 0;

    String highlightedHtml = _rawHtmlContent.replaceAllMapped(
      RegExp('($query)', caseSensitive: false),
      (match) {
        final index = matchCounter++;
        return '<mark-highlight index="$index">${match.group(0)}</mark-highlight>';
      },
    );

    setState(() {
      _allMatches = matches.map((e) => e.group(0)!).toList();
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
      _displayHtmlContent = highlightedHtml;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (matches.isNotEmpty) _jumpToResult(0);
    });
  }

  void _jumpToResult(int index) {
    if (_allMatches.isEmpty) return;

    int newIndex = index;
    if (newIndex < 0) newIndex = _allMatches.length - 1;
    if (newIndex >= _allMatches.length) newIndex = 0;

    setState(() => _currentMatchIndex = newIndex);

    final key = _searchKeys[newIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.2,
        curve: Curves.easeInOut,
      );
    }

    HapticFeedback.selectionClick();
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

    setState(() => _isSearchModalOpen = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isDismissible: true,
      enableDrag: true,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  if (!mounted) return;

                                  if (val.trim().length >= 2) {
                                    _performSearch(val);
                                  }

                                  if (mounted) setSheetState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            if (mounted) Navigator.of(context).pop();
                          },
                          child: const Text("Tutup"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      Future.microtask(() {
        if (!mounted) return;

        setState(() => _isSearchModalOpen = false);

        _debounce?.cancel();
        _currentQuery = "";
        _allMatches.clear();
        _searchKeys.clear();
        _currentMatchIndex = -1;
        _displayHtmlContent = _rawHtmlContent;

        _searchController.clear();
      });
    });
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final int displayZoom = _textZoom.toInt();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Pengaturan Tampilan",
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
                    const SizedBox(height: 24),
                    Text(
                      "Tema Baca",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            "Terang 2",
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
                            "Gelap 2",
                            () => setModalState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Ukuran Teks",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            setState(() => _textZoom = 100.0);
                            _saveZoomPref();
                            setModalState(() {});
                          },
                          child: const Text("Reset"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Zoom Controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () {
                              setState(
                                () => _textZoom = (_textZoom - 10).clamp(
                                  50.0,
                                  300.0,
                                ),
                              );
                              _saveZoomPref();
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            "$displayZoom%",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () {
                              setState(
                                () => _textZoom = (_textZoom + 10).clamp(
                                  50.0,
                                  300.0,
                                ),
                              );
                              _saveZoomPref();
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
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
                          // 👇 Padding bawah tetep pake logic player
                          bottom: _isPlayerVisible ? 340 : 120,
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
                                    tagsToExtend: {"mark-highlight"},
                                    builder: (extensionContext) {
                                      final indexStr =
                                          extensionContext.attributes['index'];
                                      if (indexStr != null) {
                                        final int index = int.parse(indexStr);
                                        final key = GlobalKey();
                                        _searchKeys[index] = key;

                                        return Container(
                                          key: key,
                                          decoration: BoxDecoration(
                                            color: Colors.yellow,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            extensionContext.element!.text,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

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
    );
  }

  // ============================================
  // STYLING (CSS)
  // ============================================
  Map<String, Style> _getHtmlStyles() {
    final colors = _themeColors;
    final bgColor = colors['bg']!;
    final textColor = colors['text']!;
    final noteColor = colors['note']!;
    final fontSize = _textZoom / 100.0;

    final serifFont = GoogleFonts.varta().fontFamily!;
    final sansFont = GoogleFonts.varta().fontFamily!;

    final isDarkVariant =
        _readerTheme == ReaderTheme.dark || _readerTheme == ReaderTheme.dark2;
    final paliAccentColor = isDarkVariant
        ? const Color(0xFFD4A574)
        : const Color(0xFF8B4513);

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
        fontFamily: sansFont,
        fontSize: FontSize(16 * fontSize),
        lineHeight: const LineHeight(1.6),
        padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 0),
        margin: Margins.zero,
      ),

      "#isi": Style(margin: Margins.zero, padding: HtmlPaddings.zero),

      "h1": Style(
        fontFamily: serifFont,
        fontSize: FontSize(22 * fontSize),
        fontWeight: FontWeight.bold,
        padding: HtmlPaddings.only(bottom: 5),
        margin: Margins.only(top: 10, bottom: 5),
        border: Border(
          bottom: BorderSide(color: noteColor.withValues(alpha: 0.3), width: 1),
        ),
      ),

      "h2": Style(
        fontFamily: serifFont,
        fontSize: FontSize(18 * fontSize),
        fontWeight: FontWeight.bold,
        margin: Margins.only(top: 25, bottom: 10),
      ),

      "h1 span.indo": Style(
        fontFamily: sansFont,
        fontWeight: FontWeight.normal,
        display: Display.block,
        margin: Margins.only(top: 2),
        fontSize: FontSize(16 * fontSize),
        color: textColor.withValues(alpha: 0.8),
        fontStyle: FontStyle.italic,
      ),

      "p": Style(
        fontFamily: serifFont,
        fontWeight: FontWeight.w600,
        color: paliAccentColor,
        margin: Margins.only(bottom: 6),
        fontSize: FontSize(16 * fontSize),
      ),

      "p.indo": Style(
        fontFamily: serifFont,
        fontWeight: FontWeight.normal,
        color: textColor,
        margin: Margins.only(bottom: 20),
        fontSize: FontSize(15 * fontSize),
      ),

      "p.footnote": Style(
        fontStyle: FontStyle.italic,
        fontFamily: sansFont,
        fontSize: FontSize(13 * fontSize),
        color: noteColor,
        margin: Margins.only(bottom: 4),
      ),

      "div.isi": Style(
        backgroundColor: contentBoxColor,
        padding: HtmlPaddings.all(12),
        margin: Margins.symmetric(vertical: 10),
        border: Border(
          left: BorderSide(color: paliAccentColor, width: 4),
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

      "div.nomor": Style(
        fontFamily: sansFont,
        fontSize: FontSize(14 * fontSize),
        color: noteColor,
        margin: Margins.only(bottom: 4, top: 4),
        fontWeight: FontWeight.bold,
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
        fontSize: FontSize(15 * fontSize),
        fontWeight: FontWeight.bold,
        color: textColor,
      ),

      "span.dindo": Style(
        fontFamily: sansFont,
        display: Display.block,
        margin: Margins.only(top: 2),
        fontSize: FontSize(13 * fontSize),
        fontWeight: FontWeight.normal,
        color: noteColor,
      ),

      ".guide": Style(
        fontFamily: sansFont,
        display: Display.block,
        margin: Margins.only(top: 2),
        fontSize: FontSize(14 * fontSize),
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
      if (url.contains(fileName)) {
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                            size: 20,
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
  Widget _buildFloatingActions(bool isPrevDisabled, bool isNextDisabled) {
    final systemScheme = Theme.of(context).colorScheme;
    final containerColor = systemScheme.surface;
    final iconColor = systemScheme.onSurface;
    final activeColor = systemScheme.primary;
    final shadowColor = Colors.black.withValues(alpha: 0.15);
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    // 🔧 Audio button logic - AUTO DETECT dari file path
    final bool showAudioButton = _isParittaPage;
    final bool hasAudioForPage = _hasAudioForCurrentPage();

    final bool isAudioButtonEnabled =
        _isOnline && hasAudioForPage && !_isPlayerVisible;

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
            padding: const EdgeInsets.all(12),
            decoration: isActive
                ? BoxDecoration(
                    color: activeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Icon(icon, color: finalColor, size: 24),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            height: 24,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          // 🔧 AUDIO BUTTON (conditional - paling kiri)
          // 🔧 AUDIO BUTTON (conditional - paling kiri)
          if (showAudioButton) ...[
            AnimatedOpacity(
              opacity: isAudioButtonEnabled ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: buildBtn(
                icon: Icons.headphones_rounded,
                //onTap: _handleAudioButtonPress,
                onTap: isAudioButtonEnabled ? _handleAudioButtonPress : null,
              ),
            ),
          ],
          // TEMATIK LIST (conditional)
          if (widget.tematikChapterIndex != null)
            buildBtn(
              icon: Icons.library_books_outlined,
              onTap: _showTematikListModal,
            ),

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
            height: 24,
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
