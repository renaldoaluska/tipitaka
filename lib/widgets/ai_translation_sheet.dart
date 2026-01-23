import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_translation.dart';
import 'ai_translation_history.dart';

class AITranslationSheet extends StatefulWidget {
  final String text;
  final bool settingsOnly;

  const AITranslationSheet({
    super.key,
    required this.text,
    this.settingsOnly = false,
  });

  @override
  State<AITranslationSheet> createState() => _AITranslationSheetState();
}

class _AITranslationSheetState extends State<AITranslationSheet> {
  Future<AITranslationResult>? _translationFuture;
  bool _showSettings = false;
  AIProvider? _currentProvider;
  bool _isCopied = false;

  // Cache status provider (mana yang ready, mana yang belum)
  final Map<AIProvider, bool> _providerReadiness = {};

  // Controllers untuk form
  final Map<AIProvider, TextEditingController> _apiKeyControllers = {};
  final Map<AIProvider, TextEditingController> _modelControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initialize();
  }

  void _initializeControllers() {
    for (var provider in AIProvider.values) {
      _apiKeyControllers[provider] = TextEditingController();
      _modelControllers[provider] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    for (var controller in _modelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    _currentProvider = await AITranslationService.getActiveProvider();

    // Load saved data & check readiness
    for (var provider in AIProvider.values) {
      final key = await AITranslationService.getApiKey(provider);
      final model = await AITranslationService.getModelName(provider);

      _apiKeyControllers[provider]?.text = key ?? '';
      _modelControllers[provider]?.text = model ?? '';

      final isReady = await AITranslationService.isProviderReady(provider);
      _providerReadiness[provider] = isReady;
    }

    if (widget.settingsOnly) {
      setState(() => _showSettings = true);
    } else {
      // Kalau provider aktif belum ready, paksa masuk settings
      if (_providerReadiness[_currentProvider] != true) {
        setState(() => _showSettings = true);
      }
    }
    setState(() {}); // Refresh UI
  }

  // Tambahkan method ini di dalam _AITranslationSheetState
  Future<void> _startTranslation() async {
    if (widget.settingsOnly) return;

    // 1. CEK HISTORY DULU
    final history = await AITranslationService.getHistory();
    // Cari yang teks aslinya sama persis, abaikan spasi/enter di ujung
    final duplicate = history.firstWhere(
      (h) => h.originalText.trim() == widget.text.trim(),
      orElse: () => TranslationHistory(
        id: '',
        originalText: '',
        translatedText: '',
        provider: '',
        model: '',
        timestamp: DateTime(1970),
      ),
    );

    // 2. KALO KETEMU DUPLIKAT
    if (duplicate.id.isNotEmpty && mounted) {
      final useOld = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.history,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          title: const Text('Sudah Pernah Diterjemahkan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teks ini ada di riwayat Anda. Menggunakan hasil lama akan menghemat kuota AI.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider: ${duplicate.provider}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Model: ${duplicate.model}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false), // False = Terjemahkan Ulang
              child: const Text('Terjemahkan Ulang'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, true), // True = Pakai Hasil Lama
              icon: const Icon(Icons.restore),
              label: const Text('Gunakan Hasil Lama'),
            ),
          ],
        ),
      );

      // User batal milih (klik luar) -> jangan ngapa-ngapain
      if (useOld == null) return;

      // Kalo user pilih "Lihat Hasil Lama"
      if (useOld) {
        setState(() {
          _showSettings = false;
          // Kita "palsukan" future-nya biar langsung sukses dengan data lama
          _translationFuture = Future.value(
            AITranslationResult(
              translatedText: duplicate.translatedText,
              success: true,
            ),
          );
        });
        return; // STOP DISINI, JANGAN PANGGIL API
      }
    }

    // 3. FLOW NORMAL (PANGGIL API)
    setState(() {
      _showSettings = false;
      _translationFuture = AITranslationService.translate(widget.text);
    });
  }

  void _handleCloseOrBack() {
    if (widget.settingsOnly) {
      Navigator.pop(context);
      return;
    }

    if (_showSettings) {
      // Back ke Main View
      setState(() {
        _showSettings = false;
      });
      // Refresh readiness pas balik dari settings
      _refreshReadiness();
    } else {
      // Close Sheet
      Navigator.pop(context);
    }
  }

  Future<void> _refreshReadiness() async {
    for (var provider in AIProvider.values) {
      final isReady = await AITranslationService.isProviderReady(provider);
      _providerReadiness[provider] = isReady;
    }
    setState(() {});
  }

  // Logic Quick Switcher
  Future<void> _onQuickProviderChange(AIProvider? newProvider) async {
    if (newProvider == null) return;

    if (_providerReadiness[newProvider] == true) {
      // KASUS 1: Provider udah setup -> Langsung ganti
      await AITranslationService.setActiveProvider(newProvider);
      setState(() {
        _currentProvider = newProvider;
        _translationFuture = null; // Reset hasil sebelumnya
      });
    } else {
      // KASUS 2: Provider belum setup -> Buka settings &arahin ke provider itu
      setState(() {
        _currentProvider = newProvider;
        _showSettings = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // DRAG HANDLE
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 16, bottom: 0),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // KIRI (Back / Icon)
                    Row(
                      children: [
                        if (_showSettings && !widget.settingsOnly)
                          InkWell(
                            onTap: _handleCloseOrBack,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.arrow_back,
                                size: 22, // Ukuran disamakan
                                color: colorScheme.onSurface,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.deepPurple.shade300,
                            size: 22,
                          ),
                        if (!(_showSettings && !widget.settingsOnly))
                          const SizedBox(width: 12),
                        Text(
                          _showSettings ? "Pengaturan AI" : "Terjemahan AI",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    // KANAN (Actions)
                    Row(
                      children: [
                        // CUMA MUNCUL DI MAIN VIEW (History & Close)
                        if (!_showSettings && !widget.settingsOnly) ...[
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    const TranslationHistorySheet(),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.history,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Settings Icon dihapus karena bisa lewat Dropdown
                          // Atau kalau mau tetap ada buat advanced settings:
                          InkWell(
                            onTap: () {
                              setState(() => _showSettings = true);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.settings,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // TOMBOL CLOSE (X) - Cuma ada di Main View
                          InkWell(
                            onTap: _handleCloseOrBack,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                            ),
                          ),
                        ],

                        // DI SETTINGS VIEW: KANAN KOSONG (Karena nav via Back kiri)
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // CONTENT
              Expanded(
                child: _showSettings
                    ? _buildSettingsView(scrollController)
                    : _buildTranslationView(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // TRANSLATION VIEW (DENGAN QUICK SWITCHER)
  // ============================================
  Widget _buildTranslationView(ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // INFO BOX DENGAN DROPDOWN SWITCHER
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Provider (Dropdown)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Provider:',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // QUICK SWITCHER DROPDOWN
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AIProvider>(
                        value: _currentProvider,
                        isDense: true,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                        items: AIProvider.values.map((provider) {
                          final isReady = _providerReadiness[provider] ?? false;
                          return DropdownMenuItem(
                            value: provider,
                            child: Row(
                              children: [
                                Text(
                                  AITranslationService.getProviderDisplayName(
                                    provider,
                                  ),
                                ),
                                if (!isReady) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 12,
                                    color: Colors.orange.withValues(alpha: 0.7),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onQuickProviderChange,
                      ),
                    ),
                  ),
                ],
              ),

              // Baris Model (Static info)
              const Divider(height: 12, thickness: 0.5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model:',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _modelControllers[_currentProvider]?.text ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // TEKS ASLI
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TEKS ASLI",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.text,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // LOGIC TOMBOL TRANSLATE VS HASIL
        if (_translationFuture == null)
          _buildStartButton(colorScheme)
        else
          FutureBuilder<AITranslationResult>(
            future: _translationFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.deepPurple.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sedang berpikir...',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              } else {
                final result = snapshot.data!;
                if (!result.success) {
                  return _buildErrorState(result.error ?? 'Unknown error');
                }
                return _buildSuccessState(
                  context,
                  result.translatedText,
                  colorScheme,
                );
              }
            },
          ),
      ],
    );
  }

  Widget _buildStartButton(ColorScheme colorScheme) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _startTranslation,
          icon: const Icon(Icons.translate, size: 20),
          label: const Text("Terjemahkan Sekarang"),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Klik tombol untuk mulai menerjemahkan.\nIni akan menggunakan kuota/token API Anda.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // ============================================
  // SETTINGS VIEW
  // ============================================
  Widget _buildSettingsView(ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // DROPDOWN PILIH PROVIDER
        Text(
          'AI Provider',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<AIProvider>(
          initialValue: _currentProvider,
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: AIProvider.values.map((provider) {
            return DropdownMenuItem(
              value: provider,
              child: Text(
                AITranslationService.getProviderDisplayName(provider),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (provider) {
            if (provider != null) {
              setState(() {
                _currentProvider = provider;
                // Reset controllers if needed logic here
              });
            }
          },
        ),

        const SizedBox(height: 20),

        // API KEY
        Text(
          'API Key',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyControllers[_currentProvider],
          decoration: InputDecoration(
            hintText: 'Paste API key di sini...',
            hintStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
            suffixIcon: _apiKeyControllers[_currentProvider]!.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        _apiKeyControllers[_currentProvider]!.clear();
                      });
                    },
                  )
                : null,
          ),
          obscureText: true,
          style: const TextStyle(fontSize: 14),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 16),

        // MODEL
        Text(
          'Model',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _modelControllers[_currentProvider],
          decoration: InputDecoration(
            hintText: AITranslationService.getModelPlaceholder(
              _currentProvider!,
            ),
            hintStyle: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
            suffixIcon: _modelControllers[_currentProvider]!.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        _modelControllers[_currentProvider]!.clear();
                      });
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 16),

        // LINK DAFTAR
        InkWell(
          onTap: () {
            final url = AITranslationService.getProviderSignupUrl(
              _currentProvider!,
            );
            Clipboard.setData(ClipboardData(text: 'https://$url'));

            // DIALOG COPY LINK
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Link disalin! Buka browser untuk daftar.'),
                    ),
                  ],
                ),
              ),
            );

            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap untuk copy link: ${AITranslationService.getProviderSignupUrl(_currentProvider!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(Icons.copy, size: 14, color: colorScheme.primary),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // TOMBOL UTAMA (Simpan Pengaturan)
        FilledButton.icon(
          onPressed: _canSave() ? _saveSettings : null,
          icon: const Icon(Icons.save, size: 20),
          label: const Text('Simpan Pengaturan'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        // DELETE BUTTON
        FutureBuilder<bool>(
          future: AITranslationService.isProviderReady(_currentProvider!),
          builder: (context, snapshot) {
            if (snapshot.data == true) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: _deleteSettings,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Hapus Setup',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  bool _canSave() {
    return _apiKeyControllers[_currentProvider]!.text.trim().isNotEmpty &&
        _modelControllers[_currentProvider]!.text.trim().isNotEmpty;
  }

  // FUNGSI SIMPAN BARU: SIMPAN & BALIK
  Future<void> _saveSettings() async {
    final key = _apiKeyControllers[_currentProvider]!.text.trim();
    final model = _modelControllers[_currentProvider]!.text.trim();

    await AITranslationService.saveApiKey(_currentProvider!, key);
    await AITranslationService.saveModelName(_currentProvider!, model);
    await AITranslationService.setActiveProvider(_currentProvider!);

    // Refresh readiness cache
    await _refreshReadiness();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              const Expanded(child: Text('Pengaturan berhasil disimpan!')),
            ],
          ),
        ),
      );

      // Auto-close dialog & back to main view
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); // Tutup Dialog
        }
        if (mounted && !widget.settingsOnly) {
          setState(() {
            _showSettings = false; // Balik ke halaman Translate
          });
        }
      });
    }
  }

  Future<void> _deleteSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Setup?'),
        content: Text(
          'API Key dan Model untuk ${AITranslationService.getProviderDisplayName(_currentProvider!)} akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AITranslationService.deleteApiKey(_currentProvider!);
      setState(() {
        _apiKeyControllers[_currentProvider]!.clear();
        _modelControllers[_currentProvider]!.clear();
      });
      await _refreshReadiness();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                const Expanded(child: Text('Setup berhasil dihapus')),
              ],
            ),
          ),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  Widget _buildErrorState(String msg) {
    String displayMsg = msg;
    String? suggestion;

    if (msg.contains('API Key tidak valid') || msg.contains('401')) {
      displayMsg = 'API Key tidak valid';
      suggestion = 'Periksa kembali API key Anda';
    } else if (msg.contains('Rate limit') || msg.contains('429')) {
      displayMsg = 'Rate limit tercapai';
      suggestion = 'Tunggu beberapa saat atau gunakan provider lain';
    } else if (msg.contains('Model') || msg.contains('404')) {
      displayMsg = 'Model tidak ditemukan';
      suggestion = 'Periksa nama model (contoh: gemini-2.0-flash-exp)';
    } else if (msg.contains('Error: ')) {
      final match = RegExp(r'Error: (.+)').firstMatch(msg);
      if (match != null) {
        displayMsg = match.group(1) ?? msg;
      }
    } else if (msg.contains('Koneksi gagal')) {
      displayMsg = 'Koneksi gagal';
      suggestion = 'Periksa koneksi internet Anda';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayMsg,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (suggestion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        suggestion,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (msg.contains('belum diatur') ||
              msg.contains('belum dipilih') ||
              msg.contains('tidak valid') ||
              msg.contains('tidak ditemukan')) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() => _showSettings = true);
                },
                icon: const Icon(Icons.settings),
                label: const Text('Atur Sekarang'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    String text,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "BAHASA INDONESIA",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade300,
                letterSpacing: 1.2,
              ),
            ),
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: text));

                setState(() => _isCopied = true);

                // Reset setelah 2 detik
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() => _isCopied = false);
                  }
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isCopied
                      ? Colors.green.withValues(alpha: 0.15)
                      : colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCopied
                        ? Colors.green
                        : colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCopied ? Icons.check : Icons.copy_rounded,
                      size: 14,
                      color: _isCopied ? Colors.green : colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isCopied ? "DISALIN" : "SALIN",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isCopied ? Colors.green : colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.7,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 32),
        // DISCLAIMER
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              "Dibuat dengan AI. Cek ulang untuk akurasi.",
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
