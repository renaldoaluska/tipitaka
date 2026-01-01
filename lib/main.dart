import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'data/tematik_data.dart';
import 'screens/tematik_page.dart';
import 'data/html_data.dart';
import 'core/theme/theme_manager.dart';
import 'screens/home.dart';
import 'screens/pariyatti_content.dart';
import 'screens/patipatti_page.dart';
import 'screens/tematik_webview.dart';
import 'widgets/header_depan.dart';
import 'dart:ui';
import 'screens/html.dart';
import 'screens/suttaplex.dart'; // ✅ TAMBAH IMPORT INI

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const TripitakaApp(),
    ),
  );
}

class TripitakaApp extends StatelessWidget {
  const TripitakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return MaterialApp(
          title: 'Tipitaka Indonesia',
          theme: themeManager.lightTheme,

          darkTheme: themeManager.darkTheme,
          themeMode: themeManager.themeMode,

          home: const _SplashGate(),
        );
      },
    );
  }
}

// Splash gate sederhana
class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const RootPage()));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onBg = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 12),
            Text("Memulai…", style: TextStyle(fontSize: 12, color: onBg)),
          ],
        ),
      ),
    );
  }
}

// RootPage
class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _lastPariyattiPage = 1;
  late PageController _pageController;

  bool _isFabExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  String? _patipattiHighlight;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index, {String? highlightSection}) {
    if (index >= 0 && index <= 4 && mounted) {
      HapticFeedback.selectionClick();

      if (_currentIndex >= 1 && _currentIndex <= 3) {
        _lastPariyattiPage = _currentIndex;
      }

      if (index == 4 && highlightSection != null) {
        _patipattiHighlight = highlightSection;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _patipattiHighlight = null);
        });
      }

      setState(() => _currentIndex = index);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          int distance =
              (_pageController.page?.round() ?? _currentIndex) - index;

          if (distance.abs() > 1) {
            _pageController.jumpToPage(index);
          } else {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }
  }

  int get _rootTab {
    if (_currentIndex == 0) return 0;
    if (_currentIndex >= 1 && _currentIndex <= 3) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(
        onNavigate: (int index, {String? highlightSection}) {
          _navigateToPage(index, highlightSection: highlightSection);
        },
      ),
      const PariyattiContent(tab: 0),
      const PariyattiContent(tab: 1),
      const PariyattiContent(tab: 2),
      PatipattiPage(highlightSection: _patipattiHighlight),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (mounted) {
                setState(() => _currentIndex = index);
              }
            },
            physics: const BouncingScrollPhysics(),
            children: pages,
          ),
          if (_currentIndex >= 1 && _currentIndex <= 3)
            _buildPariyattiOverlay(),
          if (_currentIndex >= 1 && _currentIndex <= 3) _buildFabSearch(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildPariyattiOverlay() {
    final transparentColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.85);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            color: transparentColor,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 80,
                    child: AppBar(
                      primary: false,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      automaticallyImplyLeading: false,
                      centerTitle: true,
                      titleSpacing: 0,
                      toolbarHeight: 80,
                      title: const HeaderDepan(
                        title: "Pariyatti",
                        subtitle: "Studi Dhamma",
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickButton(
                            label: "Tematik",
                            icon: Icons.category_rounded,
                            color: Colors.indigo.shade700,
                            onTap: () {
                              Future.delayed(
                                const Duration(milliseconds: 120),
                                () {
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TematikPage(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickButton(
                            label: "Saṅgaha",
                            icon: Icons.auto_stories_rounded,
                            color: Colors.amber.shade800,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HtmlReaderPage(
                                    title: 'Abhidhammatthasaṅgaha',
                                    chapterFiles: DaftarIsi.abh,
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildTabButton(0, "Sutta", 1),
                        const SizedBox(width: 8),
                        _buildTabButton(1, "Abhidhamma", 2),
                        const SizedBox(width: 8),
                        _buildTabButton(2, "Vinaya", 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color borderColor;
    Color iconColor;

    final textColor = Theme.of(context).colorScheme.onSurface;
    final arrowColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (isDark) {
      bgColor = color.withValues(alpha: 0.15);
      borderColor = color.withValues(alpha: 0.3);
      iconColor = Color.lerp(color, Colors.white, 0.3)!;
    } else {
      bgColor = Color.lerp(Colors.white, color, 0.15)!;
      borderColor = Color.lerp(Colors.white, color, 0.3)!;
      iconColor = color;
    }

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black26
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: arrowColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int tabIndex, String label, int targetPage) {
    final isActive = _currentIndex == targetPage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Expanded(
      child: Material(
        color: isActive
            ? Colors.deepOrange.withValues(alpha: 0.15)
            : (isDark ? Colors.grey[850] : Colors.white),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _navigateToPage(targetPage),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? Colors.deepOrange
                    : Colors.grey.withValues(alpha: 0.3),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.deepOrange : baseColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarColor = isDark ? Colors.grey[850]! : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: navBarColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                rootIndex: 0,
                targetPage: 0,
                icon: 'assets/home.svg',
                label: 'Beranda',
              ),
              _buildNavItem(
                rootIndex: 1,
                targetPage: _lastPariyattiPage,
                icon: Icons.menu_book_rounded,
                label: 'Pariyatti',
              ),
              _buildNavItem(
                rootIndex: 2,
                targetPage: 4,
                icon: Icons.self_improvement_rounded,
                label: 'Paṭipatti',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int rootIndex,
    required int targetPage,
    required dynamic icon,
    required String label,
  }) {
    final isSelected = _rootTab == rootIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (targetPage == 4) _patipattiHighlight = null;
            _navigateToPage(targetPage);
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.deepOrange.withValues(alpha: 0.12),
          splashColor: Colors.deepOrange.withValues(alpha: 0.25),
          highlightColor: Colors.deepOrange.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon is String)
                  SvgPicture.asset(
                    icon,
                    width: isSelected ? 26 : 24,
                    height: isSelected ? 26 : 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? Colors.deepOrange : baseColor,
                      BlendMode.srcIn,
                    ),
                  )
                else
                  Icon(
                    icon as IconData,
                    color: isSelected ? Colors.deepOrange : baseColor,
                    size: isSelected ? 26 : 24,
                  ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? Colors.deepOrange : baseColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      _isFabExpanded ? _fabController.forward() : _fabController.reverse();
    });
  }

  Widget _buildFabSearch() {
    return Stack(
      children: [
        // ✅ Barrier dengan blur
        if (_isFabExpanded)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _toggleFab,
              child: BackdropFilter(
                // ✅ Blur effect
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.1), // ✅ Sedikit gelap
                ),
              ),
            ),
          ),

        Positioned(
          right: 16,
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isFabExpanded) ...[
                ScaleTransition(
                  scale: _fabAnimation,
                  child: _buildFabOption(
                    label: "Kode Teks",
                    icon: Icons.tag_rounded,
                    color: Colors.blue.shade600,
                    onTap: () => _showCodeInput(),
                  ),
                ),
                const SizedBox(height: 10),
                ScaleTransition(
                  scale: _fabAnimation,
                  child: _buildFabOption(
                    label: "Pencarian",
                    icon: Icons.search_rounded,
                    color: Colors.green.shade600,
                    onTap: () => {
                      // final pendahuluanNumber = chapterIndex - 1;
                      _openWebView(context, "search", "Pencarian"),
                    },

                    //_showSearchModal(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FloatingActionButton(
                onPressed: _toggleFab,
                backgroundColor: Colors.deepOrange,
                elevation: 2,
                child: RotationTransition(
                  turns: _fabAnimation, // ✅ Langsung pake _fabAnimation
                  child: Icon(
                    _isFabExpanded ? Icons.close : Icons.search,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          child: InkWell(
            // ✅ Ganti ke InkWell biar ada ripple
            onTap: onTap,
            borderRadius: BorderRadius.circular(20), // ✅ Ripple ikut border
            splashColor: color.withValues(alpha: 0.2), // ✅ Warna ripple
            highlightColor: color.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: "$label-$_currentIndex",
          onPressed: onTap,
          backgroundColor: color,
          elevation: 2,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ],
    );
  }

  // 🔥 FUNGSI BARU: Input Kode Sutta
  void _showCodeInput() {
    _toggleFab();

    // ✅ SIMPAN CONTEXT & THEME DI AWAL (SEBELUM showDialog)
    final navigatorContext = context;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    showDialog(
      context: navigatorContext,
      builder: (dialogContext) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Masukkan Kode",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Contoh: mn1, sn12.1, dn16",
              hintStyle: TextStyle(color: subtextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: textColor),
            onSubmitted: (v) {
              if (v.isNotEmpty) {
                Navigator.pop(dialogContext);
                _openSuttaByCode(v.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Batal", style: TextStyle(color: subtextColor)),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _openSuttaByCode(ctrl.text.trim());
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
              child: const Text("Buka"),
            ),
          ],
        );
      },
    );
  }

  // 🔥 FUNGSI BARU: Parse & Buka Suttaplex
  void _openSuttaByCode(String input) {
    // ✅ SIMPAN SEMUA CONTEXT & THEME DI PALING AWAL
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final navigatorContext = context;

    // Normalisasi: lowercase, hapus spasi
    final code = input.toLowerCase().replaceAll(' ', '');

    // Parse UID (contoh: "mn1" → "mn1", "sn12.1" → "sn12.1")
    String? uid;

    // Deteksi pattern: huruf + angka (+ opsional .angka)
    final match = RegExp(r'^([a-z]+)(\d+(?:\.\d+)?)$').firstMatch(code);

    if (match != null) {
      final prefix = match.group(1)!; // "mn", "sn", dll
      final number = match.group(2)!; // "1", "12.1", dll
      uid = '$prefix$number'; // Gabung tanpa spasi
    }

    if (uid == null || uid.isEmpty) {
      // ✅ Pakai scaffoldMessenger yang udah disimpan
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Format kode tidak valid. Contoh: mn1, sn12.1, dn16'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 🔥 BUKA SUTTAPLEX
    showModalBottomSheet(
      context: navigatorContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Suttaplex(uid: uid!, sourceMode: "search"),
        ),
      ),
    );
  }

  /*void _showSearchModal() {
    _toggleFab();

    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final red = (subtextColor.r * 255).round();
    final green = (subtextColor.g * 255).round();
    final blue = (subtextColor.b * 255).round();

    final handleColor = Color.fromARGB(77, red, green, blue);
    final iconColor = Color.fromARGB(128, red, green, blue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Cari judul sutta...",
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: iconColor),
                    const SizedBox(height: 12),
                    Text(
                      "Ketik untuk mencari sutta...",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
*/
  void _openWebView(BuildContext context, String key, String title) {
    final url = TematikData.webviewUrls[key];
    if (url != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height:
                  MediaQuery.of(context).size.height * 0.9, // 🔥 Fixed height
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: TematikWebView(url: url, title: title, chapterIndex: null),
            ),
          );
        },
      );
    }
  }
}
