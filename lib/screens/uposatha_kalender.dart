import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async'; // untuk TimeoutException
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UposathaKalenderPage extends StatefulWidget {
  final String initialVersion;
  final Map<String, List<dynamic>>? initialData;

  const UposathaKalenderPage({
    super.key,
    this.initialVersion = "Saṅgha Theravāda Indonesia",
    this.initialData,
  });

  @override
  State<UposathaKalenderPage> createState() => _UposathaKalenderPageState();
}

class _UposathaKalenderPageState extends State<UposathaKalenderPage> {
  // Firebase Realtime Database instance
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // SATPAM: Variabel buat nyatet waktu terakhir refresh manual
  DateTime? _lastRefreshTime;

  String? _lastFetchTimeStr;
  // State
  late DateTime _focusedDate;
  final int _currentYear = DateTime.now().year;
  late String _selectedVersion;
  bool _isLoading = true;
  bool _isOnline = true;
  late PageController _pageController;

  // Data
  Map<String, List<dynamic>> _calendarData = {};
  List<String> _availableVersions = [];

  // Style Constant
  final Color _accentColor = const Color(0xFFF57F17);

  // Keys untuk SharedPreferences
  static const String _keyUposathaVersion = 'selected_uposatha_version';
  static const String _keyUposathaData = 'cached_uposatha_data';
  static const String _keyLastFetch = 'last_fetch_timestamp';

  // Helper Format Waktu
  String _formatTime(DateTime dt) {
    String twoDigits(int n) => n >= 10 ? "$n" : "0$n";
    return "${dt.year}-${twoDigits(dt.month)}-${twoDigits(dt.day)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}:${twoDigits(dt.second)}";
  }

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion;
    _focusedDate = DateTime.now();
    _pageController = PageController(initialPage: _focusedDate.month - 1);

    // 2️⃣ LOGIC BARU: Cek dulu, dikasih data gak sama halaman depan?
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      // KALAU ADA: Langsung pake! Gak usah loading2 lagi.
      _calendarData = widget.initialData!;
      _availableVersions = _calendarData.keys.toList();
      _isLoading = false;

      // Tetep jalanin init buat setup listener/cek cache timestamp, tapi gak blocking UI
      _initializeData(skipLoad: true);
    } else {
      // KALAU GAK ADA: Yauda load manual kayak biasa
      _initializeData();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Update _initializeData biar support skipLoad
  // Update _initializeData biar support skipLoad & TTL Check
  Future<void> _initializeData({bool skipLoad = false}) async {
    if (!skipLoad) setState(() => _isLoading = true);

    // 1. Load cache timestamp & data
    await _loadFromCache(onlyTimestamp: skipLoad);

    // 2. LOGIKA HEMAT (TTL CHECK)
    // Kalau data ada DAN umur cache masih muda (< 7 hari), STOP!
    if (_calendarData.isNotEmpty && _lastFetchTimeStr != null) {
      try {
        final lastFetch = DateTime.tryParse(
          _lastFetchTimeStr!.replaceAll(" ", "T"),
        );
        if (lastFetch != null) {
          final difference = DateTime.now().difference(lastFetch);
          if (difference.inDays < 7) {
            debugPrint(
              "✋ Data Kalender masih segar (${difference.inDays} hari). Skip fetch server.",
            );

            if (mounted) {
              setState(() {
                _isLoading = false;
                _isOnline = true; // Anggap online karena data valid
              });
            }
            return; // ⛔ STOP DISINI. Jangan panggil Firebase/Listener.
          }
        }
      } catch (e) {
        debugPrint("⚠️ Gagal parse tanggal cache, lanjut fetch aja.");
      }
    }

    // 3. Fetch dari Firebase CUMA KALAU:
    // - Gak punya cache (install baru)
    // - Atau cache udah basi (> 7 hari)
    if (!skipLoad && _calendarData.isEmpty) {
      await _loadDataFromFirebase();
    }

    // ❌ MATIKAN LISTENER OTOMATIS (Biar gak boros & gak ubah jam sendiri)
    // _setupRealtimeListener();
  }

  Future<bool> _loadFromCache({bool onlyTimestamp = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ambil Timestamp (PENTING: String to String, jangan diubah)
      final cachedTime = prefs.getString(_keyLastFetch);
      if (cachedTime != null) {
        setState(() {
          _lastFetchTimeStr = cachedTime;
        });
      }

      if (onlyTimestamp) return true; // Kalo cuma mau timestamp, stop disini

      final cachedJson = prefs.getString(_keyUposathaData);
      if (cachedJson != null) {
        debugPrint('📦 Loading from cache...');
        final Map<String, dynamic> decoded = json.decode(cachedJson);

        // Convert ke format yang benar
        Map<String, List<dynamic>> tempData = {};
        decoded.forEach((key, value) {
          if (value is List) {
            tempData[key] = value;
          }
        });

        setState(() {
          _calendarData = tempData;
          _availableVersions = _calendarData.keys.toList();

          // Validasi selected version
          if (!_availableVersions.contains(_selectedVersion) &&
              _availableVersions.isNotEmpty) {
            _selectedVersion = _availableVersions.first;
          }
        });

        debugPrint('✅ Cache loaded successfully');
        return true;
      }

      debugPrint('📭 No cache found');
      return false;
    } catch (e) {
      debugPrint('❌ Error loading cache: $e');
      return false;
    }
  }

  Future<void> _forceRefresh() async {
    final now = DateTime.now();

    // 1. CEK SATPAM: Apakah user pernah pencet sebelumnya?
    if (_lastRefreshTime != null) {
      final difference = now.difference(_lastRefreshTime!);

      // LOGIC: Kalau selisihnya kurang dari 5 detik, TOLAK!
      if (difference.inSeconds < 5) {
        if (mounted) {
          // Bersihin antrian snackbar lama biar gak numpuk
          ScaffoldMessenger.of(context).clearSnackBars();

          // Munculin peringatan "Sabar Woy"
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Tunggu sebentar sebelum refresh lagi",
                style: TextStyle(
                  // fontWeight: FontWeight.bold,
                  color: (Theme.of(context).colorScheme.surface),
                  fontSize: 12,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,

              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return; // ⛔ STOP DISINI! Jangan lanjut ke Firebase.
      }
    }

    // 2. KALAU LOLOS (Udah > 5 detik):
    _lastRefreshTime = now; // Catat waktu sekarang

    if (mounted) {
      setState(() => _isLoading = true);
    }

    // Kirim sinyal manualRefresh: true (Bypass TTL cache 7 hari)
    await _loadDataFromFirebase(manualRefresh: true);
  }

  // ✅ SAVE KE CACHE
  // Cari method _saveToCache, ganti jadi gini:
  Future<void> _saveToCache(
    Map<String, List<dynamic>> data, {
    bool updateTime = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(data);
      await prefs.setString(_keyUposathaData, jsonString);

      // 👇 LOGIC BARU: Cuma update waktu kalo disuruh (datanya berubah)
      // ATAU kalau waktu yang lama belum ada (null)
      if (updateTime || _lastFetchTimeStr == null) {
        final now = DateTime.now();
        //await prefs.setInt(_keyLastFetch, now.millisecondsSinceEpoch);
        await prefs.setString(_keyLastFetch, _formatTime(now));
        if (mounted) {
          setState(() {
            _lastFetchTimeStr = _formatTime(now);
          });
        }
      }

      debugPrint('💾 Data saved to cache (Time updated: $updateTime)');
    } catch (e) {
      debugPrint('❌ Error saving to cache: $e');
    }
  }

  // ✅ LOAD DARI FIREBASE (dengan error handling untuk offline)
  // Tambah parameter {bool manualRefresh = false}
  Future<void> _loadDataFromFirebase({bool manualRefresh = false}) async {
    try {
      debugPrint('🌐 Fetching from Firebase...');

      final snapshot = await _databaseRef
          .child('uposatha')
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException('Firebase timeout');
            },
          );

      if (snapshot.exists) {
        final data = snapshot.value;
        // Oper sinyal manualRefresh ke sini 👇
        _processFirebaseData(data, forceUpdateTime: manualRefresh);

        if (mounted) {
          setState(() {
            _isOnline = true;
            _isLoading = false;
          });
        }
        debugPrint('✅ Firebase data loaded & cached');
      } else {
        debugPrint('📭 No data available in Firebase');
        if (mounted) {
          setState(() {
            _isOnline = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Firebase error (probably offline): $e');

      if (mounted) {
        // ✅ CUKUP SET STATE, NO SNACKBAR
        setState(() {
          _isOnline = false;
          _isLoading = false;
        });
      }
    }
  }

  // Setup listener untuk realtime updates

  // Cari method _processFirebaseData, ganti isinya jadi gini:

  // Tambah parameter {bool forceUpdateTime = false}
  // Cari method ini di uposatha_kalender.dart dan TIMPA SEMUANYA
  void _processFirebaseData(dynamic data, {bool forceUpdateTime = false}) {
    if (data is! Map) return;

    // 1. Olah data mentah
    Map<String, List<dynamic>> newData = {};
    data.forEach((key, value) {
      if (value is List) {
        newData[key.toString()] = value;
      }
    });

    // 2. DETEKTIF: Cuma buat cek perlu update Tampilan/State apa nggak
    final String oldJson = json.encode(_calendarData);
    final String newJson = json.encode(newData);
    bool isChanged = oldJson != newJson;

    if (mounted) {
      // Update variabel data cuma kalau ada isinya yang beda
      if (isChanged || _calendarData.isEmpty) {
        setState(() {
          _calendarData = newData;
          _availableVersions = _calendarData.keys.toList();

          if (!_availableVersions.contains(_selectedVersion) &&
              _availableVersions.isNotEmpty) {
            _selectedVersion = _availableVersions.first;
          }
        });
      }

      // 3. UPDATE CACHE & JAM (WAJIB JALAN SETIAP KALI FETCH BERHASIL)
      // "Jam diupdate setiap fetch" <- SESUAI REQUEST
      // Gak peduli datanya sama atau beda, jam harus "Sekarang" biar timer 7 harinya kereset.
      _saveToCache(_calendarData, updateTime: true);
    }
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

  Future<void> _saveVersionPreference(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUposathaVersion, version);
      debugPrint('✅ Saved version to SharedPreferences: $version');
    } catch (e) {
      debugPrint('❌ Error saving preference: $e');
    }
  }

  double _getAspectRatio(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      // Tadi 1.8 (lebar & gepeng).
      // Ganti jadi 1.3 atau 1.4 biar agak tinggian dikit di landscape.
      return 1.4;
    }

    // Tadi 1.0 (Persegi).
    // Ganti jadi 0.8 atau 0.85 biar jadi persegi panjang (tinggi > lebar).
    // Semakin kecil angkanya, semakin tinggi kotaknya.
    return 0.85;
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

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // Widget isi card biar nggak duplikat kode
    Widget buildCardContent() {
      return Column(
        mainAxisSize: MainAxisSize.min, // Penting buat landscape
        children: [
          // DROPDOWN VERSI
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: lightBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 18, color: _accentColor),
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
                      value: _availableVersions.contains(_selectedVersion)
                          ? _selectedVersion
                          : null,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _accentColor,
                        size: 20,
                      ),
                      dropdownColor: Theme.of(context).cardColor,
                      hint: Text(
                        "Memuat...",
                        style: TextStyle(color: textColor),
                      ),
                      items: _availableVersions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: value == _selectedVersion
                                  ? _accentColor
                                  : textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => _selectedVersion = newValue);
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
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
            color: isDark ? Colors.white10 : Colors.grey[200],
            indent: 16,
            endIndent: 16,
          ),

          // CALENDAR GRID
          // Logic: Kalau Landscape, kasih tinggi fix biar bisa di-scroll
          // Kalau Portrait, pake Expanded biar menuhin sisa layar
          isLandscape
              ? SizedBox(
                  height: 320, // Tinggi fix biar gak kepotong di scrollview
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 12,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      return _buildMonthGrid(index + 1);
                    },
                  ),
                )
              : Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 12,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      return _buildMonthGrid(index + 1);
                    },
                  ),
                ),

          // BANNER OFFLINE (Portrait Only - di card)
          if (!_isOnline && orientation == Orientation.portrait)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mode Offline',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // 5. TAMBAHKAN TEKS UPDATE DISINI (Sebelum Footer Legend)
          if (_lastFetchTimeStr != null)
            // 5. TAMBAHKAN TEKS UPDATE & TOMBOL REFRESH DISINI
            if (_lastFetchTimeStr != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                ), // Padding dirapikan
                color: lightBg.withValues(
                  alpha: 0.3,
                ), // Background sama kayak footer
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Taruh di tengah
                  children: [
                    // TEKS JAM
                    Text(
                      "Terakhir update: $_lastFetchTimeStr",
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(width: 8), // Jarak antara teks dan ikon
                    // TOMBOL REFRESH KECIL
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh,
                          // Warna ikon ngikutin warna teks biar serasi
                          color: isDark ? Colors.white54 : Colors.black45,
                          size: 14, // Ukuran kecil pas sama teks fontSize 10
                        ),
                        // Pake _forceRefresh biar bypass satpam hemat
                        onPressed: _isLoading ? null : _forceRefresh,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "Paksa Update",
                      ),
                    ),
                  ],
                ),
              ),
          // FOOTER LEGEND
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: lightBg.withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFooterLegend('🌑', 'Baru'),
                _buildFooterLegend('🌓', 'Awal'),
                _buildFooterLegend('🌕', 'Purnama'),
                _buildFooterLegend('🌗', 'Akhir'),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // CONTENT
          SafeArea(
            bottom: false,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : _calendarData.isEmpty
                ? _buildEmptyState()
                : isLandscape
                // --- LAYOUT LANDSCAPE (SCROLLABLE) ---
                ? SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 80), // Space header
                        // Navigasi Bulan
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 64,
                            vertical: 8,
                          ),
                          child: _buildMonthNav(textColor, isDark),
                        ),

                        // Card Scrollable
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                            child: buildCardContent(),
                          ),
                        ),
                      ],
                    ),
                  )
                // --- LAYOUT PORTRAIT (FIXED / EXPANDED) ---
                : Column(
                    children: [
                      const SizedBox(
                        height: 70,
                      ), // Dikurangin dari 75 biar ga overflow
                      // NAVIGASI BULAN
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                        child: _buildMonthNav(textColor, isDark),
                      ),

                      // MAIN CARD (Expanded)
                      Expanded(
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 800),
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
                            child: buildCardContent(),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // HEADER FLOATING (Tetap di atas)
          _buildHeader(context),
        ],
      ),
    );
  }

  // Helper biar gak berantakan di build utama
  Widget _buildMonthNav(Color textColor, bool isDark) {
    return Row(
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
                icon: const Icon(Icons.chevron_left_rounded),
                color: textColor,
                disabledColor: textColor.withValues(alpha: 0.2),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(minWidth: 40),
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
                icon: const Icon(Icons.chevron_right_rounded),
                color: textColor,
                disabledColor: textColor.withValues(alpha: 0.2),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(minWidth: 40),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ EMPTY STATE (ketika benar-benar tidak ada data)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada data tersimpan dan tidak ada koneksi internet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _initializeData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
                    /*IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _forceRefresh, // 👈 Pake yang force
                      // ...
                    ),*/
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
    final orientation = MediaQuery.of(context).orientation;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: _getAspectRatio(context),
        mainAxisSpacing: orientation == Orientation.landscape
            ? 2
            : 4, // 👈 Lebih rapat di landscape
        crossAxisSpacing: orientation == Orientation.landscape ? 2 : 4,
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
            mainAxisSize: MainAxisSize.min, // Biar wrap content rapi
            children: [
              Text(
                "$dayNumber",
                style: TextStyle(
                  fontWeight: isToday || isUposatha
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12, // Kurangin dikit dari 13 ke 12 biar lega
                  color: isToday
                      ? Colors.white
                      : isUposatha
                      ? _accentColor
                      : textColor,
                ),
              ),
              if (isUposatha) ...[
                const SizedBox(
                  height: 2,
                ), // Kasih jarak dikit antara angka & bulan
                Text(
                  moonIcon,
                  // Height 1.0 biar line-height nya gak makan tempat
                  style: const TextStyle(fontSize: 18, height: 1.0),
                ),
              ],
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
