import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/pariyatti_page.dart';
import 'screens/patipatti_page.dart';

void main() {
  runApp(const TripitakaApp());
}

class TripitakaApp extends StatelessWidget {
  const TripitakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tripitaka Indonesia',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const RootPage(),
    );
  }
}

// Bottom Navigation Root
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _currentIndex = 0;
  bool _isDarkMode = false;

  Color _bgColor(bool dark) => dark ? Colors.grey[900]! : Colors.grey[50]!;
  Color _navBarColor(bool dark) => dark ? Colors.grey[850]! : Colors.white;

  @override
  Widget build(BuildContext context) {
    // Pages list
    final pages = [
      Home(
        isDarkMode: _isDarkMode,
        onThemeToggle: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
      PariyattiPage(
        isDarkMode: _isDarkMode,
        onThemeToggle: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
      PatipattiPage(
        isDarkMode: _isDarkMode,
        onThemeToggle: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    ];

    return Scaffold(
      backgroundColor: _bgColor(_isDarkMode),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navBarColor(_isDarkMode),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.menu_book_rounded,
                  label: 'Pariyatti',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.self_improvement_rounded,
                  label: 'Paṭipatti',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? Colors.deepOrange
        : (_isDarkMode ? Colors.grey[400] : Colors.grey[600]);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: isSelected ? 28 : 24),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSelected ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
