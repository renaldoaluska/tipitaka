import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/utils/system_ui_helper.dart';

// ==================== COLORS & THEME ====================
const Color kPrimaryColor = Color(0xFFD32F2F); // Merah Hati

bool _isDarkMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// ==================== MODELS ====================

class ProcessedData {
  final List<String> categories;
  final Set<String> authors;
  final Map<dynamic, dynamic> rawData;

  ProcessedData(this.categories, this.authors, this.rawData);
}

// ==================== MAIN PAGE ====================

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('video');
  late Future<ProcessedData> _dataFuture;

  // Filter State
  String _selectedCategory = 'Semua';
  String _selectedAuthor = 'Semua';

  List<Map<String, dynamic>> _historyVideos = [];
  bool _isOffline = false;

  // Scroll State untuk AppBar Effect
  bool _isScrolled = false;

  // Keys buat Simpan Cache
  static const String _keyVideoData = 'cached_video_data';
  static const String _keyLastFetch = 'video_last_fetch_time';
  // 👇 TAMBAH VARIABEL INI BUAT SATPAM
  DateTime? _lastRefreshTime;
  // late YoutubePlayerController _controller;
  // bool _hasSeeked = false;

  @override
  void initState() {
    super.initState();
    // _dataFuture = _fetchAndProcessData();
    // Ganti jadi _loadData (Smart Load)
    _dataFuture = _loadData();
    _loadHistory();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      if (mounted) {
        setState(() => _isOffline = result == ConnectivityResult.none);
      }
    });
  }

  Future<void> _refreshData() async {
    final now = DateTime.now();

    // 1. SATPAM SPAM (5 Detik)
    if (_lastRefreshTime != null) {
      final difference = now.difference(_lastRefreshTime!);
      if (difference.inSeconds < 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
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
              backgroundColor: kPrimaryColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return; // ⛔ STOP
      }
    }

    _lastRefreshTime = now;

    // 2. PAKSA UPDATE (Bypass cache 7 hari)
    setState(() {
      _dataFuture = _loadData(forceRefresh: true); // 👈 Pake forceRefresh: true
    });
  }

  // ✅ METHOD UTAMA: CEK CACHE DULU
  Future<ProcessedData> _loadData({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. JIKA TIDAK DIPAKSA REFRESH, CEK CACHE DULU
    if (!forceRefresh) {
      final cachedJson = prefs.getString(_keyVideoData);
      final lastFetchStr = prefs.getString(_keyLastFetch);

      if (cachedJson != null && lastFetchStr != null) {
        final lastFetch = DateTime.tryParse(lastFetchStr);

        if (lastFetch != null) {
          final difference = DateTime.now().difference(lastFetch);

          // 🛑 SATPAM HEMAT: Kalau belum 7 hari, pakai Cache aja!
          if (difference.inDays < 7) {
            debugPrint(
              "✋ Data Video masih segar (${difference.inDays} hari). Pakai Cache.",
            );
            try {
              final decodedMap =
                  json.decode(cachedJson) as Map<String, dynamic>;
              return _processRawData(decodedMap);
            } catch (e) {
              debugPrint("⚠️ Gagal parse cache, lanjut fetch server.");
            }
          }
        }
      }
    }

    // 2. KALAU CACHE BASI / KOSONG / DIPAKSA -> FETCH FIREBASE
    return _fetchFromFirebase(prefs);
  }

  // ✅ FETCH DARI SERVER & SIMPAN KE CACHE
  Future<ProcessedData> _fetchFromFirebase(SharedPreferences prefs) async {
    debugPrint("🌐 Fetching Video from Firebase...");

    final snapshot = await _dbRef.get();
    if (!snapshot.exists) {
      return ProcessedData([], {}, {});
    }

    // Ambil value
    final rawData = snapshot.value;

    // Simpan ke Cache (Encode ke JSON String)
    if (rawData != null) {
      try {
        await prefs.setString(_keyVideoData, json.encode(rawData));
        await prefs.setString(_keyLastFetch, DateTime.now().toIso8601String());
        debugPrint("💾 Video data saved to cache.");
      } catch (e) {
        debugPrint("❌ Gagal simpan cache: $e");
      }
    }

    // Proses datanya biar siap tampil
    // Kita perlu casting karena snapshot.value itu Object? (biasanya Map<dynamic, dynamic>)
    // json.encode biasanya butuh Map<String, dynamic> atau List, jadi amanin dulu.
    final Map<dynamic, dynamic> mapData =
        (rawData as Map<dynamic, dynamic>?) ?? {};

    return _processRawData(mapData);
  }

  // Helper pisahan buat ngolah Map jadi ProcessedData (biar codingan rapi)
  ProcessedData _processRawData(Map<dynamic, dynamic> rawData) {
    final keys = rawData.keys.map((e) => e.toString()).toList()..sort();

    Set<String> authors = {};
    for (var category in rawData.values) {
      if (category is List) {
        for (var video in category) {
          if (video is Map && video['author'] != null) {
            authors.add(video['author'].toString());
          }
        }
      }
    }

    return ProcessedData(keys, authors, rawData);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('video_history') ?? [];
    if (!mounted) return;
    setState(() {
      _historyVideos = historyJson
          .map((json) {
            final parts = json.split('|');
            if (parts.length < 4) return <String, dynamic>{};
            return {
              'id': parts[0],
              'title': parts[1],
              'author': parts[2],
              'timestamp': double.tryParse(parts[3]) ?? 0.0,
            };
          })
          .where((element) => element.isNotEmpty)
          .toList();
    });
  }

  // ✅ UPDATED: Logika Hapus jika selesai
  Future<void> _saveHistory(
    String id,
    String title,
    String author,
    double position,
    double duration,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyJson = prefs.getStringList('video_history') ?? [];

    // Hapus entry lama dengan ID yang sama
    historyJson.removeWhere((entry) => entry.startsWith('$id|'));

    // Cek apakah video dianggap selesai (misal > 95% durasi)
    bool isFinished = false;
    if (duration > 0) {
      if (position >= (duration * 0.95)) {
        isFinished = true;
      }
    }

    // Jika belum selesai, simpan ke history paling atas
    if (!isFinished) {
      final safeTitle = title.replaceAll('|', '-');
      final safeAuthor = author.replaceAll('|', '-');
      final newEntry = '$id|$safeTitle|$safeAuthor|$position';

      historyJson.insert(0, newEntry);

      if (historyJson.length > 5) {
        historyJson = historyJson.sublist(0, 5);
      }
    }

    await prefs.setStringList('video_history', historyJson);
    _loadHistory();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    if (!mounted) return;
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

  // ==================== UI WIDGETS ====================

  // ✅ UPDATED: AppBar Style Tematik Page
  Widget _buildTematikStyleHeader() {
    final isDark = _isDarkMode(context);

    final bgColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Icon back circle background
    final iconBgColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final shadowColor = isDark
        ? Colors.black26
        : Colors.black.withValues(alpha: 0.1);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
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
                color: bgColor.withValues(alpha: _isScrolled ? 0.85 : 1.0),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: textColor,
                          //size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Video Meditasi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }

  /* Widget _buildCategoryList(List<String> categories) {
    final isDark = _isDarkMode(context);
    final list = ['Semua', ...categories];

    final unselectedBg = isDark ? Colors.grey[800] : Colors.white;
    final unselectedText = isDark ? Colors.grey[300] : const Color(0xFF757575);
    final borderUnselected = isDark ? Colors.transparent : Colors.grey.shade300;

    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = list[index];
          final isSelected = _selectedCategory == cat;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FilterChip(
              label: Text(_capitalize(cat)),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() => _selectedCategory = cat);
              },
              backgroundColor: unselectedBg,
              selectedColor: kPrimaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : unselectedText,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? kPrimaryColor : borderUnselected,
                  width: 1,
                ),
              ),
              showCheckmark: false,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }
*/

  Widget _buildAuthorList(Set<String> authors) {
    final isDark = _isDarkMode(context);
    final list = ['Semua', ...authors.toList()..sort()];

    final unselectedBg = isDark ? Colors.grey[800] : Colors.grey[100];
    final unselectedText = isDark ? Colors.grey[400] : const Color(0xFF757575);
    final selectedBg = isDark
        ? kPrimaryColor.withValues(alpha: 0.3)
        : const Color(0xFFFFEBEE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Text(
            'Penceramah',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final author = list[index];
              final isSelected = _selectedAuthor == author;
              return FilterChip(
                label: Text(author),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() => _selectedAuthor = author);
                },
                backgroundColor: unselectedBg,
                selectedColor: selectedBg,
                labelStyle: TextStyle(
                  color: isSelected ? kPrimaryColor : unselectedText,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? kPrimaryColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalVideoCard(
    Map<String, dynamic> video, {
    double initialPosition = 0.0,
  }) {
    final isDark = _isDarkMode(context);
    final videoId = video['id'] as String? ?? '';
    final title = video['title'] ?? 'Tanpa Judul';
    final author = video['author'] ?? 'Unknown';

    final cardBg = isDark ? const Color(0xFF303030) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF212121);
    final subtitleColor = isDark ? Colors.grey[400] : const Color(0xFF757575);
    final shadowColor = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, bottom: 12, top: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  videoId: videoId,
                  videoTitle: title,
                  initialPosition: initialPosition,
                  onPositionChanged: (pos, dur) {
                    _saveHistory(videoId, title, author, pos, dur);
                  },
                ),
              ),
            ).then((_) => _loadHistory());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.3,
                          color: titleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.mic_none_rounded,
                            size: 14,
                            color: kPrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              author,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

  Widget _buildHistorySection() {
    if (_historyVideos.isEmpty) return const SizedBox.shrink();
    //  final isDark = _isDarkMode(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: kPrimaryColor),
              const SizedBox(width: 8),
              Text(
                'Lanjutkan Menonton',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _historyVideos.length,
            itemBuilder: (context, index) {
              return _buildHorizontalVideoCard(
                _historyVideos[index],
                initialPosition: _historyVideos[index]['timestamp'],
              );
            },
          ),
        ),
      ],
    );
  }

  List<dynamic> _getFilteredVideosForCategory(
    String categoryKey,
    List<dynamic> allVideos,
  ) {
    if (_selectedCategory != 'Semua' &&
        _selectedCategory.toLowerCase() != categoryKey.toLowerCase()) {
      return [];
    }

    if (_selectedAuthor == 'Semua') {
      return allVideos;
    } else {
      return allVideos
          .where(
            (v) => (v is Map && v['author']?.toString() == _selectedAuthor),
          )
          .toList();
    }
  }

  Widget _buildEmptyState() {
    final isDark = _isDarkMode(context);
    final textColor = isDark ? Colors.white : const Color(0xFF212121);
    final subColor = isDark ? Colors.grey[400] : const Color(0xFF757575);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.youtube_searched_for, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "Video Tidak Ditemukan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tidak ada video untuk filter:\nKategori: $_selectedCategory\nPenceramah: $_selectedAuthor",
              textAlign: TextAlign.center,
              style: TextStyle(color: subColor, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategory = 'Semua';
                  _selectedAuthor = 'Semua';
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Reset Filter"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 35;
    //  final isDark = _isDarkMode(context);
    //final sectionTitleColor = isDark ? Colors.white : const Color(0xFF212121);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 🔥 WRAP
      value: SystemUIHelper.getStyle(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              if (_isOffline)
                _buildOfflineMessage()
              else
                Column(
                  children: [
                    Expanded(
                      // ✅ Tambah NotificationListener untuk deteksi scroll
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (scrollInfo.metrics.pixels > 0 && !_isScrolled) {
                            setState(() => _isScrolled = true);
                          } else if (scrollInfo.metrics.pixels <= 0 &&
                              _isScrolled) {
                            setState(() => _isScrolled = false);
                          }
                          return false;
                        },
                        child: FutureBuilder<ProcessedData>(
                          future: _dataFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: kPrimaryColor,
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final processed = snapshot.data!;
                            if (processed.rawData.isEmpty) {
                              return const Center(
                                child: Text("Belum ada video."),
                              );
                            }

                            bool hasContent = false;
                            for (var key in processed.categories) {
                              final videos =
                                  processed.rawData[key] as List<dynamic>? ??
                                  [];
                              if (_getFilteredVideosForCategory(
                                key,
                                videos,
                              ).isNotEmpty) {
                                hasContent = true;
                                break;
                              }
                            }

                            return RefreshIndicator(
                              onRefresh: _refreshData,
                              color: kPrimaryColor,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(
                                  bottom: 50,
                                  top: topPadding,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHistorySection(),
                                    //   _buildCategoryList(processed.categories),
                                    _buildAuthorList(processed.authors),

                                    if (!hasContent)
                                      _buildEmptyState()
                                    else
                                      ...processed.categories.map((key) {
                                        final rawVideos =
                                            processed.rawData[key]
                                                as List<dynamic>? ??
                                            [];
                                        final filteredVideos =
                                            _getFilteredVideosForCategory(
                                              key,
                                              rawVideos,
                                            );

                                        if (filteredVideos.isEmpty) {
                                          return const SizedBox.shrink();
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    20,
                                                    20,
                                                    12,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  // 1. JUDUL KATEGORI
                                                  Expanded(
                                                    child: Text(
                                                      _capitalize(key),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),

                                                  // 2. TOMBOL LIHAT SEMUA (DIBUNGKUS IF)
                                                  // Cuma muncul kalau videonya lebih dari 5
                                                  if (filteredVideos.length > 5)
                                                    InkWell(
                                                      onTap: () {
                                                        // Logic Judul + Filter yang tadi
                                                        String judulHalaman =
                                                            _capitalize(key);
                                                        if (_selectedAuthor !=
                                                            'Semua') {
                                                          judulHalaman +=
                                                              ' (Filter: $_selectedAuthor)';
                                                        }

                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => SeeAllPage(
                                                                  categoryTitle:
                                                                      judulHalaman,
                                                                  videos:
                                                                      filteredVideos,
                                                                ),
                                                          ),
                                                        ).then(
                                                          (_) => _loadHistory(),
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4.0,
                                                            ),
                                                        child: Text(
                                                          'Lihat Semua (${filteredVideos.length})',
                                                          style: const TextStyle(
                                                            color:
                                                                kPrimaryColor,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              height: 270,
                                              child: ListView.builder(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                    ),
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    filteredVideos.length > 5
                                                    ? 5
                                                    : filteredVideos.length,
                                                itemBuilder: (context, index) {
                                                  final videoMap =
                                                      Map<String, dynamic>.from(
                                                        filteredVideos[index]
                                                            as Map,
                                                      );
                                                  return _buildHorizontalVideoCard(
                                                    videoMap,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              // ✅ Style Tematik Header Overlay
              _buildTematikStyleHeader(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineMessage() {
    final isDark = _isDarkMode(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Koneksi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: "Mohon periksa koneksi internet Anda\n\n",
                  ),
                  const TextSpan(
                    text:
                        "Data video memerlukan koneksi internet untuk dimuat.\n\n",
                  ),
                  TextSpan(
                    text: "Fitur offline tersedia:\n",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                  TextSpan(
                    text:
                        "Paritta • Pendahuluan Tematik • Panduan Uposatha\nAbhidhammattha-Saṅgaha • Timer Meditasi",
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkConnectivity,
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
              style: FilledButton.styleFrom(backgroundColor: kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SEE ALL PAGE ====================

class SeeAllPage extends StatefulWidget {
  final String categoryTitle;
  final List<dynamic> videos;

  const SeeAllPage({
    super.key,
    required this.categoryTitle,
    required this.videos,
  });

  @override
  State<SeeAllPage> createState() => _SeeAllPageState();
}

class _SeeAllPageState extends State<SeeAllPage> {
  bool _isScrolled = false;

  // Header Tematik (Tetap sama)
  Widget _buildTematikStyleHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconBgColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final shadowColor = isDark
        ? Colors.black26
        : Colors.black.withValues(alpha: 0.1);

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
                color: shadowColor,
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
                color: bgColor.withValues(alpha: _isScrolled ? 0.85 : 1.0),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: textColor,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.categoryTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Spacer
              SizedBox(height: MediaQuery.of(context).padding.top + 95),
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
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      // ✅ UPDATED: Ganti angka ini buat ngatur tinggi
                      // 1.0 = Persegi
                      // 0.93 = Agak tinggi dikit (mirip layout asli 280x270)
                      // Makin KECIL angkanya, makin TINGGI kotaknya.
                      childAspectRatio: 0.93,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: widget.videos.length,
                    itemBuilder: (context, index) {
                      final video = Map<String, dynamic>.from(
                        widget.videos[index] as Map,
                      );
                      return _buildGridCard(context, video, isDark);
                    },
                  ),
                ),
              ),
            ],
          ),
          _buildTematikStyleHeader(),
        ],
      ),
    );
  }

  // ✅ CARD STYLE: SAMA PERSIS HALAMAN DEPAN
  Widget _buildGridCard(
    BuildContext context,
    Map<String, dynamic> video,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF303030) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF212121);
    final subtitleColor = isDark ? Colors.grey[400] : const Color(0xFF757575);
    final shadowColor = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  videoId: video['id'],
                  videoTitle: video['title'] ?? 'Video Meditasi',
                  onPositionChanged: (pos, dur) {
                    _saveHistoryDirectly(
                      video['id'],
                      video['title'],
                      video['author'],
                      pos,
                      dur,
                    );
                  },
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. GAMBAR + TOMBOL PLAY
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://img.youtube.com/vi/${video['id']}/mqdefault.jpg',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),

              // 2. TEXT AREA (Expanded biar ngisi sisa tinggi)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        video['title'] ?? 'Tanpa Judul',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.3,
                          color: titleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.mic_none_rounded,
                            size: 14,
                            color: kPrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              video['author'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

  // Logic Simpan History
  Future<void> _saveHistoryDirectly(
    String id,
    String? title,
    String? author,
    double pos,
    double dur,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyJson = prefs.getStringList('video_history') ?? [];
    historyJson.removeWhere((entry) => entry.startsWith('$id|'));
    bool isFinished = false;
    if (dur > 0 && pos >= (dur * 0.95)) isFinished = true;
    if (!isFinished) {
      final safeTitle = (title ?? '').replaceAll('|', '-');
      final safeAuthor = (author ?? '').replaceAll('|', '-');
      final newEntry = '$id|$safeTitle|$safeAuthor|$pos';
      historyJson.insert(0, newEntry);
      if (historyJson.length > 5) historyJson = historyJson.sublist(0, 5);
    }
    await prefs.setStringList('video_history', historyJson);
  }
}

// ==================== PLAYER SCREEN (FULLSCREEN FIXED) ====================

class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  final double initialPosition;
  // Callback updated: (position, totalDuration)
  final Function(double, double) onPositionChanged;

  const PlayerScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
    this.initialPosition = 0.0,
    required this.onPositionChanged,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late YoutubePlayerController _controller;
  bool _hasSeeked = false;

  @override
  void initState() {
    super.initState();

    // Lock portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        forceHD: false,
      ),
    )..addListener(_listener);
  }

  void _listener() {
    if (_controller.value.isReady &&
        !_hasSeeked &&
        widget.initialPosition > 0) {
      _hasSeeked = true;
      _controller.seekTo(Duration(seconds: widget.initialPosition.toInt()));
    }
    if (_controller.value.isPlaying) {
      final pos = _controller.value.position.inSeconds.toDouble();
      final dur = _controller.metadata.duration.inSeconds.toDouble();
      widget.onPositionChanged(pos, dur);
    }
  }

  void _seek(int seconds) {
    final current = _controller.value.position;
    final newPos = current + Duration(seconds: seconds);
    _controller.seekTo(newPos);
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    _controller.dispose();

    // ✅ RESET CUMA DI DISPOSE (1x aja)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onExitFullScreen: () {
        // ✅ RESET ORIENTATION + UI MODE
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: kPrimaryColor,
        progressColors: const ProgressBarColors(
          playedColor: kPrimaryColor,
          handleColor: kPrimaryColor,
        ),
        topActions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 25),
            onPressed: () {
              // ✅ GAK USAH SET ORIENTATION (udah di onExitFullScreen)
              Navigator.pop(context);
            },
          ),
          const Spacer(),
        ],
        bottomActions: [
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () => _seek(-10),
          ),
          CurrentPosition(),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor: kPrimaryColor,
              handleColor: kPrimaryColor,
            ),
          ),
          RemainingDuration(),
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: () => _seek(10),
          ),
          const PlaybackSpeedButton(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(child: player),
              // Header Back Button untuk Mode Portrait
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            // ✅ GAK USAH SET ORIENTATION (udah di dispose)
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: Text(
                            widget.videoTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
