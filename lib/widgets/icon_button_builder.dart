import 'package:flutter/material.dart';

/// Reusable icon button widget untuk Quick Access, Features, dll
class IconButtonBuilder extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double? width;
  final double iconSize;
  final double containerSize;
  final double fontSize;

  const IconButtonBuilder({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.width = 75,
    this.iconSize = 28,
    this.containerSize = 56,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    //  Ambil dari Theme, bukan parameter
    final textColor = Theme.of(context).colorScheme.onSurface;

    // Extract RGB dari color untuk shadow
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    final shadowColor = Color.fromARGB(77, red, green, blue);

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: textColor, //  Ganti dari isDarkMode logic
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
