import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
  bool _isSaved = false;

  final Map<AIProvider, bool> _providerReadiness = {};
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
    final active = await AITranslationService.getActiveProvider();
    for (var provider in AIProvider.values) {
      final key = await AITranslationService.getApiKey(provider);
      final model = await AITranslationService.getModelName(provider);

      if (_apiKeyControllers[provider]?.text != key) {
        _apiKeyControllers[provider]?.text = key ?? '';
      }
      if (_modelControllers[provider]?.text != model) {
        _modelControllers[provider]?.text = model ?? '';
      }

      final isReady = await AITranslationService.isProviderReady(provider);
      _providerReadiness[provider] = isReady;
    }

    if (mounted) {
      setState(() {
        _currentProvider = active;
        if (widget.settingsOnly) {
          _showSettings = true;
        } else if (_providerReadiness[_currentProvider] != true) {
          _showSettings = true;
        }
      });
    }
  }

  Future<void> _startTranslation() async {
    if (widget.settingsOnly) return;

    final history = await AITranslationService.getHistory();
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
              const Text('Teks ini ada di riwayat Anda. Gunakan hasil lama?'),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Terjemahkan Ulang'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.restore),
              label: const Text('Gunakan Hasil Lama'),
            ),
          ],
        ),
      );

      if (useOld == null) return;

      if (useOld) {
        setState(() {
          _showSettings = false;
          _translationFuture = Future.value(
            AITranslationResult(
              translatedText: duplicate.translatedText,
              success: true,
            ),
          );
        });
        return;
      }
    }

    setState(() {
      _showSettings = false;
      _translationFuture = AITranslationService.translate(widget.text);
    });
  }

  void _handleCloseOrBack() async {
    if (widget.settingsOnly) {
      Navigator.pop(context);
      return;
    }

    if (_showSettings) {
      await _initialize();
      setState(() {
        _showSettings = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _onQuickProviderChange(AIProvider? newProvider) async {
    if (newProvider == null) return;

    if (_providerReadiness[newProvider] == true) {
      await AITranslationService.setActiveProvider(newProvider);
      await _initialize();
      setState(() {
        _translationFuture = null;
      });
    } else {
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
          ),
          child: Column(
            children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                                size: 22,
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
                        const SizedBox(width: 12),
                        Text(
                          _showSettings ? "Pengaturan AI" : "Terjemahan AI",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (!_showSettings && !widget.settingsOnly)
                      Row(
                        children: [
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
                          InkWell(
                            onTap: () => setState(() => _showSettings = true),
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
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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

  Widget _buildTranslationView(ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const BouncingScrollPhysics(),
      children: [
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
                      _modelControllers[_currentProvider]?.text.isNotEmpty ==
                              true
                          ? _modelControllers[_currentProvider]!.text
                          : '-',
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
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Klik tombol untuk mulai menerjemahkan.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsView(ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
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
            if (provider != null) setState(() => _currentProvider = provider);
          },
        ),
        const SizedBox(height: 20),
        Text(
          'API Key',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        //  UPDATE 1: TAMBAH ONCHANGED DI SINI
        TextField(
          controller: _apiKeyControllers[_currentProvider],
          onChanged: (_) =>
              setState(() {}), // Biar tombol Simpan 'bangun' pas ngetik
          decoration: InputDecoration(
            hintText: 'Paste API key di sini...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          obscureText: true,
        ),

        const SizedBox(height: 16),
        Text(
          'Model',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        //  UPDATE 2: TAMBAH ONCHANGED DI SINI JUGA
        TextField(
          controller: _modelControllers[_currentProvider],
          onChanged: (_) =>
              setState(() {}), // Biar tombol Simpan 'bangun' pas ngetik
          decoration: InputDecoration(
            hintText: AITranslationService.getModelPlaceholder(
              _currentProvider!,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 24),

        //  TOMBOL SIMPAN (LOGIKA WARNA & STATE)
        FilledButton.icon(
          onPressed: _canSave() ? _saveSettings : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _isSaved ? Colors.green : null,
            foregroundColor: _isSaved ? Colors.white : null,
            animationDuration: const Duration(milliseconds: 300),
          ),
          icon: Icon(_isSaved ? Icons.check_circle : Icons.save, size: 20),
          label: Text(_isSaved ? 'Tersimpan!' : 'Simpan Pengaturan'),
        ),

        if (_providerReadiness[_currentProvider] == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: _deleteSettings,
              child: const Text(
                'Hapus Setup',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
      ],
    );
  }

  bool _canSave() =>
      _apiKeyControllers[_currentProvider]!.text.trim().isNotEmpty &&
      _modelControllers[_currentProvider]!.text.trim().isNotEmpty;

  //  UPDATE: VISUAL FEEDBACK DI TOMBOL (NO SNACKBAR)
  Future<void> _saveSettings() async {
    // 1. Tutup Keyboard dulu biar tombol kelihatan jelas
    FocusManager.instance.primaryFocus?.unfocus();

    final key = _apiKeyControllers[_currentProvider]!.text.trim();
    final model = _modelControllers[_currentProvider]!.text.trim();

    await AITranslationService.saveApiKey(_currentProvider!, key);
    await AITranslationService.saveModelName(_currentProvider!, model);
    await AITranslationService.setActiveProvider(_currentProvider!);

    await _initialize();

    if (mounted) {
      // 2. Ubah Tombol jadi HIJAU (Tersimpan!)
      setState(() {
        _isSaved = true;
      });

      // 3. Tunggu 1 detik biar user sadar
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        setState(() {
          _isSaved = false; // Reset tombol

          // Kalau ini mode terjemahan (bukan settingsOnly), tutup panel setting
          if (!widget.settingsOnly) {
            _showSettings = false;
            _translationFuture = null;
          }
        });
      }
    }
  }

  Future<void> _deleteSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Setup?'),
        content: const Text('API Key dan Model akan dihapus.'),
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
      await _initialize();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildErrorState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(msg, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => setState(() => _showSettings = true),
            icon: const Icon(Icons.settings),
            label: const Text('Perbaiki Pengaturan'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
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
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _isCopied = false);
                });
              },
              child: Container(
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
                  ),
                ),
                child: Row(
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectionArea(
          child: MarkdownBody(
            data: text,
            selectable: false,
            styleSheet: MarkdownStyleSheet(
              // Teks Biasa (Hitam)
              p: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: colorScheme.onSurface,
              ),

              // STRONG (**Teks**) -> KITA BAJAK JADI PALI UTAMA (ABU-ABU)
              strong: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.normal, // JANGAN BOLD
                fontStyle: FontStyle.italic, // TAPI MIRING
                color: colorScheme.onSurfaceVariant, // WARNA ABU
                fontSize: 14,
              ),

              // EM (*Teks*) -> UNTUK SISIPAN (HITAM MIRING)
              em: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
                color: colorScheme.secondary,
              ),

              // Bullet Point
              listBullet: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              blockSpacing: 12,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
