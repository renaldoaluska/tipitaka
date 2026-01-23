import 'package:flutter/material.dart';

class CompactCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double titleFontSize;
  final FontWeight titleFontWeight;

  const CompactCard({
    super.key,
    required this.title,
    this.subtitle = "", // Default kosong
    required this.icon,
    required this.color,
    required this.onTap,
    this.titleFontSize = 14, // Default untuk explore_tab
    this.titleFontWeight = FontWeight.w600, // Default untuk explore_tab
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDarkMode
          ? Colors.grey[850]?.withValues(alpha: 0.4)
          : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Icon dengan ukuran lebih kecil
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize, // 👈 Pakai parameter
                        fontWeight: titleFontWeight, // 👈 Pakai parameter
                        color: isDarkMode ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Conditional subtitle
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12), // Jarak antara text & icon
              // Icon Open in New
              Icon(
                Icons.open_in_new,
                size: 16,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
