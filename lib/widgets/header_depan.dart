import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_manager.dart';

class HeaderDepan extends StatelessWidget {
  final String title;
  final String subtitle;

  const HeaderDepan({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // ❌ HAPUS SafeArea
    // ✅ Pake Padding biasa aja.
    // Kita kurangi top padding jadi 0 atau kecil, karena AppBar udah nengahin otomatis.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Kiri kanan aja
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize
                  .min, // ✅ Ini penting biar vertikalnya rapet tengah
              children: [
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: subtextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // Toggle Switch Tetap Sama...
          GestureDetector(
            onTap: () {
              final isCurrentlyDark =
                  Theme.of(context).brightness == Brightness.dark;
              context.read<ThemeManager>().toggleTheme(isCurrentlyDark);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 60,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? Colors.grey.shade800 : Colors.orange.shade100,
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedAlign(
                    alignment: isDark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.black : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.wb_sunny_rounded,
                        size: 16,
                        color: isDark ? Colors.amber : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
