import 'package:flutter/material.dart';

/// Reusable explore card untuk section seperti Tipiṭaka, Paritta, dll
class PanjangCardBuilder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDarkMode;

  const PanjangCardBuilder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isDarkMode,
  });

  Color _cardColor(bool dark) => dark ? Colors.grey[850]! : Colors.white;
  Color _textColor(bool dark) => dark ? Colors.white : Colors.black;
  Color _subtextColor(bool dark) =>
      dark ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor(isDarkMode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor(isDarkMode),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _subtextColor(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
              // Icon(
              //  Icons.arrow_forward_ios,
              // size: 16,
              //color: _subtextColor(isDarkMode),
              //),
            ],
          ),
        ),
      ),
    );
  }
}
