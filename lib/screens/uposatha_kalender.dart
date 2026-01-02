import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ TAMBAH INI

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
  // Firebase Realtime Database instance
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // State
  late DateTime _focusedDate;
  final int _currentYear = DateTime.now().year;
  late String _selectedVersion;
  bool _isLoading = true;
  late PageController _pageController;

  // Data
  Map<String, List<dynamic>> _calendarData = {};
  List<String> _availableVersions = [];

  // Style Constant
  final Color _accentColor = const Color(0xFFF57F17);

  // ✅ TAMBAH KEY YANG SAMA DENGAN PATIPATTI
  static const String _keyUposathaVersion = 'selected_uposatha_version';

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion;
    _focusedDate = DateTime.now();
    _pageController = PageController(initialPage: _focusedDate.month - 1);
    _loadDataFromFirebase();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Load data sekali dari Firebase
  Future<void> _loadDataFromFirebase() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await _databaseRef.child('uposatha').get();

      if (snapshot.exists) {
        final data = snapshot.value;
        _processFirebaseData(data);
      } else {
        debugPrint('No data available in Firebase');
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading from Firebase: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Setup listener untuk realtime updates
  void _setupRealtimeListener() {
    _databaseRef.child('uposatha').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        _processFirebaseData(data);
      }
    });
  }

  void _processFirebaseData(dynamic data) {
    if (data is! Map) return;

    setState(() {
      _calendarData = {};

      // Convert Firebase data ke format yang kita butuhin
      data.forEach((key, value) {
        if (value is List) {
          _calendarData[key.toString()] = value;
        }
      });

      _availableVersions = _calendarData.keys.toList();

      // Validasi selected version
      if (!_availableVersions.contains(_selectedVersion) &&
          _availableVersions.isNotEmpty) {
        _selectedVersion = _availableVersions.first;
      }
    });
  }

  String _getMoonIcon(String? phaseName) {
    if (phaseName == null) return '🌑';
    final lower = phaseName.toLowerCase();
    if (lower == 'purnama') return '🌕';
    if (lower == 'separuh-awal') return '🌓';
    if (lower == 'separuh-akhir') return '🌗';
    if (lower == 'baru') return '🌑';
    return '🌑';
  }

  Map<int, String> _getUposathaDaysForMonth(int year, int month) {
    Map<int, String> events = {};
    final traditionEvents = _calendarData[_selectedVersion];
    if (traditionEvents != null) {
      for (var event in traditionEvents) {
        if (event is Map) {
          try {
            DateTime eventDate = DateTime.parse(event['date'].toString());
            if (eventDate.year == year && eventDate.month == month) {
              events[eventDate.day] = _getMoonIcon(event['phase']?.toString());
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }
    }
    return events;
  }

  void _onPageChanged(int index) {
    setState(() {
      _focusedDate = DateTime(_currentYear, index + 1, 1);
    });
  }

  void _changeMonthByArrow(int offset) {
    _pageController.animateToPage(
      (_focusedDate.month - 1) + offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToToday() {
    final now = DateTime.now();
    _pageController.animateToPage(
      now.month - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  // ✅ TAMBAH FUNGSI SAVE KE SHARED PREFERENCES
  Future<void> _saveVersionPreference(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUposathaVersion, version);
      debugPrint('✅ Saved version to SharedPreferences: $version');
    } catch (e) {
      debugPrint('❌ Error saving preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final lightBg = isDark ? const Color(0xFF4A4417) : const Color(0xFFFFF8E1);
    final borderColor = isDark
        ? const Color(0xFF6D621F)
        : const Color(0xFFFFE082);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // CONTENT
          SafeArea(
            bottom: false,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : Column(
                    children: [
                      const SizedBox(height: 75),

                      // NAVIGASI BULAN
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatMonthYear(_focusedDate),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _focusedDate.month > 1
                                        ? () => _changeMonthByArrow(-1)
                                        : null,
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                    color: textColor,
                                    disabledColor: textColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: textColor.withValues(alpha: 0.1),
                                  ),
                                  IconButton(
                                    onPressed: _focusedDate.month < 12
                                        ? () => _changeMonthByArrow(1)
                                        : null,
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    color: textColor,
                                    disabledColor: textColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // MAIN CARD
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // DROPDOWN VERSI
                              Container(
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: lightBg.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      size: 18,
                                      color: _accentColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Versi",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: subtextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value:
                                              _availableVersions.contains(
                                                _selectedVersion,
                                              )
                                              ? _selectedVersion
                                              : null,
                                          isExpanded: true,
                                          icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: _accentColor,
                                            size: 20,
                                          ),
                                          dropdownColor: Theme.of(
                                            context,
                                          ).cardColor,
                                          hint: Text(
                                            "Memuat...",
                                            style: TextStyle(color: textColor),
                                          ),
                                          items: _availableVersions.map((
                                            String value,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      value == _selectedVersion
                                                      ? _accentColor
                                                      : textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (newValue) {
                                            if (newValue != null) {
                                              setState(
                                                () =>
                                                    _selectedVersion = newValue,
                                              );
                                              // ✅ SAVE KE SHARED PREFERENCES
                                              _saveVersionPreference(newValue);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // HEADER HARI
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
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
                                              width: 32,
                                              child: Text(
                                                day,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: day == "Min"
                                                      ? Colors.red[400]
                                                      : Colors.grey[500],
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey[200],
                                indent: 16,
                                endIndent: 16,
                              ),

                              // CALENDAR GRID
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: 12,
                                  onPageChanged: _onPageChanged,
                                  itemBuilder: (context, index) {
                                    return _buildMonthGrid(index + 1);
                                  },
                                ),
                              ),

                              // FOOTER LEGEND
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: lightBg.withValues(alpha: 0.3),
                                  border: Border(
                                    top: BorderSide(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildFooterLegend('🌑', 'Baru'),
                                    _buildFooterLegend('🌓', 'Paruh Awal'),
                                    _buildFooterLegend('🌕', 'Purnama'),
                                    _buildFooterLegend('🌗', 'Paruh Akhir'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // HEADER FLOATING
          _buildHeader(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.85),
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
                        "Kalender Uposatha",
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
                      icon: Icon(
                        Icons.calendar_today_rounded,
                        color: _accentColor,
                        size: 20,
                      ),
                      label: Text(
                        "Hari Ini",
                        style: TextStyle(
                          color: _accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _goToToday,
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

  Widget _buildMonthGrid(int month) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final daysInMonth = DateUtils.getDaysInMonth(_currentYear, month);
    final firstDayOfMonth = DateTime(_currentYear, month, 1);
    final int startingWeekday = firstDayOfMonth.weekday;
    final uposathaEvents = _getUposathaDaysForMonth(_currentYear, month);

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: daysInMonth + (startingWeekday - 1),
      itemBuilder: (context, index) {
        if (index < startingWeekday - 1) return const SizedBox();
        final dayNumber = index - (startingWeekday - 1) + 1;
        final now = DateTime.now();
        final isToday =
            dayNumber == now.day &&
            month == now.month &&
            _currentYear == now.year;
        final moonIcon = uposathaEvents[dayNumber];
        final isUposatha = moonIcon != null;

        return Container(
          decoration: BoxDecoration(
            color: isToday
                ? _accentColor
                : isUposatha
                ? _accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? null
                : isUposatha
                ? Border.all(color: _accentColor, width: 1)
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
                  fontSize: 13,
                  color: isToday
                      ? Colors.white
                      : isUposatha
                      ? _accentColor
                      : textColor,
                ),
              ),
              if (isUposatha)
                Text(
                  moonIcon,
                  style: const TextStyle(fontSize: 10, height: 1.2),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooterLegend(String icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
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
