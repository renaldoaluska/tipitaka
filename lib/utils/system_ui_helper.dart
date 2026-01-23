import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUIHelper {
  static SystemUiOverlayStyle getStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarColor = isDark ? const Color(0xFF303030) : Colors.white;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: navBarColor,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }
}
