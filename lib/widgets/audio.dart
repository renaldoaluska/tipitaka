import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioHandlerWidget extends StatefulWidget {
  final String audioPath;
  final VoidCallback? onClose; // Callback buat handle close

  const AudioHandlerWidget({super.key, required this.audioPath, this.onClose});

  @override
  State<AudioHandlerWidget> createState() => _AudioHandlerWidgetState();
}

class _AudioHandlerWidgetState extends State<AudioHandlerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);

    // Listeners
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() {
        _duration = d;
        _isLoading = false;
      });
    });

    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });

    _initSource();
  }

  Future<void> _initSource() async {
    try {
      await _player.setSource(UrlSource(widget.audioPath));
      await _player.resume(); // Auto play
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isLoading) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    if (_isLoading) return;
    final newPos = _position + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      await _player.seek(Duration.zero);
    } else if (newPos > _duration) {
      await _player.seek(_duration);
    } else {
      await _player.seek(newPos);
    }
  }

  String _cleanFileName(String path) {
    try {
      String name = Uri.decodeComponent(path.split('/').last);
      name = name.replaceAll(
        RegExp(r'\.(mp3|m4a|wav)$', caseSensitive: false),
        '',
      );
      name = name.replaceAll(RegExp(r'[_-]'), ' ');
      if (name.isNotEmpty) name = name[0].toUpperCase() + name.substring(1);
      return name;
    } catch (e) {
      return "Audio";
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = _cleanFileName(widget.audioPath);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        24,
        0,
        24,
        0,
      ), // Margin bawah agak gedean dikit
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Shadow 1: Ambient (lembut & menyebar)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
          // Shadow 2: Key (sedikit lebih tegas di bawah)
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.15,
            ), // ✅ UBAH INI (hapus primary)
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                // Header: Icon + Title + Close
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoading
                                ? "Memuat..."
                                : "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        hoverColor: colorScheme.errorContainer.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      tooltip: "Tutup Player",
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Controls Row (Mundur - Play - Maju)
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center biar rapi
                  children: [
                    // Mundur
                    IconButton(
                      onPressed: _isLoading ? null : () => _seekRelative(-10),
                      icon: const Icon(Icons.replay_10_rounded),
                      iconSize: 28,
                      color: colorScheme.onSurfaceVariant,
                      tooltip: "Mundur 10s",
                    ),

                    const SizedBox(width: 24),

                    // Play / Pause Button (Lebih nonjol)
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: FittedBox(
                        child: FloatingActionButton(
                          onPressed: _togglePlay,
                          elevation: 2, // Shadow bawaan FAB
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: const CircleBorder(),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.onPrimary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 32,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Maju
                    IconButton(
                      onPressed: _isLoading ? null : () => _seekRelative(10),
                      icon: const Icon(Icons.forward_10_rounded),
                      iconSize: 28,
                      color: colorScheme.onSurfaceVariant,
                      tooltip: "Maju 10s",
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Slider
                SizedBox(
                  height: 24, // Kasih height fix biar gak layout jump
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: colorScheme.primary, // UBAH BAGIAN INI:
                      // Jangan pakai surfaceContainerHighest, ganti jadi ini biar kelihatan:
                      inactiveTrackColor: colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      // atau kalau mau abu-abu fix: Colors.grey.withValues(alpha: 0.3)
                      thumbColor: colorScheme.primary,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                        elevation: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: _duration.inSeconds.toDouble() > 0
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                      value: _position.inSeconds.toDouble().clamp(
                        0.0,
                        _duration.inSeconds.toDouble(),
                      ),
                      onChanged: _isLoading
                          ? null
                          : (v) => _player.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
