import 'dart:convert'; // Buat ngolah JSON
import 'dart:ui'; // Buat efek kaca (Blur)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Buat ngatur status bar
import 'package:http/http.dart' as http; // Buat request internet
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  // --- GANTI LINK INI PAKE LINK GITHUB/JSDELIVR LU ---
  final String _dataUrl =
      'https://cdn.jsdelivr.net/gh/renaldoaluska/tipitaka@main/json/videos.json';

  // Variabel buat nampung data masa depan (Future)
  late Future<Map<String, dynamic>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _videosFuture = _fetchVideos();
  }

  // Fungsi buat download data dari GitHub
  Future<Map<String, dynamic>> _fetchVideos() async {
    try {
      final response = await http.get(Uri.parse(_dataUrl));

      if (response.statusCode == 200) {
        // Berhasil download, ubah Teks jadi Data (Map)
        return json.decode(response.body);
      } else {
        throw Exception('Gagal memuat data (Error ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Periksa koneksi internet Anda');
    }
  }

  // Fungsi Refresh kalo ditarik ke bawah
  Future<void> _refreshData() async {
    setState(() {
      _videosFuture = _fetchVideos();
    });
  }

  // --- WIDGETS ---

  Widget _buildGlassAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(
              context,
            ).scaffoldBackgroundColor.withValues(alpha: 0.85),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Video Panduan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(dynamic video) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                builder: (context) => PlayerScreen(videoId: video['id']),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://img.youtube.com/vi/${video['id']}/maxresdefault.jpg',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
              // Info Text
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title'] ?? 'Tanpa Judul',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video['author'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // FUTURE BUILDER: Handle Loading, Error, & Data
          FutureBuilder<Map<String, dynamic>>(
            future: _videosFuture,
            builder: (context, snapshot) {
              // 1. Kalo lagi Loading
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 2. Kalo Error
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat video.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              // 3. Kalo Berhasil (Data Ada)
              final data = snapshot.data!;
              final praktikList = data['praktik'] as List<dynamic>? ?? [];
              final teoriList = data['teori'] as List<dynamic>? ?? [];

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 70,
                    bottom: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (praktikList.isNotEmpty) ...[
                        _buildSectionTitle('Praktik & Panduan'),
                        ...praktikList.map((v) => _buildVideoCard(v)),
                      ],

                      const SizedBox(height: 16),

                      if (teoriList.isNotEmpty) ...[
                        _buildSectionTitle('Teori & Pengetahuan'),
                        ...teoriList.map((v) => _buildVideoCard(v)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // APPBAR KACA (Overlay)
          _buildGlassAppBar(),
        ],
      ),
    );
  }
}

// --- PLAYER SCREEN (Sama kayak sebelumnya tapi udah fix fullscreen) ---

class PlayerScreen extends StatefulWidget {
  final String videoId;
  const PlayerScreen({super.key, required this.videoId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    // Balikin status bar kalo user langsung back dari fullscreen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      // Logic Fullscreen ada di sini (Builder)
      onEnterFullScreen: () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onExitFullScreen: () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.redAccent,
        progressColors: const ProgressBarColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
        ),
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: const BackButton(color: Colors.white),
            title: const Text(
              'Memutar Video',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Center(child: player),
        );
      },
    );
  }
}
