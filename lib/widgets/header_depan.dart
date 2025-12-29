import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_manager.dart';

class HeaderDepan extends StatelessWidget {
  final String title;
  final String subtitle;

  const HeaderDepan({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    // ✅ Cek brightness AKTUAL yang lagi nampil di layar
    // Ini bakal bener entah itu karena System atau manual override
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
            // ✅ Toggle theme pakai Provider
            IconButton(
              icon: Icon(
                // Cek brightness layar saat ini
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                color: isDark ? Colors.amber : Colors.grey[700],
              ),
              onPressed: () {
                // Cek dulu skrg lagi gelap apa nggak
                final isCurrentlyDark =
                    Theme.of(context).brightness == Brightness.dark;
                context.read<ThemeManager>().toggleTheme(isCurrentlyDark);
                //context.read<ThemeManager>().toggleTheme();
              },
            ),
          ],
        ),
      ),
    );
  }
}
