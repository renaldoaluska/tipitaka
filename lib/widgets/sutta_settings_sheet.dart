import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reader_enums.dart';
import '../utils/app_colors.dart';

class SuttaSettingsSheet extends StatefulWidget {
  final bool isSegmented;
  final String lang;
  final bool isRootOnly;

  // State Awal (Diterima dari Parent)
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final String fontType;
  final ViewMode viewMode;
  final ReaderTheme readerTheme;
  final bool? showVerseNumbers;

  // ðŸ†• CUSTOM COLORS
  final Color customBgColor;
  final Color customTextColor;
  final Color customPaliColor;

  // Callback (Lapor balik ke Parent)
  final Function(double) onFontSizeChanged;
  final Function(double) onLineHeightChanged;
  final Function(double) onPaddingChanged;
  final Function(String) onFontTypeChanged;
  final Function(ViewMode) onViewModeChanged;
  final Function(ReaderTheme) onThemeChanged;
  final Function(bool)? onShowVerseNumbersChanged;

  // ðŸ†• CALLBACK CUSTOM COLORS
  final Function(Color, Color, Color) onCustomColorsChanged;

  const SuttaSettingsSheet({
    super.key,
    required this.isSegmented,
    required this.lang,
    required this.isRootOnly,
    required this.fontSize,
    required this.lineHeight,
    required this.horizontalPadding,
    required this.fontType,
    required this.viewMode,
    required this.readerTheme,
    required this.customBgColor,
    required this.customTextColor,
    required this.customPaliColor,
    this.showVerseNumbers,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onPaddingChanged,
    required this.onFontTypeChanged,
    required this.onViewModeChanged,
    required this.onThemeChanged,
    required this.onCustomColorsChanged,
    this.onShowVerseNumbersChanged,
  });

  @override
  State<SuttaSettingsSheet> createState() => _SuttaSettingsSheetState();
}

class _SuttaSettingsSheetState extends State<SuttaSettingsSheet> {
  // Kita simpan state lokal biar UI responsif pas digeser-geser
  late double _fontSize;
  late double _lineHeight;
  late double _horizontalPadding;
  late String _fontType;
  late ViewMode _viewMode;
  late ReaderTheme _readerTheme;
  late bool? _showVerseNumbers;

  // ðŸ†• LOCAL STATE UNTUK CUSTOM COLORS
  late Color _customBgColor;
  late Color _customTextColor;
  late Color _customPaliColor;

  @override
  void initState() {
    super.initState();
    _syncState();
  }

  // ðŸ†• SYNC STATE DARI PARENT (Penting untuk didUpdateWidget)
  @override
  void didUpdateWidget(covariant SuttaSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.horizontalPadding != widget.horizontalPadding ||
        oldWidget.readerTheme != widget.readerTheme ||
        oldWidget.viewMode != widget.viewMode ||
        oldWidget.fontType != widget.fontType ||
        oldWidget.customBgColor != widget.customBgColor ||
        oldWidget.customTextColor != widget.customTextColor ||
        oldWidget.customPaliColor != widget.customPaliColor ||
        oldWidget.showVerseNumbers != widget.showVerseNumbers) {
      setState(() => _syncState());
    }
  }

  void _syncState() {
    _fontSize = widget.fontSize;
    _lineHeight = widget.lineHeight;
    _horizontalPadding = widget.horizontalPadding;
    _fontType = widget.fontType;
    _viewMode = widget.viewMode;
    _readerTheme = widget.readerTheme;
    _customBgColor = widget.customBgColor;
    _customTextColor = widget.customTextColor;
    _customPaliColor = widget.customPaliColor;
    _showVerseNumbers = widget.showVerseNumbers;
  }

  // ðŸ†• COLOR PICKER DIALOG
  // 🎨 COLOR PICKER DIALOG
  void _showColorPickerDialog(int type) {
    final String title = type == 0
        ? "Pilih Warna Latar"
        : (type == 1 ? "Pilih Warna Teks" : "Pilih Warna Pāli");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: Scrollbar(
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //  tinggal looping dari map categories
                  ...AppPalettes.categories.entries.map((entry) {
                    return _buildColorCategory(
                      ctx,
                      entry.key,
                      entry.value,
                      type,
                    );
                  }),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  // 🎨 HELPER: BUILD COLOR CATEGORY
  Widget _buildColorCategory(
    BuildContext ctx,
    String categoryName,
    List<Color> colors,
    int type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Text(
            categoryName.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  if (type == 0) {
                    _customBgColor = color;
                  } else if (type == 1) {
                    _customTextColor = color;
                  } else {
                    _customPaliColor = color;
                  }
                });
                widget.onCustomColorsChanged(
                  _customBgColor,
                  _customTextColor,
                  _customPaliColor,
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Helper Warna untuk Preview (SUPPORT CUSTOM!)
  Map<String, Color> _getPreviewColors() {
    // ðŸ†• Kalau custom, langsung return custom colors
    if (_readerTheme == ReaderTheme.custom) {
      return {
        'bg': _customBgColor,
        'text': _customTextColor,
        'pali': _customPaliColor,
      };
    }

    // Kalau preset theme, pakai warna hardcoded
    switch (_readerTheme) {
      case ReaderTheme.light:
        return {
          'bg': Colors.white,
          'text': Colors.black,
          'pali': const Color(0xFF8B4513),
        };
      case ReaderTheme.light2:
        return {
          'bg': const Color(0xFFFAFAFA),
          'text': const Color(0xFF424242),
          'pali': const Color(0xFFA1887F),
        };
      case ReaderTheme.sepia:
        return {
          'bg': const Color(0xFFF4ECD8),
          'text': const Color(0xFF5D4037),
          'pali': const Color(0xFF795548),
        };
      case ReaderTheme.dark:
        return {
          'bg': const Color(0xFF121212),
          'text': Colors.white,
          'pali': const Color(0xFFD4A574),
        };
      case ReaderTheme.dark2:
        return {
          'bg': const Color(0xFF212121),
          'text': const Color(0xFFB0BEC5),
          'pali': const Color(0xFFC5B6A6),
        };
      case ReaderTheme.custom:
        return {
          'bg': _customBgColor,
          'text': _customTextColor,
          'pali': _customPaliColor,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ðŸ”¥ RESPONSIVE PREVIEW LOGIC (dari kode lama)
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.shortestSide >= 600;
    final bool showPreview = !isLandscape || isTablet;

    final readerColors = _getPreviewColors();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 4, 0),
      constraints: BoxConstraints(maxHeight: size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- HEADER HANDLE ---
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // --- HEADER TITLE + CLOSE ---
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Pengaturan Baca",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                // ðŸ”¥ RESTORED: CircleAvatar style close button
                CircleAvatar(
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  radius: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    color: colorScheme.onSurface,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ðŸ”¥ STICKY LIVE PREVIEW BOX (RESTORED dari kode lama)
          if (showPreview) ...[
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 16),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxHeight: 180,
                ), // ðŸ”¥ RESTORED
                decoration: BoxDecoration(
                  color: readerColors['bg'],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(), // ðŸ”¥ RESTORED
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 12),
                          child: Text(
                            "PRATINJAU TAMPILAN",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: readerColors['text']!.withValues(
                                alpha: 0.5,
                              ),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: _horizontalPadding < 16
                                ? 16
                                : _horizontalPadding,
                          ),
                          child: _buildPreviewText(readerColors),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // --- KONTEN SETTINGS ---
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(), // ðŸ”¥ RESTORED
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. MODE TAMPILAN
                  if (widget.isSegmented && widget.lang != "pli") ...[
                    _buildSectionHeader("Segmen Pāli", colorScheme),
                    _buildViewModeSelector(colorScheme),
                    const SizedBox(height: 8),
                    // ðŸ”¥ RESTORED: Label deskripsi mode
                    Center(
                      child: Text(
                        _viewMode == ViewMode.lineByLine
                            ? "Atas-Bawah"
                            : _viewMode == ViewMode.sideBySide
                            ? "Kiri-Kanan"
                            : "Terjemahan Saja",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. GAYA & WARNA
                  _buildSectionHeader("Gaya & Warna", colorScheme),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // ðŸ†• CUSTOM THEME OPTION
                        _buildThemeOption(
                          ReaderTheme.custom,
                          _customBgColor,
                          _customTextColor,
                          "Kustom",
                          colorScheme,
                        ),
                        const SizedBox(width: 16),
                        _buildThemeOption(
                          ReaderTheme.light,
                          Colors.white,
                          Colors.black,
                          "Terang",
                          colorScheme,
                        ),
                        const SizedBox(width: 16),
                        _buildThemeOption(
                          ReaderTheme.light2,
                          const Color(0xFFFAFAFA),
                          const Color(0xFF424242),
                          "Lembut",
                          colorScheme,
                        ),
                        const SizedBox(width: 16),
                        _buildThemeOption(
                          ReaderTheme.sepia,
                          const Color(0xFFF4ECD8),
                          const Color(0xFF5D4037),
                          "Sepia",
                          colorScheme,
                        ),
                        const SizedBox(width: 16),
                        _buildThemeOption(
                          ReaderTheme.dark,
                          const Color(0xFF121212),
                          Colors.white,
                          "Gelap",
                          colorScheme,
                        ),
                        const SizedBox(width: 16),
                        _buildThemeOption(
                          ReaderTheme.dark2,
                          const Color(0xFF212121),
                          const Color(0xFFB0BEC5),
                          "Redup",
                          colorScheme,
                        ),
                      ],
                    ),
                  ),

                  // ðŸ†• CUSTOM COLOR PICKER PANEL (muncul kalau pilih custom)
                  if (_readerTheme == ReaderTheme.custom) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildColorRow(
                            "Latar Belakang",
                            _customBgColor,
                            () => _showColorPickerDialog(0),
                          ),
                          Divider(color: Colors.grey.withValues(alpha: 0.2)),
                          _buildColorRow(
                            "Teks Utama",
                            _customTextColor,
                            () => _showColorPickerDialog(1),
                          ),
                          Divider(color: Colors.grey.withValues(alpha: 0.2)),
                          _buildColorRow(
                            "Pāli / Aksen",
                            _customPaliColor,
                            () => _showColorPickerDialog(2),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // FONT TYPE SELECTOR
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: _getFontBtnStyle(
                            _fontType == 'sans',
                            colorScheme,
                          ),
                          onPressed: () {
                            setState(() => _fontType = 'sans');
                            widget.onFontTypeChanged('sans');
                          },
                          child: Text("Sans", style: GoogleFonts.inter()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: _getFontBtnStyle(
                            _fontType == 'serif',
                            colorScheme,
                          ),
                          onPressed: () {
                            setState(() => _fontType = 'serif');
                            widget.onFontTypeChanged('serif');
                          },
                          child: Text("Serif", style: GoogleFonts.notoSerif()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 3. TATA LETAK
                  _buildSectionHeader("Tata Letak", colorScheme),
                  // Stepper Container (yang udah ada)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    child: Column(
                      children: [
                        _buildStepperRow(
                          icon: Icons.format_size_rounded,
                          label: "Ukuran Teks",
                          valueLabel: "${_fontSize.toInt()}",
                          colorScheme: colorScheme,
                          onMinus: () {
                            final newVal = (_fontSize - 1).clamp(12.0, 40.0);
                            setState(() => _fontSize = newVal); // ðŸ”¥ RESTORED
                            widget.onFontSizeChanged(newVal);
                          },
                          onPlus: () {
                            final newVal = (_fontSize + 1).clamp(12.0, 40.0);
                            setState(() => _fontSize = newVal); // ðŸ”¥ RESTORED
                            widget.onFontSizeChanged(newVal);
                          },
                        ),
                        Divider(
                          color: Colors.grey.withValues(alpha: 0.1),
                          height: 0,
                        ),
                        _buildStepperRow(
                          icon: Icons.format_line_spacing_rounded,
                          label: "Jarak Baris",
                          valueLabel: _lineHeight.toStringAsFixed(1),
                          colorScheme: colorScheme,
                          onMinus: () {
                            final newVal = (_lineHeight - 0.1).clamp(1.0, 3.0);
                            setState(
                              () => _lineHeight = newVal,
                            ); // ðŸ”¥ RESTORED
                            widget.onLineHeightChanged(newVal);
                          },
                          onPlus: () {
                            final newVal = (_lineHeight + 0.1).clamp(1.0, 3.0);
                            setState(
                              () => _lineHeight = newVal,
                            ); // ðŸ”¥ RESTORED
                            widget.onLineHeightChanged(newVal);
                          },
                        ),

                        Divider(
                          color: Colors.grey.withValues(alpha: 0.1),
                          height: 0,
                        ),
                        _buildStepperRow(
                          icon: Icons.space_bar_rounded,
                          label: "Jarak Sisi",
                          valueLabel: "${_horizontalPadding.toInt()}",
                          colorScheme: colorScheme,
                          onMinus: () {
                            final newVal = (_horizontalPadding - 4).clamp(
                              0.0,
                              128.0,
                            );
                            setState(
                              () => _horizontalPadding = newVal,
                            ); // ðŸ”¥ RESTORED
                            widget.onPaddingChanged(newVal);
                          },
                          onPlus: () {
                            final newVal = (_horizontalPadding + 4).clamp(
                              0.0,
                              128.0,
                            );
                            setState(
                              () => _horizontalPadding = newVal,
                            ); // ðŸ”¥ RESTORED
                            widget.onPaddingChanged(newVal);
                          },
                        ),

                        Divider(
                          color: Colors.grey.withValues(alpha: 0.1),
                          height: 0,
                        ),
                        //  TOGGLE SHOW/HIDE NOMOR (CONDITIONAL!)
                        if (_showVerseNumbers != null) ...[
                          SwitchListTile(
                            value: _showVerseNumbers!,
                            onChanged: (val) {
                              setState(() => _showVerseNumbers = val);
                              widget.onShowVerseNumbersChanged?.call(
                                val,
                              ); // 👈 Safe call
                            },
                            title: const Text("Indeks Referensi"),
                            subtitle: Text(
                              "Seperti 1.1, SC 1, PTS 1, §, dll.",
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            activeThumbColor: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB-WIDGET BUILDERS ---

  Widget _buildPreviewText(Map<String, Color> colors) {
    const paliText = "Namo tassa bhagavato arahato sammāsambuddhassa.";
    const transText =
        "Terpujilah Sang Bhagavā, Yang Mahasuci, Yang Telah Mencapai Penerangan Sempurna.";

    final fontFamily = _fontType == 'serif'
        ? GoogleFonts.notoSerif().fontFamily
        : GoogleFonts.inter().fontFamily;

    final paliStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: _fontSize * 0.8,
      height: _lineHeight,
      fontWeight: FontWeight.w500,
      color: colors['pali'],
    );

    final transStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: _fontSize,
      height: _lineHeight,
      color: colors['text'],
    );

    if (widget.isRootOnly) return Text(paliText, style: transStyle);
    if (!widget.isSegmented) return Text(transText, style: transStyle);

    switch (_viewMode) {
      case ViewMode.translationOnly:
        return Text(transText, style: transStyle);
      case ViewMode.sideBySide:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(paliText, style: paliStyle)),
            const SizedBox(width: 12),
            Expanded(child: Text(transText, style: transStyle)),
          ],
        );
      case ViewMode.lineByLine:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(paliText, style: paliStyle),
            const SizedBox(height: 4),
            Text(transText, style: transStyle),
          ],
        );
    }
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildViewModeSelector(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ToggleButtons(
          isSelected: [
            _viewMode == ViewMode.lineByLine,
            _viewMode == ViewMode.sideBySide,
            _viewMode == ViewMode.translationOnly,
          ],
          onPressed: (int index) {
            final newMode = index == 0
                ? ViewMode.lineByLine
                : (index == 1 ? ViewMode.sideBySide : ViewMode.translationOnly);
            setState(() => _viewMode = newMode);
            widget.onViewModeChanged(newMode);
          },
          borderRadius: BorderRadius.circular(12),
          borderColor: Colors.grey.withValues(alpha: 0.2),
          selectedBorderColor: colorScheme.primary,
          fillColor: colorScheme.primaryContainer,
          selectedColor: colorScheme.onPrimaryContainer,
          color: colorScheme.onSurfaceVariant,
          constraints: BoxConstraints(
            minWidth: (constraints.maxWidth - 4) / 3,
            minHeight: 48,
          ),
          children: const [
            // ðŸ”¥ RESTORED: Tooltips
            Tooltip(
              message: "Atas Bawah",
              child: Icon(Icons.horizontal_split_outlined),
            ),
            Tooltip(
              message: "Kiri Kanan",
              child: Icon(Icons.vertical_split_outlined),
            ),
            Tooltip(message: "Tanpa Pāli", child: Icon(Icons.block)),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    ReaderTheme theme,
    Color previewColor,
    Color textColor,
    String label,
    ColorScheme colorScheme,
  ) {
    final bool isSelected = _readerTheme == theme;
    return GestureDetector(
      onTap: () {
        setState(() => _readerTheme = theme);
        widget.onThemeChanged(theme);
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: previewColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: isSelected
                ? Icon(Icons.check, color: textColor, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ðŸ†• CUSTOM COLOR ROW BUILDER
  Widget _buildColorRow(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _getFontBtnStyle(bool isActive, ColorScheme colorScheme) {
    return OutlinedButton.styleFrom(
      backgroundColor: isActive ? colorScheme.primaryContainer : null,
      side: BorderSide(
        color: isActive
            ? colorScheme.primary
            : Colors.grey.withValues(alpha: 0.3),
      ),
      foregroundColor: isActive
          ? colorScheme.onPrimaryContainer
          : colorScheme.onSurface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );
  }

  Widget _buildStepperRow({
    required IconData icon,
    required String label,
    required String valueLabel,
    required ColorScheme colorScheme,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.secondary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onMinus,
                color: colorScheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                alignment: Alignment.center,
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onPlus,
                color: colorScheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
