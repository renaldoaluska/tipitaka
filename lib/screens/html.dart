import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/theme_manager.dart';

// Taruh di paling atas file html.dart (di luar class)
enum ReaderTheme { light, light2, sepia, dark, dark2 }

class HtmlReaderPage extends StatefulWidget {
  final String title;
  final List<String> chapterFiles;
  final int initialIndex;

  const HtmlReaderPage({
    super.key,
    required this.title,
    required this.chapterFiles,
    this.initialIndex = 0,
  });

  @override
  State<HtmlReaderPage> createState() => _HtmlReaderPageState();
}

class _HtmlReaderPageState extends State<HtmlReaderPage> {
  // Tambah variabel state ini
  ReaderTheme _readerTheme = ReaderTheme.light;
  // ✅ COPAS GETTER SAKTI INI KE DALAM CLASS _HtmlViewerScreenState
  Map<String, Color> get _themeColors {
    final systemScheme = Theme.of(context).colorScheme;
    final uiCardColor = systemScheme.surface;
    final uiIconColor = systemScheme.onSurface;

    final tm = ThemeManager(); // Pastikan import theme_manager.dart

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
          'text': const Color(0xFF424242), // Abu Tua Soft
          'note': Colors.grey[500]!,
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
          'text': const Color(0xFFB0BEC5), // Abu Kebiruan
          'note': Colors.grey[600]!,
          'card': uiCardColor,
          'icon': uiIconColor,
        };
    }
  }

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  double _textZoom = 100.0;
  bool _isLoading = true;
  late int _currentIndex;
  bool _isScrolled = false;

  // Variabel untuk konten
  String _rawHtmlContent = ''; // HTML murni dari file
  String _displayHtmlContent = ''; // HTML yang dirender (bisa ada highlight)

  // Variabel Search
  Timer? _debounce;

  List<String> _allMatches = [];
  int _currentMatchIndex = 0;
  String _currentQuery = "";

  final Map<int, GlobalKey> _searchKeys = {};
  // ✅ TAMBAH INI: Penanda apakah menu search lagi kebuka atau ngga
  bool _isSearchModalOpen = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadZoomPreference();
    _loadHtmlContent();

    _scrollController.addListener(() {
      final isScrolled = _scrollController.offset > 0;
      if (isScrolled != _isScrolled) {
        setState(() => _isScrolled = isScrolled);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadZoomPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _textZoom = prefs.getDouble('html_text_zoom') ?? 100.0);
    }
  }

  int get displayZoom => _textZoom.round();

  Future<void> _loadHtmlContent() async {
    setState(() => _isLoading = true);

    try {
      final htmlFile = widget.chapterFiles[_currentIndex];

      // Load konten file HTML
      String content = await rootBundle.loadString(htmlFile);

      // ✅ 1. AMBIL DATA PREFERENSI TEMA
      final prefs = await SharedPreferences.getInstance();

      // ✅ 2. CEK MOUNTED SETELAH AWAIT (PENTING!)
      if (!mounted) return;

      // ✅ 3. LOGIC PENENTUAN TEMA (Sama kayak di Sutta)
      final themeIndex = prefs.getInt('reader_theme_index');
      ReaderTheme targetTheme;

      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < ReaderTheme.values.length) {
        // Kalau ada simpenan, pake itu
        targetTheme = ReaderTheme.values[themeIndex];
      } else {
        // Kalau gak ada, fallback ke System HP (Dark/Light)
        final brightness = Theme.of(context).brightness;
        targetTheme = brightness == Brightness.dark
            ? ReaderTheme.dark
            : ReaderTheme.light;
      }

      // Update state tema biar background Scaffold & Style berubah
      setState(() {
        _readerTheme = targetTheme;
      });

      // ✅ 4. TENTUKAN CLASS CSS (mode-dark / mode-light)
      // Sepia, Light, Light2 --> Masuk kategori 'mode-light' (Teks gelap)
      // Dark, Dark2 ---------> Masuk kategori 'mode-dark' (Teks terang)
      final isDarkVariant =
          targetTheme == ReaderTheme.dark || targetTheme == ReaderTheme.dark2;
      final themeClass = isDarkVariant ? 'mode-dark' : 'mode-light';

      // Inject class body
      content = content.replaceFirst('<body>', '<body class="$themeClass">');

      _rawHtmlContent = content;

      // Kalau ada query search aktif, apply highlight lagi saat ganti halaman
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
      // Reset scroll ke atas saat ganti bab
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }
  // --- LOGIC SEARCH & HIGHLIGHT ---

  void _performSearch(String query) {
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

    // Reset keys setiap kali search baru
    _searchKeys.clear();
    int matchCounter = 0; // Counter manual

    // Kita pakai tag khusus <mark-highlight> biar gampang ditangkep sama flutter_html
    String highlightedHtml = _rawHtmlContent.replaceAllMapped(
      RegExp('($query)', caseSensitive: false),
      (match) {
        final index = matchCounter++;
        // Inject atribut index ke dalam tag
        return '<mark-highlight index="$index">${match.group(0)}</mark-highlight>';
      },
    );

    setState(() {
      _allMatches = matches.map((e) => e.group(0)!).toList();
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
      _displayHtmlContent = highlightedHtml;
    });

    // Opsional: Langsung scroll ke hasil pertama setelah search selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (matches.isNotEmpty) _jumpToResult(0);
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

    // ✅ LOGIC SCROLL SAKTI
    // Ambil key sesuai index saat ini
    final key = _searchKeys[newIndex];

    // Cek apakah key-nya valid dan ada di layar/tree
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300), // Durasi animasi
        alignment:
            0.2, // 0.0 = paling atas, 0.5 = tengah layar, 1.0 = paling bawah
        curve: Curves.easeInOut,
      );
    }

    HapticFeedback.selectionClick();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = "";
      _allMatches.clear();
      _currentMatchIndex = -1;
      _displayHtmlContent = _rawHtmlContent; // Balikin ke HTML original
    });
  }

  // --- NAVIGATION ---

  Future<void> _handleBackNavigation() async {
    if (_currentIndex > 0) {
      _goToIndex(0); // Balik ke cover/awal
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  void _goToIndex(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.chapterFiles.length) {
      // Clear search saat pindah halaman manual
      _currentQuery = "";
      _allMatches.clear();

      setState(() {
        _currentIndex = newIndex;
      });
      _loadHtmlContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _themeColors;

    final bool isFirst = _currentIndex <= 0;
    final bool isLast = _currentIndex >= widget.chapterFiles.length - 1;

    // Mengurangi jarak atas biar ga kopong banget
    final double topPadding = MediaQuery.of(context).padding.top + 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: colors['bg'],
        // backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // BODY CONTENT DENGAN ANIMASI
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepOrange,
                      ),
                    )
                  : AnimatedSwitcher(
                      // ANIMASI TRANSISI HALAMAN YANG LEBIH SMOOTH
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: SingleChildScrollView(
                        key: ValueKey<int>(
                          _currentIndex,
                        ), // Penting buat animasi
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                          bottom: 120,
                        ), // Space buat FAB
                        child: Html(
                          data: _displayHtmlContent,
                          style: _getHtmlStyles(),

                          // ✅ SYNTAX V3 STABLE: Pakai 'extensions'
                          extensions: [
                            TagExtension(
                              tagsToExtend: {"mark-highlight"},
                              builder: (extensionContext) {
                                // Ambil index dari atribut
                                final indexStr =
                                    extensionContext.attributes['index'];

                                if (indexStr != null) {
                                  final int index = int.parse(indexStr);
                                  final key = GlobalKey();
                                  _searchKeys[index] = key; // Simpan Key

                                  // Render highlight-nya
                                  return Container(
                                    key: key, // Tempel Key di sini!
                                    decoration: BoxDecoration(
                                      color: Colors.yellow,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    // Ambil teks asli di dalamnya
                                    child: Text(
                                      extensionContext.element!.text,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                // Fallback kalau index ga ada
                                return Text(extensionContext.element!.text);
                              },
                            ),
                          ],

                          onLinkTap: (url, attributes, element) {
                            if (url != null) {
                              _handleLinkTap(url);
                            }
                          },
                        ),
                      ),
                    ),
            ),

            // HEADER (FLOATING)
            _buildHeader(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildFloatingActions(isFirst, isLast),
      ),
    );
  }

  // --- STYLING (CSS) ---
  Map<String, Style> _getHtmlStyles() {
    // 1. AMBIL WARNA DARI KOKI PINTAR
    final colors = _themeColors;
    final bgColor = colors['bg']!; // Background Halaman
    final textColor = colors['text']!; // Warna Teks Utama
    final noteColor = colors['note']!; // Warna Catatan Kaki/Nomor

    final fontSize = _textZoom / 100.0;

    // 2. LOGIC WARNA AKSEN (PALI & BORDER)
    // Dark/Dark2 -> Emas Pudar
    // Light/Sepia -> Coklat Tua
    final isDarkVariant =
        _readerTheme == ReaderTheme.dark || _readerTheme == ReaderTheme.dark2;
    final paliAccentColor = isDarkVariant
        ? const Color(0xFFD4A574)
        : const Color(0xFF8B4513);

    // 3. LOGIC WARNA KOTAK KONTEN (div.isi)
    Color contentBoxColor;
    if (isDarkVariant) {
      contentBoxColor = const Color(0xFF252525); // Abu Gelap
    } else if (_readerTheme == ReaderTheme.sepia) {
      contentBoxColor = const Color(
        0xFFFFF8E1,
      ); // Krem Muda (Amber 50) biar manis di atas Sepia
    } else {
      contentBoxColor = Colors.white; // Putih Polos (untuk Light/Light2)
    }

    return {
      // Base body
      "body": Style(
        backgroundColor: bgColor, // ✅ Ikut Tema Reader
        color: textColor, // ✅ Ikut Tema Reader
        fontFamily: 'Noto Serif',
        fontSize: FontSize(16 * fontSize),
        lineHeight: const LineHeight(1.6),
        padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 0),
        margin: Margins.zero,
      ),

      "#isi": Style(margin: Margins.zero, padding: HtmlPaddings.zero),

      // Headers
      "h1": Style(
        fontFamily: 'Noto Serif',
        fontSize: FontSize(22 * fontSize),
        fontWeight: FontWeight.bold,
        padding: HtmlPaddings.only(bottom: 5),
        margin: Margins.only(top: 10, bottom: 5),
        border: Border(
          bottom: BorderSide(
            color: noteColor.withValues(alpha: 0.3), // ✅ Pake NoteColor
            width: 1,
          ),
        ),
      ),
      "h2": Style(
        fontFamily: 'Noto Serif',
        fontSize: FontSize(18 * fontSize),
        fontWeight: FontWeight.bold,
        margin: Margins.only(top: 25, bottom: 10),
      ),

      // Span indo inside headers
      "h1 span.indo": Style(
        fontWeight: FontWeight.normal,
        display: Display.block,
        margin: Margins.only(top: 2),
        fontSize: FontSize(16 * fontSize),
        color: textColor.withValues(alpha: 0.8), // ✅ Pake TextColor
        fontStyle: FontStyle.italic,
      ),

      // Paragraphs (Pali Text)
      "p": Style(
        fontFamily: 'Noto Serif',
        fontWeight: FontWeight.w600,
        color: paliAccentColor, // ✅ Emas (Gelap) atau Coklat (Terang)
        margin: Margins.only(bottom: 6),
        fontSize: FontSize(16 * fontSize),
      ),

      // Terjemahan Indonesia
      "p.indo": Style(
        fontWeight: FontWeight.normal,
        color: textColor, // ✅ Ikut Tema Reader
        margin: Margins.only(bottom: 20),
        fontSize: FontSize(15 * fontSize),
      ),

      // Footnote
      "p.footnote": Style(
        fontSize: FontSize(13 * fontSize),
        color: noteColor, // ✅ Ikut Tema Reader
        margin: Margins.only(bottom: 4),
      ),

      // Container ayat (div.isi)
      "div.isi": Style(
        backgroundColor: contentBoxColor, // ✅ Warna Kotak Dinamis
        padding: HtmlPaddings.all(12),
        margin: Margins.symmetric(vertical: 10),
        border: Border(
          left: BorderSide(
            color: paliAccentColor, // ✅ Border Kiri ikut warna Pali
            width: 4,
          ),
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

      // Nomor Ayat
      "div.nomor": Style(
        fontSize: FontSize(14 * fontSize),
        color: noteColor, // ✅ Ikut Tema Reader
        margin: Margins.only(bottom: 4, top: 4),
        fontWeight: FontWeight.bold,
      ),

      // Container Daftar Isi
      "div.daftar": Style(
        margin: Margins.only(top: 10),
        display: Display.block,
      ),

      // Item Daftar Isi
      "div.daftar-child": Style(
        backgroundColor: contentBoxColor, // ✅ Kotak daftar isi juga ngikut
        padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 10),
        margin: Margins.only(bottom: 8),
        border: Border(
          left: BorderSide(color: const Color(0xFF4CAF50), width: 3),
        ),
      ),

      // Teks Judul Daftar Isi
      ".daftar-child": Style(
        fontSize: FontSize(15 * fontSize),
        fontWeight: FontWeight.bold,
        color: textColor, // ✅ Ikut Tema Reader
      ),

      // Subtitle Daftar Isi
      "span.dindo": Style(
        display: Display.block,
        margin: Margins.only(top: 2),
        fontSize: FontSize(13 * fontSize),
        fontWeight: FontWeight.normal,
        color: noteColor, // ✅ Ikut Tema Reader
      ),

      "a": Style(
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

  // --- HEADER & FOOTER UI ---

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.85),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _handleBackNavigation,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "Halaman ${_currentIndex + 1} / ${widget.chapterFiles.length}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
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
    );
  }

  Widget _buildFloatingActions(bool isPrevDisabled, bool isNextDisabled) {
    // 1. Setup Warna (Ambil dari System Theme, JANGAN dari Reader Theme)
    final systemScheme = Theme.of(context).colorScheme;
    final containerColor = systemScheme.surface; // Putih/Hitam HP
    final iconColor = systemScheme.onSurface; // Hitam/Putih Teks UI
    final activeColor = systemScheme.primary; // Warna Oren
    final shadowColor = Colors.black.withValues(alpha: 0.15);

    // Warna khusus buat tombol mentok (Abu pudar)
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    // 2. Helper Button Builder
    Widget buildBtn({
      required IconData icon,
      required VoidCallback? onTap,
      bool isActive = false,
      Color? customIconColor, // Parameter baru buat override warna
    }) {
      Color finalColor;

      if (onTap == null) {
        finalColor = Colors.grey.withValues(
          alpha: 0.3,
        ); // Beneran disabled (Loading)
      } else if (customIconColor != null) {
        finalColor = customIconColor; // Mentok (Visual Pudar)
      } else if (isActive) {
        finalColor = activeColor; // Lagi aktif (Search)
      } else {
        finalColor = iconColor; // Normal
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

    // 3. Struktur UI Baru
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(32), // Makin rounded
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
            // Kalau mentok (isPrevDisabled), warnanya pudar
            customIconColor: isPrevDisabled ? disabledClickableColor : null,
            // Logic: Kalau mentok, tetep bisa diklik buat show message
            onTap: _isLoading
                ? null
                : () {
                    if (isPrevDisabled) {
                      _showNavigationMessage(true); // Panggil snackbar mentok
                    } else {
                      _goToIndex(_currentIndex - 1);
                    }
                  },
          ),

          // Divider Tipis
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- TOOLS ---
          buildBtn(
            icon: Icons.search_rounded,
            onTap: _isLoading ? null : _openSearchModal,

            // ✅ INI CARA PAKAINYA (Biar warning hilang)
            // Kalau variabel ini true (modal kebuka), tombol jadi oren.
            isActive: _isSearchModalOpen,
          ),

          buildBtn(icon: Icons.vertical_align_top_rounded, onTap: _scrollToTop),

          buildBtn(icon: Icons.text_fields_rounded, onTap: _showSettingsModal),

          // Divider Tipis
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- TOMBOL NEXT ---
          buildBtn(
            icon: Icons.chevron_right_rounded,
            // Kalau mentok (isNextDisabled), warnanya pudar
            customIconColor: isNextDisabled ? disabledClickableColor : null,
            // Logic: Kalau mentok, tetep bisa diklik buat show message
            onTap: _isLoading
                ? null
                : () {
                    if (isNextDisabled) {
                      _showNavigationMessage(false); // Panggil snackbar mentok
                    } else {
                      _goToIndex(_currentIndex + 1);
                    }
                  },
          ),
        ],
      ),
    );
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
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    // Icon Back kalau mau keluar
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
        backgroundColor: Colors.deepOrange.shade400, // Warna Alert
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSettingsModal() {
    // ❌ JANGAN TARUH displayZoom DI SINI

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
            // ✅ TARUH DI SINI (Di dalam builder)
            // Biar setiap tombol diklik, angkanya dihitung ulang dari _textZoom terbaru
            final int displayZoom = _textZoom.toInt();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. HEADER (Judul + Close) ---
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

                    // --- 2. TEMA BACA ---
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
                            Colors.grey[50]!,
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

                    // --- 3. UKURAN TEKS & RESET ---
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
                            setModalState(() {}); // Refresh angka jadi 100%
                          },
                          child: const Text("Reset"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- 4. KONTROL ZOOM ---
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
                              setModalState(() {}); // Refresh Modal
                            },
                            icon: const Icon(Icons.remove),
                          ),

                          // SEKARANG INI BAKAL UPDATE
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
                              setModalState(() {}); // Refresh Modal
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

  // Helper buat bikin tombol tema (Sama persis kayak di Sutta Detail)
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
        // 1. Update State Halaman Utama
        setState(() => _readerTheme = theme);

        // Simpan ke SharedPreferences (Key-nya SAMA kayak Sutta Detail)
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('reader_theme_index', theme.index);
        });

        // 2. Update State Modal (Biar ceklis pindah)
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

  // --- SEARCH MODAL (JUARA STYLE) ---
  void _openSearchModal() {
    // 1. Tandain menu dibuka
    setState(() => _isSearchModalOpen = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparan agar backdrop terlihat
      barrierColor: Colors.black.withValues(alpha: 0.4), // Overlay gelap
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
                    // Handle Bar
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
                                    // Kalau dihapus jadi pendek, clear highlight
                                    setState(() {
                                      _allMatches.clear();
                                      _displayHtmlContent = _rawHtmlContent;
                                    });
                                  }
                                  if (mounted) setSheetState(() {});
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Tutup"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Controls
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
      // ✅ 2. Tandain menu ditutup (PENTING!)
      // Dipanggil pas user tutup modal (pencet X, back, atau klik luar)
      if (mounted) {
        setState(() => _isSearchModalOpen = false);
      }
      // Optional: Kalau mau search-nya otomatis di-reset pas tutup, uncomment ini:
      _clearSearch();
    });
  }

  Future<void> _saveZoomPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('html_text_zoom', _textZoom);
  }

  // ✅ TAMBAH INI (Buat nyimpen Tema ke memori)
}
