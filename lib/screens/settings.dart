import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_manager.dart';
import '../widgets/ai_translation_history.dart';
import '../widgets/ai_translation_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isScrolled = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 80),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels > 0 && !_isScrolled) {
                      setState(() => _isScrolled = true);
                    } else if (scrollInfo.metrics.pixels <= 0 && _isScrolled) {
                      setState(() => _isScrolled = false);
                    }
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _buildDarkModeCard(),
                      const SizedBox(height: 4),
                      _buildAISettingsCard(),
                      const SizedBox(height: 4),
                      _buildHistoryAICard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    // Header content extracted for clarity and reuse in BackdropFilter logic
    Widget headerContent = Container(
      color: colorScheme.surface.withValues(alpha: _isScrolled ? 0.85 : 1.0),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Pengaturan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );

    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // 🔥 OPTIMASI: Hanya pasang blur jika sedang di-scroll
            child: _isScrolled
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: headerContent,
                  )
                : headerContent,
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // 🔥 RepaintBoundary mengisolasi perubahan visual lokal
    return RepaintBoundary(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                  color: Colors.deepOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mode Tema",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isDark ? "Gelap" : "Terang",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildModernSwitch(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSwitch(bool isDark) {
    return GestureDetector(
      onTap: () {
        // 🔥 Jeda 100ms agar animasi saklar tidak tabrakan dengan rebuild sistem
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            context.read<ThemeManager>().toggleTheme(isDark);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 58,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.grey.shade800 : Colors.orange.shade100,
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.orange.shade200,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.black : Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
              size: 14,
              color: isDark ? Colors.amber : Colors.orange,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAISettingsCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                const AITranslationSheet(text: '', settingsOnly: true),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pengaturan AI",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Konfigurasi terjemahan AI",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryAICard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const TranslationHistorySheet(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Riwayat AI",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Lihat riwayat terjemahan",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
