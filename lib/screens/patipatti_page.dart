import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';
import '../services/dana_everyday_service.dart';
import '../widgets/header_depan.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import '../screens/html.dart';
import '../data/html_data.dart';
import 'meditasi_timer.dart';
import 'meditasi_video.dart';
import 'uposatha_kalender.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:async';

class PatipattiPage extends StatefulWidget {
  final String? highlightSection;
  const PatipattiPage({super.key, this.highlightSection});

  @override
  State<PatipattiPage> createState() => _PatipattiPageState();
}

class _PatipattiPageState extends State<PatipattiPage>
    with AutomaticKeepAliveClientMixin {
  String? _lastCampaignFetchTimeStr; //  Tambah ini
  DateTime? _lastDermaClickTime; //  Untuk satpam refresh

  // Variabel buat nyatet waktu terakhir refresh Uposatha
  DateTime? _lastUposathaRefreshTime;
  // Tambah key baru buat simpan waktu
  static const String _keyLastFetchTime = 'last_fetch_timestamp';

  String? _lastFetchTimeStr;
  bool _isCampaignError = false; // Tambah ini di deklarasi variabel
  bool _showViewAllButton = false;
  String _selectedCategory = 'Semua';
  List<Campaign> _campaigns = [];
  bool _isLoadingCampaigns = false;
  final DanaEverydayService _danaService = DanaEverydayService();
  final ScrollController _campaignScrollController = ScrollController();

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  // Keys untuk scroll
  final GlobalKey _dermaKey = GlobalKey();
  final GlobalKey _uposathaKey = GlobalKey();
  final GlobalKey _meditasiKey = GlobalKey();
  final GlobalKey _parittaKey = GlobalKey();

  String? _highlightedSection;

  // ═══════════════════════════════════════════════════════════
  // 🌑 STATE UPOSATHA (SISTEM BARU)
  // ═══════════════════════════════════════════════════════════
  String _selectedUposathaVersion = "Saṅgha Theravāda Indonesia";
  bool _isLoadingUposatha = false;
  bool _isOnline = true;

  static const String _keyUposathaData = 'cached_uposatha_data';

  // Variable buat nyimpen data mentah dari JSON
  Map<String, List<dynamic>> _uposathaData = {};

  // List versi (key) yang didapet dari JSON
  List<String> _availableVersions = ["Saṅgha Theravāda Indonesia"];

  // Data olahan buat UI
  String _nextUposathaLabel = "Memuat...";
  List<Map<String, String>> _displayPhases = [];

  static const String _keyUposathaVersion = 'selected_uposatha_version';

  // ═══════════════════════════════════════════════════════════
  // 📚 STATE PARITTA
  // ═══════════════════════════════════════════════════════════
  String _selectedParittaTradition = "STI (Edisi Lama)";
  bool _isLoadingParitta = false;

  final Map<String, List<Map<String, dynamic>>> _parittaData = {
    "STI (Edisi Lama)": [
      {
        "type": "link",
        "label": "Panduan Pembacaan",
        "icon": Icons.info_outline,
        "files": DaftarIsi.parSti0,
      },
      {
        "type": "group",
        "label": "I. Upacara & Pāṭha",
        "icon": Icons.spa_outlined,
        "items": [
          {
            "label": "Tujuh Bulan Kandungan",
            "icon": Icons.pregnant_woman_outlined,
            "files": DaftarIsi.parSti1_1,
          },
          {
            "label": "Menjelang Kelahiran",
            "icon": Icons.child_care_outlined,
            "files": DaftarIsi.parSti1_2,
          },
          {
            "label": "Pemberkahan Kelahiran",
            "icon": Icons.child_friendly_outlined,
            "files": DaftarIsi.parSti1_3,
          },
          {
            "label": "Ulang Tahun, Turun Tanah",
            "icon": Icons.cake_outlined,
            "files": DaftarIsi.parSti1_4,
          },
          {
            "label": "Potong Rambut",
            "icon": Icons.content_cut_outlined,
            "files": DaftarIsi.parSti1_5,
          },
          {
            "label": "Peletakan Batu Pertama",
            "icon": Icons.foundation_outlined,
            "files": DaftarIsi.parSti1_6,
          },
          {
            "label": "Rumah & Usaha Baru",
            "icon": Icons.home_work_outlined,
            "files": DaftarIsi.parSti1_7,
          },
          {
            "label": "Pembersihan Tempat",
            "icon": Icons.cleaning_services_outlined,
            "files": DaftarIsi.parSti1_8,
          },
          {
            "label": "Tirta Untuk Orang Sakit",
            "icon": Icons.local_hospital_outlined,
            "files": DaftarIsi.parSti1_9,
          },
          {
            "label": "Tanam Di Sawah",
            "icon": Icons.nature_people_outlined,
            "files": DaftarIsi.parSti1_10,
          },
          {
            "label": "Pengukuhan Janji Jabatan",
            "icon": Icons.badge_outlined,
            "files": DaftarIsi.parSti1_11,
          },
          {
            "label": "Janji Di Pengadilan",
            "icon": Icons.gavel_outlined,
            "files": DaftarIsi.parSti1_12,
          },
          {
            "label": "Wisuda Upāsaka/upāsikā",
            "icon": Icons.school_outlined,
            "files": DaftarIsi.parSti1_13,
          },
          {
            "label": "Upacara Perkawinan",
            "icon": Icons.handshake_outlined,
            "files": DaftarIsi.parSti1_14,
          },
          {
            "label": "Upacara Kematian",
            "icon": Icons.local_florist_outlined,
            "files": DaftarIsi.parSti1_15,
          },
          {
            "label": "Peringatan Kematian (Berkala)",
            "icon": Icons.event_repeat_outlined,
            "files": DaftarIsi.parSti1_16a,
          },
          {
            "label": "Peringatan Kematian (Ziarah)",
            "icon": Icons.yard_outlined,
            "files": DaftarIsi.parSti1_16b,
          },
          {
            "label": "Catatan",
            "icon": Icons.note_alt_outlined,
            "files": DaftarIsi.parSti1_17,
          },
        ],
      },
      {
        "type": "link",
        "label": "II. Tuntunan Pūjā Bakti",
        "icon": Icons.volunteer_activism_outlined,
        "files": DaftarIsi.parSti2,
      },
      {
        "type": "link",
        "label": "III. Ārādhanā & Sikkhāpada",
        "icon": Icons.record_voice_over_outlined,
        "files": DaftarIsi.parSti3,
      },
      {
        "type": "link",
        "label": "IV. Upacara Maṅgala",
        "icon": Icons.favorite_border_outlined,
        "files": DaftarIsi.parSti4,
      },
      {
        "type": "link",
        "label": "V. Upacara Avamaṅgala",
        "icon": Icons.sentiment_dissatisfied_outlined,
        "files": DaftarIsi.parSti5,
      },
      {
        "type": "link",
        "label": "VI. Pāṭha-Pāṭha Khusus",
        "icon": Icons.star_outline_outlined,
        "files": DaftarIsi.parSti6,
      },
      {
        "type": "link",
        "label": "VII. Pūjā Kathā Hari Suci",
        "icon": Icons.calendar_month_outlined,
        "files": DaftarIsi.parSti7,
      },
      {
        "type": "link",
        "label": "VIII. Pakiṇṇakakathā",
        "icon": Icons.card_giftcard_outlined,
        "files": DaftarIsi.parSti8,
      },
    ],
    "Lainnya": [
      {
        "type": "link",
        "label": "Persembahan Cetiya",
        "icon": Icons.temple_buddhist_outlined,
        "files": DaftarIsi.parLCetiya,
      },
      {
        "type": "link",
        "label": "Paṭipattiyā Ratanattaya",
        "icon": Icons.self_improvement_outlined,
        "files": DaftarIsi.parLImaya,
      },
      {
        "type": "link",
        "label": "Paṭiccasamuppāda",
        "icon": Icons.sync_alt_outlined,
        "files": DaftarIsi.parLPaticca,
      },
      {
        "type": "group",
        "label": "Pelafalan Pagi",
        "icon": Icons.wb_twilight,
        "items": [
          {
            "label": "Anekajāti Pāḷi",
            "icon": Icons.wb_sunny_outlined,
            "files": DaftarIsi.parLAneka,
          },
          {
            "label": "Paccavekkhaṇā",
            "icon": Icons.restaurant_menu_outlined,
            "files": DaftarIsi.parLPacca,
          },
        ],
      },
      {
        "type": "group",
        "label": "Pelafalan Malam",
        "icon": Icons.nights_stay_outlined,
        "items": [
          {
            "label": "Mahā Namakkāra Pāḷi",
            "icon": Icons.nights_stay_outlined,
            "files": DaftarIsi.parLMaha,
          },
        ],
      },
      {
        "type": "group",
        "label": "Pelafalan Uposatha",
        "icon": Icons.calendar_month,
        "items": [
          {
            "label": "Paccayuddeso",
            "icon": Icons.list_alt_outlined,
            "files": DaftarIsi.parLYuddeso,
          },
          {
            "label": "Paccayaniddeso",
            "icon": Icons.description_outlined,
            "files": DaftarIsi.parLYaniddeso,
          },
        ],
      },
      {
        "type": "group",
        "label": "Dhammadesanā DBS",
        "icon": Icons.record_voice_over_outlined,
        "items": [
          {
            "label": "Permohonan Tisaraṇa & Pañcasīla",
            "icon": Icons.record_voice_over_outlined,
            "files": DaftarIsi.parLDBS1,
          },
          {
            "label": "Persembahan Jasa-Jasa Kebajikan",
            "icon": Icons.volunteer_activism_outlined,
            "files": DaftarIsi.parLDBS2,
          },
        ],
      },
      {
        "type": "group",
        "label": "Dhammadesanā DKS",
        "icon": Icons.record_voice_over_outlined,
        "items": [
          {
            "label": "Permohonan Tisaraṇa & Pañcasīla",
            "icon": Icons.record_voice_over_outlined,
            "files": DaftarIsi.parLDKS1,
          },
          {
            "label": "Okāsa & Pattidāna",
            "icon": Icons.volunteer_activism_outlined,
            "files": DaftarIsi.parLDKS2,
          },
        ],
      },
      {
        "type": "group",
        "label": "Dhammadesanā Yasati",
        "icon": Icons.record_voice_over_outlined,
        "items": [
          {
            "label": "Permohonan Tisaraṇa & Pañcasīla",
            "icon": Icons.record_voice_over_outlined,
            "files": DaftarIsi.parLYasati1,
          },
          {
            "label": "Pattidāna",
            "icon": Icons.volunteer_activism_outlined,
            "files": DaftarIsi.parLYasati2,
          },
        ],
      },
      {
        "type": "group",
        "label": "Dhammadesanā PATVDH",
        "icon": Icons.record_voice_over_outlined,
        "items": [
          {
            "label": "Permohonan Tisaraṇa & Pañcasīla",
            "icon": Icons.record_voice_over_outlined,
            "files": DaftarIsi.parLPA1,
          },
          {
            "label": "Okāsa & Pattidāna",
            "icon": Icons.volunteer_activism,
            "files": DaftarIsi.parLPA2,
          },
        ],
      },
    ],
  };

  static const String _keyParitta = 'selected_paritta_tradition';

  // Ini mantra biar halaman gak dimatiin pas pindah tab
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadUposathaData(); // ← GANTI INI
    //_setupRealtimeListener();
    _loadCampaigns();

    if (widget.highlightSection != null) {
      _scheduleScroll(widget.highlightSection!);
    }
  }

  @override
  void dispose() {
    _campaignScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PatipattiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightSection != oldWidget.highlightSection &&
        widget.highlightSection != null) {
      _scheduleScroll(widget.highlightSection!);
    }
  }

  //  METHOD SATPAM BUAT UPOSATHA
  void _handleUposathaRefresh() {
    final now = DateTime.now();

    // 1. CEK SATPAM: Apakah user pernah pencet sebelumnya?
    if (_lastUposathaRefreshTime != null) {
      final difference = now.difference(_lastUposathaRefreshTime!);

      // LOGIC: Kalau selisihnya kurang dari 5 detik, TOLAK!
      if (difference.inSeconds < 11) {
        // Bersihin antrian snackbar lama
        ScaffoldMessenger.of(context).clearSnackBars();

        // Munculin peringatan
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
        return; // ⛔ STOP DISINI! Jangan lanjut.
      }
    }

    // 2. KALAU LOLOS:
    _lastUposathaRefreshTime = now; // Catat waktu sekarang
    _loadUposathaFromFirebase(); //  Panggil fungsi fetch aslinya (Bypass TTL)
  }

  bool _isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    final isTablet = size.shortestSide >= 600;
    final isLandscape = orientation == Orientation.landscape;

    return isTablet && isLandscape;
  }

  // Timpa method _loadUposathaData yang lama dengan ini:

  Future<void> _loadUposathaData() async {
    // 1. Load dari cache dulu
    final hasCache = await _loadFromCache();

    // 2. KALAU ADA CACHE, CEK UMURNYA (LOGIKA HEMAT KUOTA)
    if (hasCache && mounted) {
      setState(() => _isLoadingUposatha = false);
      _calculateDisplayData();

      // Coba baca kapan terakhir update
      if (_lastFetchTimeStr != null) {
        try {
          // Parse string waktu "yyyy-MM-dd HH:mm:ss" ke DateTime
          // Kita ganti spasi jadi "T" biar formatnya ISO-8601 friendly buat diparse
          final lastFetch = DateTime.tryParse(
            _lastFetchTimeStr!.replaceAll(" ", "T"),
          );

          if (lastFetch != null) {
            final difference = DateTime.now().difference(lastFetch);

            // ATURAN HEMAT: Kalau umur cache kurang dari 7 HARI, STOP!
            // Gak usah connect internet, gak usah fetch firebase.
            if (difference.inDays < 7) {
              debugPrint(
                "✋ Data Uposatha masih segar (${difference.inDays} hari). Skip fetch server.",
              );
              return; // ⛔ STOP DISINI, KUOTA AMAN.
            }
          }
        } catch (e) {
          debugPrint("⚠️ Gagal parse tanggal cache, lanjut fetch aja.");
        }
      }
    }

    // 3. Fetch dari Firebase CUMA KALAU:
    // - Gak punya cache (install baru)
    // - Atau cache udah basi (> 7 hari)
    await _loadUposathaFromFirebase();
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_keyUposathaData);

      // Load waktu terakhir
      final cachedTime = prefs.getString(_keyLastFetchTime);

      if (cachedJson != null) {
        debugPrint('📦 Loading Uposatha from cache...');
        final Map<String, dynamic> decoded = json.decode(cachedJson);

        Map<String, List<dynamic>> tempData = {};
        decoded.forEach((key, value) {
          if (value is List) {
            tempData[key] = value;
          }
        });

        setState(() {
          _uposathaData = tempData;
          _availableVersions = _uposathaData.keys.toList();
          _lastFetchTimeStr = cachedTime;
          if (!_availableVersions.contains(_selectedUposathaVersion) &&
              _availableVersions.isNotEmpty) {
            _selectedUposathaVersion = _availableVersions.first;
          }
        });

        debugPrint(' Uposatha cache loaded');
        return true;
      }

      debugPrint('📭 No Uposatha cache found');
      return false;
    } catch (e) {
      debugPrint('❌ Error loading cache: $e');
      return false;
    }
  }

  Future<void> _saveToCache(Map<String, List<dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Simpan Data JSON
      final jsonString = json.encode(data);
      await prefs.setString(_keyUposathaData, jsonString);

      // 2. Simpan Waktu Sekarang (Format yyyy-MM-dd HH:mm:ss)
      final now = DateTime.now();
      // Bikin format manual biar ga perlu import intl
      final timeString =
          "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} ${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

      await prefs.setString(_keyLastFetchTime, timeString);

      // Update UI langsung
      if (mounted) {
        setState(() {
          _lastFetchTimeStr = timeString;
        });
      }

      debugPrint('💾 Uposatha data & time saved to cache');
    } catch (e) {
      debugPrint('❌ Error saving to cache: $e');
    }
  }

  Future<void> _loadUposathaFromFirebase() async {
    try {
      setState(() => _isLoadingUposatha = true);

      debugPrint('🌐 Fetching Uposatha from Firebase...');

      //  TAMBAH TIMEOUT 10 DETIK
      final snapshot = await _databaseRef
          .child('uposatha')
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException('Firebase timeout');
            },
          );

      if (snapshot.exists && mounted) {
        final data = snapshot.value;
        _processFirebaseData(data);
        await _saveToCache(_uposathaData);

        setState(() {
          _isOnline = true;
          _isLoadingUposatha = false;
        });
        debugPrint(' Firebase Uposatha loaded & cached');
      }
    } catch (e) {
      debugPrint('❌ Firebase error (probably offline): $e');

      if (mounted) {
        //  CUKUP SET STATE, NO SNACKBAR
        setState(() {
          _isOnline = false;
          _isLoadingUposatha = false;
        });
      }
    }
  }

  //  UPDATE: Setup listener dengan error handling
  /* void _setupRealtimeListener() {
    _databaseRef
        .child('uposatha')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists && mounted) {
              final data = event.snapshot.value;
              _processFirebaseData(data);
              _saveToCache(_uposathaData);

              if (!_isOnline) {
                setState(() => _isOnline = true);
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Realtime listener error: $error');
            if (mounted && _isOnline) {
              setState(() => _isOnline = false);
            }
          },
        );
  }
*/
  // 4️⃣ PROSES DATA DARI FIREBASE
  void _processFirebaseData(dynamic data) {
    if (data is! Map) return;

    // 1. Proses data di variabel lokal (JANGAN panggil setState dulu)
    Map<String, List<dynamic>> tempUposathaData = {};
    List<String> tempVersions = [];

    data.forEach((key, value) {
      if (value is List) {
        tempUposathaData[key.toString()] = value;
      }
    });

    tempVersions = tempUposathaData.keys.toList();

    // Cek versi terpilih valid atau nggak
    String currentVersion = _selectedUposathaVersion;
    if (!tempVersions.contains(currentVersion) && tempVersions.isNotEmpty) {
      currentVersion = tempVersions.first;
    }

    // 2. Hitung logika tampilan (Sama, jangan setState dulu)
    // Kita panggil versi modifikasi dari calculateDisplayData yang me-return hasil
    final displayResult = _calculateDisplayDataInternal(
      tempUposathaData[currentVersion],
    );

    // 3. BARU Update UI sekali gus (Cepat & Ringan)
    if (mounted) {
      setState(() {
        _uposathaData = tempUposathaData;
        _availableVersions = tempVersions;
        _selectedUposathaVersion = currentVersion;

        // Update hasil hitungan tampilan
        _nextUposathaLabel = displayResult['label'] as String;
        _displayPhases = displayResult['phases'] as List<Map<String, String>>;

        // Tandai loading selesai
        _isLoadingUposatha = false;
      });
    }
  }

  // Return tipe Map biar bisa bawa 2 data sekaligus (label & phases)
  Map<String, dynamic> _calculateDisplayDataInternal(List<dynamic>? events) {
    if (events == null || events.isEmpty) {
      return {"label": "-", "phases": <Map<String, String>>[]};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int nextIndex = -1;
    for (int i = 0; i < events.length; i++) {
      try {
        final date = DateTime.parse(events[i]['date'].toString());
        if (date.compareTo(today) >= 0) {
          nextIndex = i;
          break;
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    String label = "-";
    List<Map<String, String>> phases = [];

    if (nextIndex != -1) {
      final nextEventDate = DateTime.parse(
        events[nextIndex]['date'].toString(),
      );
      final diff = nextEventDate.difference(today).inDays;

      // Logic label yang baru (H-#)
      if (diff == 0) {
        label = "HARI INI";
      } else if (diff == 1) {
        label = "BESOK";
      } else {
        label = "H-$diff";
      }

      for (int i = 0; i < 4; i++) {
        if (nextIndex + i < events.length) {
          final evt = events[nextIndex + i];
          final d = DateTime.parse(evt['date'].toString());
          final dateStr = "${d.day} ${_getMonthShort(d.month)}";
          phases.add({
            "date": dateStr,
            "phase_name": evt['phase']?.toString() ?? 'biasa',
          });
        }
      }
    }

    return {"label": label, "phases": phases};
  }

  // 5️⃣ HITUNG DATA UNTUK DITAMPILKAN
  void _calculateDisplayData() {
    final events = _uposathaData[_selectedUposathaVersion];

    // Panggil fungsi internal tadi
    final result = _calculateDisplayDataInternal(events);

    // Update UI
    if (mounted) {
      setState(() {
        _nextUposathaLabel = result['label'];
        _displayPhases = result['phases'];
      });
    }
  }

  // 7️⃣ RELOAD PREFERENCE SETELAH KEMBALI DARI KALENDER
  Future<void> _reloadUposathaPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getString(_keyUposathaVersion);

      if (savedVersion != null && savedVersion != _selectedUposathaVersion) {
        debugPrint(
          '🔄 Reloading version from SharedPreferences: $savedVersion',
        );
        setState(() {
          _selectedUposathaVersion = savedVersion;
          _isLoadingUposatha = true;
        });

        _calculateDisplayData();

        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() => _isLoadingUposatha = false);
        }
      }

      // 2. TAMBAHAN: Cek Timestamp biar sinkron sama Kalender
      final savedTime = prefs.getString(_keyLastFetchTime);
      if (savedTime != null && savedTime != _lastFetchTimeStr) {
        setState(() => _lastFetchTimeStr = savedTime);
      }
    } catch (e) {
      debugPrint('❌ Error reloading preference: $e');
    }
  }

  // 6️⃣ UPDATE VERSI YANG DIPILIH
  Future<void> _updateVersion(String newVersion) async {
    setState(() {
      _selectedUposathaVersion = newVersion;
      _isLoadingUposatha = true;
    });

    _calculateDisplayData();

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoadingUposatha = false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUposathaVersion, newVersion);
  }

  String _getMonthShort(int month) {
    const m = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];
    return m[month - 1];
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

  Future<void> _launchCustomTab(BuildContext context, String url) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: const CustomTabsOptions(
          showTitle: true,
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: true,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: isDarkMode ? Colors.grey[900] : Colors.orange,
          preferredControlTintColor: Colors.white,
          barCollapsingEnabled: true,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error membuka $url: $e")));
      }
    }
  }

  void _openHtmlBook(BuildContext context, String title, List<String>? files) {
    if (files != null && files.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlReaderPage(
            title: title,
            chapterFiles: files,
            initialIndex: 0,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Konten '$title' belum tersedia.")),
      );
    }
  }

  void _scheduleScroll(String section) {
    _attemptScroll(section, 0);
  }

  void _attemptScroll(String section, int attempt) {
    if (!mounted) return;

    GlobalKey? targetKey;
    switch (section) {
      case 'derma':
        targetKey = _dermaKey;
        break;
      case 'uposatha':
        targetKey = _uposathaKey;
        break;
      case 'meditasi':
        targetKey = _meditasiKey;
        break;
      case 'paritta':
        targetKey = _parittaKey;
        break;
    }

    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );

      setState(() => _highlightedSection = section);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedSection = null);
      });
    } else {
      if (attempt < 10) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _attemptScroll(section, attempt + 1);
        });
      }
    }
  }

  Widget _buildHighlightWrapper({
    required String sectionKey,
    required GlobalKey globalKey,
    required Widget child,
  }) {
    final isHighlighted = _highlightedSection == sectionKey;
    return AnimatedContainer(
      key: globalKey,
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  //  FUNGSI SATPAM - Cegah spam refresh
  void _handleDermaRefresh() {
    final now = DateTime.now();

    // Cek: Apakah user pernah pencet sebelumnya?
    if (_lastDermaClickTime != null) {
      final difference = now.difference(_lastDermaClickTime!);

      // LOGIC: Kalau selisihnya kurang dari 11 detik, tolak!
      if (difference.inSeconds < 11) {
        // 1. Hapus antrian snackbar lama biar gak numpuk
        ScaffoldMessenger.of(context).clearSnackBars();

        // 2. Munculin peringatan
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Tunggu sebentar sebelum refresh lagi",
              style: TextStyle(
                color: Theme.of(context).colorScheme.surface,
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
        return; // ⛔ BERHENTI DI SINI, jangan load data
      }
    }

    // Kalau lolos (udah lebih dari 11 detik atau baru pertama kali):
    _lastDermaClickTime = now;
    _loadCampaigns(forceRefresh: true); //  PAKSA REFRESH SERVER
  }

  Future<void> _loadCampaigns({
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    setState(() {
      _isLoadingCampaigns = true;
      _isCampaignError = false;
    });

    try {
      //  FETCH SEMUA KATEGORI SEKALIGUS
      final result = await _danaService
          .fetchAllCampaigns(forceRefresh: forceRefresh)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Timeout saat fetch campaigns');
            },
          );

      //  DEBUG: Print semua kategori yang ada
      debugPrint('📋 Categories from API:');
      result.dataByCategory.forEach((key, value) {
        debugPrint('   - "$key" (${value.length} campaigns)');
      });

      //  FILTER berdasarkan kategori yang dipilih
      List<Campaign> displayCampaigns = [];

      if (categoryId != null) {
        // 1. Cari nama kategori expected dari map
        final entry = DanaEverydayService.categories.entries.firstWhere(
          (e) => e.value == categoryId,
          orElse: () => const MapEntry('', ''),
        );

        if (entry.key.isEmpty) {
          throw Exception('Category ID $categoryId not found in map');
        }

        final expectedName = entry.key;
        debugPrint('🔍 Looking for category: "$expectedName"');

        // 2. Coba exact match dulu
        if (result.dataByCategory.containsKey(expectedName)) {
          displayCampaigns = result.dataByCategory[expectedName]!;
          debugPrint(
            ' Exact match found: ${displayCampaigns.length} campaigns',
          );
        }
        // 3. Kalau ga ada, coba case-insensitive match
        else {
          final lowerExpected = expectedName.toLowerCase();
          bool found = false;

          for (final mapEntry in result.dataByCategory.entries) {
            if (mapEntry.key.toLowerCase() == lowerExpected) {
              displayCampaigns = mapEntry.value;
              debugPrint(
                ' Case-insensitive match: "${mapEntry.key}" (${displayCampaigns.length})',
              );
              found = true;
              break;
            }
          }

          // 4. Kalau masih ga ketemu, log error tapi jangan crash
          if (!found) {
            debugPrint('⚠️ No match for "$expectedName"');
            debugPrint(
              '⚠️ Available: ${result.dataByCategory.keys.join(", ")}',
            );
          }
        }

        // Ambil max 8 per kategori
        displayCampaigns = displayCampaigns.take(8).toList();
      } else {
        // "Semua" → Ambil top 12, sort by HARI TERSISA (terdekat dulu)
        displayCampaigns = result.allCampaigns;

        //  SORT BY DAYS REMAINING (paling sedikit dulu)
        displayCampaigns.sort((a, b) {
          // Campaign yang udah lewat deadline (daysRemaining = 0) → taruh belakang
          if (a.daysRemaining == 0 && b.daysRemaining > 0) return 1;
          if (b.daysRemaining == 0 && a.daysRemaining > 0) return -1;

          // Sort ascending (paling sedikit hari dulu)
          return a.daysRemaining.compareTo(b.daysRemaining);
        });

        displayCampaigns = displayCampaigns.take(12).toList();
        debugPrint(
          ' "Semua" selected: ${displayCampaigns.length} campaigns (sorted by deadline)',
        );
      }

      //  VALIDASI
      if (displayCampaigns.isEmpty) {
        debugPrint('⚠️ No campaigns to display');
      }

      // Validasi data quality
      final validCampaigns = displayCampaigns
          .where((c) => c.name.isNotEmpty && c.categoryName.isNotEmpty)
          .toList();

      if (validCampaigns.length != displayCampaigns.length) {
        debugPrint(
          '⚠️ Filtered ${displayCampaigns.length - validCampaigns.length} invalid campaigns',
        );
      }

      //  UPDATE TIMESTAMP CUMA KALAU FETCH SERVER
      if (mounted && result.wasFetchedFromServer) {
        final now = DateTime.now();
        final timeToDisplay =
            "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} "
            "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

        await _danaService.saveLastUpdateTime(timeToDisplay);

        setState(() {
          _lastCampaignFetchTimeStr = timeToDisplay;
        });

        debugPrint(' Fetched from SERVER! Updated timestamp: $timeToDisplay');
      } else {
        debugPrint('📦 From CACHE. Timestamp NOT updated.');
      }

      //  UPDATE UI
      if (mounted) {
        setState(() {
          _campaigns = validCampaigns;
          _isLoadingCampaigns = false;
          _isCampaignError = false;
          _showViewAllButton = false;
        });
      }
    } on TimeoutException catch (e) {
      debugPrint("⏱️ Timeout: $e");
      if (mounted) {
        setState(() {
          _isLoadingCampaigns = false;
          _isCampaignError = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error fetch campaigns: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _isLoadingCampaigns = false;
          _isCampaignError = true;
        });
      }
    }
  }

  // Helper untuk format angka jadi 2 digit
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Uposatha version
    final savedUposathaVersion = prefs.getString(_keyUposathaVersion);
    if (savedUposathaVersion != null) {
      setState(() => _selectedUposathaVersion = savedUposathaVersion);
    }

    // Load Paritta tradition
    final savedParittaTradition = prefs.getString(_keyParitta);
    if (savedParittaTradition != null) {
      setState(() => _selectedParittaTradition = savedParittaTradition);
    }

    //  TAMBAH INI: Load waktu update Campaign
    final savedCampaignTime = prefs.getString('last_campaign_update_time');
    if (savedCampaignTime != null) {
      setState(() => _lastCampaignFetchTimeStr = savedCampaignTime);
    }
  }

  Future<void> _savePreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    // final isTabletLandscape = _isTabletLandscape(context);

    // Kita ubah jadi isLandscape aja, tanpa cek ukuran tablet
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          // 📱 TABLET LANDSCAPE: Derma + Uposatha side-by-side
          if (isLandscape)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDermaCard()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildUposathaCard()),
                  ],
                ),
              ),
            )
          else ...[
            // 📱 MOBILE: Stack biasa
            SliverToBoxAdapter(child: _buildDermaCard()),
            SliverToBoxAdapter(child: _buildUposathaCard()),
          ],
          SliverToBoxAdapter(child: _buildMeditationCard()),
          SliverToBoxAdapter(child: _buildParittaCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    // 1️⃣ Deteksi Landscape
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // 2️⃣ Tentukan tinggi: 60 kalau miring, 80 kalau berdiri
    final double toolbarHeight = isLandscape ? 60.0 : 80.0;

    final transparentColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.85);
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false, // 3️⃣ Pasang tinggi dinamis
      toolbarHeight: toolbarHeight,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(color: transparentColor),
        ),
      ),
      // 4️⃣ Geser teks ke atas (-8) saat landscape
      title:
          //Transform.translate(
          //  offset: Offset(0, isLandscape ? -8 : 0),
          //child:
          HeaderDepan(
            title: "Paṭipatti",
            subtitle: "Praktik Dhamma",
            //),
          ),
      centerTitle: true,
      titleSpacing: 0,
    );
  }

  Widget _buildHeaderStrip(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.withValues(alpha: 0.08);
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 1. DERMA CARD (Dāna)
  // ═══════════════════════════════════════════════════════════

  Widget _buildDermaCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFF009688);
    final lightBg = isDark ? const Color(0xFF1A3F3A) : const Color(0xFFE0F2F1);
    final borderColor = isDark
        ? const Color(0xFF2D6A64)
        : const Color(0xFFB2DFDB);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final cardMargin = isLandscape ? 8.0 : 16.0;

    return _buildHighlightWrapper(
      sectionKey: 'derma',
      globalKey: _dermaKey,
      child: Container(
        margin: EdgeInsets.fromLTRB(cardMargin, 4, cardMargin, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // -----------------------------------------------------
              // HEADER STRIP (Updated: Ada tombol refresh di kanan)
              // -----------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // BAGIAN KIRI (Label "DĀNA")
                    Text(
                      "DĀNA",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: subtextColor,
                        letterSpacing: 1.2,
                      ),
                    ),

                    // BAGIAN KANAN (Timestamp + Refresh)
                    Row(
                      children: [
                        if (_lastCampaignFetchTimeStr != null) ...[
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 10.5,
                                color: subtextColor.withValues(alpha: 0.6),
                              ),
                              children: [
                                const TextSpan(text: "Terakhir update: "),
                                TextSpan(
                                  text: _lastCampaignFetchTimeStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        //  TOMBOL REFRESH DI SINI
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: _isLoadingCampaigns
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accentColor,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: accentColor,
                                  ),
                            onPressed: _isLoadingCampaigns
                                ? null
                                : _handleDermaRefresh,
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
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
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dana",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Yayasan Dana Everyday",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ❌ BUTTON LAMA DI SINI SUDAH DIHAPUS
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryChip(
                            label: 'Semua',
                            isSelected: _selectedCategory == 'Semua',
                            accentColor: accentColor,
                            lightBg: lightBg,
                            onTap: () => _onCategorySelected('Semua'),
                          ),
                          ...DanaEverydayService.categories.entries.map((
                            entry,
                          ) {
                            return _buildCategoryChip(
                              label: entry.key,
                              isSelected: _selectedCategory == entry.key,
                              accentColor: accentColor,
                              lightBg: lightBg,
                              onTap: () => _onCategorySelected(
                                entry.key,
                                categoryId: entry.value,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _isLoadingCampaigns
                        ? _buildLoadingShimmer(lightBg, borderColor)
                        : _campaigns.isEmpty
                        ? _buildEmptyState(
                            subtextColor,
                            isError: _isCampaignError,
                          )
                        : SizedBox(
                            height: 185,
                            child: Stack(
                              children: [
                                NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification
                                        is ScrollUpdateNotification) {
                                      final scrollController =
                                          notification.metrics;
                                      final isAtEnd =
                                          scrollController.pixels >=
                                          scrollController.maxScrollExtent - 50;
                                      if (isAtEnd != _showViewAllButton) {
                                        setState(
                                          () => _showViewAllButton = isAtEnd,
                                        );
                                      }
                                    }
                                    return false;
                                  },
                                  child: ListView.separated(
                                    controller: _campaignScrollController,

                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.only(right: 95),
                                    itemCount: _campaigns.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final campaign = _campaigns[index];
                                      return _buildCampaignCard(
                                        campaign: campaign,
                                        accentColor: accentColor,
                                        lightBg: lightBg,
                                        borderColor: borderColor,
                                        textColor: textColor,
                                        subtextColor: subtextColor,
                                      );
                                    },
                                  ),
                                ),
                                if (_showViewAllButton)
                                  Positioned(
                                    right: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Material(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(30),
                                        elevation: 4,
                                        child: InkWell(
                                          onTap: () => _launchCustomTab(
                                            context,
                                            'https://www.danaeveryday.id/campaign_category',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.open_in_new_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Lebih\nBanyak',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: _buildMenuButton(
                        label: "Lihat Semua Campaign",
                        icon: Icons.open_in_new_rounded,
                        color: accentColor,
                        lightBg: lightBg,
                        borderColor: borderColor,
                        isHorizontal: true,
                        isCentered: true,
                        onTap: () => _launchCustomTab(
                          context,
                          'https://www.danaeveryday.id/campaign_category',
                        ),
                      ),
                    ),
                    SizedBox(width: double.infinity),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fungsi pembantu untuk menangani logika ganti kategori
  void _onCategorySelected(String categoryName, {String? categoryId}) {
    // 1. Reset Scroll ke Kiri (Fix UX)
    if (_campaignScrollController.hasClients) {
      _campaignScrollController.jumpTo(0);
    }

    // 2. Update State UI
    setState(() {
      _selectedCategory = categoryName;
      _showViewAllButton = false; // Reset tombol view all
    });

    // 3. Load Data Baru
    _loadCampaigns(categoryId: categoryId);
  }

  Widget _buildCampaignCard({
    required Campaign campaign,
    required Color accentColor,
    required Color lightBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: lightBg.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _launchCustomTab(context, campaign.fullUrl),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: campaign.imageUrl.isNotEmpty
                        ? Image.network(
                            campaign.imageUrl,
                            height: 80,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // 👇 GANTI BAGIAN INI
                            errorBuilder: (_, _, _) =>
                                _buildOfflineImagePlaceholder(
                                  accentColor,
                                  80,
                                  isImageError: true,
                                ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildImagePlaceholder(accentColor, 80);
                            },
                          )
                        // 👇 DAN BAGIAN INI (jika URL kosong dari awal)
                        : _buildOfflineImagePlaceholder(
                            accentColor,
                            80,
                            isImageError: false,
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        campaign.categoryName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                campaign.formattedCollected,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              Text(
                                '${campaign.percent}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: campaign.percent / 100,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accentColor,
                              ),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Target: ${campaign.formattedTarget}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: subtextColor,
                                ),
                              ),
                              if (campaign.daysRemaining > 0)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 10,
                                      color: subtextColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${campaign.daysRemaining} hari',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(Color color, double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      child: Icon(
        Icons.image_outlined,
        size: 35,
        color: color.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildOfflineImagePlaceholder(
    Color color,
    double height, {
    bool isImageError = true,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isImageError
                ? Icons.cloud_off_rounded
                : Icons.image_not_supported_rounded,
            size: 20,
            color: color.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            isImageError ? "Mode Offline" : "Tidak ada gambar",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(Color lightBg, Color borderColor) {
    return SizedBox(
      height: 185,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 280,
          decoration: BoxDecoration(
            color: lightBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFF009688),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subtextColor, {bool isError = false}) {
    return Container(
      height: 185,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError
                ? Icons.wifi_off_rounded
                : Icons.campaign_rounded, // Icon beda
            size: 40,
            color: subtextColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            isError
                ? 'Gagal memuat data.\nCek koneksi internet.'
                : 'Belum ada campaign tersedia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: subtextColor),
          ),
          if (isError) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _loadCampaigns,
              child: Text(
                "Coba Lagi",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 🌙 2. UPOSATHA CARD (Sīla) - DENGAN CACHING & OFFLINE MODE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildUposathaCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFF57F17);
    final lightBg = isDark ? const Color(0xFF4A4417) : const Color(0xFFFFF8E1);
    final borderColor = isDark
        ? const Color(0xFF6D621F)
        : const Color(0xFFFFE082);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final phaseBoxHeight = isLandscape ? 169.0 : 85.0;

    return _buildHighlightWrapper(
      sectionKey: 'uposatha',
      globalKey: _uposathaKey,
      child: Container(
        margin: isLandscape
            ? const EdgeInsets.fromLTRB(0, 4, 8, 8)
            : const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // -----------------------------------------------------
              // HEADER STRIP (Updated: Ada tombol refresh di kanan)
              // -----------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // TULISAN "SĪLA" (Kiri)
                    Text(
                      "SĪLA",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: subtextColor,
                        letterSpacing: 1.2,
                      ),
                    ),

                    // KANAN (Timestamp + Refresh)
                    Row(
                      children: [
                        if (_lastFetchTimeStr != null) ...[
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 10.5,
                                color: subtextColor.withValues(alpha: 0.6),
                              ),
                              children: [
                                const TextSpan(text: "Terakhir update: "),
                                TextSpan(
                                  text: _lastFetchTimeStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        //  TOMBOL REFRESH DI SINI
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: _isLoadingUposatha
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accentColor,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: accentColor,
                                  ),
                            onPressed: _isLoadingUposatha
                                ? null
                                : _handleUposathaRefresh,
                            tooltip: 'Cek Update',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
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
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.nightlight_round,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Uposatha",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Jadwal Puasa",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ❌ BUTTON LAMA DIHAPUS (Icon Refresh dihapus)
                        // Label Next Event tetap di sini
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isLoadingUposatha ? 0.5 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              _nextUposathaLabel,
                              style: const TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // DROPDOWN VERSI
                    Container(
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
                          const Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Tradisi",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    _availableVersions.contains(
                                      _selectedUposathaVersion,
                                    )
                                    ? _selectedUposathaVersion
                                    : null,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: accentColor,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                hint: Text(
                                  "Memuat...",
                                  style: TextStyle(color: textColor),
                                ),
                                items: _availableVersions.map((version) {
                                  return DropdownMenuItem(
                                    value: version,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        version,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    _updateVersion(value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // PREVIEW 4 UPOSATHA TERDEKAT
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      height: phaseBoxHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: _isLoadingUposatha
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accentColor,
                                ),
                              ),
                            )
                          : _displayPhases.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isOnline
                                        ? Icons.info_outline
                                        : Icons.cloud_off,
                                    size: 28,
                                    color: subtextColor.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isOnline
                                        ? 'Belum ada data'
                                        : 'Offline - Belum ada data tersimpan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: _displayPhases.map((phaseData) {
                                String icon = _getMoonIcon(
                                  phaseData["phase_name"]!,
                                );
                                String date = phaseData["date"]!;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      icon,
                                      style: TextStyle(
                                        fontSize: isLandscape ? 32 : 22,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: isLandscape ? 11 : 10,
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // TOMBOL KALENDER & PANDUAN
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            label: "Kalender",
                            icon: Icons.calendar_today,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: true,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UposathaKalenderPage(
                                    initialVersion: _selectedUposathaVersion,
                                    initialData: _uposathaData,
                                  ),
                                ),
                              );
                              // RELOAD PREFERENCE SETELAH KEMBALI
                              await _reloadUposathaPreference();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Panduan",
                            icon: Icons.article_outlined,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HtmlReaderPage(
                                    title: 'Panduan Uposatha',
                                    chapterFiles: DaftarIsi.upo,
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  // ═══════════════════════════════════════════════════════════
  // 🧘 3. MEDITASI CARD (Samādhi)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMeditationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFD32F2F);
    final lightBg = isDark ? const Color(0xFF4A1F1F) : const Color(0xFFFFEBEE);
    final borderColor = isDark
        ? const Color(0xFF6D2C2C)
        : const Color(0xFFFFCDD2);

    return _buildHighlightWrapper(
      sectionKey: 'meditasi',
      globalKey: _meditasiKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeaderStrip("Bhāvanā"),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.self_improvement_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Meditasi",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Pengembangan Batin",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            label: "Timer",
                            icon: Icons.timer_outlined,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: false,
                            isCentered: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MeditationTimerPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        /*  const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Audio",
                            icon: Icons.headphones_rounded,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: false,
                            isCentered: false,
                            onTap: () {},
                          ),
                        ),
                        */
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuButton(
                            label: "Video/Audio",
                            icon: Icons.play_circle_outline,
                            color: accentColor,
                            lightBg: lightBg,
                            borderColor: borderColor,
                            isHorizontal: false,
                            isCentered: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VideoPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  // ═══════════════════════════════════════════════════════════
  // 📖 4. PARITTA CARD (Paññā)
  // ═══════════════════════════════════════════════════════════
  Widget _buildParittaCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    const accentColor = Color(0xFFF57C00);
    final lightBg = isDark ? const Color(0xFF4A3517) : const Color(0xFFFFF3E0);
    final borderColor = isDark
        ? const Color(0xFF6D4C1F)
        : const Color(0xFFFFE0B2);

    final List<Map<String, dynamic>> currentList =
        _parittaData[_selectedParittaTradition] ?? [];

    return _buildHighlightWrapper(
      sectionKey: 'paritta',
      globalKey: _parittaKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Card(
          color: cardColor,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeaderStrip("Bhāvanā"),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.book_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Paritta",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                "Syair Perlindungan",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
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
                          const Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Tradisi",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedParittaTradition,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: accentColor,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: _parittaData.keys.map((String key) {
                                  return DropdownMenuItem(
                                    value: key,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        key,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) async {
                                  if (value != null &&
                                      value != _selectedParittaTradition) {
                                    setState(() => _isLoadingParitta = true);
                                    await Future.delayed(
                                      const Duration(milliseconds: 500),
                                    );
                                    setState(() {
                                      _selectedParittaTradition = value;
                                      _isLoadingParitta = false;
                                    });
                                    _savePreference(_keyParitta, value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    const SizedBox(height: 12),
                    _isLoadingParitta
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: accentColor,
                              ),
                            ),
                          )
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _isLoadingParitta ? 0.0 : 1.0,
                            child: _buildParittaItemsList(
                              currentList,
                              accentColor,
                              lightBg,
                              borderColor,
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

  Widget _buildParittaItemsList(
    List<Map<String, dynamic>> items,
    Color accentColor,
    Color lightBg,
    Color borderColor,
  ) {
    final isTabletLandscape = _isTabletLandscape(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      // 📱 MODE GRID - Tetap urutan asli
      return MasonryGridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: (isTabletLandscape ? 3 : 2),
        ),
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index]; //  Pakai items langsung
          return _buildParittaItem(item, accentColor, lightBg, borderColor);
        },
      );
    }

    // 📱 MODE LIST (Portrait/Mobile - Original)
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildParittaItem(item, accentColor, lightBg, borderColor),
        );
      }).toList(),
    );
  }

  Widget _buildParittaItem(
    Map<String, dynamic> item,
    Color accentColor,
    Color lightBg,
    Color borderColor,
  ) {
    if (item['type'] == 'group') {
      return _buildExpansionGroup(
        title: item['label'],
        sectionIcon: item['icon'],
        items: item['items'],
        accentColor: accentColor,
        lightBg: lightBg,
      );
    } else {
      return _buildMenuButton(
        label: item['label'],
        icon: item['icon'],
        color: accentColor,
        lightBg: lightBg,
        borderColor: borderColor,
        isHorizontal: true,
        onTap: () {
          _openHtmlBook(context, item['label'], item['files']);
        },
      );
    }
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required Color accentColor,
    required Color lightBg,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? accentColor : lightBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white24 : Colors.black12),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionGroup({
    required String title,
    required IconData sectionIcon,
    required List<Map<String, dynamic>> items,
    required Color accentColor,
    required Color lightBg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF6D4C1F)
        : const Color(0xFFFFE0B2);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final iconBoxColor = isDark
        ? Colors.black26
        : Colors.white.withValues(alpha: 0.6);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    final isTabletLandscape = _isTabletLandscape(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // 📱 TABLET LANDSCAPE: Buka bottom sheet dengan grid
    if (isTabletLandscape || isLandscape) {
      return Material(
        color: lightBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (modalContext) => FractionallySizedBox(
                heightFactor: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.close, color: textColor),
                              onPressed: () => Navigator.pop(modalContext),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconBoxColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                sectionIcon,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                      // Grid 2 Kolom
                      Expanded(
                        child: MasonryGridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 10,
                          itemCount: items.length,
                          itemBuilder: (_, index) {
                            final item = items[index];
                            return _buildMenuButton(
                              label: item['label'],
                              icon: item['icon'],
                              color: accentColor,
                              lightBg: lightBg,
                              borderColor: borderColor,
                              isHorizontal: true,
                              onTap: () {
                                Navigator.pop(
                                  modalContext,
                                ); // Tutup bottom sheet
                                _openHtmlBook(
                                  context,
                                  item['label'],
                                  item['files'],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          splashColor: accentColor.withValues(alpha: 0.15),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBoxColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(sectionIcon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 📱 MOBILE: ExpansionTile biasa (kode lama)
    final expandedContentBg = isDark
        ? lightBg.withValues(alpha: 0.5)
        : lightBg.withValues(alpha: 0.3);

    return Material(
      //  Langsung Material
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: expandedContentBg,
          collapsedBackgroundColor: lightBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBoxColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(sectionIcon, color: accentColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildMenuButton(
                label: item['label'],
                icon: item['icon'],
                color: accentColor,
                lightBg: lightBg,
                borderColor: borderColor,
                isHorizontal: true,
                onTap: () {
                  _openHtmlBook(context, item['label'], item['files']);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color lightBg,
    required Color borderColor,
    required VoidCallback onTap,
    bool isHorizontal = false,
    bool isCentered = true,
    bool isSlider = false,
    double? width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final iconBoxColor = isDark
        ? Colors.black26
        : Colors.white.withValues(alpha: 0.6);

    return Material(
      color: lightBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          width: width,
          height: isHorizontal ? 54 : 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: isHorizontal
              ? Row(
                  mainAxisAlignment: isCentered
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBoxColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    isSlider
                        ? Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          )
                        : Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBoxColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
