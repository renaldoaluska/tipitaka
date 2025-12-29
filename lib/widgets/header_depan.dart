import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../core/theme/theme_manager.dart';

class HeaderDepan extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String>? subtitlesList;
  final bool enableAnimation;

  const HeaderDepan({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitlesList,
    this.enableAnimation = false,
  });

  @override
  State<HeaderDepan> createState() => _HeaderDepanState();
}

class _HeaderDepanState extends State<HeaderDepan> {
  late int _currentIndex;
  Timer? _timer;
  List<String> _displayList = [];

  @override
  void initState() {
    super.initState();
    _setupLogic();
  }

  @override
  void didUpdateWidget(covariant HeaderDepan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimation != oldWidget.enableAnimation ||
        widget.subtitlesList != oldWidget.subtitlesList ||
        widget.subtitle != oldWidget.subtitle) {
      _setupLogic();
    }
  }

  void _setupLogic() {
    _timer?.cancel();
    _currentIndex = 0;
    _displayList = [widget.subtitle, ...?widget.subtitlesList];

    if (widget.enableAnimation && _displayList.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _displayList.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final currentText = _displayList.isNotEmpty
        ? _displayList[_currentIndex]
        : widget.subtitle;

    final titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: textColor,
    );

    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: subtextColor,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, style: titleStyle),
                const SizedBox(height: 2),

                if (widget.enableAnimation && _displayList.length > 1)
                  ClipRect(
                    child: SizedBox(
                      height: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        // LayoutStack biar transisi lancar
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          final isNewWidget =
                              child.key == ValueKey(currentText);

                          if (isNewWidget) {
                            // --- MASUK (TEKS BARU) ---
                            // Masuk normal dari bawah (Offset 0, 1.0)
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.0, 1.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut, // Masuk santai
                                    ),
                                  ),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          } else {
                            // --- KELUAR (TEKS LAMA) ---
                            // DISINI KUNCINYA:
                            // Kita geser JAUH ke atas (-1.0) biar cepet minggir
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(
                                      0.0,
                                      -1.0,
                                    ), // Geser Full ke atas
                                    end: Offset
                                        .zero, // (Posisi awal sebelum gerak)
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(
                                        0.0,
                                        0.7,
                                        curve: Curves.easeIn,
                                      ), // Selesai lebih cepet (70% durasi)
                                    ),
                                  ),
                              child: FadeTransition(
                                // Ilang lebih cepet lagi (50% durasi udah transparan)
                                opacity: Tween<double>(begin: 0.0, end: 1.0)
                                    .animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: const Interval(
                                          0.5,
                                          1.0,
                                        ), // Kebalik karena exit animation itu reverse
                                      ),
                                    ),
                                child: child,
                              ),
                            );
                          }
                        },
                        child: Text(
                          currentText,
                          key: ValueKey<String>(currentText),
                          style: subtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                else
                  Text(widget.subtitle, style: subtitleStyle),
              ],
            ),
          ),

          // Toggle Switch (Gak diubah)
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
