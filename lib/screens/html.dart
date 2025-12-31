import 'dart:async';
import 'dart:ui'; // Untuk ImageFilter
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late WebViewController _controller;

  // --- State Utama ---
  double _textZoom = 80.0;
  bool _isLoading = true;
  late int _currentIndex;
  bool _isScrolled = false;

  // --- Search State ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _totalMatches = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadZoomPreference();
    _initWebView();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadZoomPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _textZoom = prefs.getDouble('html_text_zoom') ?? 80.0);
    }
  }

  int get displayZoom {
    // 80 internal dianggap 100% tampilan
    return ((_textZoom / 80.0) * 100).round();
  }

  void _initWebView() {
    String htmlFile = widget.chapterFiles.isNotEmpty
        ? widget.chapterFiles[_currentIndex]
        : 'about:blank';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false) // Disable pinch zoom
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _applyViewport();
            _applyTextZoom();
            _applyThemeMode();
          },
          onNavigationRequest: (NavigationRequest request) {
            for (int i = 0; i < widget.chapterFiles.length; i++) {
              final String fileInList = widget.chapterFiles[i];
              final String fileName = fileInList.split('/').last;

              if (request.url.contains(fileName)) {
                _goToIndex(i);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadFlutterAsset(htmlFile);
  }

  Future<void> _handleBackNavigation() async {
    if (_currentIndex > 0) {
      _goToIndex(0);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _scrollToTop() async {
    await _controller.runJavaScript(
      'window.scrollTo({top: 0, behavior: "smooth"});',
    );
  }

  void _goToIndex(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.chapterFiles.length) {
      setState(() {
        _currentIndex = newIndex;
        _isLoading = true;
      });
      _controller.loadFlutterAsset(widget.chapterFiles[_currentIndex]);
    }
  }

  Future<void> _applyTextZoom() async {
    try {
      final zoom = _textZoom.round();
      await _controller.runJavaScript('document.body.style.zoom = "$zoom%";');
    } catch (e) {
      debugPrint('Zoom error: $e');
    }
  }

  Future<void> _applyThemeMode() async {
    final isDarkApp = Theme.of(context).brightness == Brightness.dark;
    final String className = isDarkApp ? 'mode-dark' : 'mode-light';

    await _controller.runJavaScript('''
      document.body.classList.remove('mode-dark', 'mode-light');
      document.body.classList.add('$className');
    ''');
  }

  Future<void> _runSearch(String query, {bool next = false}) async {
    if (query.isEmpty) return;

    await _controller.runJavaScript(
      'window.find("$query", false, ${next ? "false" : "true"}, true)',
    );

    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          try {
            var bodyText = document.body.innerText;
            var query = "$query";
            if (!query) return 0;
            var matches = bodyText.match(new RegExp(query.replace(/[.*+?^\\\$()|[\\]\\\\]/g, '\\\\\$&'), "gi"));
            return matches ? matches.length : 0;
          } catch(e) { return 0; }
        })();
      ''');

      int count = 0;
      if (result is int) {
        count = result;
      } else if (result is String) {
        count = int.tryParse(result) ?? 0;
      }

      if (mounted) setState(() => _totalMatches = count);
    } catch (e) {
      debugPrint("JS Search Error: $e");
    }
  }

  void _clearSearch() {
    _controller.runJavaScript('window.getSelection().removeAllRanges();');
    _searchController.clear();
    setState(() => _totalMatches = 0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirst = _currentIndex <= 0;
    final bool isLast = _currentIndex >= widget.chapterFiles.length - 1;
    final double topPadding = MediaQuery.of(context).padding.top + 80;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels > 0 && !_isScrolled) {
                  setState(() => _isScrolled = true);
                } else if (scrollInfo.metrics.pixels <= 0 && _isScrolled) {
                  setState(() => _isScrolled = false);
                }
                return false;
              },
              child: Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: WebViewWidget(controller: _controller),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  ),
                ),
              ),
            _buildHeader(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildFloatingActions(isFirst, isLast),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Padding(
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
              filter: ImageFilter.blur(
                sigmaX: _isScrolled ? 10.0 : 0.0,
                sigmaY: _isScrolled ? 10.0 : 0.0,
              ),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: _isScrolled ? 0.85 : 1.0,
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
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
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: _handleBackNavigation,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            "Halaman ${_currentIndex + 1} dari ${widget.chapterFiles.length}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.blue),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Membaca: ${widget.title}"),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
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

  Widget _buildFloatingActions(bool isPrevDisabled, bool isNextDisabled) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledBg = isDark
        ? Colors.grey[800]!.withValues(alpha: 0.9)
        : Colors.grey[300]!.withValues(alpha: 0.9);
    final disabledFg = Colors.grey;

    Color getBgColor(bool isDisabled, {Color? activeColor}) {
      if (isDisabled) return disabledBg;
      return (activeColor ?? Theme.of(context).colorScheme.primary).withValues(
        alpha: 0.9,
      );
    }

    Color getFgColor(bool isDisabled) => isDisabled ? disabledFg : Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: "btn_prev",
          backgroundColor: getBgColor(isPrevDisabled),
          foregroundColor: getFgColor(isPrevDisabled),
          onPressed: isPrevDisabled
              ? null
              : () => _goToIndex(_currentIndex - 1),
          child: const Icon(Icons.arrow_back_ios_new),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: "btn_search",
          backgroundColor: getBgColor(false, activeColor: Colors.deepOrange),
          foregroundColor: Colors.white,
          onPressed: _showSearchModal,
          child: const Icon(Icons.search),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: "btn_top",
          backgroundColor: getBgColor(false, activeColor: Colors.deepOrange),
          foregroundColor: Colors.white,
          onPressed: _scrollToTop,
          child: const Icon(Icons.vertical_align_top),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: "btn_view",
          backgroundColor: getBgColor(false),
          foregroundColor: Colors.white,
          onPressed: _showSettingsModal,
          child: const Icon(Icons.visibility),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: "btn_next",
          backgroundColor: getBgColor(isNextDisabled),
          foregroundColor: getFgColor(isNextDisabled),
          onPressed: isNextDisabled
              ? null
              : () => _goToIndex(_currentIndex + 1),
          child: const Icon(Icons.arrow_forward_ios),
        ),
      ],
    );
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
          builder: (context, setModalState) {
            ButtonStyle btnStyle = OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tampilan",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        "Ukuran Teks",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${displayZoom}%", // bukan langsung _textZoom
                          //"${_textZoom.toInt()}%",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: btnStyle,
                          icon: const Icon(Icons.remove, size: 18),
                          label: const Text("Kecil"),
                          onPressed: () {
                            setState(
                              () => _textZoom = (_textZoom - 10).clamp(
                                50.0,
                                300.0,
                              ),
                            );
                            _applyTextZoom();
                            _saveZoomPref();
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: btnStyle,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Reset"),
                          onPressed: () {
                            setState(() => _textZoom = 80.0);
                            _applyTextZoom();
                            _saveZoomPref();
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: btnStyle,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Besar"),
                          onPressed: () {
                            setState(
                              () => _textZoom = (_textZoom + 10).clamp(
                                50.0,
                                300.0,
                              ),
                            );
                            _applyTextZoom();
                            _saveZoomPref();
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                  color: Theme.of(context).colorScheme.surface,
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
                              hintText: "Cari kata...",
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
                                        setSheetState(() {});
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
                                  if (val.length >= 2) {
                                    _runSearch(val);
                                  } else {
                                    setState(() => _totalMatches = 0);
                                  }
                                  if (mounted) setSheetState(() {});
                                },
                              );
                            },
                            onSubmitted: (val) => _runSearch(val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Batal"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _searchController.text.isEmpty
                              ? "Mulai mengetik..."
                              : _totalMatches > 0
                              ? "Ditemukan $_totalMatches hasil"
                              : "Tidak ada hasil",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _totalMatches == 0
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              tooltip: "Sebelumnya",
                              onPressed: _totalMatches == 0
                                  ? null
                                  : () => _runSearch(
                                      _searchController.text,
                                      next: false,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              tooltip: "Selanjutnya",
                              onPressed: _totalMatches == 0
                                  ? null
                                  : () => _runSearch(
                                      _searchController.text,
                                      next: true,
                                    ),
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
    ).whenComplete(() => _debounce?.cancel());
  }

  Future<void> _applyViewport() async {
    // Script JS untuk mencari meta viewport, kalau belum ada dibuat baru.
    // Lalu memaksa content-nya menjadi settingan yang kamu mau.
    const String jsCode = '''
      (function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = "viewport";
          document.head.appendChild(meta);
        }
        meta.content = "width=device-width, initial-scale=1.0, user-scalable=no";
      })();
    ''';

    try {
      await _controller.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Viewport injection error: $e');
    }
  }

  Future<void> _saveZoomPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('html_text_zoom', _textZoom);
  }
}
