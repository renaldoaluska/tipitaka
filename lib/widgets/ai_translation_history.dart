import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; //  1. IMPORT WAJIB
import '../services/ai_translation.dart';

class TranslationHistorySheet extends StatefulWidget {
  const TranslationHistorySheet({super.key});

  @override
  State<TranslationHistorySheet> createState() =>
      _TranslationHistorySheetState();
}

class _TranslationHistorySheetState extends State<TranslationHistorySheet> {
  late Future<List<TranslationHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = AITranslationService.getHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Colors.deepPurple.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Riwayat Terjemah AI",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Clear All Button
                        FutureBuilder<List<TranslationHistory>>(
                          future: _historyFuture,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              return InkWell(
                                onTap: () => _showClearAllDialog(),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.delete_sweep,
                                    color: Colors.red.shade400,
                                    size: 22,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(width: 8),
                        // Close Button
                        InkWell(
                          onTap: () => Navigator.pop(context),
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

              // CONTENT
              Expanded(
                child: FutureBuilder<List<TranslationHistory>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState('Error: ${snapshot.error}');
                    }

                    final history = snapshot.data ?? [];

                    if (history.isEmpty) {
                      return _buildEmptyState(colorScheme);
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryItem(history[index], colorScheme);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getProviderColor(String providerName) {
    final name = providerName.toLowerCase();
    if (name.contains('gemini')) return Colors.blue.shade600;
    if (name.contains('openai') || name.contains('gpt')) {
      return Colors.green.shade600;
    }
    if (name.contains('anthropic') || name.contains('claude')) {
      return Colors.orange.shade800;
    }
    return Colors.purple.shade400;
  }

  Widget _buildHistoryItem(TranslationHistory item, ColorScheme colorScheme) {
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final providerColor = _getProviderColor(item.provider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () => _showDetailDialog(item, colorScheme),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: providerColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: providerColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            item.provider,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: providerColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.model,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateFormat.format(item.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.originalText,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Preview Terjemahan (Bersih tanpa karakter markdown)
              Text(
                item.translatedText.replaceAll('**', '').replaceAll('*', ''),
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat terjemahan',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  //  UPDATE: VISUAL FEEDBACK LANGSUNG DI TOMBOL (TANPA SNACKBAR)
  void _showDetailDialog(TranslationHistory item, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) {
        // Kita butuh state lokal di dalam dialog untuk ubah tombol jadi hijau
        bool isCopied = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.history, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text("Detail Riwayat", style: TextStyle(fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // INFO BOX (PROVIDER & MODEL - VERTIKAL)
                    // INFO BOX (LAYOUT BARU: Provider & Tanggal Sejajar, Model di Bawah)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        // horizontal: 12,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BARIS 1: Provider (Kiri) & Tanggal (Kanan)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Nama Provider
                              Row(
                                children: [
                                  Icon(
                                    Icons.dns_rounded,
                                    size: 12,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.provider,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),

                              // Tanggal
                              Text(
                                DateFormat(
                                  'dd MMM, HH:mm',
                                ).format(item.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 6,
                          ), // Jarak antara Header dan Model
                          // BARIS 2: Nama Model (Full Width di Bawah)
                          // Kita kasih background tipis biar kelihatan kayak "badge"
                          // ✅ CUKUP GANTI CONTAINER INI AJA
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SelectableText(
                              // 👈 Pakai SelectableText biar bisa dicopy
                              item.model,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: colorScheme.onSurfaceVariant,
                              ),
                              // maxLines & overflow dihapus biar kalau panjang, dia turun ke bawah (wrap)
                              // dan user bisa blok semuanya.
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      'TEKS ASLI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      item.originalText,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const Divider(height: 24),

                    Text(
                      'TERJEMAHAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    SelectionArea(
                      child: MarkdownBody(
                        data: item.translatedText,
                        selectable: false,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                          strong: TextStyle(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.normal,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          em: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.normal,
                            color: colorScheme.secondary,
                          ),
                          listBullet: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          blockSpacing: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteItem(item.id);
                  },
                  child: Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                ),

                // 🔥 TOMBOL SALIN YANG BERUBAH WARNA
                FilledButton.icon(
                  onPressed: () async {
                    // 1. Salin ke Clipboard
                    await Clipboard.setData(
                      ClipboardData(text: item.translatedText),
                    );

                    // 2. Ubah tampilan tombol jadi Hijau "Tersalin!"
                    setDialogState(() {
                      isCopied = true;
                    });

                    // 3. Tunggu 1 detik biar user sadar
                    await Future.delayed(const Duration(milliseconds: 1000));

                    // 4. Baru tutup dialog
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  // Logika Warna: Kalau isCopied = Hijau, Kalau belum = Default Primary
                  style: FilledButton.styleFrom(
                    backgroundColor: isCopied ? Colors.green : null,
                    foregroundColor: isCopied ? Colors.white : null,
                    animationDuration: const Duration(milliseconds: 300),
                  ),
                  icon: Icon(
                    isCopied ? Icons.check_circle : Icons.copy,
                    size: 16,
                  ),
                  label: Text(isCopied ? 'Tersalin!' : 'Salin'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Item?'),
        content: const Text('Terjemahan ini akan dihapus dari riwayat.'),
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
      await AITranslationService.deleteHistoryItem(id);
      _loadHistory();
    }
  }

  Future<void> _showClearAllDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text('Semua riwayat terjemahan akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AITranslationService.clearHistory();
      _loadHistory();
    }
  }
}
