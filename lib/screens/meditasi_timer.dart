import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'dart:ui'; // Buat ImageFilter.blur

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
  Timer? _previewDebounce;
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
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    _initializeVolumeController();
    _loadSettings();
    _loadDeviceVolume();
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
    _previewDebounce?.cancel();
    _stopPreviewTimer?.cancel(); // <--- TAMBAH INI
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
            // HAPUS padding manual yang ribet tadi
            // Ganti pake SafeArea, tapi set bottom: false biar ga ngefek ke bawah
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
                      onTap: () async {
                        if (_isRunning) {
                          final canExit = await _confirmExit();
                          if (canExit && context.mounted) {
                            setState(() {
                              _isRunning = false;
                              _isPreparation = false;
                              _isPaused = false;
                            });
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Timer Meditasi',
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
    // 1. BATALIN semua rencana yang lama (Debounce & Jadwal Stop)
    // Ini kuncinya biar timer lama gak "membunuh" suara baru
    _previewDebounce?.cancel();
    _stopPreviewTimer?.cancel();

    // 2. Matiin semua suara dulu biar sepi
    await _startBellPlayer.stop();
    await _endBellPlayer.stop();
    await _ambientPlayer.stop();

    // Kalo milih "Tanpa...", yaudah stop aja, gak usah lanjut
    if (sound == 'Tanpa Bel' || sound == 'Tanpa Latar') return;

    // 3. Mulai Debounce (Tunggu user diem dulu 300ms, baru play)
    // Biar kalo dia nge-scroll cepet, gak semua file keload bikin lag
    _previewDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        if (type == 'start') {
          await _startBellPlayer.setVolume(_startBellVolume * _deviceVolume);
          await _startBellPlayer.play(AssetSource('sounds/$sound'));
        } else if (type == 'end') {
          await _endBellPlayer.setVolume(_endBellVolume * _deviceVolume);
          await _endBellPlayer.play(AssetSource('sounds/$sound'));
        } else if (type == 'ambient') {
          await _ambientPlayer.setVolume(_ambientVolume * _deviceVolume);
          await _ambientPlayer.play(
            AssetSource('sounds/${sound.toLowerCase()}.mp3'),
          );

          // 4. Jadwalin Stop pake Timer yang BISA DIBATALIN (_stopPreviewTimer)
          // Jangan pake Future.delayed biasa
          _stopPreviewTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) _ambientPlayer.stop();
          });
        }
      } catch (e) {
        debugPrint('Error playing preview: $e');
      }
    });
  }

  void _startMeditation() {
    _saveSettings();
    setState(() {
      _isRunning = true;
      _isPreparation = true;
      _remainingSeconds = 10;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            // --- BAGIAN INI YANG DIUBAH ---
            if (_isPreparation) {
              _isPreparation = false;
              _remainingSeconds = (_hours * 3600) + (_minutes * 60) + _seconds;

              // 1. Mainkan Bel DULUAN
              _playStartBell();

              // 2. Hapus/Comment baris _playAmbient() yang lama di sini
              // _playAmbient(); <--- INI JANGAN DIPAKE LANGSUNG

              // 3. Kita kasih delay (jeda) misal 3 detik, baru ambient masuk
              if (_ambient != 'Tanpa Latar') {
                Future.delayed(const Duration(seconds: 3), () {
                  // Cek lagi: takutnya user keburu stop/pause pas lagi jeda 3 detik itu
                  if (mounted && _isRunning && !_isPaused) {
                    _playAmbient();
                  }
                });
              }
            } else {
              _finishMeditation();
            }
            // --- SELESAI UBAH ---
          }
        });
      }
    });
  }

  Future<void> _playStartBell() async {
    if (_startBell != 'Tanpa Bel') {
      try {
        await _startBellPlayer.setVolume(_startBellVolume * _deviceVolume);
        await _startBellPlayer.play(AssetSource('sounds/$_startBell'));
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  Future<void> _playEndBell() async {
    if (_endBell != 'Tanpa Bel') {
      try {
        await _endBellPlayer.setVolume(_endBellVolume * _deviceVolume);
        await _endBellPlayer.play(AssetSource('sounds/$_endBell'));
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  Future<void> _playAmbient() async {
    if (_ambient != 'Tanpa Latar') {
      try {
        await _ambientPlayer.setVolume(_ambientVolume * _deviceVolume);
        await _ambientPlayer.play(
          AssetSource('sounds/${_ambient.toLowerCase()}.mp3'),
        );
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  void _pauseResume() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      if (_ambient != 'Tanpa Latar') _ambientPlayer.pause();
    } else {
      if (!_isPreparation && _ambient != 'Tanpa Latar') _ambientPlayer.resume();
    }
  }

  void _finishMeditation() {
    _timer?.cancel();
    _ambientPlayer.stop();
    _playEndBell();
    setState(() {
      _isRunning = false;
      _isPreparation = false;
      _isPaused = false;
    });
    _showCompletionDialog();
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
      _ambientPlayer.stop();
      setState(() {
        _isRunning = false;
        _isPreparation = false;
        _isPaused = false;
      });
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
          'Semoga meditasi Anda membawa kedamaian dan kebijaksanaan.',
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _bellOptions.map((bell) {
              return RadioListTile<String>(
                // --- BAGIAN INI DIGANTI ---
                title: Text(_getBellDisplayName(bell)),
                // --------------------------
                value: bell,
                groupValue: tempSelection,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempSelection = value);
                    setState(() {
                      if (type == 'start')
                        _startBell = value;
                      else
                        _endBell = value;
                    });
                    _saveSettings();
                    _playPreview(value, type);
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _previewDebounce?.cancel();
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
              return RadioListTile<String>(
                title: Text(ambient),
                value: ambient,
                groupValue: tempSelection,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempSelection = value);
                    setState(() => _ambient = value);
                    _saveSettings();
                    _playPreview(value, 'ambient');
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _previewDebounce?.cancel();
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
              // --- Header ---
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
                        // --- VALIDASI PAKE POPUP ---
                        if (tempDuration.inSeconds < 60) {
                          // Ganti SnackBar jadi showDialog biar nongol di atas Sheet
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
                          return; // Stop di sini
                        }

                        // Save kalo lolos
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

              // --- Wheel Picker ---
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

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _confirmExit();
          if (shouldPop && context.mounted) {
            setState(() {
              _isRunning = false;
              _isPreparation = false;
              _isPaused = false;
            });
          }
        }
      },
      child: Scaffold(
        // Body dibikin full screen (tanpa SafeArea) biar scroll-nya tembus ke atas
        body: Stack(
          children: [
            // KONTEN
            Padding(
              // Kita tetep butuh ini biar konten awal ga ketutupan AppBar
              // Tapi sekarang hitungannya lebih simpel
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 70,
              ),
              child: _isRunning
                  ? _buildTimerView(isDark, accentColor)
                  : _buildSettingsView(isDark, accentColor),
            ),

            // APPBAR (Melayang di atas konten)
            _buildGlassAppBar(),
          ],
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

  Widget _buildSettingsView(bool isDark, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER: PENGATURAN WAKTU ---
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
                    Text(
                      'Durasi', // Kasih label jelas di dalem
                      style: const TextStyle(fontWeight: FontWeight.w500),
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

          // --- HEADER: PENGATURAN SUARA ---
          _buildSectionHeader(context, 'Suara'),

          // Item 1: Bel Mulai
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

          // Item 2: Bel Selesai
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

          // Item 3: Suara Latar
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

          // Tombol Aksi di bawah
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
          const SizedBox(height: 20), // Spasi bawah biar ga mentok
        ],
      ),
    );
  }

  // Cuma buat ngebungkus kontennya aja, ga pake judul lagi
  Widget _buildSettingItem({required Widget child}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }

  // Fungsi buat ngerapihin nama file jadi nama cantik
  String _getBellDisplayName(String filename) {
    if (filename == 'Tanpa Bel') return filename;
    // Hapus .mp3, terus ubah 'bel' jadi 'Bel ' (pake spasi biar ada jarak)
    return filename.replaceAll('.mp3', '').replaceAll('bel', 'Bel ');
  }
}

// Fungsi baru buat bikin Header a la ExploreTab
Widget _buildSectionHeader(BuildContext context, String title) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  // Logic warna divider copas dari ExploreTab
  final dividerColor = isDarkMode
      ? const Color.fromARGB(77, 158, 158, 158)
      : const Color.fromARGB(102, 158, 158, 158);

  return Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8), // Jarak atas-bawah
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 4), // Dikit indent biar sejajar
            Text(
              title.toUpperCase(), // Biasanya header digedein semua biar tegas
              style: TextStyle(
                fontSize: 13, // Ukuran pas buat label section
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
