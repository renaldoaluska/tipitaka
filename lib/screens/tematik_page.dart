// lib/screens/tematik_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:tipitaka/widgets/tematik_chapter_list.dart';
import '../data/html_data.dart';
import '../data/tematik_data.dart';
import 'html.dart';

class TematikPage extends StatefulWidget {
  const TematikPage({super.key});

  @override
  State<TematikPage> createState() => _TematikPageState();
}

class _TematikPageState extends State<TematikPage> {
  Set<String> _checkedSuttas = {};
  bool _isLoading = true;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('tematik_checklist') ?? [];
    setState(() {
      _checkedSuttas = list.toSet();
      _isLoading = false;
    });
  }

  // Reload checklist setelah ada perubahan
  void _reloadChecklist() {
    _loadChecklist();
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: TematikData.mainMenu.length,
                          itemBuilder: (context, index) =>
                              _buildChapterCard(index),
                        ),
                ),
              ),
            ],
          ),
          // Header dengan backdrop blur
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isScrolled ? 10.0 : 0.0,
                sigmaY: _isScrolled ? 10.0 : 0.0,
              ),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: _isScrolled ? 0.85 : 1.0,
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
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
                          Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Tematik",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.blue,
                        size: 20,
                      ),
                      label: const Text(
                        "Progres",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _showInfo(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Cuma part yang perlu diupdate di tematik_page.dart

  // REPLACE _buildChapterCard dengan ini:
  Widget _buildChapterCard(int chapterIndex) {
    final item = TematikData.mainMenu[chapterIndex];
    final detail = TematikData.getChapterDetail(chapterIndex);
    final items = detail["items"] as List<Map<String, String>>;

    final textColor = Theme.of(context).colorScheme.onSurface;
    final total = items.where((s) => s["code"]!.isNotEmpty).length;
    final done = items.where((s) {
      final uid = TematikData.parseSuttaCode(s["code"]!);
      return _checkedSuttas.contains(uid);
    }).length;
    final percent = total > 0 ? done / total : 0.0;
    final romanNumeral = _getRomanNumeral(chapterIndex);

    if (chapterIndex <= 1) {
      return _buildIntroCard(chapterIndex, item, items);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Area clickable cuma bagian chapter info aja
            InkWell(
              onTap: () => _showChapterSheet(chapterIndex),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // FIX alignment
                  children: [
                    if (romanNumeral.isNotEmpty) ...[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepOrange.shade600,
                              Colors.deepOrange.shade800,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          romanNumeral,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["title"]!,
                            style: TextStyle(
                              fontSize: 14, //3dst
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percent,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$done/$total selesai (${(percent * 100).toStringAsFixed(0)}%)",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Pendahuluan di luar InkWell utama, jadi gak conflict
            _buildPendahuluanItem(chapterIndex),
          ],
        ),
      ),
    );
  }

  // REPLACE _buildPendahuluanItem dengan ini:
  Widget _buildPendahuluanItem(int chapterIndex) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final roman = _getRomanNumeral(chapterIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepOrange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final pendahuluanNumber = chapterIndex - 1;
            /*_openWebView(
              context,
              "pendahuluan$pendahuluanNumber",
              "Pendahuluan $roman",
              chapterIndex,
            );
            */

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HtmlReaderPage(
                  title: 'Pendahuluan $roman',
                  // akses pake kurung siku []
                  // pastiin kasih default value (?? []) jaga-jaga kalo null
                  chapterFiles: DaftarIsi.tem1_10[pendahuluanNumber] ?? [],
                  initialIndex: 0,
                  tematikChapterIndex: chapterIndex,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Pendahuluan $roman",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.deepOrange.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChapterSheet(int chapterIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TematikChapterList(
          chapterIndex: chapterIndex,
          onChecklistChanged: _reloadChecklist,
        ),
      ),
    );
  }

  Widget _buildIntroCard(
    int chapterIndex,
    Map<String, String> item,
    List<Map<String, String>> items,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    //final cardColor = Theme.of(context).colorScheme.surface;

    // UBAH DARI SINI: Pakai Card biasa, bukan Container dengan dekorasi manual
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Elevation ikut default theme, jadi sama persis kayak card chapter lain
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    chapterIndex == 0 ? Icons.info_outline : Icons.menu_book,
                    color: Colors.deepOrange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item["title"]!,
                      style: TextStyle(
                        fontSize: 14, //dlm dialog
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((sutta) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Card(
                      elevation: 0, // Dalam dialog biasanya flat atau stroke
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3), // Sedikit bedain
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _handleSpecialCase(
                            context,
                            chapterIndex,
                            items.indexOf(sutta),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sutta["name"]!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    if (sutta["desc"]!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        sutta["desc"]!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subtextColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: subtextColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup"),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                chapterIndex == 0 ? Icons.info_outline : Icons.menu_book,
                color: Colors.deepOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["title"]!,
                      style: TextStyle(
                        fontSize: 14, //1-2
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item["desc"]!,
                      style: TextStyle(fontSize: 12, color: subtextColor),
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

  void _handleSpecialCase(BuildContext context, int chapterIndex, int index) {
    if (chapterIndex == 0) {
      switch (index) {
        case 0:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HtmlReaderPage(
                title: 'Penjelasan Singkat',
                chapterFiles: DaftarIsi.tem,
                initialIndex: 0,
                tematikChapterIndex: 0, // ✅ Kirim index 0 (Info Umum)
              ),
            ),
          );
          break;
        // ... case 1 ...
        case 1:
          _launchURL(
            context,
            "https://readingfaithfully.org/in-the-buddhas-words-an-anthology-of-discourses-from-the-pali-canon-linked-to-suttacentral-net/",
          );
          break;
      }
    } else if (chapterIndex == 1) {
      if (index == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HtmlReaderPage(
              title: 'Prakata',
              chapterFiles: DaftarIsi.tem0_1,
              initialIndex: 0,
              tematikChapterIndex: 1, // ✅ Kirim index 1
            ),
          ),
        );
      } else if (index == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HtmlReaderPage(
              title: 'Pendahuluan Umum',
              chapterFiles: DaftarIsi.tem0_2,
              initialIndex: 0,
              tematikChapterIndex: 1, // ✅ Kirim index 1
            ),
          ),
        );
      }
    }
  }

  /* void _openWebView(
    BuildContext context,
    String key,
    String title,
    int? chapterIndex, // Tambah parameter ini
  ) {
    final url = TematikData.webviewUrls[key];
    if (url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TematikWebView(
            url: url,
            title: title,
            chapterIndex: chapterIndex, // Pass ke webview
          ),
        ),
      );
    }
  }
*/
  String _getRomanNumeral(int index) {
    if (index < 2) return "";
    const numerals = [
      "",
      "",
      "I",
      "II",
      "III",
      "IV",
      "V",
      "VI",
      "VII",
      "VIII",
      "IX",
      "X",
      "XI",
      "XII",
    ];
    return numerals[index];
  }

  void _showInfo(BuildContext context) {
    final totalSuttas = _getTotalSuttaCount();
    final checkedCount = _checkedSuttas.length;
    final percentage = totalSuttas > 0
        ? (checkedCount / totalSuttas * 100).toStringAsFixed(1)
        : "0";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Colors.deepOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Progres Tematik",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepOrange.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Bagian:",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "$totalSuttas",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Sudah Dibaca:",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "$checkedCount",
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalSuttas > 0 ? checkedCount / totalSuttas : 0,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$percentage% selesai",
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (checkedCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text("Reset"),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _confirmReset(context);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text("Reset Progres"),
          ],
        ),
        content: const Text(
          "Yakin ingin menghapus semua centang? Tindakan ini tidak bisa dibatalkan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tematik_checklist');

              if (!mounted) return;
              setState(() => _checkedSuttas.clear());

              navigator.pop();
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text("Progres berhasil direset")),
              );
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  int _getTotalSuttaCount() {
    int count = 0;
    for (int i = 2; i < TematikData.mainMenu.length; i++) {
      final detail = TematikData.getChapterDetail(i);
      final items = detail["items"] as List<Map<String, String>>;
      count += items.where((s) => s["code"]!.isNotEmpty).length;
    }
    return count;
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: Theme.of(context).colorScheme.surface,
          ),
          shareState: CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
          browser: const CustomTabsBrowserConfiguration(
            prefersDefaultBrowser: false,
          ),
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: Theme.of(context).colorScheme.surface,
          preferredControlTintColor: Colors.deepOrange,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tidak bisa membuka link: $e')));
      }
    }
  }
}
