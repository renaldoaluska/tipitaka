import 'dart:io';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';

class ShareService {
  // Controller tetep disimpen di sini biar gampang diakses
  static final ScreenshotController _controller = ScreenshotController();
}

//  UBAH NAMA CLASS JADI PUBLIC (Hapus tanda '_' di depan)
class QuoteEditorPage extends StatefulWidget {
  final String text, acronym, title;
  final Color nikayaColor;
  final String? translator;
  final String? verseNum;

  const QuoteEditorPage({
    super.key, // Tambahin super.key biar best practice
    required this.text,
    required this.acronym,
    required this.title,
    required this.nikayaColor,
    this.translator,
    this.verseNum,
  });

  @override
  State<QuoteEditorPage> createState() => _QuoteEditorPageState();
}

class _QuoteEditorPageState extends State<QuoteEditorPage> {
  // Di bagian atas _QuoteEditorPageState
  bool _showShadow = false; // default mati
  // Di dalam _QuoteEditorPageState
  late Color _customBgColor;
  late Color _customTextColor;
  late Color _customAccentColor;

  final List<String> _bgNames = [
    'Pekat', // Solid
    'Pijar', // Linear Gradient
    'Sorot', // Radial Gradient
    'Esensi', // Dynamic Gradient
    'Transparan', // Tanpa BG
  ];

  int _bgStyle = 0;

  bool _isBold = false;
  bool _isItalic = false;
  int _fontIndex = 0;

  final List<String> _fontLabels = ['Serif', 'Sans', 'Mono'];
  // PENGGANTI _fontFamilies
  // Kita paksa pakai font yang support Pāli 100%
  String? get _currentFontFamily {
    switch (_fontIndex) {
      case 0: // Serif
        return GoogleFonts.notoSerif().fontFamily;
      case 1: // Sans
        return GoogleFonts.inter().fontFamily;
      case 2: // Mono
        // Pakai Noto Sans Mono biar karakter Pāli tetep kebaca di mode coding
        return GoogleFonts.notoSansMono().fontFamily;
      default:
        return GoogleFonts.notoSerif().fontFamily;
    }
  }

  TextAlign _textAlign = TextAlign.left;

  late double _fontSize;
  late double _sliderMax;
  double _lineHeight = 1.5;
  double _letterSpacing = 0.0;
  double _paragraphSpacing = 40.0;

  final ScrollController _scrollController = ScrollController();
  late String _displayText;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    // Set default awal
    _customBgColor = Colors.white;
    _customTextColor = Colors.black.withValues(alpha: 0.9);
    _customAccentColor = widget.nikayaColor;

    _displayText = _formatQuoteText(widget.text);
    //  UBAH INI: Pake LockedTextController biar berwarna
    _textController = LockedTextController(text: _displayText);
    _calculateInitialFontSize(); // Dipisah biar bisa dipanggil tombol reset
    _loadPreferences();
  }

  void _calculateInitialFontSize() {
    final int length = _displayText.length;

    if (length > 800) {
      _sliderMax = 70.0;
      _fontSize = 32.0;
    } else if (length > 600) {
      _sliderMax = 90.0;
      _fontSize = 36.0;
    } else if (length > 150) {
      // --- TITAH 44 (Harga Mati) ---
      // Range 151 - 600 karakter dikunci di sini.
      _sliderMax = 160.0;
      _fontSize = 44.0;
    } else {
      // --- ZONA LEGA (Teks Pendek < 150) ---
      // Karena lega, kita gaspol ke 66 biar menuhin layar dan estetik!
      _sliderMax = 250.0;
      _fontSize = 66.0;
    }

    _fontSize = _fontSize.clamp(20.0, _sliderMax);
  }

  void _resetFormatting() {
    setState(() {
      _calculateInitialFontSize();
      _lineHeight = 1.5;
      _letterSpacing = 0.0;
      _paragraphSpacing = 40.0;
    });
    _savePreferences();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quote_share_v4_show_shadow', _showShadow);
    await prefs.setDouble('quote_share_v4_font_size', _fontSize);
    await prefs.setDouble('quote_share_v4_line_height', _lineHeight);
    await prefs.setDouble('quote_share_v4_letter_spacing', _letterSpacing);
    await prefs.setDouble('quote_share_v4_para_spacing', _paragraphSpacing);
    await prefs.setBool('quote_share_v4_is_bold', _isBold);
    await prefs.setBool('quote_share_v4_is_italic', _isItalic);
    await prefs.setInt('quote_share_v4_font_index', _fontIndex);
    await prefs.setInt('quote_share_v4_bg_style', _bgStyle);
    await prefs.setInt('quote_share_v4_text_align', _textAlign.index);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 1. Hitung max slider dulu (PENTING)
      _calculateInitialFontSize();

      // 2. Load Boolean (Aman)
      _showShadow = prefs.getBool('quote_share_v4_show_shadow') ?? false;
      _isBold = prefs.getBool('quote_share_v4_is_bold') ?? false;
      _isItalic = prefs.getBool('quote_share_v4_is_italic') ?? false;

      // 3. Load Double (Aman dengan default)
      // Khusus font size di-clamp biar gak meledak
      _fontSize = (prefs.getDouble('quote_share_v4_font_size') ?? _fontSize)
          .clamp(20.0, _sliderMax);

      _lineHeight = prefs.getDouble('quote_share_v4_line_height') ?? 1.5;
      _letterSpacing = prefs.getDouble('quote_share_v4_letter_spacing') ?? 0.0;
      _paragraphSpacing =
          prefs.getDouble('quote_share_v4_para_spacing') ?? 40.0;

      // 4. Load List Index (HARUS DI-CLAMP BIAR GAK CRASH)

      // Background (Sudah benar ada clamp)
      _bgStyle = (prefs.getInt('quote_share_v4_bg_style') ?? 0).clamp(
        0,
        _bgNames.length - 1,
      );

      //  Font Index (TAMBAHKAN CLAMP INI)
      // Biar kalau indexnya 99, dipaksa turun ke max font yang ada
      _fontIndex = (prefs.getInt('quote_share_v4_font_index') ?? 0).clamp(
        0,
        _fontLabels.length - 1,
      );

      //  Text Align (TAMBAHKAN CLAMP INI)
      // Biar gak error RangeError kalau enum TextAlign berubah
      int alignIdx = (prefs.getInt('quote_share_v4_text_align') ?? 0).clamp(
        0,
        TextAlign.values.length - 1,
      );
      _textAlign = TextAlign.values[alignIdx];
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _getFormattedTranslator(String? name) {
    if (name == null) return "";
    return name.replaceAll(
      'Mahāsaṅgīti Tipiṭaka Buddhavasse 2500',
      'Mahāsaṅgīti Tipiṭaka',
    );
  }

  //  HELPER: AUTO-WRAP FORMATTING
  void _applySelectionFormatting(String symbol) {
    final text = _textController.text;
    final selection = _textController.selection;

    // 1. Cek validasi: Harus ada teks yang diblok
    if (!selection.isValid || selection.isCollapsed) return;

    // 2. Ambil teks yang diblok
    final selectedContent = text.substring(selection.start, selection.end);

    // 3. Bungkus teks (Contoh: "Aku" jadi "*Aku*")
    // Logic pembungkus khusus untuk // (biar gak dobel //..//)
    final String wrapped;
    if (symbol == '//') {
      wrapped = '//$selectedContent//';
    } else {
      wrapped = '$symbol$selectedContent$symbol';
    }

    // 4. Update Controller
    // Kita ganti range seleksi dengan teks baru yang udah dibungkus
    final newText = text.replaceRange(selection.start, selection.end, wrapped);

    // 5. Update Value & Pindahin Kursor ke akhir bungkusan
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            selection.end + (symbol == '//' ? 4 : 2), // Sesuaikan offset kursor
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "Edit Teks",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                maxLines: null,
                style: const TextStyle(color: Colors.white),

                // Satpam Integritas (Tetap Ada)
                inputFormatters: [ImmutableTextFormatter()],

                //  MENU PINTAR SAAT SELEKSI (CONTEXT MENU)
                contextMenuBuilder: (context, editableTextState) {
                  // 1. Ambil menu bawaan (Copy, Select All)
                  final List<ContextMenuButtonItem> buttonItems =
                      editableTextState.contextMenuButtonItems;

                  // Hapus Cut & Paste (Biar gak ngerusak integritas / ribet)
                  buttonItems.removeWhere(
                    (item) =>
                        item.type == ContextMenuButtonType.cut ||
                        item.type == ContextMenuButtonType.paste,
                  );

                  // 2. Tambah Tombol Formatting Kita di POSISI PERTAMA
                  buttonItems.insert(
                    0,
                    ContextMenuButtonItem(
                      label: 'Tebal', // *...*
                      onPressed: () {
                        editableTextState.hideToolbar(); // Tutup menu
                        _applySelectionFormatting('*');
                      },
                    ),
                  );

                  buttonItems.insert(
                    1,
                    ContextMenuButtonItem(
                      label: 'Miring', // _..._
                      onPressed: () {
                        editableTextState.hideToolbar();
                        _applySelectionFormatting('_');
                      },
                    ),
                  );

                  buttonItems.insert(
                    2,
                    ContextMenuButtonItem(
                      label: 'Aksen', // //...//
                      onPressed: () {
                        editableTextState.hideToolbar();
                        _applySelectionFormatting('//');
                      },
                    ),
                  );

                  // 3. Render Menu Platform-Adaptive (Android/iOS style)
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: editableTextState.contextMenuAnchors,
                    buttonItems: buttonItems,
                  );
                },

                decoration: const InputDecoration(
                  hintText: "tulis kutipan di sini...",
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const Text(
                "💡 TIPS PEMFORMATAN:",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                //  TAMBAHAN DI BARIS TERAKHIR:
                "• *teks* = Tebal\n"
                "• _teks_ = Miring\n"
                "• //teks// = Warna Aksen\n"
                "• Spasi dan enter bisa diedit\n" // <--- UPDATE KALIMAT INI
                "• Isi ayat tak bisa diedit",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            // PERBAIKAN: Pakai _formatQuoteText biar balik ke format awal yang bener
            onPressed: () => setState(
              () => _textController.text = _formatQuoteText(widget.text),
            ),
            child: const Text(
              "Reset",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _displayText = _textController.text);
              Navigator.pop(ctx);
            },
            child: const Text(
              "Selesai",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  //  CLEANER: JANGAN HAPUS \n\n YANG SUDAH KITA SET DI SUTTA_DETAIL
  String _formatQuoteText(String input) {
    if (input.isEmpty) return "";
    // Cuma hapus kalau enter-nya lebay (3x atau lebih)
    return input.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Gradient _getSelectedGradient() {
    final String name = _bgNames[_bgStyle];
    if (name == 'Transparan') {
      return const LinearGradient(
        colors: [Colors.transparent, Colors.transparent],
      );
    }

    //  kuncinya di sini: campur warna latar sama warna aksen
    // accentMix1: 15% warna aksen (halus buat pijar/sorot)
    // accentMix2: 35% warna aksen (lebih tegas buat esensi)
    final Color accentMix1 = Color.lerp(
      _customBgColor,
      _customAccentColor,
      0.25,
    )!;
    final Color accentMix2 = Color.lerp(
      _customBgColor,
      _customAccentColor,
      0.45,
    )!;

    switch (name) {
      case 'Pijar':
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accentMix1, _customBgColor],
        );
      case 'Sorot':
        return RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.2,
          colors: [accentMix1, _customBgColor],
        );
      case 'Esensi':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentMix2, _customBgColor],
        );
      default: // Pekat
        return LinearGradient(colors: [_customBgColor, _customBgColor]);
    }
  }

  void _showColorPicker(int type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          type == 0
              ? "Warna Latar"
              : (type == 1 ? "Warna Teks" : "Warna Aksen"),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                children: AppPalettes.categories.entries.map((entry) {
                  return _buildColorCategory(ctx, entry.key, entry.value, type);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper buat item warna di dalam dialog
  Widget _buildColorCategory(
    BuildContext ctx,
    String name,
    List<Color> colors,
    int type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            name.toUpperCase(),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    setState(() {
                      if (type == 0) {
                        _customBgColor = c;
                      } else if (type == 1) {
                        _customTextColor = c;
                      } else {
                        _customAccentColor = c;
                      }
                    });
                    Navigator.pop(ctx);
                    _savePreferences();
                  },
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _getFormattedAcronym(String acronym) {
    if (acronym.isEmpty) return "";
    final regex = RegExp(r'^([a-zA-Z]+)(.*)$');
    final match = regex.firstMatch(acronym.trim());
    if (match == null) return acronym;
    String letters = match.group(1)!;
    String remainder = match.group(2)!;
    String lowerLetters = letters.toLowerCase();
    const allCapsKitab = ['dn', 'mn', 'sn', 'an'];
    String formattedLetters = allCapsKitab.contains(lowerLetters)
        ? lowerLetters.toUpperCase()
        : lowerLetters[0].toUpperCase() +
              lowerLetters.substring(1).toLowerCase();
    return formattedLetters + remainder;
  }

  //  PARSER VISUAL: Update //...// jadi Warna Only
  List<TextSpan> _parseInlineStyles(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r'(//|\*|_)(.*?)\1'); // Regex tetep sama

    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      // 1. Teks Biasa
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      // 2. Teks Formatting
      final marker = match.group(1);
      final content = match.group(2)!;
      TextStyle newStyle = baseStyle;

      if (marker == '*') {
        newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
      } else if (marker == '_') {
        newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
      } else if (marker == '//') {
        //  UPDATE DI SINI: Hapus fontStyle.italic
        newStyle = newStyle.copyWith(
          //  color: widget.nikayaColor,
          color: _customAccentColor, // Gunakan variabel state kustom kita
          // fontStyle: FontStyle.italic, <--- DIBUANG
        );
      }

      // Rekursif (tetep support nesting)
      spans.addAll(_parseInlineStyles(content, newStyle));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }

  // Tambahin fungsi ini di dalam _QuoteEditorState
  Future<void> _confirmExit() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A), // Gelap biar senada
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Keluar dari Editor?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Perubahan yang belum disimpan akan hilang",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // Pilih Batal
            child: const Text(
              "Lanjut Edit",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // Pilih Keluar
            child: const Text(
              "Keluar",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    // Kalau user pilih "Keluar" (true), baru kita tutup halaman editornya
    if (shouldPop == true) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      // HAPUS AnnotatedRegion DI SINI, LANGSUNG SCAFFOLD
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.black,

          // --- UPDATE SYSTEM OVERLAY STYLE ---
          systemOverlayStyle: const SystemUiOverlayStyle(
            // Ganti dari transparent jadi black biar tegas
            statusBarColor: Colors.black,

            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          // -----------------------------------

          // ------------------------
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _confirmExit,
          ),
          title: const Text(
            "Editor",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: _saveImage,
              child: const Text(
                "SIMPAN",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _generateAndShare,
              child: const Text(
                "BAGIKAN",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // --- LAYER 1: VISUAL CHECKERBOARD (GAK KESIMPEN) ---
                        // Cuma muncul kalau mode Transparan
                        if (_bgNames[_bgStyle] == 'Transparan')
                          Positioned.fill(
                            child: CustomPaint(painter: _CheckerBoardPainter()),
                          ),

                        // --- LAYER 2: TARGET SCREENSHOT (KESIMPEN) ---
                        // Ini "Daging"-nya. Cuma widget ini yang difoto sama controller.
                        Screenshot(
                          controller: ShareService._controller,
                          child: _buildFinalCard(),
                        ),

                        // --- LAYER 3: BADGE PREVIEW (GAK KESIMPEN) ---
                        // Biar user tau ini transparan, bukan error item doang
                        if (_bgNames[_bgStyle] == 'Transparan')
                          Positioned(
                            top: 40,
                            right: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.grid_on_rounded,
                                    color: Colors.white70,
                                    size: 50,
                                  ),
                                  SizedBox(width: 20),
                                  Text(
                                    "TRANSPARAN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- BARU: TOMBOL RESET ALL-IN-ONE ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetFormatting,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Reset Ukuran",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // -------------------------------------
                    _buildSliderRow(
                      Icons.format_size,
                      _fontSize,
                      20,
                      _sliderMax,
                      "${_fontSize.toInt()}pt",
                      (v) {
                        setState(() => _fontSize = v);
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSliderRow(
                      Icons.format_line_spacing,
                      _lineHeight,
                      0.8,
                      2.5,
                      "${_lineHeight.toStringAsFixed(1)}lh",
                      (v) {
                        setState(() => _lineHeight = v);
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 8),

                    // CEK APAKAH ADA LEBIH DARI 1 PARAGRAF
                    // Kita cek simpel aja: kalau ada '\n\n', berarti minimal 2 paragraf
                    Builder(
                      builder: (context) {
                        final bool hasMultiParagraphs = _displayText
                            .trim()
                            .contains('\n\n');

                        return _buildSliderRow(
                          Icons.unfold_more_rounded,
                          _paragraphSpacing,
                          0,
                          200,
                          "${_paragraphSpacing.toInt()}px",
                          (v) {
                            setState(() => _paragraphSpacing = v);
                            _savePreferences();
                          },
                          // Kirim status enabled ke sini
                          enabled: hasMultiParagraphs,
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    _buildSliderRow(
                      Icons.format_indent_increase,
                      _letterSpacing,
                      -2,
                      10,
                      "${_letterSpacing.toInt()}ls",
                      (v) {
                        setState(() => _letterSpacing = v);
                        _savePreferences();
                      },
                    ),

                    const SizedBox(height: 16),
                    Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 3,
                      radius: const Radius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // --- GRUP 1: EDITING (FORMAT) ---
                              _buildCircularIconButton(
                                "Format",
                                Icons.edit_note_rounded,
                                _showEditDialog,
                              ),

                              const SizedBox(width: 12),

                              // --- GRUP 2: PICKER WARNA (BG, TEKS, AKSEN) ---
                              _buildColorPreviewBox(
                                "Latar",
                                _customBgColor,
                                () => _showColorPicker(0),
                              ),

                              const SizedBox(width: 12),
                              _buildColorPreviewBox(
                                "Teks",
                                _customTextColor,
                                () => _showColorPicker(1),
                              ),

                              //  if (_displayText.contains('//')) ...[
                              const SizedBox(width: 12),
                              _buildColorPreviewBox(
                                "Aksen",
                                _customAccentColor,
                                () => _showColorPicker(2),
                              ),

                              //   ],
                              _buildVerticalDivider(), // <--- Pake helper biar gak menuhi Row
                              // --- GRUP 3: TEMA & LAYOUT ---
                              _buildStyleToggle(
                                _bgNames[_bgStyle],
                                true,
                                Icons.auto_awesome_motion,
                                () {
                                  _updateState(
                                    () => _bgStyle =
                                        (_bgStyle + 1) % _bgNames.length,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildStyleToggle(
                                _getAlignLabel(),
                                true,
                                _getAlignIcon(),
                                () {
                                  _updateState(() {
                                    if (_textAlign == TextAlign.left) {
                                      _textAlign = TextAlign.center;
                                    } else if (_textAlign == TextAlign.center) {
                                      _textAlign = TextAlign.right;
                                    } else {
                                      _textAlign = TextAlign.left;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildStyleToggle(
                                _fontLabels[_fontIndex],
                                true,
                                Icons.font_download_rounded,
                                () {
                                  _updateState(
                                    () => _fontIndex = (_fontIndex + 1) % 3,
                                  );
                                },
                              ),

                              _buildVerticalDivider(),

                              // --- GRUP 4: TYPOGRAPHY ---
                              _buildStyleToggle(
                                'Bayangan', // Label tombol
                                _showShadow,
                                Icons.layers_outlined,
                                () => _updateState(
                                  () => _showShadow = !_showShadow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStyleToggle(
                                'Tebal',
                                _isBold,
                                Icons.format_bold,
                                () {
                                  _updateState(() => _isBold = !_isBold);
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildStyleToggle(
                                'Miring',
                                _isItalic,
                                Icons.format_italic,
                                () {
                                  _updateState(() => _isItalic = !_isItalic);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateState(VoidCallback action) {
    setState(action);
    _savePreferences();
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white24,
    );
  }

  Widget _buildSliderRow(
    IconData icon,
    double value,
    double min,
    double max,
    String label,
    Function(double) onChanged, {
    bool enabled = true,
  }) {
    // 1. Tentukan warna visual biar user tau ini lagi mati
    final Color mainColor = enabled ? Colors.white : Colors.white24;
    final Color iconColor = enabled ? Colors.white70 : Colors.white24;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                // Kita set warna track-nya manual biar pas disabled beneran keliatan redup
                activeTrackColor: enabled ? widget.nikayaColor : Colors.white24,
                inactiveTrackColor: Colors.white10,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                // HAPUS disabledThumbShape YANG BIKIN ERROR
                // Flutter otomatis nanganin tampilan disabled kok
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                activeColor: widget.nikayaColor,
                // INI KUNCINYA:
                // Kalau enabled = false, onChanged jadi null.
                // Saat onChanged null, Slider otomatis disabled & warnanya redup.
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(color: mainColor, fontSize: 10),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAlignIcon() => _textAlign == TextAlign.left
      ? Icons.format_align_left
      : (_textAlign == TextAlign.center
            ? Icons.format_align_center
            : Icons.format_align_right);
  String _getAlignLabel() => _textAlign == TextAlign.left
      ? 'Kiri'
      : (_textAlign == TextAlign.center ? 'Tengah' : 'Kanan');
  Widget _buildStyleToggle(
    String label,
    bool isActive,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? widget.nikayaColor.withValues(alpha: 0.3)
              : Colors.white10,
          border: Border.all(
            color: isActive ? widget.nikayaColor : Colors.white30,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIconButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white10, // warna dasar lingkaran
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 9),
          ),
        ],
      ),
    );
  }

  String _simplifyVerse(String? v) {
    if (v == null) return "";

    // 1. handle berbagai jenis dash (minus, en-dash, em-dash)
    final dashPattern = RegExp(r'[-–—]');
    if (!v.contains(dashPattern)) return v;

    final List<String> range = v.split(dashPattern);
    if (range.length != 2) return v;

    String s = range[0].trim();
    String e = range[1].trim();

    // cari pemisah terakhir (titik atau titik dua)
    int lastS = s.lastIndexOf(RegExp(r'[:\.]'));
    int lastE = e.lastIndexOf(RegExp(r'[:\.]'));

    if (lastE == -1 || lastS == -1) return v;

    String sPrefix = s.substring(0, lastS);
    String ePrefix = e.substring(0, lastE);
    String eSuffix = e.substring(lastE + 1);
    String sepS = s.substring(lastS, lastS + 1);
    String sepE = e.substring(lastE, lastE + 1);

    // bersihin karakter non-angka di awal (biar ":1" jadi "1")
    String cleanS = sPrefix.replaceAll(RegExp(r'^[^0-9]+'), '');
    String cleanE = ePrefix.replaceAll(RegExp(r'^[^0-9]+'), '');

    // debug di console biar lo tau isinya apa
    debugPrint("S: $cleanS | E: $cleanE | Sep: $sepS");

    if (cleanS == cleanE && sepS == sepE) {
      if (sepS == ':' && eSuffix.contains('.')) return v;
      return "$s-$eSuffix"; // return pake dash standar
    }

    return v;
  }

  Widget _buildFinalCard() {
    final String name = _bgNames[_bgStyle];
    final bool isTransparent = name == 'Transparan';
    // final bool isWhiteBG = name == 'Putih Bersih' || name == 'Pijar Nikaya';

    final paragraphs = _displayText
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    double xOffset = 0;
    if (_textAlign == TextAlign.left) {
      xOffset = -12.0;
    } else if (_textAlign == TextAlign.right) {
      xOffset = 12.0;
    }

    // Helper Shadow: Muncul cuma kalau mode transparan atau background gelap
    // Biar kalau ditempel di foto terang, tulisan tetap kebaca

    /* List<Shadow> safeShadows = (isTransparent || !isWhiteBG)
        ? [
          
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ]
        : [];
*/
    List<Shadow> quoteShadows = _showShadow
        ? [
            // lapis 1: untuk mempertegas pinggiran huruf (kontur)
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
            // lapis 2: sebaran halus biar teks "lepas" dari background
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 2),
              blurRadius: 10, // blur tinggi bikin efek halus
            ),
          ]
        : [];

    return ClipRect(
      child: Container(
        width: 1080,
        height: 1920,
        decoration: BoxDecoration(
          // Jika transparan, tetap transparan. Jika tidak, pakai warna kustom kamu.
          color: isTransparent ? Colors.transparent : _customBgColor,
          //  color: baseColor,
          gradient:
              _getSelectedGradient(), // Pastikan ini return transparent juga
        ),
        child: Stack(
          children: [
            // --- IKON QUOTE ---
            Positioned(
              top: 80,
              left: 100,
              right: 100,
              child: SizedBox(
                height: 150,
                child: Align(
                  alignment: _textAlign == TextAlign.left
                      ? Alignment.bottomLeft
                      : (_textAlign == TextAlign.center
                            ? Alignment.bottomCenter
                            : Alignment.bottomRight),
                  child: Transform.translate(
                    offset: Offset(xOffset, 0),
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Transform.scale(
                        scaleX: _textAlign == TextAlign.right ? -1 : 1,
                        child: Icon(
                          Icons.format_quote_rounded,
                          //  color: widget.nikayaColor,
                          color:
                              _customAccentColor, //  Pakai warna aksen kustom
                          size: 120,
                          // Shadow buat ikon
                          //    shadows: safeShadows,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- TEKS UTAMA ---
            Positioned(
              top: 240,
              bottom: 320,
              left: 100,
              right: 100,
              child: ClipRect(
                child: OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: _textAlign == TextAlign.left
                        ? CrossAxisAlignment.start
                        : (_textAlign == TextAlign.center
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.end),
                    children: paragraphs.asMap().entries.map((entry) {
                      int idx = entry.key;
                      bool isLast = idx == paragraphs.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: isLast ? 0 : _paragraphSpacing,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: _parseInlineStyles(
                              entry.value,
                              TextStyle(
                                color:
                                    _customTextColor, //  Pakai warna teks kustom
                                //color: mainTextColor,
                                fontSize: _fontSize,
                                fontStyle: _isItalic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                fontWeight: _isBold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontFamily: _currentFontFamily,
                                height: _lineHeight,
                                letterSpacing: _letterSpacing,
                                shadows: quoteShadows, // APPLY SHADOW
                              ),
                            ),
                          ),
                          textAlign: _textAlign,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // --- FOOTER ---
            Positioned(
              bottom: 80,
              left: 100,
              right: 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: _textAlign == TextAlign.left
                    ? CrossAxisAlignment.start
                    : (_textAlign == TextAlign.center
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.end),
                children: [
                  Container(
                    width: 120,
                    height: 6,
                    // HAPUS 'color' DI SINI, PINDAH KE DALAM DECORATION
                    decoration: BoxDecoration(
                      // color: widget.nikayaColor, // <--- Pindah ke sini
                      color: _customAccentColor, //  Pakai warna aksen kustom
                      boxShadow: isTransparent
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: _customAccentColor, //  Ganti ke Aksen
                      // color: _customTextColor, //  Pakai warna teks kustom
                      // color: isWhiteBG ? Colors.black : Colors.white,
                      //  shadows: quoteShadows, // APPLY SHADOW
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: _textAlign,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        // shadows: safeShadows, // APPLY SHADOW
                      ),
                      children: [
                        TextSpan(
                          text: _getFormattedAcronym(widget.acronym),
                          //style: TextStyle(color: widget.nikayaColor),
                          style: TextStyle(
                            color: _customAccentColor,
                          ), //  Pakai warna aksen kustom
                        ),
                        if (widget.verseNum != null)
                          TextSpan(
                            text: " ${_simplifyVerse(widget.verseNum)}",
                            style: TextStyle(
                              color: _customAccentColor,
                              fontWeight: FontWeight.normal,
                              //   color: _customTextColor.withValues(alpha: 0.6),
                            ),
                            //  style: TextStyle(color: subTextColor),
                          ),
                        if (widget.translator != null) ...[
                          TextSpan(
                            text: "  •  ",
                            style: TextStyle(
                              //color: widget.nikayaColor.withValues(alpha: 0.6),
                              //color: _customAccentColor.withValues(alpha: 0.6),
                              color: _customAccentColor,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          TextSpan(
                            text: _getFormattedTranslator(widget.translator),
                            style: TextStyle(
                              //  Ganti ke Aksen Redup
                              color: _customAccentColor.withValues(alpha: 1),
                              // color: _customTextColor.withValues(alpha: 0.7),
                              //          color: isWhiteBG ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    textAlign: _textAlign,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "via myDhamma",
                    style: TextStyle(
                      //  Ganti ke Aksen Tipis
                      color: _customAccentColor,
                      fontWeight: FontWeight.w300,
                      // color: _customTextColor.withValues(alpha: 0.5),
                      //   color: signatureColor,
                      fontSize: 30,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                      // shadows: safeShadows, // APPLY SHADOW
                    ),
                    textAlign: _textAlign,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndShare() async {
    final image = await ShareService._controller.capture(
      pixelRatio: 1.0,
      delay: const Duration(milliseconds: 100),
    );
    if (image == null) return;
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/dhamma_quote_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(image);
    if (!mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _saveImage() async {
    final image = await ShareService._controller.capture(
      pixelRatio: 1.0,
      delay: const Duration(milliseconds: 100),
    );
    if (image == null) return;
    try {
      if (!(await Gal.hasAccess())) await Gal.requestAccess();
      await Gal.putImageBytes(Uint8List.fromList(image));
      _showSnackBar('Gambar berhasil disimpan!');
    } catch (e) {
      _showSnackBar('Gagal menyimpan gambar.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Widget _buildColorPreviewBox(String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 2),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
      ],
    ),
  );
}

// Taro di baris paling akhir file share.dart
class _CheckerBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0xFF222222);
    // Warna selang-selingnya gelap (0xFF222222),
    // Warna dasarnya udah gelap dari Scaffold (0xFF0F0F0F).

    const double squareSize = 20.0; // Ukuran kotak

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        // Logika ganjil-genap buat selang-seling
        if ((x / squareSize).floor() % 2 == (y / squareSize).floor() % 2) {
          canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  SATPAM INTEGRITAS AYAT
// Class ini memastikan user TIDAK BISA mengubah satu huruf pun dari ayat asli.
// User cuma boleh nambah/hapus: Spasi, Enter, Bintang (*), Underscore (_), dan Garis Miring (/).
class ImmutableTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Fungsi buat "telanjangi" teks (buang semua formatting & spasi)
    // Kita buang: Spasi (\s), Bintang (*), Underscore (_), Garis Miring (/)
    String stripFormatting(String s) {
      return s.replaceAll(RegExp(r'[\s\*_/]+'), '');
    }

    // 2. Bandingkan "Daging"-nya
    final String coreOld = stripFormatting(oldValue.text);
    final String coreNew = stripFormatting(newValue.text);

    // 3. LOGIC HAKIM:
    // Kalau dagingnya sama persis, berarti user cuma mainan formatting -> IZINKAN (Return newValue)
    if (coreOld == coreNew) {
      return newValue;
    }

    // Kalau dagingnya beda (ada huruf keganti/kehapus) -> TOLAK (Balikin ke oldValue)
    // Efeknya: User ngetik huruf/backspace huruf, tapi gak ngefek apa-apa di layar.
    return oldValue;
  }
}

//  CONTROLLER PINTAR: SPASI KUNING (ENTER POLOS)
class LockedTextController extends TextEditingController {
  LockedTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final regex = RegExp(r'([\*_/]|\s)');

    text.splitMapJoin(
      regex,
      onMatch: (Match m) {
        final String match = m[0]!;

        // 1. ENTER (\n) -> BIARKAN POLOS
        // Gak usah dikasih background/style apa-apa.
        if (match == '\n') {
          children.add(TextSpan(text: match, style: style));
          return "";
        }

        // 2. SPASI (' ') -> BACKGROUND KUNING TIPIS
        if (match == ' ') {
          children.add(
            TextSpan(
              text: match,
              style: style?.copyWith(
                backgroundColor: Colors.amberAccent.withValues(alpha: 0.25),
              ),
            ),
          );
          return "";
        }

        // 3. SIMBOL (* _ /) -> WARNA EMAS
        children.add(
          TextSpan(
            text: match,
            style: style?.copyWith(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        return "";
      },
      onNonMatch: (String s) {
        // AYAT (Daging) -> ABU REDUP
        children.add(
          TextSpan(
            text: s,
            style: style?.copyWith(color: Colors.white38),
          ),
        );
        return "";
      },
    );

    return TextSpan(style: style, children: children);
  }
}
