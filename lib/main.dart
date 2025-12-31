import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tipitaka/screens/tematik_page.dart';
import 'core/theme/theme_manager.dart';
import 'screens/home.dart';
import 'screens/pariyatti_content.dart';
import 'screens/patipatti_page.dart';
import 'widgets/header_depan.dart';
import 'dart:ui';

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
          home: const _SplashGate(), // ⬅️ loading gate
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

  void _navigateToPage(int index) {
    if (index >= 0 && index <= 4 && _currentIndex != index && mounted) {
      HapticFeedback.selectionClick();
      if (_currentIndex >= 1 && _currentIndex <= 3) {
        _lastPariyattiPage = _currentIndex;
      }
      setState(() => _currentIndex = index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && mounted) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
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
      const Home(),
      const PariyattiContent(tab: 0),
      const PariyattiContent(tab: 1),
      const PariyattiContent(tab: 2),
      const PatipattiPage(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (mounted) setState(() => _currentIndex = index);
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

                  // ✅ BAGIAN TOMBOL DIPERBAIKI (Lebih Bersih)
                  // Di dalam _buildPariyattiOverlay
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickButton(
                            label: "Tematik",
                            icon: Icons.category_rounded,
                            color: Colors.indigo.shade700,
                            // ❌ Hapus isHorizontal: true, karena otomatis horizontal sekarang
                            onTap: () {
                              Future.delayed(
                                const Duration(milliseconds: 120),
                                () {
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
                            // ❌ Hapus isHorizontal: true, di sini juga
                            onTap: () {
                              Future.delayed(
                                const Duration(milliseconds: 120),
                                () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Saṅgaha: TO DO'),
                                      duration: Duration(milliseconds: 800),
                                    ),
                                  );
                                },
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
    required Color color, // Ini warna aksen (Indigo/Amber)
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Tentukan Warna Background & Border (Logika asli main.dart)
    Color bgColor;
    Color borderColor;

    // 2. Warna Ikon (Tetap berwarna biar cantik)
    Color iconColor;

    // 3. Warna Teks (WAJIB HITAM/PUTIH sesuai request)
    final textColor = Theme.of(context).colorScheme.onSurface;
    final arrowColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (isDark) {
      // Dark Mode: Glassy Transparan
      bgColor = color.withValues(alpha: 0.15);
      borderColor = color.withValues(alpha: 0.3);
      // Ikon di dark mode dibikin agak terang dikit dari warna aslinya
      iconColor = Color.lerp(color, Colors.white, 0.3)!;
    } else {
      // Light Mode: Solid Pastel
      // Campur putih 85% + warna 15%
      bgColor = Color.lerp(Colors.white, color, 0.15)!;
      borderColor = Color.lerp(Colors.white, color, 0.3)!;
      // Ikon pakai warna asli (gelap/tajam)
      iconColor = color;
    }

    return Container(
      height: 54, // Sedikit lebih tinggi biar touch-friendly
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14), // Sedikit lebih rounded
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.1), // Shadow halus warna senada
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
                // 1. KOTAK IKON
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black26
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor, // Ikon tetap Indigo/Amber
                  ),
                ),

                const SizedBox(width: 12),

                // 2. TEKS (Putih/Hitam)
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor, // ✅ Ikutin tema (Hitam/Putih)
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 3. PANAH
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: arrowColor.withValues(alpha: 0.5), // Panah agak samar
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
                fontWeight: FontWeight.w500, // 👈 Pake bold biar teges
                //fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
          onTap: () => _navigateToPage(targetPage),
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
    return Positioned(
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
                label: "Kode Sutta",
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
                onTap: () => _showSearchModal(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            onPressed: _toggleFab,
            backgroundColor: Colors.deepOrange,
            elevation: 2,
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.250 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isFabExpanded ? Icons.close : Icons.search,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
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

  void _showCodeInput() {
    _toggleFab();
    showDialog(
      context: context,
      builder: (context) {
        final cardColor = Theme.of(context).colorScheme.surface;
        final textColor = Theme.of(context).colorScheme.onSurface;
        final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Masukkan Kode Sutta",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Contoh: mn1, sn12.1",
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
                Navigator.pop(context);
                // TODO: Parse & navigate
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.isNotEmpty) {
                  Navigator.pop(context);
                  // TODO: Parse & navigate
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

  void _showSearchModal() {
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
}
