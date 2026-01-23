import 'package:flutter/material.dart';
import 'dart:async';
import '../screens/settings.dart';

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
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
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
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              final isNewWidget =
                                  child.key == ValueKey(currentText);

                              if (isNewWidget) {
                                return SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0.0, 1.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              } else {
                                return SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0.0, -1.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: const Interval(
                                            0.0,
                                            0.7,
                                            curve: Curves.easeIn,
                                          ),
                                        ),
                                      ),
                                  child: FadeTransition(
                                    opacity: Tween<double>(begin: 0.0, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: const Interval(0.5, 1.0),
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

          // Settings Button
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
