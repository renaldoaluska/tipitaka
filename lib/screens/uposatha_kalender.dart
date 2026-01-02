import 'package:flutter/material.dart';
import 'dart:convert'; // Buat baca JSON
import 'package:http/http.dart' as http; // Buat download
import 'dart:ui';

class UposathaKalenderPage extends StatefulWidget {
  final String initialVersion;

  const UposathaKalenderPage({
    super.key,
    this.initialVersion = "Saṅgha Theravāda Indonesia",
  });

  @override
  State<UposathaKalenderPage> createState() => _UposathaKalenderPageState();
}

class _UposathaKalenderPageState extends State<UposathaKalenderPage> {
  // --- LINK JSON (Ganti username/repo lu disini) ---
  final String _dataUrl =
      'https://cdn.jsdelivr.net/gh/renaldoaluska/tipitaka@main/json/uposatha.json';

  // State
  DateTime _focusedDate = DateTime.now();
  late String _selectedVersion;
  bool _isLoading = true;
  String? _errorMessage;

  // Data Uposatha dari JSON
  // Struktur: { "Nama Tradisi": [List Event] }
  Map<String, List<dynamic>> _calendarData = {};

  final List<String> _versions = [
    "Saṅgha Theravāda Indonesia",
    "Pa-Auk Tawya",
    "Dhammayuttika",
    "Mahānikāya",
    "Lunar Tionghoa",
  ];

  final Color _accentColor = const Color(0xFFF57F17); // Warna Oranye Bikhu

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion;
    _fetchCalendarData();
  }

  // 1. FUNGSI DOWNLOAD DATA
  Future<void> _fetchCalendarData() async {
    try {
      final response = await http.get(Uri.parse(_dataUrl));

      if (response.statusCode == 200) {
        setState(() {
          _calendarData = Map<String, List<dynamic>>.from(
            json.decode(response.body),
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data (${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Gagal terhubung ke server.\nPastikan internet aktif.";
      });
      debugPrint("Error fetching uposatha: $e");
    }
  }

  // 2. LOGIC CARI TANGGAL DARI DATA JSON
  Map<int, String> _getUposathaDaysForMonth(int year, int month) {
    Map<int, String> events = {};

    // Ambil list event berdasarkan tradisi yang dipilih
    final traditionEvents = _calendarData[_selectedVersion];

    if (traditionEvents != null) {
      for (var event in traditionEvents) {
        // Format di JSON: "2026-01-02"
        String dateStr = event['date'];
        DateTime eventDate = DateTime.parse(dateStr);

        // Cek apakah tahun & bulan sama dengan yang lagi dilihat user
        if (eventDate.year == year && eventDate.month == month) {
          // Kalo cocok, simpan tanggalnya & icon fasenya
          events[eventDate.day] = event['phase'] ?? '🌑';
        }
      }
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    // Hitung data kalender
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDate.year,
      _focusedDate.month,
    );
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final int startingWeekday = firstDayOfMonth.weekday;

    // Ambil event (hasil filter dari JSON)
    final uposathaEvents = _getUposathaDaysForMonth(
      _focusedDate.year,
      _focusedDate.month,
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Theme.of(context).colorScheme.onSurface),
        title: Text(
          "Kalender Uposatha",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF57F17)),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _fetchCalendarData();
                    },
                    child: const Text("Coba Lagi"),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // 1. FILTER TRADISI
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVersion,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down_circle_outlined,
                          color: _accentColor,
                        ),
                        items: _versions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: value == _selectedVersion
                                    ? _accentColor
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() => _selectedVersion = newValue);
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 2. NAVIGASI BULAN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            _focusedDate = DateTime(
                              _focusedDate.year,
                              _focusedDate.month - 1,
                            );
                          });
                        },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        _formatMonthYear(_focusedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            _focusedDate = DateTime(
                              _focusedDate.year,
                              _focusedDate.month + 1,
                            );
                          });
                        },
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. GRID KALENDER
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header Hari
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children:
                                [
                                      "Sen",
                                      "Sel",
                                      "Rab",
                                      "Kam",
                                      "Jum",
                                      "Sab",
                                      "Min",
                                    ]
                                    .map(
                                      (day) => SizedBox(
                                        width: 30,
                                        child: Text(
                                          day,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                        const Divider(height: 1),

                        // Grid Tanggal
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(8),
                            // Biar gak double scroll (scroll ikut body aja kalo perlu, tapi ini expanded)
                            // Pake NeverScrollable biar rapi
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: daysInMonth + (startingWeekday - 1),
                            itemBuilder: (context, index) {
                              if (index < startingWeekday - 1) {
                                return const SizedBox();
                              }

                              final dayNumber =
                                  index - (startingWeekday - 1) + 1;
                              final isToday =
                                  dayNumber == DateTime.now().day &&
                                  _focusedDate.month == DateTime.now().month &&
                                  _focusedDate.year == DateTime.now().year;

                              // Ambil icon dari Map hasil filter JSON tadi
                              final moonIcon = uposathaEvents[dayNumber];
                              final isUposatha = moonIcon != null;

                              return Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? _accentColor.withValues(alpha: 0.1)
                                      : isUposatha
                                      ? Colors.orange.withValues(alpha: 0.05)
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isToday
                                      ? Border.all(
                                          color: _accentColor,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "$dayNumber",
                                      style: TextStyle(
                                        fontWeight: isToday || isUposatha
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isUposatha ? _accentColor : null,
                                      ),
                                    ),
                                    if (isUposatha) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        moonIcon,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. LEGEND
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem('🌑', 'Bulan Baru'),
                      _buildLegendItem('🌓', '8 Awal'),
                      _buildLegendItem('🌕', 'Purnama'),
                      _buildLegendItem('🌗', '8 Akhir'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return "${months[date.month - 1]} ${date.year}";
  }
}
