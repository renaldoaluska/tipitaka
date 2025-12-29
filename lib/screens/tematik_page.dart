// lib/screens/tematik_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import '../data/tematik_data.dart';
import '../styles/nikaya_style.dart';
import 'suttaplex.dart';
import 'tematik_webview.dart';

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

  Future<void> _toggleCheck(String code) async {
    final uid = TematikData.parseSuttaCode(code);
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (_checkedSuttas.contains(uid)) {
        _checkedSuttas.remove(uid);
      } else {
        _checkedSuttas.add(uid);
      }
    });

    await prefs.setStringList('tematik_checklist', _checkedSuttas.toList());
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

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
          // HEADER solid → transparan saat discroll
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isScrolled ? 10.0 : 0.0,
                    sigmaY: _isScrolled ? 10.0 : 0.0,
                  ),
                  child: Material(
                    elevation: 6, // shadow jelas nampak
                    borderRadius: BorderRadius.circular(12),
                    color: _isScrolled
                        ? Theme.of(context).colorScheme.surface.withOpacity(0.7)
                        : Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Back button dengan shadow bundar
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.arrow_back, color: textColor),
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
                                color: textColor,
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
          ),
          Positioned(
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
                      color: Colors.black.withOpacity(0.1),
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
                      color: Theme.of(context).colorScheme.surface.withOpacity(
                        _isScrolled ? 0.85 : 1.0,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Tombol back dengan shadow bundar
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
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
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(int chapterIndex) {
    final item = TematikData.mainMenu[chapterIndex];
    final detail = TematikData.getChapterDetail(chapterIndex);
    final items = detail["items"] as List<Map<String, String>>;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 20,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                        "$done/$total selesai",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pendahuluan Bab
            _buildPendahuluanItem(chapterIndex),
            const SizedBox(height: 12),
            ..._buildChapterContent(items),
          ],
        ),
      ),
    );
  }

  Widget _buildPendahuluanItem(int chapterIndex) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final roman = _getRomanNumeral(chapterIndex);
    return InkWell(
      onTap: () {
        final pendahuluanNumber = chapterIndex - 1;
        _openWebView(
          context,
          "pendahuluan$pendahuluanNumber",
          "Pendahuluan $roman",
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 18,
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 12),
            Text(
              "Pendahuluan $roman",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChapterContent(List<Map<String, String>> items) {
    final grouped = <String, List<Map<String, String>>>{};
    for (final sutta in items) {
      final section = sutta["section"] ?? "";
      grouped.putIfAbsent(section, () => []).add(sutta);
    }

    return grouped.entries.map((entry) {
      final section = entry.key;
      final suttas = entry.value;

      if (section.isNotEmpty) {
        return _buildSectionExpansion(section, suttas);
      }

      // Items tanpa section
      return Column(
        children: suttas.map((s) {
          final code = s["code"] ?? "";
          if (code.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSuttaItemSeparated(s, code),
          );
        }).toList(),
      );
    }).toList();
  }

  Widget _buildSectionExpansion(
    String section,
    List<Map<String, String>> suttas,
  ) {
    final total = suttas.where((s) => s["code"]!.isNotEmpty).length;
    final done = suttas.where((s) {
      final uid = TematikData.parseSuttaCode(s["code"]!);
      return _checkedSuttas.contains(uid);
    }).length;
    final allDone = total > 0 && done == total;

    return ExpansionTile(
      leading: Icon(
        allDone ? Icons.check_circle : Icons.folder_outlined,
        color: allDone ? Colors.green : Colors.deepOrange,
        size: 20,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              section,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12), // margin tambahan biar tracker ga mepet
          Text(
            "$done/$total",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.expand_more, size: 20),
      children: suttas.map((s) {
        final code = s["code"] ?? "";
        if (code.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
          child: _buildSuttaItemSeparated(s, code),
        );
      }).toList(),
    );
  }

  // Item sutta dengan checkbox terpisah dari area klik
  Widget _buildSuttaItemSeparated(Map<String, String> sutta, String code) {
    final uid = TematikData.parseSuttaCode(code);
    final isChecked = _checkedSuttas.contains(uid);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final nikaya = code.split(' ').first.toUpperCase();
    final nikayaColor = getNikayaColor(nikaya);

    return Container(
      decoration: BoxDecoration(
        color: isChecked
            ? Colors.deepOrange.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isChecked
              ? Colors.deepOrange.withOpacity(0.2)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Checkbox sendiri (di luar area klik sutta)
            GestureDetector(
              onTap: () => _toggleCheck(code),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isChecked ? Colors.deepOrange : Colors.transparent,
                  border: Border.all(
                    color: isChecked ? Colors.deepOrange : subtextColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isChecked
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Area klik sutta (terpisah dari checkbox)
            Expanded(
              child: InkWell(
                onTap: () => _openSuttaplex(context, code),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sutta["name"]!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: subtextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge nikaya
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: nikayaColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: nikayaColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: nikayaColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16), // ripple sesuai bentuk kotak
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
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
                          fontSize: 18,
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                          fontSize: 18,
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
      ),
    );
  }

  /*Widget _buildIntroItem(
    Map<String, String> sutta,
    int chapterIndex,
    int index,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => _handleSpecialCase(context, chapterIndex, index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.arrow_forward_ios, size: 14, color: subtextColor),
            const SizedBox(width: 12),
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
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
*/
  void _openSuttaplex(BuildContext context, String code) {
    final uid = TematikData.parseSuttaCode(code);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // biar bisa tinggi hampir penuh
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.7, // tinggi sheet (90% layar)
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Suttaplex(uid: uid), // langsung panggil widget Suttaplex
          ),
        );
      },
    );
  }

  void _handleSpecialCase(BuildContext context, int chapterIndex, int index) {
    if (chapterIndex == 0) {
      switch (index) {
        case 0:
          _openWebView(context, "apaitutematik", "Penjelasan Singkat");
          break;
        case 1:
          _launchURL(
            context,
            "https://readingfaithfully.org/in-the-buddhas-words-an-anthology-of-discourses-from-the-pali-canon-linked-to-suttacentral-net/",
          );
          break;
      }
    } else if (chapterIndex == 1) {
      if (index == 0) {
        _openWebView(context, "prakata", "Prakata");
      } else if (index == 1) {
        _openWebView(context, "pendahuluanUmum", "Pendahuluan Umum");
      }
    } else {
      if (index == 0) {
        final pendahuluanNumber = chapterIndex - 1;
        _openWebView(
          context,
          "pendahuluan$pendahuluanNumber",
          "Pendahuluan ${_getRomanNumeral(chapterIndex)}",
        );
      }
    }
  }

  void _openWebView(BuildContext context, String key, String title) {
    final url = TematikData.webviewUrls[key];
    if (url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TematikWebView(url: url, title: title),
        ),
      );
    }
  }

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
                color: Colors.deepOrange.withOpacity(0.1),
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
                color: Colors.deepOrange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepOrange.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Sutta:",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "$totalSuttas",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "$checkedCount",
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                  const SizedBox(height: 8),
                  Text(
                    "$percentage% selesai",
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('tematik_checklist');
              setState(() => _checkedSuttas.clear());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
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
