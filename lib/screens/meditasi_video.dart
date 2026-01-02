import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  // ==========================================
  // 1. DATA VIDEO (MANUAL CURATION)
  // ==========================================
  // Lu tinggal copas "Video ID" dari link Youtube.
  // Misal: https://www.youtube.com/watch?v=inpok4MKVLM -> ID nya "inpok4MKVLM"

  final List<Map<String, String>> _praktikVideos = [
    {
      'title': 'Meditasi Pemula 5 Menit',
      'author': 'Pagar Kehidupan',
      'id': 'inpok4MKVLM', // Ganti ID ini
    },
    {
      'title': 'Guided Meditation for Deep Sleep',
      'author': 'Great Meditation',
      'id': 'aEqlQvczMJQ',
    },
    {
      'title': 'Latihan Pernafasan Diafragma',
      'author': 'Satu Persen',
      'id': 'q0D4t-T9r9U',
    },
  ];

  final List<Map<String, String>> _teoriVideos = [
    {
      'title': 'Apa itu Mindfulness?',
      'author': 'Pijar Psikologi',
      'id': 'OpJ2gXJ3_gE',
    },
    {
      'title': 'Manfaat Meditasi Secara Ilmiah',
      'author': 'Kok Bisa?',
      'id': 'n6zZHwK2aT0',
    },
  ];

  // ==========================================
  // 2. LOGIC UI & APP BAR
  // ==========================================

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
              color: Colors.redAccent, // Warna Youtube banget
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

  Widget _buildVideoCard(Map<String, String> video) {
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
            // Buka Player Halaman Baru
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(videoId: video['id']!),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THUMBNAIL
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
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  // Icon Play di tengah gambar
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

              // TEXT INFO
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video['title']!,
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
                                video['author']!,
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
          // KONTEN UTAMA (LIST)
          SingleChildScrollView(
            // Padding top disesuain biar ga ketutupan AppBar
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 70,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- BAGIAN 1: PRAKTIK ---
                _buildSectionTitle('Praktik & Panduan'),
                ..._praktikVideos.map((video) => _buildVideoCard(video)),

                const SizedBox(height: 16),

                // --- BAGIAN 2: TEORI ---
                _buildSectionTitle('Teori & Pengetahuan'),
                ..._teoriVideos.map((video) => _buildVideoCard(video)),
              ],
            ),
          ),

          // APPBAR KACA (Melayang)
          _buildGlassAppBar(),
        ],
      ),
    );
  }
}

// ==========================================
// 3. LAYAR PEMUTAR VIDEO (PLAYER SCREEN)
// ==========================================
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
        // forceHD: true, // Opsional kalo mau paksa HD
      ),
    );
  }

  @override
  void dispose() {
    // 3. JAGA-JAGA: Balikin status bar kalo user langsung back/kill page
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
      onEnterFullScreen: () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onExitFullScreen: () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        // Atau: SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      },

      // Ini widget yang handle rotasi otomatis
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
