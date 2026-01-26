// lib/widgets/tematik_chapter_list.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/tematik_data.dart';
import '../styles/nikaya_style.dart';
import '../screens/suttaplex.dart';

class TematikChapterList extends StatefulWidget {
  final int chapterIndex;
  final VoidCallback? onChecklistChanged; // callback untuk notify parent

  const TematikChapterList({
    super.key,
    required this.chapterIndex,
    this.onChecklistChanged,
  });

  @override
  State<TematikChapterList> createState() => _TematikChapterListState();
}

class _TematikChapterListState extends State<TematikChapterList> {
  Set<String> _checkedSuttas = {};
  bool _isLoading = true;

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

    // Notify parent kalo ada perubahan
    widget.onChecklistChanged?.call();
  }

  void _openSuttaplex(BuildContext context, String code) {
    final uid = TematikData.parseSuttaCode(code);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Suttaplex(
              uid: uid,
              sourceMode: "tematik", //  Mode dari Tematik
            ),
          ),
        );
      },
    );
  }

  String _getRomanNumeral() {
    final index = widget.chapterIndex;
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
    return index < numerals.length ? numerals[index] : "";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final detail = TematikData.getChapterDetail(widget.chapterIndex);
    final items = detail["items"] as List<Map<String, String>>;
    final romanNumeral = _getRomanNumeral();

    // PERBAIKAN: Ambil judul dengan fallback ke Main Menu kalau null
    // Jadi kalau detail["title"] kosong/dihapus, dia ambil judul asli dari menu depan
    final String titleText = (detail["title"] as String?)?.isNotEmpty == true
        ? detail["title"]
        : TematikData.mainMenu[widget.chapterIndex]["title"]!;

    // Hitung progress
    final total = items.where((s) => s["code"]!.isNotEmpty).length;
    final done = items.where((s) {
      final uid = TematikData.parseSuttaCode(s["code"]!);
      return _checkedSuttas.contains(uid);
    }).length;
    final percent = total > 0 ? done / total : 0.0;

    return Column(
      children: [
        // Header progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // BAGIAN 1: KOTAK ANGKA ROMAWI (Kotak Oranye)
                  // Ini otomatis muncul kalau ada angkanya (Chapter 2 ke atas)
                  if (romanNumeral.isNotEmpty) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepOrange.shade600,
                            Colors.deepOrange.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        romanNumeral, // <--- Angka Romawi diambil dari sini
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // BAGIAN 2: TEKS JUDUL
                  // REPLACE Expanded Text yang lama dengan ini:
                  Expanded(
                    child: Text(
                      titleText, // <--- Pakai variabel titleText yang baru
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation(Colors.deepOrange),
              ),
              const SizedBox(height: 6),
              Text(
                "$done/$total selesai (${(percent * 100).toStringAsFixed(0)}%)",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // List content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _buildChapterContent(items),
          ),
        ),
      ],
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

      return Column(
        children: suttas.map((s) {
          final code = s["code"] ?? "";
          if (code.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4), // Ganti dari 8 jadi 4
            child: _buildSuttaItem(s, code),
          );
        }).toList(),
      );
    }).toList();
  }

  // Replace fungsi _buildSectionExpansion di tematik_chapter_list.dart dengan ini:

  // COPY PASTE 2 METHOD INI KE tematik_chapter_list.dart
  // Replace method _buildSectionExpansion dan _buildSuttaItem yang lama

  // METHOD 1: _buildSectionExpansion (dengan range "Teks I,1-5" di header)
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

    // Ambil range referensi teks
    final refs = suttas
        .where((s) => s["ref"] != null && s["ref"]!.isNotEmpty)
        .map((s) => s["ref"]!)
        .toList();

    String refRange = "";
    if (refs.isNotEmpty) {
      final romanNumeral = _getRomanNumeral();
      if (romanNumeral.isNotEmpty) {
        if (refs.length == 1) {
          refRange = "Teks $romanNumeral,${refs.first}";
        } else {
          refRange = "Teks $romanNumeral,${refs.first}-${refs.last}";
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2), // Margin kiri kanan
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: EdgeInsets.zero,
        collapsedShape: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        shape: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        leading: Icon(
          allDone ? Icons.check_circle : Icons.folder_outlined,
          color: allDone ? Colors.green : Colors.deepOrange,
          size: 20,
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (refRange.isNotEmpty) ...[
                    Text(
                      refRange,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    section,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "$done/$total",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: suttas.map((s) {
          final code = s["code"] ?? "";
          if (code.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(right: 12, top: 4), // Hapus left: 12
            child: _buildSuttaItem(s, code),
          );
        }).toList(),
      ),
    );
  }

  // METHOD 2: _buildSuttaItem (tanpa "Teks" tapi tetep ada "I,")
  Widget _buildSuttaItem(Map<String, String> sutta, String code) {
    final uid = TematikData.parseSuttaCode(code);
    final isChecked = _checkedSuttas.contains(uid);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final nikaya = code.split(' ').first.toUpperCase();
    final nikayaColor = getNikayaColor(nikaya);

    final ref = sutta["ref"] ?? "";
    final romanNumeral = _getRomanNumeral();

    return Container(
      margin: const EdgeInsets.only(left: 10), // Cuma kiri aja
      decoration: BoxDecoration(
        color: isChecked
            ? Colors.deepOrange.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isChecked
              ? Colors.deepOrange.withValues(alpha: 0.2)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Row(
          children: [
            // Checkbox
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
            // Content sutta dengan hover
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openSuttaplex(context, code),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ref.isNotEmpty && romanNumeral.isNotEmpty) ...[
                          Text(
                            "$romanNumeral,$ref",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                        Row(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: nikayaColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: nikayaColor.withValues(alpha: 0.4),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
