import 'package:flutter/material.dart';

class HeaderDepan extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final String title;
  final String subtitle;

  const HeaderDepan({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.title,
    required this.subtitle,
  });

  Color _textColor(bool dark) => dark ? Colors.white : Colors.black;
  Color _subtextColor(bool dark) =>
      dark ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  Widget build(BuildContext context) {
    //final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            // Kiri: judul + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: _subtextColor(isDarkMode),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textColor(isDarkMode),
                    ),
                  ),
                ],
              ),
            ),

            // Kanan: tahun Masehi + Buddhis range
            /* Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text(
                //   "${now.year} M",
                //  style: TextStyle(
                //    fontSize: 12,
                //    color: _subtextColor(isDarkMode),
                //  ),
                // ),
                Text(
                  "${now.year + 543 - 1}–${now.year + 543} BE",
                  style: TextStyle(
                    fontSize: 12,
                    color: _subtextColor(isDarkMode),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
*/
            // Tombol toggle theme
            IconButton(
              icon: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: isDarkMode ? Colors.amber : Colors.grey[700],
              ),
              onPressed: onThemeToggle,
            ),
          ],
        ),
      ),
    );
  }
}
