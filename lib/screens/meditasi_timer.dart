import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:ui';

import '../utils/system_ui_helper.dart';

class MeditationTimerPage extends StatefulWidget {
  const MeditationTimerPage({super.key});

  @override
  State<MeditationTimerPage> createState() => _MeditationTimerPageState();
}

class _MeditationTimerPageState extends State<MeditationTimerPage> {
  final AudioPlayer _startBellPlayer = AudioPlayer();
  final AudioPlayer _endBellPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  late final VolumeController _volumeController;
  StreamSubscription? _bellCompleteSubscription;

  int _hours = 0;
  int _minutes = 10;
  int _seconds = 0;
  String _startBell = 'bel1.mp3';
  String _endBell = 'bel2.mp3';
  String _ambient = 'Tanpa Latar';

  double _deviceVolume = 1.0;
  double _startBellVolume = 0.8;
  double _endBellVolume = 0.8;
  double _ambientVolume = 0.5;

  bool _isRunning = false;
  bool _isPreparation = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  Timer? _stopPreviewTimer;

  final List<String> _bellOptions = [
    'Tanpa Bel',
    'bel1.mp3',
    'bel2.mp3',
    'bel3.mp3',
  ];
  final List<String> _ambientOptions = [
    'Tanpa Latar',
    'Hutan',
    'Sungai',
    'Laut',
  ];

  static const String _keyHours = 'meditation_hours';
  static const String _keyMinutes = 'meditation_minutes';
  static const String _keySeconds = 'meditation_seconds';
  static const String _keyStartBell = 'meditation_start_bell';
  static const String _keyEndBell = 'meditation_end_bell';
  static const String _keyAmbient = 'meditation_ambient';
  static const String _keyStartBellVolume = 'meditation_start_bell_volume';
  static const String _keyEndBellVolume = 'meditation_end_bell_volume';
  static const String _keyAmbientVolume = 'meditation_ambient_volume';

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayers();
    _initializeVolumeController();
    _loadSettings();
    _loadDeviceVolume();
  }

  void _initializeAudioPlayers() {
    // Set audio context untuk background playback
    _startBellPlayer.setReleaseMode(ReleaseMode.stop);
    _endBellPlayer.setReleaseMode(ReleaseMode.stop);
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);

    // Set audio context agar bisa jalan saat layar mati
    _startBellPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck, // UBAH INI!
        ),
      ),
    );

    _endBellPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck, // UBAH INI!
        ),
      ),
    );

    _ambientPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain, // Ambient tetep gain
        ),
      ),
    );
  }

  void _initializeVolumeController() {
    _volumeController = VolumeController.instance;
    _volumeController.addListener((volume) {
      if (mounted) setState(() => _deviceVolume = volume);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    _stopPreviewTimer?.cancel();
    _bellCompleteSubscription?.cancel();
    _startBellPlayer.dispose();
    _endBellPlayer.dispose();
    _ambientPlayer.dispose();
    _volumeController.removeListener();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hours = prefs.getInt(_keyHours) ?? 0;
        _minutes = prefs.getInt(_keyMinutes) ?? 10;
        _seconds = prefs.getInt(_keySeconds) ?? 0;
        _startBell = prefs.getString(_keyStartBell) ?? 'bel1.mp3';
        _endBell = prefs.getString(_keyEndBell) ?? 'bel2.mp3';
        _ambient = prefs.getString(_keyAmbient) ?? 'Tanpa Latar';
        _startBellVolume = prefs.getDouble(_keyStartBellVolume) ?? 0.8;
        _endBellVolume = prefs.getDouble(_keyEndBellVolume) ?? 0.8;
        _ambientVolume = prefs.getDouble(_keyAmbientVolume) ?? 0.5;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHours, _hours);
    await prefs.setInt(_keyMinutes, _minutes);
    await prefs.setInt(_keySeconds, _seconds);
    await prefs.setString(_keyStartBell, _startBell);
    await prefs.setString(_keyEndBell, _endBell);
    await prefs.setString(_keyAmbient, _ambient);
    await prefs.setDouble(_keyStartBellVolume, _startBellVolume);
    await prefs.setDouble(_keyEndBellVolume, _endBellVolume);
    await prefs.setDouble(_keyAmbientVolume, _ambientVolume);
  }

  Widget _buildGlassAppBar() {
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
                        onPressed: () async {
                          if (_isRunning) {
                            final navigator = Navigator.of(context);
                            final canExit = await _confirmExit();
                            if (canExit && mounted) {
                              navigator.pop();
                            }
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Timer Meditasi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
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

  Future<void> _loadDeviceVolume() async {
    try {
      final volume = await _volumeController.getVolume();
      if (mounted) setState(() => _deviceVolume = volume);
    } catch (e) {
      debugPrint('Error loading device volume: $e');
    }
  }

  Future<void> _setDeviceVolume(double volume) async {
    try {
      await _volumeController.setVolume(volume);
      if (mounted) setState(() => _deviceVolume = volume);
    } catch (e) {
      debugPrint('Error setting device volume: $e');
    }
  }

  Future<void> _playPreview(String sound, String type) async {
    _stopPreviewTimer?.cancel();

    // Stop semua audio dulu
    await _startBellPlayer.stop();
    await _endBellPlayer.stop();
    await _ambientPlayer.stop();

    if (sound == 'Tanpa Bel' || sound == 'Tanpa Latar') return;

    // Langsung play tanpa debounce
    try {
      if (type == 'start') {
        await _startBellPlayer.setVolume(_startBellVolume * _deviceVolume);
        await _startBellPlayer.play(AssetSource('sounds/$sound'));

        _stopPreviewTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _startBellPlayer.stop();
        });
      } else if (type == 'end') {
        await _endBellPlayer.setVolume(_endBellVolume * _deviceVolume);
        await _endBellPlayer.play(AssetSource('sounds/$sound'));

        _stopPreviewTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _endBellPlayer.stop();
        });
      } else if (type == 'ambient') {
        await _ambientPlayer.setVolume(_ambientVolume * _deviceVolume);
        await _ambientPlayer.play(
          AssetSource('sounds/${sound.toLowerCase()}.mp3'),
        );

        _stopPreviewTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) _ambientPlayer.stop();
        });
      }
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  void _startMeditation() {
    _stopPreviewTimer?.cancel();
    _bellCompleteSubscription?.cancel();

    // Nyalakan segera agar layar tidak redup saat loading audio/settings
    WakelockPlus.enable();

    Future.wait([
          _startBellPlayer.stop(),
          _endBellPlayer.stop(),
          _ambientPlayer.stop(),
        ])
        .then((_) {
          _saveSettings();
          if (mounted) {
            setState(() {
              _isRunning = true;
              _isPreparation = true;
              _remainingSeconds = 10;
            });
            _startTimer();
            _playAmbient();
          }
        })
        .catchError((e) {
          debugPrint('Error stopping audio: $e');
          _saveSettings();
          if (mounted) {
            setState(() {
              _isRunning = true;
              _isPreparation = true;
              _remainingSeconds = 10;
            });

            //        WakelockPlus.enable();
            _startTimer();
            // Play ambient langsung sejak preparation
            _playAmbient();
          }
        });
  }

  DateTime? _targetTime;

  void _startTimer() {
    // Hitung kapan timer harus selesai
    _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPaused && _targetTime != null) {
        final now = DateTime.now();
        final difference = _targetTime!.difference(now).inSeconds;

        if (difference <= 0) {
          timer.cancel();
          setState(() {
            _remainingSeconds = 0;
            if (_isPreparation) {
              _isPreparation = false;
              _remainingSeconds = (_hours * 3600) + (_minutes * 60) + _seconds;
              _playStartBell();
              _startTimer(); // Mulai timer meditasi yang sesungguhnya
            } else {
              _finishMeditation();
            }
          });
        } else {
          setState(() {
            _remainingSeconds = difference;
          });
        }
      }
    });
  }

  Future<void> _playStartBell() async {
    if (_startBell != 'Tanpa Bel') {
      try {
        // Jangan stop ambient player di sini!
        await _startBellPlayer.setVolume(_startBellVolume * _deviceVolume);
        await _startBellPlayer.play(AssetSource('sounds/$_startBell'));
      } catch (e) {
        debugPrint('Error playing start bell: $e');
      }
    }
  }

  Future<void> _playEndBell() async {
    if (_endBell != 'Tanpa Bel') {
      try {
        await _endBellPlayer.setVolume(_endBellVolume * _deviceVolume);
        await _endBellPlayer.play(AssetSource('sounds/$_endBell'));
      } catch (e) {
        debugPrint('Error playing end bell: $e');
      }
    }
  }

  Future<void> _playAmbient() async {
    // Cek cuma running dan ga pause
    if (!_isRunning || _isPaused) return;

    if (_ambient != 'Tanpa Latar') {
      try {
        // Cek apakah ambient udah playing, kalau udah jangan play lagi
        final state = _ambientPlayer.state;
        if (state == PlayerState.playing) {
          return; // Udah jalan, ga usah play lagi
        }

        // Start dari volume 0
        await _ambientPlayer.setVolume(0);
        await _ambientPlayer.play(
          AssetSource('sounds/${_ambient.toLowerCase()}.mp3'),
        );

        // Fade in dalam 2 detik
        const steps = 20;
        const duration = Duration(milliseconds: 100);

        for (int i = 0; i <= steps; i++) {
          if (!mounted || !_isRunning) break;
          final volume = (_ambientVolume * _deviceVolume) * (i / steps);
          await _ambientPlayer.setVolume(volume);
          await Future.delayed(duration);
        }
      } catch (e) {
        debugPrint('Error playing ambient: $e');
      }
    }
  }

  void _pauseResume() {
    if (!mounted) return;

    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        // Hentikan ambient
        if (_ambient != 'Tanpa Latar') _ambientPlayer.pause();
        // Opsional: Hentikan timer untuk hemat CPU, meski DateTime akan handle akurasinya
      } else {
        // SAAT RESUME: Hitung ulang target waktu berdasarkan sisa detik sekarang
        _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
        if (_ambient != 'Tanpa Latar') _ambientPlayer.resume();
      }
    });
  }

  void _finishMeditation() {
    _timer?.cancel();
    _bellCompleteSubscription?.cancel();

    WakelockPlus.disable();
    _startBellPlayer.stop();
    // Jangan stop ambient dulu, biar overlap sama bell

    setState(() {
      _isRunning = false;
      _isPreparation = false;
      _isPaused = false;
    });

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        // Play bell akhir DAN langsung fade out ambient (paralel!)
        _playEndBell(); // Ga pake await biar ga nunggu
        _fadeOutAmbient(); // Langsung fade out bareng

        _showCompletionDialog();
      }
    });
  }

  Future<void> _fadeOutAmbient() async {
    // Fade out dalam 2 detik
    const steps = 20;
    const duration = Duration(milliseconds: 100); // 20 steps * 100ms = 2 detik

    for (int i = steps; i >= 0; i--) {
      if (!mounted) break;
      final volume = (_ambientVolume * _deviceVolume) * (i / steps);
      await _ambientPlayer.setVolume(volume);
      await Future.delayed(duration);
    }

    if (mounted) {
      await _ambientPlayer.stop();
      // Reset volume untuk next session
      await _ambientPlayer.setVolume(_ambientVolume * _deviceVolume);
    }
  }

  Future<bool> _confirmExit() async {
    if (!_isRunning) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Meditasi?'),
        content: const Text(
          'Timer akan dibatalkan dan tidak dapat dilanjutkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (result == true) {
      _timer?.cancel();
      WakelockPlus.disable();
      _bellCompleteSubscription?.cancel();
      _startBellPlayer.stop();
      _endBellPlayer.stop();
      _ambientPlayer.stop();
      if (mounted) {
        setState(() {
          _isRunning = false;
          _isPreparation = false;
          _isPaused = false;
        });
      }
    }
    return result ?? false;
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🙏 Meditasi Selesai'),
        content: const Text(
          'Sabbe sattā bhavantu sukhitattā.\nNibbānaṃ paramaṃ sukhaṃ\nSādhu sādhu sādhu!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _showVolumeSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 24),
              SizedBox(width: 8),
              Text('Pengaturan Volume'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVolumeSlider('Volume Perangkat', _deviceVolume, (val) {
                  setDialogState(() => _deviceVolume = val);
                  setState(() => _deviceVolume = val);
                  _setDeviceVolume(val);
                }),
                const SizedBox(height: 12),
                _buildVolumeSlider('Bel Mulai', _startBellVolume, (val) {
                  setDialogState(() => _startBellVolume = val);
                  setState(() => _startBellVolume = val);
                  _saveSettings();
                }),
                const SizedBox(height: 12),
                _buildVolumeSlider('Bel Selesai', _endBellVolume, (val) {
                  setDialogState(() => _endBellVolume = val);
                  setState(() => _endBellVolume = val);
                  _saveSettings();
                }),
                const SizedBox(height: 12),
                _buildVolumeSlider('Suara Latar', _ambientVolume, (val) {
                  setDialogState(() => _ambientVolume = val);
                  setState(() => _ambientVolume = val);
                  _saveSettings();
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                onChanged: onChanged,
                min: 0.0,
                max: 1.0,
                divisions: 20,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBellPicker(String type) {
    String tempSelection = type == 'start' ? _startBell : _endBell;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Pilih ${type == 'start' ? 'Bel Mulai' : 'Bel Selesai'}'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _bellOptions.map((bell) {
              final isSelected = bell == tempSelection;
              return InkWell(
                onTap: () {
                  setDialogState(() => tempSelection = bell);
                  setState(() {
                    if (type == 'start') {
                      _startBell = bell;
                    } else {
                      _endBell = bell;
                    }
                  });
                  _saveSettings();
                  _playPreview(bell, type);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_getBellDisplayName(bell))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _stopPreviewTimer?.cancel();
                _startBellPlayer.stop();
                _endBellPlayer.stop();
                Navigator.pop(context);
              },
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmbientPicker() {
    String tempSelection = _ambient;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pilih Suara Latar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _ambientOptions.map((ambient) {
              final isSelected = ambient == tempSelection;
              return InkWell(
                onTap: () {
                  setDialogState(() => tempSelection = ambient);
                  setState(() => _ambient = ambient);
                  _saveSettings();
                  _playPreview(ambient, 'ambient');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(ambient)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _stopPreviewTimer?.cancel();
                _ambientPlayer.stop();
                Navigator.pop(context);
              },
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDurationPicker() {
    Duration tempDuration = Duration(
      hours: _hours,
      minutes: _minutes,
      seconds: _seconds,
    );

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          height: 300,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (tempDuration.inSeconds < 60) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Durasi'),
                                content: const Text('Maaf, minimal 1 menit.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Siap'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }

                        setState(() {
                          _hours = tempDuration.inHours;
                          _minutes = tempDuration.inMinutes % 60;
                          _seconds = tempDuration.inSeconds % 60;
                        });
                        _saveSettings();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Simpan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: tempDuration,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  onTimerDurationChanged: (Duration newDuration) {
                    tempDuration = newDuration;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDuration() {
    List<String> parts = [];
    if (_hours > 0) parts.add('$_hours jam');
    if (_minutes > 0) parts.add('$_minutes menit');
    if (_seconds > 0) parts.add('$_seconds detik');
    return parts.isEmpty ? '0 detik' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFFD32F2F);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _confirmExit();
        }
      },

      child: AnnotatedRegion<SystemUiOverlayStyle>(
        //  WRAP
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: _isRunning
                    ? (isLandscape
                          ? _buildTimerViewLandscape(isDark, accentColor)
                          : _buildTimerView(isDark, accentColor))
                    : (isLandscape
                          ? _buildSettingsViewLandscape(isDark, accentColor)
                          : _buildSettingsView(isDark, accentColor)),
              ),
              _buildGlassAppBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerView(bool isDark, Color accentColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    double fontSize = _remainingSeconds >= 36000
        ? screenWidth * 0.12
        : _remainingSeconds >= 3600
        ? screenWidth * 0.14
        : screenWidth * 0.18;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Text(
            _isPreparation ? 'Persiapan' : 'Meditasi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: screenWidth * 0.75,
            height: screenWidth * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w200,
                      color: _isPreparation ? Colors.orange : accentColor,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
          IconButton(
            onPressed: _pauseResume,
            icon: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            iconSize: 48,
            style: IconButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerViewLandscape(bool isDark, Color accentColor) {
    final screenHeight = MediaQuery.of(context).size.height;
    //  final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenHeight * 0.55;
    double fontSize = _remainingSeconds >= 36000
        ? circleSize * 0.18
        : _remainingSeconds >= 3600
        ? circleSize * 0.22
        : circleSize * 0.28;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                Text(
                  _isPreparation ? 'Persiapan' : 'Meditasi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w200,
                            color: _isPreparation ? Colors.orange : accentColor,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              IconButton(
                onPressed: _pauseResume,
                icon: Icon(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                iconSize: 48,
                style: IconButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView(bool isDark, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),
          _buildSectionHeader(context, 'Waktu'),
          _buildSettingItem(
            child: InkWell(
              onTap: _showDurationPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Durasi',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatDuration(),
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSectionHeader(context, 'Suara'),
          _buildSettingItem(
            child: InkWell(
              onTap: () => _showBellPicker('start'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bel Mulai'),
                    Row(
                      children: [
                        Text(
                          _getBellDisplayName(_startBell),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSettingItem(
            child: InkWell(
              onTap: () => _showBellPicker('end'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bel Selesai'),
                    Row(
                      children: [
                        Text(
                          _getBellDisplayName(_endBell),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSettingItem(
            child: InkWell(
              onTap: _showAmbientPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Suara Latar'),
                    Row(
                      children: [
                        Text(
                          _ambient,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              IconButton(
                onPressed: _showVolumeSettings,
                icon: const Icon(Icons.volume_up_rounded),
                iconSize: 26,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _startMeditation,
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text('Mulai'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsViewLandscape(bool isDark, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Column(
        children: [
          const SizedBox(height: 80),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Kiri - Suara
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context, 'Suara'),
                    _buildSettingItem(
                      child: InkWell(
                        onTap: () => _showBellPicker('start'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bel Mulai'),
                              Row(
                                children: [
                                  Text(
                                    _getBellDisplayName(_startBell),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildSettingItem(
                      child: InkWell(
                        onTap: () => _showBellPicker('end'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bel Selesai'),
                              Row(
                                children: [
                                  Text(
                                    _getBellDisplayName(_endBell),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildSettingItem(
                      child: InkWell(
                        onTap: _showAmbientPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Suara Latar'),
                              Row(
                                children: [
                                  Text(
                                    _ambient,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Kolom Kanan - Waktu & Tombol
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context, 'Waktu'),
                    _buildSettingItem(
                      child: InkWell(
                        onTap: _showDurationPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Durasi',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showVolumeSettings,
                          icon: const Icon(Icons.volume_up_rounded),
                          iconSize: 26,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _startMeditation,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 26,
                            ),
                            label: const Text('Mulai'),
                            style: FilledButton.styleFrom(
                              backgroundColor: accentColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingItem({required Widget child}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }

  String _getBellDisplayName(String filename) {
    if (filename == 'Tanpa Bel') return filename;
    return filename.replaceAll('.mp3', '').replaceAll('bel', 'Bel ');
  }
}

Widget _buildSectionHeader(BuildContext context, String title) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final dividerColor = isDarkMode
      ? const Color.fromARGB(77, 158, 158, 158)
      : const Color.fromARGB(102, 158, 158, 158);
  return Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Divider(thickness: 1, color: dividerColor),
      ],
    ),
  );
}
