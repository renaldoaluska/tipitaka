import 'package:flutter/material.dart';
import '../widgets/panjang_card_builder.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor(widget.isDarkMode),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildCard(
              title: "Meditasi",
              subtitle: "Ānāpānasati, Mettā, Vipassanā",
              icon: Icons.self_improvement_rounded,
              gradientColors: widget.isDarkMode
                  ? [const Color(0xFFFF6F00), const Color(0xFFFF9800)]
                  : [Colors.orange.shade400, Colors.amber.shade400],
              actionLabel: "Mulai",
              footerIcon: Icons.timer_outlined,
              footerText: "Timer • Guide • Tracker",
              onTap: () {
                /* Navigate */
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _buildCard(
              title: "Uposatha",
              subtitle: "Hari Observasi Sīla",
              icon: Icons.nightlight_round,
              gradientColors: widget.isDarkMode
                  ? [const Color(0xFF283593), const Color(0xFF3949AB)]
                  : [Colors.indigo.shade700, Colors.indigo.shade400],
              actionLabel: "3 hari lagi",
              footerIcon: Icons.calendar_today,
              footerText: "Calendar • 8 Precepts • Reminder",
              onTap: () {
                /* Navigate */
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _buildCard(
              title: "Chanting Paritta",
              subtitle: "Sutta Perlindungan & Berkah",
              icon: Icons.book_rounded,
              gradientColors: widget.isDarkMode
                  ? [const Color(0xFF1A237E), const Color(0xFF3949AB)]
                  : [Colors.indigo.shade700, Colors.indigo.shade400],
              actionLabel: "Baca",
              footerIcon: Icons.auto_awesome,
              footerText: "Chanting • Blessing • Devotion",
              onTap: () {
                /* Navigate */
              },
            ),
          ),
          SliverToBoxAdapter(child: _buildPracticeTools()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: _bgColor(widget.isDarkMode),
      elevation: 0,
      toolbarHeight: 64,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Praktik Dhamma",
                  style: TextStyle(
                    fontSize: 13,
                    color: _subtextColor(widget.isDarkMode),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Paṭipatti 🧘",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textColor(widget.isDarkMode),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: widget.isDarkMode ? Colors.amber : Colors.grey[700],
            ),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeTools() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Alat Praktik",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _textColor(widget.isDarkMode),
            ),
          ),
          const SizedBox(height: 12),

          PanjangCardBuilder(
            title: "Meditation Timer",
            subtitle: "Atur waktu meditasi dengan bell",
            icon: Icons.menu_book_rounded,
            color: Colors.orange.shade700,
            isDarkMode: widget.isDarkMode,
            onTap: () {},
          ),
          const SizedBox(height: 8),

          PanjangCardBuilder(
            title: "Daily Tracker",
            subtitle: "Catat progress praktik harian",
            icon: Icons.check_circle_outline,
            color: Colors.green.shade700,
            isDarkMode: widget.isDarkMode,
            onTap: () {},
          ),
          const SizedBox(height: 8),

          PanjangCardBuilder(
            title: "5 Sīla Checklist",
            subtitle: "Monitor praktik moralitas",
            icon: Icons.playlist_add_check,
            color: Colors.blue.shade700,
            isDarkMode: widget.isDarkMode,
            onTap: () {},
          ),
          const SizedBox(height: 8),

          PanjangCardBuilder(
            title: "Mettā Practice",
            subtitle: "Latihan cinta kasih universal",
            icon: Icons.favorite_outline,
            color: Colors.pink.shade700,
            isDarkMode: widget.isDarkMode,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required String actionLabel,
    required IconData footerIcon,
    required String footerText,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Card(
        color: _cardColor(widget.isDarkMode),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(footerIcon, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      footerText,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
