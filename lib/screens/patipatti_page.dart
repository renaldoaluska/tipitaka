import 'package:flutter/material.dart';
import '../widgets/header_depan.dart';

class PatipattiPage extends StatefulWidget {
  const PatipattiPage({super.key});

  @override
  State<PatipattiPage> createState() => _PatipattiPageState();
}

class _PatipattiPageState extends State<PatipattiPage> {
  // Versi kalender Uposatha
  String _selectedUposathaVersion = "Mahanikaya";
  final List<String> _uposathaVersions = [
    "Mahanikaya",
    "Dhammayuttika",
    "Myanmar",
  ];

  final List<Map<String, String>> _moonPhases = [
    {"date": "1 Jan", "phase": "🌑", "label": "New Moon"},
    {"date": "8 Jan", "phase": "🌓", "label": "First Quarter"},
    {"date": "15 Jan", "phase": "🌕", "label": "Full Moon"},
    {"date": "23 Jan", "phase": "🌗", "label": "Last Quarter"},
  ];

  @override
  Widget build(BuildContext context) {
    // ✅ Ambil dari Theme
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildUposathaCard()),
          SliverToBoxAdapter(child: _buildMeditationCard()),
          SliverToBoxAdapter(child: _buildParittaCard()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return const SliverToBoxAdapter(
      child: HeaderDepan(title: "Paṭipatti", subtitle: "Praktik Dhamma"),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 1. UPOSATHA CARD - Kuning (warna bendera ke-2)
  // ═══════════════════════════════════════════════════════════
  Widget _buildUposathaCard() {
    // ✅ Ambil dari Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFF57F17);
    final lightBg = isDark ? const Color(0xFF4A4417) : const Color(0xFFFFF8E1);
    final borderColor = isDark
        ? const Color(0xFF6D621F)
        : const Color(0xFFFFE082);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Card(
        color: cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.nightlight_round,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Uposatha",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Pengamalan Puasa",
                          style: TextStyle(fontSize: 12, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: const Text(
                      "3 hari lagi",
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_view_month,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _selectedUposathaVersion,
                      underline: const SizedBox(),
                      isDense: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: accentColor,
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _uposathaVersions.map((version) {
                        return DropdownMenuItem(
                          value: version,
                          child: Text(version),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUposathaVersion = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Perhitungan Januari 2025",
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _moonPhases.map((phase) {
                        return Column(
                          children: [
                            Text(
                              phase["phase"]!,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phase["date"]!,
                              style: TextStyle(
                                fontSize: 9,
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: lightBg,
                        foregroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text(
                        "Kalender",
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: lightBg,
                        foregroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.article_outlined, size: 16),
                      label: const Text(
                        "Panduan",
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. MEDITASI CARD - Merah (warna bendera ke-3)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMeditationCard() {
    // ✅ Ambil dari Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFD32F2F);
    final lightBg = isDark ? const Color(0xFF4A1F1F) : const Color(0xFFFFEBEE);
    final borderColor = isDark
        ? const Color(0xFF6D2C2C)
        : const Color(0xFFFFCDD2);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        color: cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.self_improvement_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Meditasi",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Ketenangan & Pandangan Terang",
                          style: TextStyle(fontSize: 12, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Timer",
                      icon: Icons.timer_outlined,
                      color: accentColor,
                      lightBg: lightBg,
                      borderColor: borderColor,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: "Audio",
                      icon: Icons.headphones_rounded,
                      color: accentColor,
                      lightBg: lightBg,
                      borderColor: borderColor,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: "Video",
                      icon: Icons.play_circle_outline,
                      color: accentColor,
                      lightBg: lightBg,
                      borderColor: borderColor,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 3. PARITTA CARD - Oranye (warna bendera ke-5)
  // ═══════════════════════════════════════════════════════════
  Widget _buildParittaCard() {
    // ✅ Ambil dari Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFF57C00);
    final lightBg = isDark ? const Color(0xFF4A3517) : const Color(0xFFFFF3E0);
    final borderColor = isDark
        ? const Color(0xFF6D4C1F)
        : const Color(0xFFFFE0B2);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        color: cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.book_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Paritta",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Syair Perlindungan",
                          style: TextStyle(fontSize: 12, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: "Tradisi STI",
                          icon: Icons.menu_book_rounded,
                          color: accentColor,
                          lightBg: lightBg,
                          borderColor: borderColor,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: "Pagi Hari",
                          icon: Icons.wb_sunny_outlined,
                          color: accentColor,
                          lightBg: lightBg,
                          borderColor: borderColor,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: "Malam Hari",
                          icon: Icons.nights_stay_outlined,
                          color: accentColor,
                          lightBg: lightBg,
                          borderColor: borderColor,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: "Uposatha",
                          icon: Icons.calendar_month,
                          color: accentColor,
                          lightBg: lightBg,
                          borderColor: borderColor,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: "Dhammadesanā",
                          icon: Icons.church_rounded,
                          color: accentColor,
                          lightBg: lightBg,
                          borderColor: borderColor,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: "Lainnya",
                          icon: Icons.more_horiz,
                          color: accentColor,
                          lightBg: lightBg,
                          borderColor: borderColor,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color lightBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: lightBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
