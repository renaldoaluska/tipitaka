import 'package:flutter/material.dart';
import '../widgets/header_depan.dart';

class PatipattiPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const PatipattiPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<PatipattiPage> createState() => _PatipattiPageState();
}

class _PatipattiPageState extends State<PatipattiPage> {
  Color _bgColor(bool dark) => dark ? Colors.grey[900]! : Colors.grey[50]!;
  Color _cardColor(bool dark) => dark ? Colors.grey[850]! : Colors.white;
  Color _textColor(bool dark) => dark ? Colors.white : Colors.black;
  Color _subtextColor(bool dark) =>
      dark ? Colors.grey[400]! : Colors.grey[600]!;

  // Versi kalender Uposatha
  String _selectedUposathaVersion = "Mahanikaya"; // default
  final List<String> _uposathaVersions = [
    "Mahanikaya",
    "Dhammayuttika",
    "Myanmar",
    // TODO: Tambah versi lain dari DB
  ];

  // TODO: Hitung fase bulan dan uposatha dates berdasarkan versi
  final List<Map<String, String>> _moonPhases = [
    {"date": "1 Jan", "phase": "🌑", "label": "New Moon"},
    {"date": "8 Jan", "phase": "🌓", "label": "First Quarter"},
    {"date": "15 Jan", "phase": "🌕", "label": "Full Moon"},
    {"date": "23 Jan", "phase": "🌗", "label": "Last Quarter"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor(widget.isDarkMode),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildUposathaCard()),
          SliverToBoxAdapter(child: _buildMeditationCard()),
          SliverToBoxAdapter(child: _buildParittaCard()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: HeaderDepan(
        isDarkMode: widget.isDarkMode,
        onThemeToggle: widget.onThemeToggle,
        title: "Paṭipatti",
        subtitle: "Praktik Dhamma",
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 1. UPOSATHA CARD - neutral background dengan accent indigo
  // ═══════════════════════════════════════════════════════════
  Widget _buildUposathaCard() {
    const accentColor = Color(0xFF3949AB); // Indigo
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        color: _cardColor(widget.isDarkMode),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
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
                            color: _textColor(widget.isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Pengamalan Puasa",
                          style: TextStyle(
                            fontSize: 12,
                            color: _subtextColor(widget.isDarkMode),
                          ),
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
                      border: Border.all(
                        color: accentColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
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

              // Dropdown versi kalender
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_view_month,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _selectedUposathaVersion,
                      underline: const SizedBox(),
                      isDense: true,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: accentColor,
                      ),
                      style: TextStyle(
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

              // Fase bulan (plain box, no background)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Perhitungan Januari 2025",
                      style: TextStyle(
                        fontSize: 11,
                        color: _textColor(widget.isDarkMode),
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
                                color: _textColor(widget.isDarkMode),
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

              // Tombol aksi bawah
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: accentColor.withOpacity(
                          0.05,
                        ), // sama kayak dropdown
                        foregroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: accentColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text(
                        "Kalender",
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        // TODO: Navigate ke kalender
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: accentColor.withOpacity(
                          0.05,
                        ), // sama kayak dropdown
                        foregroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: accentColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.article_outlined, size: 16),
                      label: const Text(
                        "Panduan",
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        // TODO: Navigate ke kalender
                      },
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
  // 2. MEDITASI CARD - neutral background dengan accent orange
  // ═══════════════════════════════════════════════════════════
  Widget _buildMeditationCard() {
    const accentColor = Color(0xFFFF6F00); // Orange
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        color: _cardColor(widget.isDarkMode),
        elevation: 1, // ✅ tambahin ini biar nggak ada shadow
        // shape: RoundedRectangleBorder(
        //  borderRadius: BorderRadius.circular(16),
        //  side: BorderSide(color: accentColor.withOpacity(0.3), width: 2),
        // ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title dalam satu row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      // border: Border.all(
                      //  color: accentColor.withOpacity(0.3),
                      //  width: 1.5,
                      // ),
                    ),
                    child: Icon(
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
                            color: _textColor(widget.isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Ketenangan & Pandangan Terang",
                          style: TextStyle(
                            fontSize: 12,
                            color: _subtextColor(widget.isDarkMode),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tombol aksi (3 tombol)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Timer",
                      icon: Icons.timer_outlined,
                      color: accentColor,
                      onTap: () {
                        // TODO: Buka meditation timer
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: "Audio",
                      icon: Icons.headphones_rounded,
                      color: accentColor,
                      onTap: () {
                        // TODO: Buka audio guide (termasuk Mettā)
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: "Video",
                      icon: Icons.play_circle_outline,
                      color: accentColor,
                      onTap: () {
                        // TODO: Buka video guide
                      },
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
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

  // ═══════════════════════════════════════════════════════════
  // 3. PARITTA CARD - neutral background dengan accent purple
  // ═══════════════════════════════════════════════════════════
  Widget _buildParittaCard() {
    const accentColor = Color(0xFF8E24AA); // Purple
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        color: _cardColor(widget.isDarkMode),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          //decoration: BoxDecoration(
          //   borderRadius: BorderRadius.circular(16),
          //   border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
          // ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title dalam satu row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      //  border: Border.all(
                      //   color: accentColor.withOpacity(0.3),
                      //  width: 1.5,
                      //),
                    ),
                    child: Icon(
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
                            color: _textColor(widget.isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Syair Perlindungan",
                          style: TextStyle(
                            fontSize: 12,
                            color: _subtextColor(widget.isDarkMode),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tombol kategori paritta (3x2 grid)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: "Tradisi STI",
                          icon: Icons.menu_book_rounded,
                          color: accentColor,
                          onTap: () {
                            // TODO: Buka submenu 9 kategori STI
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: "Pagi Hari",
                          icon: Icons.wb_sunny_outlined,
                          color: accentColor,
                          onTap: () {
                            // TODO: Buka list paritta pagi
                          },
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
                          onTap: () {
                            // TODO: Buka list paritta malam
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: "Uposatha",
                          icon: Icons.calendar_month,
                          color: accentColor,
                          onTap: () {
                            // TODO: Buka list paritta uposatha
                          },
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
                          onTap: () {
                            // TODO: Pilih vihara (DBS/DR/Yasati/PATVDH)
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: "Lainnya",
                          icon: Icons.more_horiz,
                          color: accentColor,
                          onTap: () {
                            // TODO: Kategori tambahan
                          },
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
}
