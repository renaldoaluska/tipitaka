import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/theme_manager.dart';
import '../widgets/ai_translation_history.dart';
import '../widgets/ai_translation_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isScrolled = false;
  String _appVersion = "";

  @override
  void initState() {
    super.initState();
    _getAppVersion(); // Panggil fungsi ini
  }

  // Fungsi buat narik versi asli dari pubspec.yaml
  Future<void> _getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        // Format: 1.7.1 (80)
        _appVersion = "v${info.version} (${info.buildNumber})";
      });
    }
  }

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

                      const SizedBox(height: 32), // Jarak biar gak nempel
                      _buildAppInfo(),
                      const SizedBox(
                        height: 40,
                      ), // Padding bawah biar enak discroll
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

  void _showContributionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ... (HEADER & CONTENT TEXT DI SINI BIARIN AJA SAMA KAYAK SEBELUMNYA) ...
              // Biar hemat tempat, saya skip bagian atas yang gak berubah ya Bang.
              // Langsung ke bagian bawah (Action Buttons):

              // Header compact
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF57F17),
                      const Color(0xFFF57F17).withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.volunteer_activism_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Kontribusi",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "mettā · karuṇā · muditā · upekkhā",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Content compact
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        // 1. Style Utama (Default tegak)
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                        children: [
                          const TextSpan(
                            text:
                                "Aplikasi gratis dan tanpa iklan ini dikembangkan secara terbuka dengan ",
                          ),
                          // 2. Kata 'viriya' (Miring)
                          const TextSpan(
                            text: "viriya",
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                          const TextSpan(text: " atas "),
                          // 3. Kata 'puñña' (Miring)
                          const TextSpan(
                            text: "puñña",
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                          const TextSpan(text: "."),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildCompactItem(
                      ctx,
                      Icons.feedback_rounded,
                      "Memberi masukan",
                    ),
                    _buildCompactItem(
                      ctx,
                      Icons.money_rounded,
                      "Dāna seikhlasnya",
                    ),
                    _buildCompactItem(
                      ctx,
                      Icons.code_rounded,
                      "Menyumbang kode",
                    ),
                    _buildCompactItem(
                      ctx,
                      Icons.share_rounded,
                      "Sebarkan ke sesama",
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Terima kasih atas dukungan Anda 🙏",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF57F17),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons (UDPATE DI SINI)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // 🔥 1. TOMBOL QRIS (PALING ATAS BIAR MENCOLOK)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showQrisDialog(context),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          "Dāna via QRIS",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF57F17),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Email & GitHub (Row Existing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              final uri = Uri(
                                scheme: 'mailto',
                                path: 'aluskaindonesia@gmail.com',
                                query:
                                    'subject=Saran Aplikasi Tripitaka Indonesia',
                              );
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            icon: const Icon(Icons.email_rounded, size: 16),
                            label: const Text(
                              "Email",
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF57F17),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFF57F17),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              launchUrl(
                                Uri.parse(
                                  "https://github.com/renaldoaluska/tipitaka",
                                ),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            icon: const Icon(Icons.code_rounded, size: 16),
                            label: const Text(
                              "GitHub",
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF57F17),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFF57F17),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),
                    // Tombol Tutup
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          "Tutup",
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      fontSize: 12,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. DIVIDER HALUS (<hr> di atas tombol)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Divider(
            color: colorScheme.outline.withValues(alpha: 0.2),
            thickness: 1,
          ),
        ),

        const SizedBox(height: 16),

        // 2. TOMBOL KONTRIBUSI & DANA
        OutlinedButton.icon(
          onPressed: () => _showContributionDialog(context),
          icon: const Icon(
            Icons.volunteer_activism_rounded,
            size: 18,
            color: Color(0xFFF57F17),
          ),
          label: const Text(
            "Kontribusi",
            style: TextStyle(color: Color(0xFFF57F17)),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: const Color(0xFFF57F17).withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        const SizedBox(height: 32),

        // 3. VERSI APLIKASI (REAL)
        // Kalau belum ke-load, tampilkan strip dulu
        Text.rich(
          TextSpan(
            // Style Induk (Default buat "myDhamma")
            style: textStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            children: [
              const TextSpan(text: "myDhamma "),

              // Bagian Versi (Warna Primary)
              TextSpan(
                text: _appVersion.isEmpty ? '...' : _appVersion,
                style: TextStyle(
                  color: colorScheme.primary, // 🔥 Ini kuncinya
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 4. NAMA DEVELOPER (DIBAGUSIN)
        // Pake RichText biar bisa bedain style "Developed by" sama "Alfalaska"
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: "Dengan "),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 10,
                  color: Colors.pinkAccent,
                ),
              ),
              const TextSpan(text: " oleh "),
              TextSpan(
                text: "Alfa Renaldo Aluska",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary, // Warnanya ngikut tema
                ),
              ),
            ],
            style: textStyle,
          ),
        ),

        const SizedBox(height: 16),

        // 5. PELIMPAHAN JASA
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "\"Idaṁ vo ñātīnaṁ hotu,\nsukhitā hontu ñātayo.\"",
            textAlign: TextAlign.center,
            style: textStyle.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // Helper buat list item di dialog
  Widget _buildCompactItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF57F17).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: const Color(0xFFF57F17)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi khusus buat buka gambar QRIS
  void _showQrisDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Scan QRIS",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Gambar QRIS
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/qris.jpeg', // Pastikan file ini ada & terdaftar di pubspec
                width: 250,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 250,
                    height: 250,
                    color: Colors.grey[100],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Gambar QRIS belum ada",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF57F17),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Tutup"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
