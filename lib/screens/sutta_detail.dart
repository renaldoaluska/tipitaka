import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tipitaka/screens/menu_page.dart';
import 'package:tipitaka/screens/suttaplex.dart';
import 'package:tipitaka/services/sutta.dart';
import 'package:tipitaka/styles/nikaya_style.dart';
import '../utils/system_ui_helper.dart';
import '../models/sutta_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async';
import 'dart:ui';
import '../services/history.dart';
import '../services/share.dart';
import '../services/tafsir.dart';
import '../widgets/dpd_view.dart';
import '../widgets/ai_translation_sheet.dart';
import '../utils/sutta_text_helper.dart'; // Import Helper
import '../widgets/sutta_settings_sheet.dart'; // Import Settings UI
import '../models/reader_enums.dart';

class SuttaDetail extends StatefulWidget {
  final String uid;
  final String lang;
  final Map<String, dynamic>? textData;

  final bool openedFromSuttaDetail;
  final String? originalSuttaUid;

  // Flag untuk tracking "entry point" (dari mana user masuk pertama kali)
  final String? entryPoint; // "menu_page" | "tematik" | "search" | null
  // Parameter pembawa pesan
  final bool isNavigated;

  final String? targetParaNum;

  const SuttaDetail({
    super.key,
    required this.uid,
    required this.lang,
    required this.textData,
    this.openedFromSuttaDetail = false,
    this.originalSuttaUid,
    this.entryPoint, // Default null = dari SuttaDetail sendiri (via book button)//  2. TAMBAH INI (Default false buat yg pertama dibuka)
    this.isNavigated = false,
    this.targetParaNum,
  });

  @override
  State<SuttaDetail> createState() => _SuttaDetailState();
}

enum SuttaSnackType {
  translatorFallback,
  firstText,
  lastText,
  disabledForTematik,
  disabledTafsir,
}

class _SuttaDetailState extends State<SuttaDetail> {
  // Pindahkan ke sini sebagai 'static final' agar hemat memori
  static final _jTagRegex = RegExp(r'<j\s*/?>', caseSensitive: false);
  static final _markerRegex = RegExp(
    r'\b(pts|vri|mymr|thai)\s+[\d.-]+\s*',
    caseSensitive: false,
  );
  static final _segmentRegex = RegExp(r'§\s*[\d.-]+\s*');
  static final _wsRegex = RegExp(r'\s+');

  //  CACHE DATABASE PALI & TRANS (Biar Gak Lag)
  // Format: List of Entries [MapEntry('1.1', 'text...'), ...]
  List<MapEntry<String, String>>? _cachedPaliList;
  List<MapEntry<String, String>>? _cachedTransList;

  // --- STATE GESTURE ---
  double _dragStartX = 0.0;
  double _currentDragX = 0.0; // Tambah ini buat nyimpen posisi terakhir
  final double _minDragDistance = 100.0; // Jarak minimal tarik (100px)

  // VALUE NOTIFIER:
  final ValueNotifier<double> _scrollProgressVN = ValueNotifier(0.0);
  final ValueNotifier<double> _viewportRatioVN = ValueNotifier(0.1);
  final ValueNotifier<String?> _visibleParaNumVN = ValueNotifier(null);
  final ValueNotifier<bool> _showFloatingBtnVN = ValueNotifier(false);

  bool _isUserDragging = false; // Ini tetap dipakai
  String _currentSelectedText = ''; // Ini tetap dipakai
  int _lastScrollTime = 0; // Ini throttle baru

  DateTime? _lastErrorTime;
  double _horizontalPadding = 16.0;
  //Penampung konten footer (Lisensi/Copyright)
  String _htmlFooter = "";

  //  1. DETEKSI TAFSIR MODE
  bool get _isTafsirMode => widget.textData?["is_tafsir"] == true;

  //  2. VARIABEL BUAT NYIMPEN DAFTAR PARAGRAF (§)
  final Map<String, int> _tafsirSectionMap = {};
  final List<String> _tafsirAvailableSections = [];

  // Index ke-0 di list ini adalah target scroll buat tombol ke-0 di Grid
  final List<int> _tafsirSectionTargetIndices = [];

  //  TAMBAHAN BARU: CACHE PINTAR BUAT SCROLL
  final List<int> _sortedTafsirIndices = []; // Daftar nomor baris yang punya §
  final Map<int, String> _indexToTafsirLabel =
      {}; // Kebalikan dari _tafsirSectionMap

  // --- NAV CONTEXT & STATE ---
  late bool _hasNavigatedBetweenSuttas; //  3. Ubah jadi 'late' (hapus = false)
  String? _parentVaggaId;
  bool _isSearchActive = false; //BUAT DETEKSI SEARCH

  bool _isFirst = false;
  bool _isLast = false;
  bool _isLoading = false;
  bool _connectionError = false;

  bool _isHtmlParsed = false;
  RegExp? _cachedSearchRegex;
  ViewMode _viewMode = ViewMode.lineByLine;
  double _fontSize = 16.0;

  double _lineHeight = 1.6; // Default enak baca
  String _fontType = 'sans'; // 'sans' (Varta) atau 'serif' (Lora)
  String? get _currentFontFamily {
    return _fontType == 'serif'
        ? GoogleFonts.notoSerif().fontFamily
        : GoogleFonts.inter().fontFamily;
  }

  //  HELPER: Cek tipe tafsir yang sedang aktif
  TafsirType _getCurrentTafsirType() {
    final title =
        widget.textData?["root_text"]?["title"]?.toString().toLowerCase() ?? "";
    if (title.contains("aṭṭhakathā")) return TafsirType.att;
    if (title.contains("ṭīkā")) return TafsirType.tik;
    return TafsirType.mul; // Default
  }

  //  Variabel info Footer

  final Map<int, GlobalKey> _searchKeys = {}; //  SIMPAN KEY DISINI

  // --- STATE PENCARIAN ---
  final TextEditingController _searchController = TextEditingController();
  final List<SearchMatch> _allMatches = [];
  int _currentMatchIndex = 0;
  Timer? _debounce;

  // --- SCROLL CONTROLLER ---
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  //  AUTO-HIDE UI STATE
  bool _isBottomMenuVisible = true;
  //Timer? _autoHideTimer;

  // Default awal kita set Light dulu (cuma placeholder)
  // Nanti di _loadPreferences kita timpa sesuai logika kamu
  ReaderTheme _readerTheme = ReaderTheme.light;

  //  BARU: Show/Hide Verse Numbers
  bool _showVerseNumbers = true; // Default: tampil

  Color _customBgColor = Colors.white;
  Color _customTextColor = Colors.black;
  Color _customPaliColor = const Color(
    0xFF8B4513,
  ); // Warna Pali default (coklat)

  // Getter pusat (pastikan ReaderThemeStyle.getStyle sudah diupdate terima 3 warna)
  ReaderThemeStyle get _currentStyle => ReaderThemeStyle.getStyle(
    _readerTheme,
    customBg: _customBgColor,
    customText: _customTextColor,
    customPali: _customPaliColor,
  );

  void _showShareOptions(String selectedText) {
    final navigator = Navigator.of(context);
    final scaffoldContext = context;

    // A. Persiapan Metadata (Judul, Warna, Author)
    final String rawAcronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        "";

    final Color nikayaColor = getNikayaColor(
      normalizeNikayaAcronym(rawAcronym),
    );

    final String suttaTitle =
        widget.textData?["suttaplex"]?["original_title"] ??
        widget.textData?["root_text"]?["title"] ??
        widget.uid;

    String typeLabel = "";
    if (_isTafsirMode) {
      final rootTitle =
          widget.textData?["root_text"]?["title"]?.toString().toLowerCase() ??
          "";
      if (rootTitle.contains("aṭṭhakathā")) {
        typeLabel = " Aṭṭhakathā";
      } else if (rootTitle.contains("ṭīkā")) {
        typeLabel = " Ṭīkā";
      }
    }
    final String displayTitle = "$suttaTitle$typeLabel";

    // B. Cari Translator
    String? translator;
    if (_isTafsirMode) {
      translator = "CSCD VRI";
    } else if (widget.textData?["segmented"] == true) {
      final translations =
          widget.textData?["suttaplex"]?["translations"] as List?;
      final currentAuthorUid = widget.textData?["author_uid"];

      if (translations != null && currentAuthorUid != null) {
        try {
          final trans = translations.firstWhere(
            (t) =>
                t["author_uid"] == currentAuthorUid && t["lang"] == widget.lang,
            orElse: () => null,
          );
          translator = trans?["author"]?.toString();
        } catch (e) {
          translator = null;
        }
      }
    } else {
      translator = widget.textData?["translation"]?["author"];
    }

    //  UPDATE: Pake logika range baru
    String? verseNum;
    final bool isSegmented = widget.textData?["segmented"] == true;

    if (isSegmented && selectedText.isNotEmpty) {
      verseNum = _calculateSegmentRange(selectedText);
    }

    // Filter PTS/SC biar bersih (DI-KOMEN AJA KARENA UDAH GAK PERLU)
    /* if (verseNum != null) {
      final vLower = verseNum.toLowerCase();
      if (vLower.contains('pts') || vLower.contains('sc')) {
        verseNum = null;
      }
    } */

    //  FORMALIN TEKS SEBELUM DIKIRIM
    // Ini biar enter-nya bener dan Pali-nya ada //
    final String cleanContent = _getSmartFormattedText(selectedText);
    // Format Footer
    final String footer =
        "\n\n— $displayTitle ($rawAcronym${verseNum ?? ''})${translator != null ? ' - $translator' : ''}";

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;

        Widget buildShareCard({
          required IconData icon,
          required String label,
          required String subLabel,
          required Color color,
          required VoidCallback onTap,
        }) {
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  "Bagikan Ayat",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // KOTAK 1: SHARE TEXT
                    buildShareCard(
                      icon: Icons.text_fields_rounded,
                      label: "Salin Teks",
                      subLabel: "Bagikan sebagai pesan teks",
                      color: colorScheme.primary,
                      onTap: () async {
                        navigator.pop();
                        // Share Teks Biasa (Bersih + Footer)
                        await SharePlus.instance.share(
                          ShareParams(
                            text: "$cleanContent$footer - via myDhamma",
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),

                    // KOTAK 2: SHARE GAMBAR
                    buildShareCard(
                      icon: Icons.image_rounded,
                      label: "Buat Gambar",
                      subLabel: "Edit sebagai poster kutipan",
                      color: Colors.purple,
                      onTap: () {
                        navigator.pop();
                        // Kirim teks yang SUDAH DIFORMAT (cleanContent)
                        Navigator.of(scaffoldContext).push(
                          MaterialPageRoute(
                            builder: (context) => QuoteEditorPage(
                              text: cleanContent, // <--- PAKE YANG SMART
                              acronym: rawAcronym,
                              title: displayTitle,
                              nikayaColor: nikayaColor,
                              translator: translator,
                              verseNum: verseNum
                                  ?.trim(), // <--- RANGE SEGMEN 1.1-1.2
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Panggil ini SETELAH textData berhasil dimuat (di dalam _processNewTextData)
  void _buildSearchCache() {
    if (widget.textData == null) return;

    String normalize(String s) =>
        s.trim().toLowerCase().replaceAll(_wsRegex, ' ');

    // 1. Build Pali Cache
    final rootMap = widget.textData?["root_text"] is Map
        ? widget.textData!["root_text"] as Map
        : {};

    _cachedPaliList = [];
    for (var entry in rootMap.entries) {
      if ([
        'uid',
        'lang',
        'author_uid',
        'title',
        'acronym',
      ].contains(entry.key)) {
        continue;
      }
      String val = entry.value.toString();
      if (val.length < 2) continue; // Skip yang terlalu pendek
      _cachedPaliList!.add(MapEntry(entry.key.toString(), normalize(val)));
    }

    // 2. Build Trans Cache
    Map transMap = {};
    if (widget.textData?["translation_text"] is Map) {
      transMap = widget.textData!["translation_text"] as Map;
    } else if (widget.textData?["translation"]?["data"] is Map) {
      transMap = widget.textData!["translation"]["data"] as Map;
    }

    _cachedTransList = [];
    for (var entry in transMap.entries) {
      if ([
        'uid',
        'lang',
        'author_uid',
        'title',
        'acronym',
      ].contains(entry.key)) {
        continue;
      }
      String val = entry.value.toString();
      if (val.length < 2) continue;
      _cachedTransList!.add(MapEntry(entry.key.toString(), normalize(val)));
    }
  }

  String _normalizeDbText(String text, {bool useNewline = false}) {
    return text
        // 1. Ganti <j> jadi \n (share) atau spasi (footer)
        .replaceAll(_jTagRegex, useNewline ? '\n' : ' ')
        // 2. Ganti semua tag lain jadi SPASI (biar kata ga nempel)
        .replaceAll(SuttaTextHelper.htmlTagRegex, ' ')
        .replaceAll(_segmentRegex, ' ')
        .replaceAll(_markerRegex, ' ')
        .trim()
        // 3. KUNCI: Kempeskan spasi berlebih (termasuk hasil 3 tag nempel tadi)
        // Gunakan r' +' (spasi diikuti plus) agar \n dari <j> tidak ikut terhapus
        .replaceAll(RegExp(r' +'), ' ');
  }

  //  HITUNG NOMOR SEGMEN V4: STRICT SEGMENTED ONLY
  String? _calculateSegmentRange(String selectedText) {
    if (selectedText.trim().isEmpty) return null;

    //  KILL SWITCH: Kalau bukan Segmented, matikan fitur ini.
    // Biar gak maksa nyari koordinat di teks buta (HTML Legacy / Tafsir Blob).
    if (widget.textData?["segmented"] != true) return null;

    if (_cachedPaliList == null) _buildSearchCache();

    final String cleanSelect = selectedText.trim().toLowerCase().replaceAll(
      _wsRegex,
      ' ',
    );

    int cursor = 0;
    String? startId;
    String? endId;

    // ... (Sisa kodenya sama persis kayak V3 / V2 Pac-Man kemarin) ...
    // ... Copy paste bagian bawahnya dari V3 kemarin ...

    final keys = _cachedKeysOrder;
    final rootMap = widget.textData?["root_text"] as Map? ?? {};
    final transMap = widget.textData?["translation_text"] as Map? ?? {};
    final transMapLegacy =
        widget.textData?["translation"]?["data"] as Map? ?? {};
    final tafsirMap = widget.textData?["commentary_text"] as Map? ?? {};

    bool tryConsume(String dbText) {
      if (cursor >= cleanSelect.length) return false;

      // Panggil helper universal (pake spasi saja karena cuma buat hitung range)
      String cleanDb = _normalizeDbText(dbText, useNewline: false);

      if (cleanDb.isEmpty) return false;
      String normDb = cleanDb.toLowerCase().replaceAll(_wsRegex, ' ');
      String remainingUser = cleanSelect.substring(cursor).trimLeft();

      if (remainingUser.startsWith(normDb)) {
        int nextPos = cleanSelect.indexOf(normDb, cursor);
        cursor = (nextPos != -1)
            ? nextPos + normDb.length
            : cursor + normDb.length;
        return true;
      }
      int checkLen = normDb.length;
      if (checkLen > remainingUser.length) checkLen = remainingUser.length;
      for (int len = checkLen; len >= 3; len--) {
        String dbTail = normDb.substring(normDb.length - len);
        String userHead = remainingUser.substring(0, len);
        if (dbTail == userHead) {
          int matchInUser = cleanSelect.indexOf(userHead, cursor);
          cursor = (matchInUser != -1) ? matchInUser + len : cursor + len;
          return true;
        }
      }
      if (normDb.contains(remainingUser)) {
        cursor = cleanSelect.length;
        return true;
      }
      return false;
    }

    for (String key in keys) {
      if (cursor >= cleanSelect.length) break;

      String rawPali = rootMap[key]?.toString() ?? "";
      String rawTrans =
          transMap[key]?.toString() ?? transMapLegacy[key]?.toString() ?? "";
      String rawTafsir = tafsirMap[key]?.toString() ?? "";

      bool hitPali = tryConsume(rawPali);
      bool hitContent = false;

      if (_isTafsirMode) {
        hitContent = tryConsume(rawTafsir);
      } else {
        hitContent = tryConsume(rawTrans);
      }

      if (hitPali || hitContent) {
        startId ??= key;
        endId = key;
      }
    }

    if (startId == null) return null;
    String cleanId(String id) => id.contains(':') ? id.split(':').last : id;
    final s = cleanId(startId);
    final e = endId != null ? cleanId(endId) : s;

    // Pake Titik Dua
    if (s == e) return ":$s";
    return ":$s–$e";
  }

  //  FORMATTING FINAL V16: TRIPLE SAFETY (SYNTAX FIXED + LOGIC SAFE)
  String _getSmartFormattedText(String selectedText) {
    if (selectedText.trim().isEmpty) return selectedText;

    //  CUCI TEKS USER (INPUT BERSIH)
    // Ini teks murni yang dilihat user. Paling aman ya pake ini.
    String sanitizedText = selectedText
        .replaceAll(_segmentRegex, '') // Gunakan underscore (_)
        .replaceAll(_markerRegex, '')
        .replaceAll(RegExp(r'\$\$.*?\$\$'), '')
        .trim();

    //  CEK TIPE DATA
    final bool isSegmented = widget.textData?["segmented"] == true;

    // ============================================================
    // JALUR 1: LEGACY HTML / TAFSIR (MODE AMAN / MANUAL)
    // ============================================================
    // Di sini kita MATIKAN total logic Matching Database.
    // Kita percaya 100% teks seleksi user, cuma kita rapihin enternya.
    // Risiko kata hilang = 0%.
    if (!isSegmented) {
      return sanitizedText
          .replaceAll(
            RegExp(r'\n\s*\n'),
            '\n',
          ) // Normalin jadi single enter dulu
          .replaceAll('\n', '\n\n'); // Jadiin double enter biar paragraf jelas
    }

    // ============================================================
    // JALUR 2: SEGMENTED / BILARA (MODE CANGGIH)
    // ============================================================
    // Kalau Segmented, datanya bersih. Kita tetep pake Pac-Man biar dapet fitur
    // "Auto Pali" (munculin teks Pali pasangan terjemahannya).

    if (_cachedPaliList == null) _buildSearchCache();

    final String cleanSelect = sanitizedText.toLowerCase().replaceAll(
      _wsRegex,
      ' ',
    );

    StringBuffer buffer = StringBuffer();
    int cursor = 0;
    bool hasContent = false;
    List<String> feedingQueue = [];

    // ... (LOAD DATA SEGMENTED) ...
    final keys = _cachedKeysOrder;
    final rootMap = widget.textData?["root_text"] as Map? ?? {};
    final transMap = widget.textData?["translation_text"] as Map? ?? {};
    final transMapLegacy =
        widget.textData?["translation"]?["data"] as Map? ?? {};
    final tafsirMap = widget.textData?["commentary_text"] as Map? ?? {};

    for (String key in keys) {
      String rawPali = rootMap[key]?.toString() ?? "";
      if (rawPali.isNotEmpty) feedingQueue.add("PALI::$rawPali");

      String content = "";
      if (_isTafsirMode) {
        content = tafsirMap[key]?.toString() ?? "";
      } else {
        content =
            transMap[key]?.toString() ?? transMapLegacy[key]?.toString() ?? "";
      }
      if (content.isNotEmpty) feedingQueue.add("TRANS::$content");
    }

    // ... (LOGIC KONSUMSI / PAC-MAN) ...
    String? consumeMatch(String dbText) {
      if (cursor >= cleanSelect.length) return null;

      // Panggil helper universal (pake \n agar format puisi terjaga)
      String cleanDb = _normalizeDbText(dbText, useNewline: true);

      if (cleanDb.isEmpty) return null;

      String normDb = cleanDb.toLowerCase().replaceAll(_wsRegex, ' ');
      String remainingUser = cleanSelect.substring(cursor).trimLeft();

      // 1. HEAD MATCH
      if (remainingUser.startsWith(normDb)) {
        int nextPos = cleanSelect.indexOf(normDb, cursor);
        cursor = (nextPos != -1)
            ? nextPos + normDb.length
            : cursor + normDb.length;
        return cleanDb;
      }
      // 2. TAIL / PARTIAL MATCH
      int checkLen = normDb.length;
      if (checkLen > remainingUser.length) checkLen = remainingUser.length;
      for (int len = checkLen; len >= 3; len--) {
        String dbTail = normDb.substring(normDb.length - len);
        String userHead = remainingUser.substring(0, len);
        if (dbTail == userHead) {
          int matchInUser = cleanSelect.indexOf(userHead, cursor);
          cursor = (matchInUser != -1) ? matchInUser + len : cursor + len;
          return cleanDb.substring(cleanDb.length - len);
        }
      }
      if (normDb.contains(remainingUser)) {
        cursor = cleanSelect.length;
        int idx = normDb.indexOf(remainingUser);
        if (idx >= 0 && idx + remainingUser.length <= cleanDb.length) {
          return cleanDb.substring(idx, idx + remainingUser.length);
        }
        return remainingUser;
      }
      return null;
    }

    // JALANKAN QUEUE
    for (String item in feedingQueue) {
      if (cursor >= cleanSelect.length) break;
      bool isPaliItem = item.startsWith("PALI::");
      String rawContent = item.substring(6);
      String? matched = consumeMatch(rawContent);

      if (matched != null) {
        if (hasContent) {
          bool previousWasPali = buffer.toString().trimRight().endsWith("//");
          if (isPaliItem) {
            buffer.write('\n\n');
          } else {
            if (previousWasPali) {
              buffer.write('\n');
            } else {
              buffer.write('\n\n');
            }
          }
        }
        if (isPaliItem && !_isRootOnly) {
          // Pake kurung kurawal di variabelnya: ${matched}
          buffer.write('//_${matched}_//');
        } else {
          buffer.write(matched);
        }
        hasContent = true;
      }
    }

    // Fallback Safety buat Segmented
    if (buffer.isEmpty) return sanitizedText.replaceAll(RegExp(r'\n+'), '\n\n');
    return buffer.toString();
  }

  Widget _buildMyContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    // --- PERBAIKAN: HAPUS IF NULL CHECK YANG ERROR ---
    // Langsung ambil items-nya saja.
    final List<ContextMenuButtonItem> buttonItems =
        selectableRegionState.contextMenuButtonItems;

    // --- TAMBAHAN SAFETY LOGIC ---
    // Kalau tidak ada tombol yang harus ditampilkan (misal seleksi kosong),
    // kembalikan widget kosong biar gak error saat render.
    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }
    // -----------------------------

    // Hapus Share bawaan agar tidak redundan
    buttonItems.removeWhere(
      (item) =>
          item.type == ContextMenuButtonType.share ||
          item.type == ContextMenuButtonType.selectAll || // Tambahkan baris ini
          item.label?.toLowerCase() == 'share' ||
          item.label?.toLowerCase() == 'select all',
    );

    final List<ContextMenuButtonItem> customButtons = [];
    // 1. Tombol Bagikan (Selalu ada & Posisi Pertama)
    customButtons.add(
      ContextMenuButtonItem(
        label: 'Bagikan',
        onPressed: () {
          selectableRegionState.hideToolbar();
          _showShareOptions(_currentSelectedText);
        },
      ),
    );

    // 2. Logika Filter Alat Pāli (Anti-Bocor)
    final bool isSegmented = widget.textData?["segmented"] == true;
    final bool isCurrentlyPali = widget.lang == 'pli' || widget.lang == 'pali';

    bool showPaliTools = false;

    if (_isTafsirMode) {
      showPaliTools = true;
    } else if (isCurrentlyPali) {
      showPaliTools = true;
    } else if (isSegmented && _viewMode != ViewMode.translationOnly) {
      showPaliTools = true;
    }

    // Sembunyikan jika teks Indonesia murni dan bukan mode tafsir
    if (widget.lang == 'id' && !isSegmented && !_isTafsirMode) {
      showPaliTools = false;
    }

    if (showPaliTools) {
      customButtons.add(
        ContextMenuButtonItem(
          label: 'Kamus',
          onPressed: () {
            selectableRegionState.hideToolbar();
            _handleWordLookup(_currentSelectedText);
          },
        ),
      );
      customButtons.add(
        ContextMenuButtonItem(
          label: 'Terjemah AI',
          onPressed: () {
            selectableRegionState.hideToolbar();
            _handleAiTranslation(_currentSelectedText);
          },
        ),
      );
    }

    buttonItems.insertAll(0, customButtons);

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  String _normalizeTeiTags(String rawHtml) {
    final isTafsir = widget.textData?["is_tafsir"] == true;
    if (!isTafsir) return rawHtml;

    // 1. NIKAYA -> HIDE/HAPUS (Double Protection)
    rawHtml = rawHtml.replaceAll(
      RegExp(
        r'<p[^>]*rend="nikaya"[^>]*>.*?</p>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // 2. BOOK/VAGGA -> HIDE JUGA (Sesuai update terakhir)
    rawHtml = rawHtml.replaceAll(
      RegExp(
        r'<head[^>]*>.*?<book[^>]*>.*?</book>.*?</head>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // 3. SUTTA TITLE -> H2 (HANYA DARI READUNIT)
    // Ambil isi <readunit>, buang pembungkus luarnya
    rawHtml = rawHtml.replaceAllMapped(
      RegExp(
        r'<((?:head|p))[^>]*>.*?<readunit[^>]*>(.*?)</readunit>.*?</\1>',
        dotAll: true,
        caseSensitive: false,
      ),
      (m) => '<h2>${m.group(2)}</h2>',
    );

    // 4. SUBHEAD LAINNYA -> H3
    rawHtml = rawHtml.replaceAllMapped(
      RegExp(
        r'<p[^>]*rend="subhead"[^>]*>(.*?)</p>',
        dotAll: true,
        caseSensitive: false,
      ),
      (m) => '<h3>${m.group(1)}</h3>',
    );

    // 5. BERSIH-BERSIH SISA TAG
    rawHtml = rawHtml.replaceAll(
      RegExp(r'<\/?(nikaya|book|pgroup|readunit)[^>]*>', caseSensitive: false),
      '',
    );

    return rawHtml;
  }

  // --- DAFTAR ISI ---
  final List<Map<String, dynamic>> _tocList = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  //  CACHE DATA (Biar Scroll Enteng)
  Map<String, String> _cachedPaliSegs = {};
  Map<String, String> _cachedTransSegs = {};
  Map<String, String> _cachedCommentSegs = {};
  List<String> _cachedKeysOrder = [];

  // Penampung data suttaplex yang valid (Canonical)
  Map<String, dynamic>? _canonicalSuttaplex;

  @override
  void initState() {
    super.initState();

    // 1. Inisialisasi Data & Prefs
    _canonicalSuttaplex = widget.textData?["suttaplex"];
    _hasNavigatedBetweenSuttas = widget.isNavigated;
    _loadPreferences();

    // 2.  PROSES DATA (SATU PINTU)
    _processNewTextData();

    // 3. Background Services
    _initNavigationContext();
    _saveToHistory();

    // 4. UI Cleanups & Auto-Scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearMaterialBanners();
      if (widget.targetParaNum != null) {
        _handleInitialJump(widget.targetParaNum!);
      }
    });

    // 5. Scroll Listener
    _itemPositionsListener.itemPositions.addListener(_updateVisibleParagraph);
  }

  // Helper biar initState gak kepanjangan
  void _handleInitialJump(String paraNum) {
    bool hasShownNotif = false;

    // Percobaan 1: Cepat (300ms)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final bool shouldNotify = _isTafsirMode && !hasShownNotif;
      _scrollToParagraph(paraNum, showSnackBar: shouldNotify);
      if (shouldNotify) hasShownNotif = true;
    });

    // Percobaan 2: Backup (800ms) buat HP yang agak lambat render
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _scrollToParagraph(paraNum, showSnackBar: false); // Silent jump
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 1. Coba ambil settingan user
    int? savedIndex = prefs.getInt('reader_theme_index');

    // 2. Tentukan tema
    ReaderTheme targetTheme;

    if (savedIndex != null) {
      //  KASUS A: User udah pernah setting, ikutin maunya user
      if (savedIndex >= 0 && savedIndex < ReaderTheme.values.length) {
        targetTheme = ReaderTheme.values[savedIndex];
      } else {
        targetTheme = ReaderTheme.light;
      }
    } else {
      //  KASUS B: Belum pernah setting (Default)
      // Cek tema HP sekarang (Gelap/Terang)
      final brightness = Theme.of(context).brightness;

      if (brightness == Brightness.dark) {
        targetTheme = ReaderTheme.dark; // Kalau HP gelap -> Mode Baca Gelap
      } else {
        targetTheme = ReaderTheme.light; // Kalau HP terang -> Mode Baca Terang
      }
    }

    setState(() {
      // Gunakan key universal tanpa prefix biar sinkron
      _customBgColor = Color(
        prefs.getInt('custom_bg_color') ?? Colors.white.toARGB32(),
      );
      _customTextColor = Color(
        prefs.getInt('custom_text_color') ?? Colors.black.toARGB32(),
      );
      _customPaliColor = Color(
        prefs.getInt('custom_pali_color') ?? const Color(0xFF8B4513).toARGB32(),
      );

      _fontSize = prefs.getDouble('sutta_font_size') ?? 16.0;
      _horizontalPadding = prefs.getDouble('horizontal_padding') ?? 16.0;
      //  3. LOAD LINE HEIGHT & FONT
      _lineHeight = prefs.getDouble('line_height') ?? 1.6;
      _fontType = prefs.getString('font_type') ?? 'sans';

      //  LOAD BOTTOM MENU VISIBILITY
      _isBottomMenuVisible = prefs.getBool('bottom_menu_visible') ?? true;

      final savedMode = prefs.getInt('sutta_view_mode');
      if (savedMode != null && savedMode < ViewMode.values.length) {
        _viewMode = ViewMode.values[savedMode];
      }

      // Update tema baca
      _readerTheme = targetTheme;

      _showVerseNumbers = prefs.getBool('show_verse_numbers') ?? true;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // pake .toARGB32() kalo flutter baru, atau .value kalo .toARGB32() merah
    await prefs.setInt('custom_bg_color', _customBgColor.toARGB32());
    await prefs.setInt('custom_text_color', _customTextColor.toARGB32());
    await prefs.setInt('custom_pali_color', _customPaliColor.toARGB32());

    await prefs.setDouble('sutta_font_size', _fontSize);
    await prefs.setInt('sutta_view_mode', _viewMode.index);
    await prefs.setDouble('horizontal_padding', _horizontalPadding);
    // Simpan index enum
    await prefs.setInt('reader_theme_index', _readerTheme.index);
    await prefs.setDouble('line_height', _lineHeight);
    await prefs.setString('font_type', _fontType);
    //  SIMPAN BOTTOM MENU STATE
    await prefs.setBool('bottom_menu_visible', _isBottomMenuVisible);
    await prefs.setBool('show_verse_numbers', _showVerseNumbers);
  }

  // ============================================================
  // ⚙️ DATA PROCESSOR (Inisialisasi Ulang)
  // Dipanggil saat pertama buka (initState) ATAU saat data berubah (didUpdateWidget)
  // ============================================================
  // ============================================================
  // ⚙️ DATA PROCESSOR (Inisialisasi Ulang)
  // ============================================================
  void _processNewTextData() {
    // Di awal fungsi _processNewTextData & _parseHtmlAndGenerateTOC:
    _sortedTafsirIndices.clear();
    _indexToTafsirLabel.clear();

    _tafsirSectionTargetIndices.clear();

    if (widget.textData == null) return;

    // 1. Reset Data Lama
    _htmlSegments.clear();
    _tocList.clear();

    //  RESET MAP REFERENSI (PENTING!)
    _tafsirSectionMap.clear();
    _tafsirAvailableSections.clear();

    //  Reset Cache Baru
    _cachedPaliSegs.clear();
    _cachedTransSegs.clear();
    _cachedCommentSegs.clear();
    _cachedKeysOrder.clear();

    _isHtmlParsed = false;

    // 2. Cek Tipe Data
    final bool isSegmented = widget.textData!["segmented"] == true;

    if (isSegmented) {
      // --- LOGIC SEGMENTED (OPTIMIZED) ---

      // A. Siapkan Keys Order
      if (widget.textData!["keys_order"] is List) {
        _cachedKeysOrder = List<String>.from(widget.textData!["keys_order"]);
        _generateTOC();
      } else {
        // Fallback logic
        final rawPali = widget.textData!["root_text"] as Map? ?? {};
        final rawTrans = widget.textData!["translation_text"] as Map? ?? {};
        final metadataKeys = {
          'previous',
          'next',
          'author_uid',
          'vagga_uid',
          'lang',
          'title',
          'acronym',
          'text',
        };
        final source = rawTrans.isNotEmpty ? rawTrans : rawPali;

        _cachedKeysOrder = source.keys
            .where((k) => !metadataKeys.contains(k))
            .map((e) => e.toString())
            .toList();
      }

      // ============================================================
      //  GENERATE INDEKS REFERENSI (SEGMENTED)
      // ============================================================
      for (int i = 0; i < _cachedKeysOrder.length; i++) {
        final rawKey = _cachedKeysOrder[i];

        // 1. Bersihkan Key (misal: "dn1:1.1" -> "1.1")
        String label = rawKey.contains(':') ? rawKey.split(':').last : rawKey;
        label = label.trim();

        // 2. Filter: Jangan masukin Header (0.1, 0.2) ke grid referensi
        // Karena Header udah ada di Daftar Isi (TOC)
        if (label.startsWith('0.')) continue;

        // MASIH PAKE MAP (Buat pencarian manual/range)
        _tafsirSectionMap[label] = i;

        // MASUKIN KE LIST TAMPILAN
        _tafsirAvailableSections.add(label);

        // 🔥 ISI LIST TARGET (Ini kuncinya: simpan 'i' apa adanya)
        // Walaupun labelnya '1' lagi, kita simpan 'i' yang baru (misal index 500)
        _tafsirSectionTargetIndices.add(i);

        //  TAMBAHAN BARU: ISI REVERSE MAP
        _sortedTafsirIndices.add(i);
        _indexToTafsirLabel[i] = label;
      }
      //  PENTING: SORT BIAR PENCARIAN CEPAT
      _sortedTafsirIndices.sort();
      // ============================================================

      // B. Siapkan Data Maps (Pali, Trans, Comment)
      if (widget.textData!["root_text"] is Map) {
        _cachedPaliSegs = (widget.textData!["root_text"] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      if (widget.textData!["translation_text"] is Map) {
        _cachedTransSegs = (widget.textData!["translation_text"] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      if (widget.textData!["comment_text"] is Map) {
        _cachedCommentSegs = (widget.textData!["comment_text"] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    } else {
      // --- LOGIC HTML / NON-SEGMENTED ---
      _parseHtmlIfNeeded(force: true);
    }
  }

  bool get _isRootOnly {
    final trans = widget.textData?["translation_text"];
    return trans == null || (trans is Map && trans.isEmpty);
  }

  void _generateTOC() {
    if (widget.textData!["keys_order"] == null) return;

    final keysOrder = List<String>.from(widget.textData!["keys_order"]);
    final transSegs = (widget.textData!["translation_text"] is Map)
        ? (widget.textData!["translation_text"] as Map)
        : {};
    final rootSegs = (widget.textData!["root_text"] is Map)
        ? (widget.textData!["root_text"] as Map)
        : {};

    _tocList.clear();

    for (int i = 0; i < keysOrder.length; i++) {
      final key = keysOrder[i];
      final verseNumRaw = key.contains(":") ? key.split(":").last : key;
      final verseNum = verseNumRaw.trim();

      bool isH1 = verseNum == "0.1";
      bool isH2 = verseNum == "0.2";
      final headerRegex = RegExp(r'^(?:\d+\.)*0(?:\.\d+)*$');
      final isHeader = headerRegex.hasMatch(verseNum);
      bool isH3 = isHeader && !isH1 && !isH2;

      if (isH1 || isH2 || isH3) {
        String title =
            transSegs[key]?.toString() ?? rootSegs[key]?.toString() ?? "";
        title = title.replaceAll(SuttaTextHelper.htmlTagRegex, '').trim();

        if (title.isEmpty) title = "Bagian $verseNum";

        _tocList.add({
          "title": title,
          "index": i,
          "type": isH1 ? 1 : (isH2 ? 2 : 3),
        });
      }
    }
  }

  void _jumpToResult(int index) {
    if (!mounted || _allMatches.isEmpty) return;

    final safeIndex = index.clamp(0, _allMatches.length - 1);
    setState(() {
      _currentMatchIndex = safeIndex;
    });

    // ✅ CEK NULL SEBELUM AKSES
    if (_allMatches.isEmpty || safeIndex >= _allMatches.length) {
      return; // ← TAMBAHKAN INI
    }

    final targetRow = _allMatches[safeIndex].listIndex;
    final isSegmented = widget.textData?["segmented"] == true;

    if (_itemScrollController.isAttached) {
      if (isSegmented) {
        // --- MODE SEGMENTED (Tetap Scroll Biasa) ---
        // Karena item pendek, scroll biasa udah enak & kebaca semua
        _itemScrollController.scrollTo(
          index: targetRow,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.2, // Posisi agak atas (sweet spot)
        );
      } else {
        // --- MODE HTML / NON-SEGMENTED (Jururs Sat-Set) ---

        // 1. JUMP (Teleport): Langsung pindah ke paragraf target tanpa animasi.
        // Ini ngilangin efek "scroll panjang" yang bikin pusing.
        _itemScrollController.jumpTo(
          index: targetRow,
          alignment: 0.1, // Taruh di bagian atas layar
        );

        // 2. ADJUST (Geser Halus): Langsung pas-in kata ke tengah layar.
        // Delay dikit banget (50ms) cuma buat nunggu rendering kelar.
        Future.delayed(const Duration(milliseconds: 50), () {
          // 1. Check mounted DULU sebelum akses apapun
          if (!mounted) return;

          // 2. Ambil context dari key (bukan dari widget tree)
          final targetContext = _searchKeys[safeIndex]?.currentContext;

          // 3. Validasi context masih valid
          if (targetContext != null && targetContext.mounted) {
            Scrollable.ensureVisible(
              targetContext,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5,
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  final List<String> _htmlSegments = [];
  void _parseHtmlAndGenerateTOC(String rawHtml) {
    // Di awal fungsi _processNewTextData & _parseHtmlAndGenerateTOC:
    _sortedTafsirIndices.clear();
    _indexToTafsirLabel.clear();

    // 1. Ekstrak Footer
    try {
      final footerRegex = RegExp(
        r'<footer>(.*?)</footer>',
        caseSensitive: false,
        dotAll: true,
      );
      final match = footerRegex.firstMatch(rawHtml);
      if (match != null) {
        _htmlFooter = match.group(1) ?? "";
        rawHtml = rawHtml.replaceFirst(footerRegex, "");
      }
    } catch (e) {
      debugPrint("Gagal ekstrak footer: $e");
    }

    //  [FIX SCROLL] FLATTEN BLOCKQUOTE
    // Bongkar <blockquote> biar isinya (paragraf) jadi segmen terpisah.
    // Tapi kita suntik class 'gatha-segment' biar nanti bisa distyle nyambung.
    rawHtml = rawHtml.replaceAllMapped(
      RegExp(
        r"<blockquote class=['|]gatha['|]>(.*?)</blockquote>",
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        String content = match.group(1) ?? "";
        // Ubah <p> biasa jadi <p class='gatha-segment'>
        // Ganti margin bawaan p biar nempel
        content = content.replaceAll('<p>', "<p class='gatha-segment'>");
        return content; // Balikin isinya doang, bungkus blockquote DIBUANG.
      },
    );

    // 2. Normalisasi Tag
    rawHtml = _normalizeTeiTags(rawHtml);

    // 3. Reset Data
    _tocList.clear();
    _htmlSegments.clear();
    // CLEAR DI SINI JUGA
    _tafsirSectionTargetIndices.clear();
    _tafsirSectionMap.clear();
    _tafsirAvailableSections.clear();

    if (rawHtml.trim().isEmpty) return;

    try {
      // REGEX UTAMA (Blockquote udah ga perlu dicari lagi karena udah dibongkar)
      final RegExp blockRegex = RegExp(
        r'''<(h[1-6]|p|div)[^>]*>(.*?)<\/\1>''',
        caseSensitive: false,
        dotAll: true,
      );

      final RegExp paraNumRegex = RegExp(r'data-num="([^"]+)"');
      // Regex Ref Aman (Triple Quote)
      final RegExp refRegex = RegExp(
        r"""<a\s+[^>]*class=["'][^"']*\bref\b[^"']*["'][^>]*>(.*?)</a>""",
        caseSensitive: false,
      );

      final matches = blockRegex.allMatches(rawHtml);
      int lastIndex = 0;

      for (final match in matches) {
        try {
          if (match.start > lastIndex) {
            String gap = rawHtml.substring(lastIndex, match.start);
            if (gap.trim().isNotEmpty) {
              _htmlSegments.add(gap);
              if (_isTafsirMode) {
                final numMatch = paraNumRegex.firstMatch(gap);
                if (numMatch != null) {
                  String num = numMatch.group(1)!;
                  _tafsirSectionMap[num] = _htmlSegments.length - 1;
                  _tafsirAvailableSections.add(num);
                }
              }
            }
          }

          String fullTag = match.group(0) ?? "";
          String tagName = match.group(1)?.toLowerCase() ?? "";
          String content = match.group(2) ?? "";

          _htmlSegments.add(fullTag);
          int currentIndex = _htmlSegments.length - 1;

          // LOGIC REF / NOMOR PARAGRAF
          final numMatch = paraNumRegex.firstMatch(fullTag);
          if (numMatch != null) {
            String num = numMatch.group(1)!;
            _tafsirSectionMap[num] = currentIndex;
            _tafsirAvailableSections.add(num);
            _tafsirSectionTargetIndices.add(currentIndex);

            //  AMAN: Para Num pasti ada isinya
            _sortedTafsirIndices.add(currentIndex);
            _indexToTafsirLabel[currentIndex] = num;
          } else {
            final refMatches = refRegex.allMatches(fullTag);
            for (final refMatch in refMatches) {
              String label = refMatch.group(1) ?? "";
              label = label.trim();

              //  PERBAIKAN DI SINI:
              // Pastikan cuma dimasukin kalau labelnya valid (Gak kosong)
              if (label.isNotEmpty) {
                _tafsirSectionMap[label] = currentIndex;
                _tafsirAvailableSections.add(label);
                _tafsirSectionTargetIndices.add(currentIndex);
                //  PINDAHIN KE DALAM SINI BANG
                // Biar index cuma nambah kalau labelnya beneran ada
                _sortedTafsirIndices.add(currentIndex);
                _indexToTafsirLabel[currentIndex] = label;
              }
            }
          }

          if (tagName.startsWith("h")) {
            String levelStr = tagName.substring(1);
            String cleanTitle = content
                .replaceAll(SuttaTextHelper.htmlTagRegex, '')
                .trim();
            _tocList.add({
              "title": cleanTitle.isEmpty ? "Bagian" : cleanTitle,
              "index": currentIndex,
              "type": int.tryParse(levelStr) ?? 3,
            });
          }
          lastIndex = match.end;
        } catch (e) {
          continue;
        }
      }

      if (lastIndex < rawHtml.length) {
        String tail = rawHtml.substring(lastIndex);
        if (tail.trim().isNotEmpty) _htmlSegments.add(tail);
      }
      if (_htmlSegments.isEmpty) _htmlSegments.add(rawHtml);
    } catch (e) {
      _htmlSegments.clear();
      _htmlSegments.add(rawHtml);
      _tocList.clear();
    }
  }

  void _parseHtmlIfNeeded({bool force = false}) {
    final isHtmlFormat =
        (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"));
    // Cek: Kalau bukan HTML, atau sudah diparse DAN tidak dipaksa -> STOP
    if (!isHtmlFormat || (_isHtmlParsed && !force)) return;

    String rawHtml = "";
    if (widget.textData!["translation_text"] is Map &&
        widget.textData!["translation_text"].containsKey("text")) {
      final transMap = Map<String, dynamic>.from(
        widget.textData!["translation_text"],
      );
      final sutta = NonSegmentedSutta.fromJson(transMap);
      //  rawHtml = HtmlUnescape().convert(sutta.text);

      rawHtml = SuttaTextHelper.unescape.convert(sutta.text);
    } else if (widget.textData!["root_text"] is Map &&
        widget.textData!["root_text"].containsKey("text")) {
      final root = widget.textData?["root_text"] as Map<String, dynamic>? ?? {};
      final sutta = NonSegmentedSutta.fromJson(root);
      // rawHtml = HtmlUnescape().convert(sutta.text);
      rawHtml = SuttaTextHelper.unescape.convert(sutta.text);
    }

    //  DEBUG AMAN - NO SUBSTRING!
    if (rawHtml.contains('blockquote')) {
      //   debugPrint(" BLOCKQUOTE FOUND!");

      // Cari blockquote dan print FULL ISI (tanpa substring yang error)
      RegExp(
        r'<blockquote[^>]*>(.*?)</blockquote>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(rawHtml);

      //if (blockquoteMatch != null) {
      // final fullContent = blockquoteMatch.group(1) ?? "";
      //   debugPrint("📦 FULL BLOCKQUOTE CONTENT:");
      //  debugPrint(fullContent); //  Print semuanya tanpa potong
      //   debugPrint("📏 LENGTH: ${fullContent.length}");
      //  }
    } //else {
    // debugPrint(" NO BLOCKQUOTE FOUND!");
    //}

    if (rawHtml.isNotEmpty) {
      _parseHtmlAndGenerateTOC(rawHtml);
      _isHtmlParsed = true;
    }
  }

  // ============================================================
  // 1. HELPER SAKTI: SATU PINTU UNTUK CEK NAVIGASI
  // Urutan Cek: Translation -> Root -> Suttaplex (The Savior)
  // ============================================================
  Map<String, dynamic>? _getNavTarget(String key) {
    final root = widget.textData?["root_text"];
    final trans = widget.textData?["translation"];

    bool isValid(dynamic data) {
      return data is Map &&
          data["uid"] != null &&
          data["uid"].toString().isNotEmpty;
    }

    // 1. Cek Translation
    if (isValid(trans?[key])) return trans![key];

    // 2. Cek Root
    if (isValid(root?[key])) return root![key];

    // 3. Cek Suttaplex (Pake variable STATE, bukan widget.textData)
    // Ini kuncinya biar dapet data yang udah di-fetch ulang
    if (isValid(_canonicalSuttaplex?[key])) return _canonicalSuttaplex![key];

    return null;
  }

  Future<void> _initNavigationContext() async {
    // ... Logic Parent Vagga yang lama biarin aja ...
    final root = widget.textData?["root_text"];
    if (root is Map) {
      _parentVaggaId =
          root["vagga_uid"]?.toString() ??
          widget.textData?["resolved_vagga_uid"]?.toString();

      if (_parentVaggaId == null) {
        final resolved = await _resolveVaggaUid(widget.uid);
        if (resolved != null && mounted) {
          setState(() {
            _parentVaggaId = resolved;
          });
        }
      }
    }
    //  LOGIC BARU: CEK & ISI ULANG SUTTAPLEX KALAU KOPONG
    // Cek apakah prev & next null semua? (Indikasi data busuk)
    bool isHollow =
        (_canonicalSuttaplex?["previous"]?["uid"] == null) &&
        (_canonicalSuttaplex?["next"]?["uid"] == null);

    // Kalau datanya null/kopong, kita tarik data ASLI dari API
    if (_canonicalSuttaplex == null || isHollow) {
      try {
        // Pake service yang udah ada di sutta.dart
        final freshData = await SuttaService.fetchSuttaplex(widget.uid);

        if (mounted) {
          setState(() {
            // API Suttaplex balikinnya List, jadi ambil index [0]
            if (freshData is List && freshData.isNotEmpty) {
              _canonicalSuttaplex = freshData[0];
            } else if (freshData is Map<String, dynamic>) {
              _canonicalSuttaplex = freshData;
            }
          });
        }
      } catch (e) {
        debugPrint("Gagal fetch canonical suttaplex: $e");
      }
    }

    // Hitung ulang status tombol pake data baru
    _isFirst = _getNavTarget("previous") == null;
    _isLast = _getNavTarget("next") == null;

    if (mounted) setState(() {});
  }

  void _openTafsirGridModal() {
    // 1. Tentukan Tipe Tafsir (Cuma buat pewarnaan aja kalau di Sutta biasa)
    TafsirType currentType = TafsirType.mul;
    if (_isTafsirMode) {
      final title =
          widget.textData?["root_text"]?["title"]?.toString().toLowerCase() ??
          "";
      if (title.contains("aṭṭhakathā")) {
        currentType = TafsirType.att;
      } else if (title.contains("ṭīkā")) {
        currentType = TafsirType.tik;
      }
    }

    final bool showTikaButton = TafsirService().hasTika(widget.uid); // Cek dulu

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget buildSwitchBtn(String lbl, TafsirType type, bool isActive) {
          // ... (Fungsi buildSwitchBtn biarin sama persis kayak sebelumnya) ...
          final colorScheme = Theme.of(ctx).colorScheme;
          return SizedBox(
            width: 36,
            height: 36,
            child: FilledButton(
              onPressed: isActive
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _navigateTafsirInternal(widget.uid, type);
                    },
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: isActive
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: isActive
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                lbl,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    // Ubah judul dikit biar enak
                    // _isTafsirMode ? "Lompat ke Bagian (§)" : "Indeks Referensi",
                    "Indeks Referensi",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  //  HANYA TAMPILKAN SWITCHER M/A/T KALAU MODENYA TAFSIR
                  if (_isTafsirMode)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildSwitchBtn(
                          "M",
                          TafsirType.mul,
                          currentType == TafsirType.mul,
                        ),
                        const SizedBox(width: 8),
                        buildSwitchBtn(
                          "A",
                          TafsirType.att,
                          currentType == TafsirType.att,
                        ),
                        if (showTikaButton) const SizedBox(width: 8),
                        if (showTikaButton)
                          buildSwitchBtn(
                            "Ṭ",
                            TafsirType.tik,
                            currentType == TafsirType.tik,
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _tafsirAvailableSections.length,
                  itemBuilder: (context, index) {
                    final num = _tafsirAvailableSections[index];
                    final int targetIndex = _tafsirSectionTargetIndices[index];

                    // BIKIN NOMOR URUT (Index + 1)
                    final String sequence = "(${index + 1})";

                    return InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (!mounted) return;
                        //_scrollToParagraph(num);
                        _scrollToParagraphByIndex(targetIndex, num);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        // Biar nomor urutnya kecil, nomor aslinya gede
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              height: 1.2,
                            ),
                            children: [
                              // 1. Nomor Urut Kecil di atas/depan (Pudar dikit)
                              TextSpan(
                                text: "$sequence ",
                                style: TextStyle(
                                  fontSize: 10, // Kecilin dikit
                                  fontWeight: FontWeight.normal,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              // 2. Nomor Asli (Tebal)
                              TextSpan(
                                text: _isTafsirMode ? "§$num" : num,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // ============================================================
  // 🎮 CONTROLLER: LOGIKA NAVIGASI TERPUSAT
  // ============================================================

  void _goToPrevSutta() => _handleNavigation(isNext: false);
  void _goToNextSutta() => _handleNavigation(isNext: true);

  Future<void> _handleNavigation({required bool isNext}) async {
    // 1. Cek Blokir Tematik
    if (widget.entryPoint == "tematik") {
      _showSuttaSnackBar(SuttaSnackType.disabledForTematik);
      return;
    }

    // 2. Ambil Target
    final key = isNext ? "next" : "previous";
    final navTarget = _getNavTarget(key);

    // 3. Cek Mentok
    if (navTarget == null || navTarget["uid"] == null) {
      _showSuttaSnackBar(
        isNext ? SuttaSnackType.lastText : SuttaSnackType.firstText,
        uid: widget.uid,
      );
      return;
    }

    final String targetUid = navTarget["uid"].toString();

    // 4. Cabang Logika
    if (_isTafsirMode) {
      // --- TAFSIR ---
      await _handleTafsirNavigation(targetUid, isNext: isNext);
    } else {
      // --- SUTTA BIASA ---
      await _handleStandardNavigation(targetUid, navTarget, isNext: isNext);
    }
  }

  // Logic Tafsir (Tetap pakai logic khusus karena strukturnya beda)
  Future<void> _handleTafsirNavigation(
    String targetUid, {
    required bool isNext,
  }) async {
    setState(() => _isLoading = true);
    try {
      final currentType = _getCurrentTafsirType();

      // Update suttaplex context
      final freshData = await SuttaService.fetchSuttaplex(targetUid);
      if (freshData is List && freshData.isNotEmpty) {
        _canonicalSuttaplex = freshData[0];
      }

      await _navigateTafsirInternal(
        targetUid,
        currentType,
        isNextPrevAction: true,
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Logic Standard (Sekarang jauh lebih bersih karena pake Engine _replaceToSutta)
  Future<void> _handleStandardNavigation(
    String targetUid,
    Map<String, dynamic> navTarget, {
    required bool isNext,
  }) async {
    // A. Tentukan Author (Priority: Author sekarang -> Author saran -> 'ms')
    String? currentAuthorUid = widget.textData?["author_uid"]?.toString();
    if (currentAuthorUid == null && widget.textData?["translation"] != null) {
      currentAuthorUid = widget.textData?["translation"]?["author_uid"]
          ?.toString();
    }
    final String targetAuthorUid =
        currentAuthorUid ?? navTarget["author_uid"]?.toString() ?? "ms";

    // B. Tentukan Bahasa & Segmented
    final segmented = widget.textData?["segmented"] == true;
    final targetLang = segmented
        ? widget.lang
        : navTarget["lang"]?.toString() ?? widget.lang;

    // C. PANGGIL ENGINE
    await _replaceToSutta(
      targetUid,
      targetLang,
      authorUid: targetAuthorUid,
      segmented: segmented,
      isNext: isNext, // Ngatur arah animasi
      isNavigatedAction: true, // Ngasih tau ini hasil navigasi Next/Prev
    );
  }

  // ============================================================
  //  FUNGSI SCROLL PARAGRAF (WAJIB ADA)
  // ============================================================

  // 1. Logic Cari Index (Support Range kayak 101-103)
  int? _findTafsirSectionIndex(String targetNum) {
    if (_tafsirSectionMap.containsKey(targetNum)) {
      return _tafsirSectionMap[targetNum];
    }

    // Parse input user (misal "101")
    int? inputStart;
    if (targetNum.contains('-')) {
      final parts = targetNum.split('-');
      if (parts.isNotEmpty) inputStart = int.tryParse(parts[0]);
    } else {
      inputStart = int.tryParse(targetNum);
    }

    if (inputStart == null) return null;

    // Cari di map
    for (final key in _tafsirSectionMap.keys) {
      int? keyStart;
      int? keyEnd;

      if (key.contains('-')) {
        final parts = key.split('-');
        if (parts.length == 2) {
          final startStr = parts[0];
          final endStr = parts[1];
          keyStart = int.tryParse(startStr);

          // Handle range pendek (101-3 -> 101-103)
          if (endStr.length < startStr.length) {
            final prefix = startStr.substring(
              0,
              startStr.length - endStr.length,
            );
            keyEnd = int.tryParse(prefix + endStr);
          } else {
            keyEnd = int.tryParse(endStr);
          }
        }
      } else {
        keyStart = int.tryParse(key);
        keyEnd = keyStart;
      }

      if (keyStart != null && keyEnd != null) {
        // Cek apakah input ada di dalam range key
        if (inputStart >= keyStart && inputStart <= keyEnd) {
          return _tafsirSectionMap[key];
        }
        // Cek sebaliknya (Key ada di dalam input range)
        if (targetNum.contains('-') && keyStart == inputStart) {
          return _tafsirSectionMap[key];
        }
      }
    }
    return null;
  }

  // Fungsi baru buat Grid (Langsung tembak index, gak perlu nyari)
  void _scrollToParagraphByIndex(int index, String label) {
    if (!_itemScrollController.isAttached) return;

    final colors = _currentStyle;

    _itemScrollController.jumpTo(index: index, alignment: 0.15);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Melompat ke §$label",
          style: TextStyle(color: colors.bg),
        ),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.text,
        margin: EdgeInsets.only(
          bottom: _getSnackBarBottomMargin(),
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  // 2. Fungsi Eksekusi Scroll (UPDATED: SMART FALLBACK)
  void _scrollToParagraph(String num, {bool showSnackBar = true}) {
    if (!_itemScrollController.isAttached) return;

    // A. CARI EXACT MATCH DULU (Logika Lama)
    int? index = _findTafsirSectionIndex(num);
    String targetLabel = num; // Label yang akan muncul di SnackBar

    // B. LOGIKA BARU: SMART SCANNING / FALLBACK
    // Jika nomor persis (misal 81) gak ketemu, cari angka berikutnya (82, 83...)
    if (index == null) {
      int? startSeq;
      int? endSeq;

      // 1. Parse Range Input (misal: "81-85" atau "81")
      try {
        if (num.contains('-')) {
          final parts = num.split('-');
          if (parts.length >= 2) {
            startSeq = int.tryParse(parts[0]);

            // Handle logic range pendek (misal "101-5" artinya "101-105")
            final String startStr = parts[0];
            final String endStr = parts[1];

            if (startSeq != null) {
              if (endStr.length < startStr.length) {
                final prefix = startStr.substring(
                  0,
                  startStr.length - endStr.length,
                );
                endSeq = int.tryParse(prefix + endStr);
              } else {
                endSeq = int.tryParse(endStr);
              }
            }
          }
        } else {
          startSeq = int.tryParse(num);
          // Kalau input cuma angka tunggal ("81"), kita kasih toleransi scan
          // misal +5 angka ke depan untuk jaga-jaga beda penomoran sedikit.
          if (startSeq != null) endSeq = startSeq + 5;
        }

        // 2. Jalankan Loop Scanning
        if (startSeq != null && endSeq != null && endSeq > startSeq) {
          // Safety: Batasi loop max 20 langkah biar ga ngelag kalau rangenya "1-1000"
          int scanLimit = (endSeq - startSeq).clamp(0, 20);

          for (int i = 1; i <= scanLimit; i++) {
            int nextCandidate = startSeq + i;
            String nextKey = nextCandidate.toString();

            // Cek ke Database (Map) apakah angka tetangga ini ada?
            // Fungsi _findTafsirSectionIndex sudah pinter, dia bisa ngecek
            // kalau kita cari "82" tapi di DB adanya "82-85", dia bakal return indexnya.
            int? fallbackIndex = _findTafsirSectionIndex(nextKey);

            if (fallbackIndex != null) {
              index = fallbackIndex;
              targetLabel =
                  nextKey; // Update label jadi yang ketemu (misal "82")
              break; // STOP LOOP, KETEMU!
            }
          }
        }
      } catch (e) {
        // Silent error parsing, lanjut ke logic error biasa
      }
    }

    final colors = _currentStyle;

    if (index != null) {
      //  1. KASUS KETEMU (SUKSES)
      _itemScrollController.jumpTo(index: index, alignment: 0.15);

      if (showSnackBar) {
        ScaffoldMessenger.of(context).clearSnackBars();

        // Cek apakah ini hasil fallback? (Input user != Target yang ketemu)
        final bool isFallback = targetLabel != num;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFallback
                  ? "Melompat ke §$targetLabel (Terdekat)" // Kasih tau user kalau digeser dikit
                  : "Melompat ke §$targetLabel",
              style: TextStyle(color: colors.bg),
            ),
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.text,
            margin: EdgeInsets.only(
              bottom: _getSnackBarBottomMargin(),
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    } else {
      if (!RegExp(r'^\d').hasMatch(num)) return;

      if (showSnackBar) {
        // 1. CEK ANTI-SPAM
        if (_lastErrorTime != null &&
            (_lastErrorTime != null &&
                DateTime.now().difference(_lastErrorTime!) <
                    const Duration(seconds: 2))) {
          return;
        }
        _lastErrorTime = DateTime.now();

        // 2. PAKSA HILANGKAN YANG LAMA TANPA ANIMASI
        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        debugPrint("SnackBar Muncul! - Target: §$num");

        // 3. TAMPILKAN SNACKBAR (DURASI 5 DETIK)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tak ada penjelas spesifik untuk §$num",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: _getSnackBarBottomMargin(),
              left: 16,
              right: 16,
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Kembali',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                _navigateTafsirInternal(
                  widget.uid,
                  TafsirType.mul,
                  targetParamNum: num,
                );
              },
            ),
          ),
        );

        // 🔥 JALUR KERAS: Paksa tutup manual setelah 5 detik lewat Timer
        Timer(const Duration(seconds: 5), () {
          if (mounted) ScaffoldMessenger.of(context).removeCurrentSnackBar();
        });
      }
    }
  }

  // A. Dialog Switcher (Muncul pas klik nomor paragraf di teks)
  //  UI BARU: Dialog Ganti Versi (Tampilan Tafsir Style)
  void _showTafsirSwitcherDialog(String num) {
    final bool showTikaButton = TafsirService().hasTika(widget.uid); // Cek dulu

    // Tentukan tipe sekarang (default Mula kalau gak kedeteksi)
    TafsirType currentType = TafsirType.mul;
    final titleLower =
        widget.textData?["root_text"]?["title"]?.toString().toLowerCase() ?? "";
    if (titleLower.contains("aṭṭhakathā")) {
      currentType = TafsirType.att;
    } else if (titleLower.contains("ṭīkā")) {
      currentType = TafsirType.tik;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          scrollable: true,
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '§$num',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jika ada, buka penjelas/komentar bagian ini di kitab:',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _buildNavButton(
                ctx,
                icon: Icons.book_outlined,
                label: 'Mūla',
                subtitle: 'Kitab Induk',
                isActive: currentType == TafsirType.mul,
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateTafsirInternal(
                    widget.uid,
                    TafsirType.mul,
                    targetParamNum: num,
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildNavButton(
                ctx,
                icon: Icons.comment_outlined,
                label: 'Aṭṭhakathā',
                subtitle: 'Kitab Komentar',
                isActive: currentType == TafsirType.att,
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateTafsirInternal(
                    widget.uid,
                    TafsirType.att,
                    targetParamNum: num,
                  );
                },
              ),
              if (showTikaButton) const SizedBox(height: 8),
              if (showTikaButton)
                _buildNavButton(
                  ctx,
                  icon: Icons.layers_outlined,
                  label: 'Ṭīkā',
                  subtitle: 'Kitab Subkomentar',
                  isActive: currentType == TafsirType.tik,
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateTafsirInternal(
                      widget.uid,
                      TafsirType.tik,
                      targetParamNum: num,
                    );
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _handleWordLookup(String text) {
    if (text.isEmpty) return;

    //  Cuma butuh context sama text doang
    PaliDictionaryManager.show(context, text: text);
  }

  // 2. Replace fungsi _handleAiTranslation
  void _handleAiTranslation(String text) {
    if (text.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AITranslationSheet(text: text),
    );
  }

  //  HELPER BARU: SATU PINTU UNTUK SEMUA NAVIGASI MENU
  // Fungsi ini otomatis ngitung Acronym "Bu Pj" dkk sebelum buka halaman.
  void _openMenuPage(String targetUid) {
    String derivedAcronym = "";
    final uid = targetUid.toLowerCase().trim();

    // --- FILTER 1: KHUSUS VINAYA (Manual Mapping) ---
    if (uid.startsWith("pli-tv-")) {
      if (uid.contains("bu-vb-pj")) {
        derivedAcronym = "Bu Pj";
      } else if (uid.contains("bu-vb-ss")) {
        derivedAcronym = "Bu Ss";
      } else if (uid.contains("bu-vb-ay")) {
        derivedAcronym = "Bu Ay";
      } else if (uid.contains("bu-vb-np")) {
        derivedAcronym = "Bu Np";
      } else if (uid.contains("bu-vb-pc")) {
        derivedAcronym = "Bu Pc";
      } else if (uid.contains("bu-vb-pd")) {
        derivedAcronym = "Bu Pd";
      } else if (uid.contains("bu-vb-sk")) {
        derivedAcronym = "Bu Sk";
      } else if (uid.contains("bu-vb-as")) {
        derivedAcronym = "Bu As";
      } else if (uid.contains("bi-vb-pj")) {
        derivedAcronym = "Bi Pj";
      } else if (uid.contains("bi-vb-ss")) {
        derivedAcronym = "Bi Ss";
      } else if (uid.contains("bi-vb-np")) {
        derivedAcronym = "Bi Np";
      } else if (uid.contains("bi-vb-pc")) {
        derivedAcronym = "Bi Pc";
      } else if (uid.contains("bi-vb-pd")) {
        derivedAcronym = "Bi Pd";
      } else if (uid.contains("bi-vb-sk")) {
        derivedAcronym = "Bi Sk";
      } else if (uid.contains("bi-vb-as")) {
        derivedAcronym = "Bi As";
      } else if (uid.contains("kd")) {
        derivedAcronym = "Kd";
      } else if (uid.contains("pvr")) {
        derivedAcronym = "Pvr";
      } else if (uid.contains("bu-pm")) {
        derivedAcronym = "Bu";
      } else if (uid.contains("bi-pm")) {
        derivedAcronym = "Bi";
      }
    }
    // --- FILTER 2: 4 NIKAYA UTAMA ---
    else if (uid.startsWith("dn") ||
        uid.startsWith("mn") ||
        uid.startsWith("sn") ||
        uid.startsWith("an")) {
      if (uid.length >= 2) {
        derivedAcronym = uid.substring(0, 2).toUpperCase();
      }
    }
    // --- FILTER 3: KHUDDAKA & LAINNYA ---
    else {
      //  FIX: Regex yang lebih robust untuk handle berbagai format
      // Misal: "tha-ap-1.1" → "tha-ap"
      //        "thag-1-upalivagga" → "thag"
      //        "thig-2.1" → "thig"
      final match = RegExp(r'^([a-z]+(?:-[a-z]+)?)').firstMatch(uid);
      if (match != null) {
        String raw = match.group(1)!.replaceAll("-", " ").trim();
        derivedAcronym = raw
            .split(" ")
            .map(
              (str) =>
                  str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : "",
            )
            .join(" ");
      }
    }

    //  NORMALIZE hasilnya buat konsistensi
    derivedAcronym = normalizeNikayaAcronym(derivedAcronym);

    //debugPrint("🚀 [OPEN MENU] UID: $targetUid → ACRONYM: '$derivedAcronym'");

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/vagga/$targetUid'),
        builder: (_) => MenuPage(uid: targetUid, parentAcronym: derivedAcronym),
      ),
    );
  }

  // ============================================================
  // 📖 ENGINE KHUSUS TAFSIR (CSCD VRI)
  // Dipanggil kalau user lagi baca Mula/Att/Tik
  // ============================================================
  Future<void> _navigateTafsirInternal(
    String targetUid,
    TafsirType type, {
    String? targetParamNum,
    bool isNextPrevAction = false, // Parameter penting buat Back Button
  }) async {
    setState(() => _isLoading = true);

    try {
      String titlePrefix = type == TafsirType.mul
          ? "Mūla"
          : (type == TafsirType.att ? "Aṭṭhakathā" : "Ṭīkā");

      // Tarik konten HTML tafsir
      final html = await TafsirService().getContent2(targetUid, type: type);

      if (html == null || html.trim().isEmpty || html.length < 50) {
        throw Exception("Konten tafsir kosong");
      }

      // Bikin data palsu (Mock Data) biar SuttaDetail bisa baca
      final fakeData = {
        "uid": targetUid,
        "is_tafsir": true,
        "segmented": false,
        "root_text": {
          "title": "$titlePrefix (Tafsir)",
          "text": html,
          "lang": "pli",
        },
        "suttaplex": _canonicalSuttaplex,
        "target_paragraph": targetParamNum,
      };

      if (!mounted) return;

      // Push halaman baru
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => SuttaDetail(
            uid: targetUid,
            lang: 'pli',
            textData: fakeData,

            //  LOGIC BACK BUTTON:
            // Kalau ini aksi Next/Prev, paksa true biar History nyambung.
            // Kalau cuma ganti Tab (M/A/T), ikut status sebelumnya.
            isNavigated: isNextPrevAction || widget.isNavigated,

            entryPoint: widget.entryPoint,
            targetParaNum: targetParamNum,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (e) {
      debugPrint("Gagal load tafsir: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        final typeName = type == TafsirType.att
            ? "Aṭṭhakathā"
            : (type == TafsirType.tik ? "Ṭīkā" : "Mūla");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Maaf, $typeName untuk $targetUid tidak tersedia."),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            // Pake helper margin biar gak ketutup menu
            margin: EdgeInsets.only(
              bottom: _getSnackBarBottomMargin(),
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

  // Wrapper buat tombol Back di UI
  Future<void> _onBackPressed() async {
    if (_isLoading) return;
    final navigator = Navigator.of(context);

    // Panggil logic pengecekan (dialog konfirmasi, reset stack, dll)
    final allow = await _handleBackReplace();

    // Kalau diizinkan (allow == true), baru pop
    if (allow && mounted) {
      navigator.pop();
    }
  }

  Future<bool> _handleBackReplace() async {
    // 1. Resolve Parent Vagga (Logika Backend)
    if (_parentVaggaId == null) {
      final resolved = await _resolveVaggaUid(widget.uid);
      if (mounted && resolved != null) {
        setState(() {
          _parentVaggaId = resolved;
        });
      }
    }

    if (!mounted) return false;

    // 2. Tampilkan Dialog Konfirmasi (UI Baru)
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        //  Use 'ctx' NOT 'context'
        final colorScheme = Theme.of(ctx).colorScheme; //  FIXED

        final bool showTikaButton = TafsirService().hasTika(
          widget.uid,
        ); // Cek dulu

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Judul dengan Icon
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  "Sudahi sesi baca?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Anda akan kembali ke menu utama dan riwayat navigasi saat ini akan direset.",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),

              //  KOTAK TIPS PINTAR
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Warna background tipis banget biar gak norak
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                          children: _isTafsirMode
                              ? [
                                  //  TIPS KHUSUS TAFSIR / CSCD
                                  const TextSpan(
                                    text:
                                        "Ingin lompat ke bagian tertentu? Gunakan ",
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.link, // Ikon Rantai
                                        size: 16,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    // Hapus 'const' di sini karena teksnya sekarang dinamis
                                    text:
                                        " di menu bawah. Ketuk §# atau M|A${showTikaButton ? '|Ṭ' : ''} di atas untuk akses cepat.",
                                  ),
                                ]
                              : [
                                  //  TIPS STANDARD (SUTTA BIASA)
                                  const TextSpan(
                                    text:
                                        "Ingin ganti versi atau tandai teks? Gunakan ",
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.translate_rounded,
                                        size: 16,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: " di menu bawah tanpa perlu keluar.",
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Batal"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),

                      //  GANTI JADI INI:
                      // Pake 'primary' biar warnanya Oren ngikut tema aplikasi
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text("Keluar"),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    // Cek hasil dialog
    if (shouldLeave != true) return false;
    if (!mounted) return false;

    // ---------------------------------------------------------
    //  LOGIC NAVIGASI UTAMA (Sesuai kode sebelumnya)
    // ---------------------------------------------------------

    // SKENARIO 1: Belum pindah-pindah sutta, langsung pop aja
    if (!_hasNavigatedBetweenSuttas) {
      return true;
    }

    // SKENARIO 2: Udah navigasi jauh, kita reset stack-nya

    // A. Reset sampai Home
    Navigator.of(context).popUntil((route) => route.isFirst);

    // B. Buka ulang Menu Page (Vagga) kalau entry point-nya dari Menu
    if (widget.entryPoint == "menu_page") {
      final rootPrefix = widget.uid.replaceAll(RegExp(r'\d.*$'), '');
      if (rootPrefix.isNotEmpty && rootPrefix != _parentVaggaId) {
        _openMenuPage(rootPrefix);
      }
      if (_parentVaggaId != null) {
        _openMenuPage(_parentVaggaId!);
      }
    }

    // C. Tampilin Modal Suttaplex lagi (Biar user gak bingung tiba-tiba ilang)
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        settings: RouteSettings(name: '/suttaplex/${widget.uid}'),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: Suttaplex(
                        uid: widget.uid,
                        sourceMode: "sutta_detail",
                        initialData:
                            widget.textData?["suttaplex"]
                                as Map<String, dynamic>?,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    return false; // Kita handle navigasi manual, jadi return false
  }

  void _replaceToRoute(String route) {
    Widget targetPage;

    if (route.startsWith('/vagga/')) {
      final vaggaId = route.split('/').last;
      targetPage = MenuPage(uid: vaggaId);
    } else if (route.startsWith('/suttaplex/')) {
      final suttaId = route.split('/').last;
      targetPage = Suttaplex(uid: suttaId);
    } else {
      targetPage = const Scaffold(
        body: Center(child: Text("Route belum dihubungkan")),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  // ============================================================
  // 🚜 ENGINE: FUNGSI PEMUAT HALAMAN (REUSABLE)
  // Dipakai oleh: Next/Prev, Modal Suttaplex, dan Retry Koneksi
  // ============================================================
  // ============================================================
  // 🚜 ENGINE: FUNGSI PEMUAT HALAMAN (REUSABLE)
  // Dipakai oleh: Next/Prev, Modal Suttaplex, dan Retry Koneksi
  // ============================================================
  Future<void> _replaceToSutta(
    String newUid,
    String lang, {
    required String authorUid,
    required bool segmented,
    Map<String, dynamic>? textData,
    bool isNext = true, // Default animasi slide dari kanan (Next)
    bool isNavigatedAction = false, // Flag kalau ini hasil pencetan Next/Prev
  }) async {
    // --- TAMBAHAN 3: BERSIHKAN STATE SELEKSI ---
    // Mencegah error saat widget lama dibuang (dispose)
    _currentSelectedText = '';
    FocusManager.instance.primaryFocus?.unfocus();
    // -------------------------------------------

    setState(() {
      _isLoading = true;
      _connectionError = false;
    });

    try {
      // 1. Fetch Data (Kalau belum ada textData)
      final data =
          textData ??
          await SuttaService.fetchFullSutta(
            uid: newUid,
            authorUid: authorUid,
            lang: lang,
            segmented: segmented,
            siteLanguage: "id",
          );

      // 2. Validasi Author (Server kadang bandel)
      String? fetchedAuthor;
      if (segmented) {
        if (data["translation_text"] is Map) {
          fetchedAuthor = data["translation_text"]["author_uid"]?.toString();
        }
      } else {
        fetchedAuthor = data["translation"]?["author_uid"]?.toString();
      }

      // ---  TAMBAHAN LOGIKA VALIDASI KONTEN (SATPAM) ---
      // Cek apakah data segmented ada isinya atau data HTML ada "text"-nya
      final bool hasSegmentedContent =
          segmented &&
          (data["root_text"] is Map && (data["root_text"] as Map).isNotEmpty);

      final bool hasHtmlContent =
          !segmented &&
          ((data["translation_text"] is Map &&
                  data["translation_text"].containsKey("text")) ||
              (data["root_text"] is Map &&
                  data["root_text"].containsKey("text")));

      // Jika Author tidak sesuai (mismatch) atau konten beneran kosong, munculkan SnackBar
      if ((authorUid != "ms" &&
              fetchedAuthor != null &&
              fetchedAuthor != authorUid) ||
          (!hasSegmentedContent && !hasHtmlContent)) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSuttaSnackBar(
            SuttaSnackType.translatorFallback,
            uid: newUid,
            lang: lang,
            author: authorUid,
          );
        }
        return; // 🛑 BERHENTI DI SINI, jangan lanjut pindah halaman
      }
      // --------------------------------------------------

      // 3. Merge Data
      final Map<String, dynamic> mergedData = {
        ...data,
        "segmented": segmented,
        "suttaplex": data["suttaplex"] ?? widget.textData?["suttaplex"],
      };

      // 4. Update Tracking Vagga
      await _processVaggaTracking(mergedData, newUid);

      if (!mounted) return;

      // 5. Push Route
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: '/sutta/$newUid'),
          pageBuilder: (_, _, _) => SuttaDetail(
            uid: newUid,
            lang: lang,
            textData: mergedData,
            openedFromSuttaDetail: true,
            originalSuttaUid: null,
            entryPoint: widget.entryPoint,
            //  PENTING: Flag ini biar tombol Back tau history-nya
            isNavigated: isNavigatedAction || widget.isNavigated,
          ),
          transitionsBuilder: (_, animation, _, child) {
            // Logic Animasi:
            // Next -> Slide dari Kanan (Offset 1,0)
            // Prev -> Slide dari Kiri (Offset -1,0)
            final offsetBegin = isNext
                ? const Offset(1, 0)
                : const Offset(-1, 0);
            final tween = Tween(
              begin: offsetBegin,
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeInOut));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );

      if (lang == "en") _showEnFallbackBanner();
    } catch (e) {
      debugPrint(" Error _replaceToSutta: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains("SocketException")) {
          setState(() => _connectionError = true);
        } else {
          // Fallback ke suttaplex kalau gagal total
          _replaceToRoute('/suttaplex/$newUid');
        }
      }
    }
  }

  Future<String?> _resolveVaggaUid(String suttaUid) async {
    try {
      final match = SuttaTextHelper.vaggaUidRegex.firstMatch(
        suttaUid.toLowerCase(),
      );

      if (match == null) {
        return null;
      }

      final collection = match.group(1)!;
      final bookNum = int.parse(match.group(2)!);
      final suttaNum = match.group(3) != null
          ? int.parse(match.group(3)!)
          : null;

      String currentParent = collection;
      String? lastValidParent;

      for (int level = 0; level < 5; level++) {
        final menuData = await SuttaService.fetchMenu(
          currentParent,
          language: "id",
        );
        if (menuData is! List || menuData.isEmpty) break;

        final root = menuData[0];
        final children = root["children"] as List?;
        if (children == null || children.isEmpty) {
          if (currentParent != collection) {
            lastValidParent = currentParent;
          }
          break;
        }

        String? nextParent;

        for (var child in children) {
          final childUid = child["uid"]?.toString() ?? "";
          final rangeStr = child["child_range"]?.toString() ?? "";

          if (rangeStr.isEmpty) continue;

          final nums = RegExp(
            r'(\d+)',
          ).allMatches(rangeStr).map((m) => int.parse(m.group(1)!)).toList();

          if (nums.isEmpty) continue;

          bool isMatch = false;

          if (level == 0 && (collection == 'sn' || collection == 'an')) {
            int start = nums.first;
            int end = nums.last;
            if (bookNum >= start && bookNum <= end) isMatch = true;
          } else if (nums.length == 2 && suttaNum == null) {
            int start = nums[0];
            int end = nums[1];
            if (bookNum >= start && bookNum <= end) isMatch = true;
          } else if (nums.length == 3 && suttaNum != null) {
            int rangeBook = nums[0];
            int start = nums[1];
            int end = nums[2];

            if (rangeBook == bookNum && suttaNum >= start && suttaNum <= end) {
              isMatch = true;
            }
          } else if (nums.length == 1 && suttaNum == null) {
            if (nums.first == bookNum &&
                childUid.contains(bookNum.toString())) {
              isMatch = true;
            }
          } else if (nums.length == 2 && suttaNum != null) {
            if (childUid.contains('$collection$bookNum')) {
              int start = nums[0];
              int end = nums[1];
              if (suttaNum >= start && suttaNum <= end) isMatch = true;
            }
          } else if (suttaNum != null &&
              nums.length >= 3 &&
              (collection == 'sn' || collection == 'an')) {
            if (nums[0] == bookNum) {
              int start = nums[nums.length - 2];
              int end = nums.last;
              if (suttaNum >= start && suttaNum <= end) isMatch = true;
            }
          }

          if (isMatch) {
            nextParent = child["uid"];
            break;
          }
        }

        if (nextParent != null) {
          if (currentParent != collection) {
            lastValidParent = currentParent;
          }
          currentParent = nextParent;
        } else {
          if (currentParent != collection) {
            lastValidParent = currentParent;
          }
          break;
        }
      }

      if (currentParent != collection) {
        return currentParent;
      } else if (lastValidParent != null) {
        return lastValidParent;
      }

      return collection;
    } catch (e) {
      debugPrint("Error resolving vagga: $e");
      return null;
    }
  }

  Future<void> _processVaggaTracking(
    Map<String, dynamic> mergedData,
    String targetUid,
  ) async {
    final vaggaBeforeNavigate = _parentVaggaId;

    _updateParentAnchorOnMove(
      mergedData["root_text"] as Map<String, dynamic>?,
      mergedData["suttaplex"] as Map<String, dynamic>?,
    );

    if (widget.textData?["initial_vagga_uid"] != null) {
      mergedData["initial_vagga_uid"] = widget.textData!["initial_vagga_uid"];
    } else {
      mergedData["initial_vagga_uid"] = vaggaBeforeNavigate;
    }

    final rootMeta = mergedData["root_text"];
    if (rootMeta is Map &&
        rootMeta["vagga_uid"] != null &&
        rootMeta["vagga_uid"].toString().trim().isNotEmpty) {
      final vaggaUid = rootMeta["vagga_uid"].toString();
      if (mounted) setState(() => _parentVaggaId = vaggaUid);
      mergedData["resolved_vagga_uid"] = vaggaUid;
    } else {
      final resolvedVagga = await _resolveVaggaUid(targetUid);
      if (resolvedVagga != null) {
        if (mounted) setState(() => _parentVaggaId = resolvedVagga);
        mergedData["resolved_vagga_uid"] = resolvedVagga;
      }
    }
  }

  //  HELPER BARU: Hitung posisi notif biar gak ketutupan menu
  double _getSnackBarBottomMargin() {
    // Margin dasar dari bawah layar
    double margin = 20.0;

    // Cek Menu Bawah
    if (_isBottomMenuVisible) {
      // Tinggi Menu (~60px) + Toggle (16px) + Buffer
      margin += 80.0;
    } else {
      // Tinggi Toggle doang (Super Ceper 16px)
      margin += 16.0;
    }

    return margin;
  }

  void _showSuttaSnackBar(
    SuttaSnackType type, {
    String? uid,
    String? lang,
    String? author,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    List<InlineSpan> contentSpans = [];
    Color bgColor = Theme.of(context).colorScheme.inverseSurface;

    String acronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        uid ??
        "kitab ini";

    switch (type) {
      case SuttaSnackType.translatorFallback:
        bgColor = Colors.deepOrange.shade400;
        contentSpans = [
          TextSpan(
            text:
                "Teks $uid ($lang) oleh $author tak tersedia. Ganti versi terjemahan melalui ",
          ),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.translate_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const TextSpan(text: " di menu bawah."),
        ];
        break;

      case SuttaSnackType.firstText:
        bgColor = Colors.deepOrange.shade400;
        contentSpans = [
          TextSpan(text: "Anda berada di awal ($acronym). Gunakan tombol "),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const TextSpan(text: " untuk kembali ke menu."),
        ];
        break;

      case SuttaSnackType.lastText:
        bgColor = Colors.deepOrange.shade400;
        contentSpans = [
          TextSpan(
            text: "Anda telah mencapai akhir ($acronym). Gunakan tombol ",
          ),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const TextSpan(text: " untuk kembali ke menu."),
        ];
        break;

      case SuttaSnackType.disabledForTematik:
        bgColor = Colors.grey.shade800;
        contentSpans = [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.block_rounded, color: Colors.white, size: 18),
            ),
          ),
          const TextSpan(text: "Navigasi dimatikan pada mode Tematik."),
        ];
        break;

      // TAMBAHIN CASE INI:
      case SuttaSnackType.disabledTafsir:
        bgColor = Colors.grey.shade800;
        contentSpans = [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.info_outline, color: Colors.white, size: 18),
            ),
          ),
          const TextSpan(text: "Navigasi dimatikan pada mode CSCD VRI."),
        ];
        break;
    }

    //  AMBIL MARGIN DINAMIS
    final bottomMargin = _getSnackBarBottomMargin();

    messenger.showSnackBar(
      SnackBar(
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            children: contentSpans,
          ),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

        //  UPDATE MARGIN BIAR GAK KETUTUP MENU
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin, // <--- INI KUNCINYA
        ),

        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // 3. UPDATE ANCHOR SAAT GESER (Konsisten pake helper)
  // ============================================================
  void _updateParentAnchorOnMove(
    Map<String, dynamic>? root,
    Map<String, dynamic>? suttaplex,
  ) {
    _isFirst = _getNavTarget("previous") == null;
    _isLast = _getNavTarget("next") == null;

    if (mounted) setState(() {});
  }

  void _showEnFallbackBanner() {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
          "Bahasa Indonesia tidak tersedia, menampilkan versi Inggris.",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SuttaDetail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Kalau data teks berubah (misal ganti bahasa di modal suttaplex)
    if (widget.textData != oldWidget.textData) {
      setState(() {
        //  CUKUP PANGGIL INI AJA:
        _processNewTextData();
      });
    }
  }

  //  FIX: Replace '|' with double break line for readability

  WidgetSpan _buildCommentSpan(
    BuildContext context,
    String comm,
    double fontSize,
  ) {
    //  VALIDASI: Kalau comm null/kosong, return widget kosong
    if (comm.isEmpty) {
      return const WidgetSpan(child: SizedBox.shrink());
    }

    // Format baris baru di komentar
    final formattedComm = comm.replaceAll('|', '<br><br>');

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                "Komentar",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SingleChildScrollView(
                child: Html(
                  data: formattedComm,
                  style: {
                    "body": Style(
                      fontFamily: _currentFontFamily,
                      fontSize: FontSize(fontSize),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  },
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
        },
        child: SelectionContainer.disabled(
          child: Padding(
            padding: const EdgeInsets.only(left: 0.1),
            child: Text(
              "[note]",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w100,
                fontSize: fontSize * 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cachedSearchRegex = null;

    _itemPositionsListener.itemPositions.removeListener(
      _updateVisibleParagraph,
    );

    _scrollProgressVN.dispose();
    _viewportRatioVN.dispose();
    _visibleParaNumVN.dispose();
    _showFloatingBtnVN.dispose();

    super.dispose();
  }

  SuttaHeaderConfig _getHeaderConfig(String key, {bool isPaliOnly = false}) {
    final verseNumRaw = key.contains(":") ? key.split(":").last : key;
    final verseNum = verseNumRaw.trim();

    final isH1 = verseNum == "0.1";
    final isH2 = verseNum == "0.2";
    final headerRegex = RegExp(r'^(?:\d+\.)*0(?:\.\d+)*$');
    final isHeader = headerRegex.hasMatch(verseNum);
    final isH3 = isHeader && !isH1 && !isH2;

    final colors = _currentStyle;
    final mainTextColor = colors.text;

    //  INI KUNCINYA: Ambil warna Pali dari tema
    final paliThemeColor = colors.pali;

    // Logic: Kalau mode Pali Only, judul pake warna teks biasa biar tegas.
    // Tapi kalau ada terjemahan (segmented), judul Pali pake warna Pali.
    final paliColorToUse = isPaliOnly ? mainTextColor : paliThemeColor;

    TextStyle paliStyle, transStyle;
    double topPadding, bottomPadding;

    if (isH1) {
      topPadding = 16.0;
      bottomPadding = 16.0;

      //  PALI STYLE (Pake paliColorToUse)
      paliStyle = TextStyle(
        fontFamily: _currentFontFamily,
        fontSize: _fontSize * 1.10,
        fontWeight: FontWeight.w900,
        color: paliColorToUse, // <--- GANTI DISINI
        height: 1.2,
        letterSpacing: -0.5,
      );

      //  TRANS STYLE (Tetep Hitam/Warna Teks Utama)
      transStyle = paliStyle.copyWith(color: mainTextColor);
    } else if (isH2) {
      topPadding = 8.0;
      bottomPadding = 12.0;

      paliStyle = TextStyle(
        fontFamily: _currentFontFamily,
        fontSize: _fontSize * 1.05,
        fontWeight: FontWeight.bold,
        color: paliColorToUse.withValues(alpha: 0.9), // <--- GANTI DISINI
        height: 1.3,
      );

      transStyle = paliStyle.copyWith(
        color: mainTextColor.withValues(alpha: 0.87),
      );
    } else if (isH3) {
      topPadding = 16.0;
      bottomPadding = 8.0;

      paliStyle = TextStyle(
        fontFamily: _currentFontFamily,
        fontSize: _fontSize * 1,
        fontWeight: FontWeight.w700,
        color: paliColorToUse.withValues(alpha: 0.9), // <--- GANTI DISINI
        height: 1.4,
      );

      transStyle = paliStyle.copyWith(
        color: mainTextColor.withValues(alpha: 0.87),
      );
    } else {
      // --- BODY TEXT (Ini udah bener sebelumnya) ---
      topPadding = 0.0;
      bottomPadding = 8.0;
      paliStyle = TextStyle(
        fontFamily: _currentFontFamily,
        fontSize: isPaliOnly ? _fontSize : _fontSize * 0.8,
        fontWeight: FontWeight.w500,
        color: paliColorToUse,
        height: _lineHeight,
      );
      transStyle = TextStyle(
        fontFamily: _currentFontFamily,
        fontSize: _fontSize,
        fontWeight: FontWeight.normal,
        color: mainTextColor,
        height: _lineHeight,
      );
    }

    return SuttaHeaderConfig(
      isH1: isH1,
      isH2: isH2,
      isH3: isH3,
      verseNum: verseNum,
      paliStyle: paliStyle,
      transStyle: transStyle,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
    );
  }

  //  WIDGET UTAMA RENDER SEGMENTED (Sekarang Support HTML)
  Widget _buildSegmentedItem(
    BuildContext context,
    int index,
    String key,
    Map<String, String> paliSegs,
    Map<String, String> translationSegs,
    Map<String, String> commentarySegs,
  ) {
    // ✅ VALIDASI AWAL
    if (key.isEmpty) return const SizedBox.shrink();

    final config = _getHeaderConfig(key, isPaliOnly: _isRootOnly);

    var pali = paliSegs[key] ?? "";
    if (pali.trim().isEmpty) pali = "...";

    var trans = translationSegs[key] ?? "";
    final isTransEmpty = trans.trim().isEmpty;
    final comm = commentarySegs[key] ?? "";

    ViewMode effectiveViewMode = _viewMode;
    if (_isRootOnly) {
      effectiveViewMode = ViewMode.lineByLine;
    }

    switch (effectiveViewMode) {
      case ViewMode.translationOnly:
        return _buildLayoutTransOnly(config, index, trans, isTransEmpty, comm);
      case ViewMode.lineByLine:
        return _buildLayoutLineByLine(
          config,
          index,
          pali,
          trans,
          isTransEmpty,
          comm,
        );
      case ViewMode.sideBySide:
        return _buildLayoutSideBySide(
          config,
          index,
          pali,
          trans,
          isTransEmpty,
          comm,
        );
    }
  }

  //  HELPER RENDER HTML DENGAN HIGHLIGHT

  Widget _buildLayoutTransOnly(
    SuttaHeaderConfig config,
    int index,
    String trans,
    bool isTransEmpty,
    String comm,
  ) {
    final baseStyle = isTransEmpty
        ? config.transStyle.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          )
        : config.transStyle;

    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: config.topPadding),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            //  NOMOR PARAGRAF (INLINE SPAN)
            _buildVerseNumberSpan(config),

            //  TEKS TERJEMAHAN
            if (isTransEmpty)
              TextSpan(text: "...", style: baseStyle)
            else
              ...SuttaTextHelper.parseHtmlToSpansWithHighlight(
                trans,
                baseStyle,
                index,
                false,
                _cachedSearchRegex,
                _allMatches,
                _currentMatchIndex,
              ),

            //  PENTING: Validasi comm sebelum panggil _buildCommentSpan
            if (comm.isNotEmpty)
              _buildCommentSpan(
                context,
                comm,
                config.transStyle.fontSize ?? _fontSize,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutLineByLine(
    SuttaHeaderConfig config,
    int index,
    String pali,
    String trans,
    bool isTransEmpty,
    String comm,
  ) {
    final isPe = pali == "..." && !config.isH1 && !config.isH2 && !config.isH3;
    final finalPaliStyle = config.paliStyle.copyWith(
      fontStyle: isPe ? FontStyle.italic : FontStyle.normal,
      color: isPe
          ? _currentStyle.text.withValues(alpha: 0.3)
          : config.paliStyle.color,
    );

    final baseTransStyle = isTransEmpty
        ? config.transStyle.copyWith(
            color: _currentStyle.text.withValues(alpha: 0.3),
            fontStyle: FontStyle.italic,
          )
        : config.transStyle;

    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: config.topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  PALI TEXT (DENGAN NOMOR INLINE)
          // Kita gabung nomor + pali di sini pake parseHtmlToSpansWithHighlight
          // TAPI kita inject nomornya di awal children
          Builder(
            builder: (context) {
              // Parse Pali jadi spans dulu
              final paliSpans = SuttaTextHelper.parseHtmlToSpansWithHighlight(
                pali,
                finalPaliStyle,
                index,
                true,
                _cachedSearchRegex,
                _allMatches,
                _currentMatchIndex,
              );

              return Text.rich(
                TextSpan(
                  style: finalPaliStyle,
                  children: [
                    //  NOMOR DI DEPAN
                    _buildVerseNumberSpan(config),
                    //  TEKS PALI
                    ...paliSpans,
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 4),

          //  TERJEMAHAN (TANPA NOMOR)
          if (!_isRootOnly)
            Text.rich(
              TextSpan(
                style: baseTransStyle,
                children: [
                  if (isTransEmpty)
                    TextSpan(text: "...", style: baseTransStyle)
                  else
                    ...SuttaTextHelper.parseHtmlToSpansWithHighlight(
                      trans,
                      baseTransStyle,
                      index,
                      false,
                      _cachedSearchRegex,
                      _allMatches,
                      _currentMatchIndex,
                    ),

                  if (comm.isNotEmpty)
                    _buildCommentSpan(
                      context,
                      comm,
                      config.transStyle.fontSize ?? _fontSize,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLayoutSideBySide(
    SuttaHeaderConfig config,
    int index,
    String pali,
    String trans,
    bool isTransEmpty,
    String comm,
  ) {
    final isPe = pali == "..." && !config.isH1 && !config.isH2 && !config.isH3;
    final finalPaliStyle = config.paliStyle.copyWith(
      fontStyle: isPe ? FontStyle.italic : FontStyle.normal,
      color: isPe
          ? _currentStyle.text.withValues(alpha: 0.3)
          : config.paliStyle.color,
    );

    if (_isRootOnly || config.isH1 || config.isH2 || config.isH3) {
      return _buildLayoutLineByLine(
        config,
        index,
        pali,
        trans,
        isTransEmpty,
        comm,
      );
    }

    final int paliFlex = 1;
    final int transFlex = 1;

    final baseTransStyle = isTransEmpty
        ? config.transStyle.copyWith(
            color: _currentStyle.text.withValues(alpha: 0.3),
            fontStyle: FontStyle.italic,
          )
        : config.transStyle;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: config.topPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //  KOLOM PALI (DENGAN NOMOR INLINE)
              Expanded(
                flex: paliFlex,
                child: Builder(
                  builder: (context) {
                    //  EXTRACT TEXT DARI HTML DULU
                    String cleanPali = pali
                        .replaceAll(SuttaTextHelper.htmlTagRegex, '')
                        .trim();

                    // Parse jadi TextSpan dengan highlight
                    final paliSpans =
                        SuttaTextHelper.parseHtmlToSpansWithHighlight(
                          cleanPali,
                          finalPaliStyle,
                          index,
                          true,
                          _cachedSearchRegex,
                          _allMatches,
                          _currentMatchIndex,
                        );

                    return Text.rich(
                      TextSpan(
                        style: finalPaliStyle,
                        children: [
                          //  NOMOR INLINE (PAKE HELPER BARU)
                          _buildVerseNumberSpan(config),

                          //  TEKS PALI
                          ...paliSpans,
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              //  KOLOM TERJEMAHAN (TANPA NOMOR)
              Expanded(
                flex: transFlex,
                child: Text.rich(
                  TextSpan(
                    style: baseTransStyle,
                    children: [
                      if (isTransEmpty)
                        TextSpan(text: "...", style: baseTransStyle)
                      else
                        ...SuttaTextHelper.parseHtmlToSpansWithHighlight(
                          trans,
                          baseTransStyle,
                          index,
                          true,
                          _cachedSearchRegex,
                          _allMatches,
                          _currentMatchIndex,
                        ),

                      if (comm.isNotEmpty)
                        _buildCommentSpan(
                          context,
                          comm,
                          config.transStyle.fontSize ?? _fontSize,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  InlineSpan _buildVerseNumberSpan(SuttaHeaderConfig config) {
    //  KALAU USER MATIIN, RETURN KOSONG
    if (!_showVerseNumbers) {
      return const TextSpan(text: ''); // Kosong (invisible)
    }

    final colors = _currentStyle;

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: SelectionContainer.disabled(
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
          decoration: BoxDecoration(
            color: colors.text.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: colors.text.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Text(
            config.verseNum,
            style: TextStyle(
              fontSize: _fontSize * 0.50,
              color: colors.text.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  //  VERSI BARU: INLINE DENGAN TEKS (UNSELECTABLE)

  Map<String, dynamic> _getMetadata() {
    //  1. LOGIC KHUSUS TAFSIR (CSCD VRI)
    if (_isTafsirMode) {
      return {
        "isSegmented": false,
        "author": "CSCD VRI", // <--- INI HASILNYA NANTI
        "langName": "Pāli",
        "pubDate": null, // Gak perlu tahun
      };
    }
    //  2. LOGIC SUTTA BIASA (EXISTING - Gak Diubah)
    final isSegmented = widget.textData?["segmented"] == true;
    final translations =
        widget.textData?["suttaplex"]?["translations"] as List?;

    String author = "";
    String langName = "";

    if (isSegmented) {
      if (translations != null) {
        try {
          final currentTrans = translations.firstWhere(
            (t) =>
                t["author_uid"] == widget.textData?["author_uid"] &&
                t["lang"] == widget.lang,
            orElse: () => null,
          );
          author = currentTrans?["author"]?.toString() ?? "";
          langName = currentTrans?["lang_name"]?.toString() ?? "";
        } catch (e) {
          author = "";
        }
      }
    } else {
      author = widget.textData?["translation"]?["author"]?.toString() ?? "";
      if (translations != null) {
        final currentTrans = translations.firstWhere(
          (t) => t["lang"] == widget.lang,
          orElse: () => null,
        );
        langName = currentTrans?["lang_name"]?.toString() ?? "";
      }
    }

    if (langName.isEmpty) {
      langName = isSegmented
          ? (widget.textData?["bilara_translated_text"]?["lang_name"] ??
                widget.textData?["translation_text"]?["lang_name"] ??
                widget.textData?["root_text"]?["lang_name"] ??
                widget.lang.toUpperCase())
          : (widget.textData?["translation"]?["lang_name"] ??
                widget.textData?["root_text"]?["lang_name"] ??
                widget.lang.toUpperCase());
    }

    final pubDate = translations?.firstWhere(
      (t) =>
          t["author_uid"] == widget.textData?["author_uid"] &&
          t["lang"] == widget.lang,
      orElse: () => null,
    )?["publication_date"];

    return {
      "isSegmented": isSegmented,
      "author": author,
      "langName": langName,
      "pubDate": pubDate,
    };
  }

  Future<void> _saveToHistory() async {
    // Ambil metadata bawaan (buat Sutta biasa)
    final metadata = _getMetadata();

    final rawAcronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        "";
    final normalizedAcronym = normalizeNikayaAcronym(rawAcronym);

    // Variabel penampung hasil akhir
    String finalTitle;
    String finalAuthor;
    String finalLang;

    //  LOGIC PENENTUAN JUDUL & AUTHOR
    if (_isTafsirMode) {
      // ----------------------------------------------------
      // A. KHUSUS TAFSIR (CSCD)
      // ----------------------------------------------------
      // 1. JUDUL: Pake Nama Sutta Asli (Pali)
      finalTitle =
          widget.textData?["suttaplex"]?["original_title"] ??
          widget.textData?["root_text"]?["title"] ??
          widget.uid;

      // 2. AUTHOR: Pake Format "Tipe (CSCD VRI)"
      var rootTitle =
          widget.textData?["root_text"]?["title"]?.toString().toLowerCase() ??
          "";
      String typeLabel = "Mūla";
      if (rootTitle.contains("aṭṭhakathā")) {
        typeLabel = "Aṭṭhakathā";
      } else if (rootTitle.contains("ṭīkā")) {
        typeLabel = "Ṭīkā";
      }
      finalAuthor = "CSCD VRI";
      //  if (!rootTitle.contains("mūla")) {
      //  finalTitle = "$typeLabel dari $finalTitle";
      //  }
      //  rootTitle = "$typeLabel: $rootTitle";

      // 3. BAHASA: Pali
      finalLang = typeLabel;
    } else {
      // ----------------------------------------------------
      // B. SUTTA BIASA (LOGIK LAMA - Gak diotak-atik)
      // ----------------------------------------------------
      // 1. JUDUL: Prioritas Terjemahan (Indo/Inggris) -> Baru Pali
      finalTitle =
          widget.textData?["suttaplex"]?["translated_title"] ??
          widget.textData?["suttaplex"]?["original_title"] ??
          widget.textData?["root_text"]?["title"] ??
          widget.uid;

      // 2. AUTHOR & LANG: Ambil dari metadata biasa
      finalAuthor = metadata["author"];
      finalLang = metadata["langName"];
    }

    final historyItem = {
      'uid': widget.uid,
      'title': finalTitle, // <--- Sesuai logic di atas (Judul Sutta)
      'original_title': widget.textData?["suttaplex"]?["original_title"] ?? "",
      'acronym': normalizedAcronym,
      'author':
          finalAuthor, // <--- Sesuai logic di atas (Nama Penerjemah / Tipe Tafsir)
      'lang_name': finalLang,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await HistoryService.addToHistory(historyItem);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    //  FIX: Ambil warna dari tema baca, bukan System HP
    // final colors = _currentStyle;
    //final mainColor = colors.text;
    //final subColor = colors['note']!; // atau colors['icon']
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurface; // atau colors['icon']

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: iconColor),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  //  WIDGET NO INTERNET (ELEGAN)
  Widget _buildNoInternetView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              "Koneksi Terputus",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Gagal memuat teks sutta.\nSilakan periksa internet Anda.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                //  Validate data dulu
                final authorUid = widget.textData?["author_uid"]?.toString();
                if (authorUid == null || authorUid.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Data tidak lengkap untuk mencoba lagi"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _isLoading = true;
                  _connectionError = false;
                });

                _replaceToSutta(
                  widget.uid,
                  widget.lang,
                  authorUid: authorUid,
                  segmented: widget.textData?["segmented"] == true,
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Coba Lagi"),
            ),
          ],
        ),
      ),
    );
  }

  void _updateVisibleParagraph() {
    if (!mounted) return;

    if (_itemPositionsListener.itemPositions.value.isEmpty) {
      return; // ← INI PENTING
    }

    if (_isUserDragging) return;
    //  1. THROTTLING LEBIH SANTAI (25ms -> 150ms)
    // Biar CPU gak engap dipaksa kerja rodi tiap milidetik
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollTime < 150) return;
    _lastScrollTime = now;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return; // ← DOUBLE CHECK

    // Sort posisi
    final sortedRawPositions = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final firstVisible = sortedRawPositions.first;
    final lastVisible = sortedRawPositions.last;

    // 2. Hitung Total Item
    int totalItems = 1;
    if (_htmlSegments.isNotEmpty) {
      totalItems = _htmlSegments.length;
    } else if (widget.textData != null &&
        widget.textData!["keys_order"] is List) {
      totalItems = (widget.textData!["keys_order"] as List).length;
    }

    // ==========================================================
    //  LOGIC BARU: ESTIMASI STABIL (BEST PRACTICE)
    // ==========================================================

    // Kita asumsikan 1 layar rata-rata muat 12 item/paragraf.
    // Angka ini bikin jempol "pas": Gak kegedean di teks panjang, gak kekecilan di teks pendek.
    const double itemsPerScreen = 12.0;

    // Rumus: Viewport = Kapasitas Layar / Total Item
    double targetRatio = (itemsPerScreen / totalItems);

    // Clamp: Minimal 10% (biar gak ilang), Maksimal 100% (Full layar)
    targetRatio = targetRatio.clamp(0.1, 1.0);

    // Update Ratio LANGSUNG (Gak perlu smoothing karena nilainya KONSTAN)
    // Ini bikin scrollbar diem anteng gak memanjang-mendek sendiri.
    if ((_viewportRatioVN.value - targetRatio).abs() > 0.001) {
      _viewportRatioVN.value = targetRatio;
    }

    // ==========================================================
    // LOGIC SNAP TO BOTTOM (ANTI GANTUNG)
    // ==========================================================
    double progress = 0.0;
    bool isLastItemVisible = lastVisible.index >= totalItems - 1;
    bool isBottomReached =
        isLastItemVisible && lastVisible.itemTrailingEdge <= 1.05;

    if (isBottomReached) {
      progress = 1.0;
    } else {
      progress = totalItems > 1
          ? (firstVisible.index / (totalItems - 1)).clamp(0.0, 1.0)
          : 0.0;
    }

    // ==========================================================
    // LOGIC TAFSIR (Tetap Sama)
    // ==========================================================
    String? foundNum;
    bool shouldShow = false;
    //  UBAH BARIS INI: Jangan cuma cek _isTafsirMode
    // Tapi cek juga kalau _tafsirSectionMap ada isinya (berarti ada Ref SC/Verse tadi)

    // ==========================================================
    //  LOGIC PENCARIAN TAFSIR (VERSI TURBO O(1))
    // ==========================================================

    if (_isTafsirMode || _tafsirSectionMap.isNotEmpty) {
      final double statusBarHeight = MediaQuery.of(context).padding.top;
      final double triggerPixel = statusBarHeight + 95.0;
      final double detectionLine =
          triggerPixel / MediaQuery.of(context).size.height;

      final visibleItems = positions.where((pos) {
        return pos.itemTrailingEdge > detectionLine;
      }).toList();

      if (visibleItems.isNotEmpty) {
        visibleItems.sort((a, b) => a.index.compareTo(b.index));
        final topItem = visibleItems.first;
        final int currentReadingIndex = topItem.index;

        //  INI DIA PERUBAHANNYA: GAK PAKE LOOPING MAP LAGI!
        // Kita cari index section terbesar yang <= index bacaan sekarang
        // Karena listnya udah urut, ini cepet banget.

        if (_sortedTafsirIndices.isNotEmpty) {
          // Cari index section terakhir yang sudah kita lewati
          final int lastSectionIdx = _sortedTafsirIndices.lastWhere(
            (idx) => idx <= currentReadingIndex,
            orElse: () => -1,
          );

          if (lastSectionIdx != -1 &&
              _indexToTafsirLabel.containsKey(lastSectionIdx)) {
            foundNum = _indexToTafsirLabel[lastSectionIdx];
          }
        }

        shouldShow = foundNum != null && foundNum.isNotEmpty;
      }
    } else {
      foundNum = _visibleParaNumVN.value;
      shouldShow = _showFloatingBtnVN.value;
    }

    // ==========================================================
    // UPDATE UI (PROGRESS & BUTTON)
    // ==========================================================

    // Update Progress (Posisi scroll tetep responsif)
    // Kita kasih smoothing dikit disini biar pergerakan jempolnya enak
    double currentProg = _scrollProgressVN.value;
    if ((currentProg - progress).abs() > 0.001) {
      // Smoothing factor 0.5 (Cepat tapi smooth)
      _scrollProgressVN.value = currentProg + (progress - currentProg) * 0.5;
    }

    // Update Tafsir UI (Logika ini juga bakal nge-update tombolnya)
    if (_isTafsirMode || _tafsirSectionMap.isNotEmpty) {
      //  Update juga kondisi if di sini
      if (_visibleParaNumVN.value != foundNum) {
        _visibleParaNumVN.value = foundNum;
      }
      if (_showFloatingBtnVN.value != shouldShow) {
        _showFloatingBtnVN.value = shouldShow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.textData == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: const Center(child: Text("Data tidak tersedia")),
        ),
      );
    }

    // 1. Ambil palet warna
    final colors = _currentStyle;
    final bgColor = colors.bg; // Ini warna dasar (Putih/Sepia/Hitam)
    final textColor = colors.text;
    final accentColor = colors.pali;
    final cardColor = Theme.of(context).colorScheme.surface;
    final iconColor = Theme.of(context).colorScheme.onSurface;

    final metadata = _getMetadata();

    final String suttaTitle =
        widget.textData?["root_text"]?["title"] ??
        widget.textData?["translation"]?["title"] ??
        widget.uid;

    final String rawAcronym =
        widget.textData?["suttaplex"]?["acronym"] ??
        widget.textData?["root_text"]?["acronym"] ??
        "";
    final String acronym = normalizeNikayaAcronym(rawAcronym);

    final String rawBlurb = widget.textData?["suttaplex"]?["blurb"] ?? "";
    bool shouldShowBlurb = rawBlurb.isNotEmpty;

    final bool isError = widget.textData == null || widget.textData!.isEmpty;
    final bool isSegmented =
        !isError && (widget.textData!["segmented"] == true);

    // --- LOGIC SETUP DATA (OPTIMIZED) ---
    // Langsung ambil dari cache yang udah disiapin _processNewTextData
    final paliSegs = _cachedPaliSegs;
    final translationSegs = _cachedTransSegs;
    final keysOrder = _cachedKeysOrder;
    // commentarySegs nanti langsung pake _cachedCommentSegs di bawah

    Widget body;

    // Hitung Padding Atas
    final double topContentPadding = MediaQuery.of(context).padding.top + 80;

    //  LOGIC BODY BUILDER
    if (_connectionError) {
      body = _buildNoInternetView();
    } else if (isError) {
      body = Center(
        child: Text("Teks tidak tersedia", style: TextStyle(color: textColor)),
      );
    } else if (isSegmented) {
      body = RepaintBoundary(
        child: SelectionArea(
          key: ValueKey(widget.uid),
          onSelectionChanged: (content) {
            // Tambahan safety: cek null content
            _currentSelectedText = content?.plainText ?? '';
          },
          contextMenuBuilder: _buildMyContextMenu,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => notification.depth != 0,
            // child:
            // Scrollbar(
            //  thumbVisibility: false,
            // thickness: 4,
            //  radius: const Radius.circular(8),
            child: ScrollablePositionedList.builder(
              physics: const BouncingScrollPhysics(),
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding,
                topContentPadding,
                _horizontalPadding,
                (_isSearchActive ? 250 : (_isBottomMenuVisible ? 100 : 40)) +
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              itemCount: keysOrder.length,
              itemBuilder: (context, index) {
                return _buildSegmentedItem(
                  context,
                  index,
                  keysOrder[index],
                  paliSegs,
                  translationSegs,
                  _cachedCommentSegs,
                );
              },
            ),
          ),
          //  ),
        ),
      );
    } else if ((widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) ||
        (widget.textData!["root_text"] is Map &&
            widget.textData!["root_text"].containsKey("text"))) {
      // NON-SEGMENTED HTML
      if (_htmlSegments.isEmpty) {
        String rawHtml = "";
        if (widget.textData!["translation_text"] is Map &&
            widget.textData!["translation_text"].containsKey("text")) {
          final transMap = Map<String, dynamic>.from(
            widget.textData!["translation_text"],
          );

          rawHtml = SuttaTextHelper.unescape.convert(
            NonSegmentedSutta.fromJson(transMap).text,
          );
          //   rawHtml = HtmlUnescape().convert(
          //     NonSegmentedSutta.fromJson(transMap).text,
          //   );
        } else if (widget.textData!["root_text"] is Map) {
          final rootMap = Map<String, dynamic>.from(
            widget.textData!["root_text"],
          );

          rawHtml = SuttaTextHelper.unescape.convert(
            NonSegmentedSutta.fromJson(rootMap).text,
          );

          // rawHtml = HtmlUnescape().convert(
          //    NonSegmentedSutta.fromJson(rootMap).text,
          //  );
        }
        if (rawHtml.isNotEmpty) _parseHtmlAndGenerateTOC(rawHtml);
      }
      body = RepaintBoundary(
        child: SelectionArea(
          key: ValueKey(widget.uid),
          onSelectionChanged: (content) {
            // Tambahan safety: cek null content
            _currentSelectedText = content?.plainText ?? '';
          },
          contextMenuBuilder: _buildMyContextMenu,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => notification.depth != 0,
            //  child: Scrollbar(
            //   thumbVisibility: false,
            //   thickness: 4,
            //   radius: const Radius.circular(8),
            child: ScrollablePositionedList.builder(
              physics: const BouncingScrollPhysics(),
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding,
                topContentPadding + 32,
                _horizontalPadding,
                _isBottomMenuVisible ? 100 : 40,
              ),
              itemCount: _htmlSegments.length,
              itemBuilder: (context, index) {
                String content = SuttaTextHelper.injectSearchHighlights(
                  _htmlSegments[index],
                  index,
                  false,
                  _cachedSearchRegex,
                  _allMatches,
                  _currentMatchIndex,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Html(
                    data: content,
                    extensions: [
                      // =============================================
                      // 1. EXTENSION HIGHLIGHT SEARCH
                      // =============================================
                      TagExtension(
                        tagsToExtend: {"x-highlight"},
                        builder: (extensionContext) {
                          //  VALIDASI: Pastikan element tidak null
                          final element = extensionContext.element;
                          if (element == null) {
                            return const SizedBox.shrink();
                          }

                          final attrs = extensionContext.attributes;
                          final isGlobalActive = attrs['data-active'] == 'true';

                          //  VALIDASI: Pastikan text tidak null
                          final text = element.text.trim();
                          if (text.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final key = GlobalKey();
                          if (isGlobalActive) {
                            if (_allMatches.isNotEmpty &&
                                _currentMatchIndex < _allMatches.length) {
                              _searchKeys[_currentMatchIndex] = key;
                            }
                          }

                          //  VALIDASI: fontSize bisa null
                          final style = extensionContext.styledElement?.style;
                          double currentFontSize =
                              style?.fontSize?.value ?? _fontSize;

                          return Container(
                            key: isGlobalActive ? key : null,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isGlobalActive
                                  ? Colors.orange
                                  : Colors.yellow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Transform.translate(
                              offset: const Offset(0, 0),
                              child: Text(
                                element.text,
                                style: TextStyle(
                                  color: isGlobalActive
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: currentFontSize,
                                  height: _lineHeight,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // =============================================
                      // 2. EXTENSION HR (GARIS PEMISAH TENGAH)
                      // =============================================
                      TagExtension(
                        tagsToExtend: {"hr"},
                        builder: (ctx) {
                          return Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.symmetric(vertical: 24),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.6,
                              child: Divider(
                                height: 1,
                                thickness: 1.5,
                                color: colors.text.withValues(alpha: 0.3),
                              ),
                            ),
                          );
                        },
                      ),
                      // =============================================
                      // 4. EXTENSION SPAN (PARA-NUM, PB-MARKER, EVAM)
                      // =============================================
                      //  UPDATE EXTENSION SPAN & A (SEPKEET FIX LINE-HEIGHT)
                      TagExtension(
                        tagsToExtend: {"span", "a"},
                        builder: (extensionContext) {
                          final attrs = extensionContext.attributes;
                          final className = attrs['class'] ?? '';

                          // A. REF (SC 1, Verse, dll) - STYLE ALA PB-MARKER
                          if (className.contains('ref')) {
                            //  KALAU USER MATIIN, JANGAN RENDER
                            if (!_showVerseNumbers) {
                              return const SizedBox.shrink(); // Invisible
                            }

                            final text = extensionContext.element?.text ?? '';

                            return SelectionContainer.disabled(
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  // Warna Abu Transparan (Mirip PB Marker)
                                  color: colors.text.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colors.text.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: _fontSize * 0.60, // Kecil
                                    color: colors.text.withValues(
                                      alpha: 0.5,
                                    ), // Abu tua
                                    fontWeight: FontWeight.w600,
                                    height:
                                        1.0, // Paksa tinggi 1 biar nggak ngerusak baris
                                  ),
                                ),
                              ),
                            );
                          }

                          // B. Para Number (§) - Untuk tafsir
                          if (className == 'para-num') {
                            //  KALAU USER MATIIN, JANGAN RENDER
                            if (!_showVerseNumbers) {
                              return const SizedBox.shrink(); // Invisible
                            }

                            final num = attrs['data-num'] ?? '';
                            return GestureDetector(
                              onTap: () {
                                if (_isTafsirMode) {
                                  _showTafsirSwitcherDialog(num);
                                }
                              },
                              child: SelectionContainer.disabled(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.text.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: colors.text.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '§$num',
                                        style: TextStyle(
                                          fontSize: _fontSize * 0.7,
                                          fontWeight: FontWeight.bold,
                                          color: colors.text,
                                          height: 1.0,
                                        ),
                                      ),
                                      if (_isTafsirMode) ...[
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.link,
                                          size: _fontSize * 0.6,
                                          color: colors.text,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // C. PB Marker (Page Break - PTS/CSCD)
                          if (className == 'pb-marker') {
                            //  KALAU USER MATIIN, JANGAN RENDER
                            if (!_showVerseNumbers) {
                              return const SizedBox.shrink(); // Invisible
                            }

                            final rawEdition = attrs['data-edition'] ?? '';
                            final page = attrs['data-page'] ?? '';
                            String editionLabel = rawEdition;
                            switch (rawEdition) {
                              case 'M':
                                editionLabel = 'Mymr';
                                break;
                              case 'P':
                                editionLabel = 'PTS';
                                break;
                              case 'T':
                                editionLabel = 'Thai';
                                break;
                              case 'V':
                                editionLabel = 'VRI';
                                break;
                            }
                            return SelectionContainer.disabled(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _currentStyle.text.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "$editionLabel $page",
                                    style: TextStyle(
                                      fontSize: _fontSize * 0.55,
                                      color: _currentStyle.text.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          //  F. SPEAKER (NAMA PEMBICARA) - VERSI CENTER
                          if (className == 'speaker') {
                            return Container(
                              width: double.infinity, // 1. Paksa lebar penuh
                              alignment:
                                  Alignment.center, // 2. Posisikan di tengah
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(
                                (extensionContext.element?.text ?? "")
                                    .toUpperCase(),
                                textAlign:
                                    TextAlign.center, // 3. Rata tengah teksnya
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: _fontSize * 0.85,
                                  letterSpacing:
                                      1.0, // Tambahin spasi dikit biar elegan
                                ),
                              ),
                            );
                          }

                          // D. EVAM (Opening formula - uppercase)
                          if (className == 'evam') {
                            final text = extensionContext.element?.text ?? "";
                            return Text(
                              text.toUpperCase(),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: _fontSize * 0.85,
                                height: 1.0,
                              ),
                            );
                          }

                          // E. Default span handler (UNTUK .ADD / PIKIRANNYA)
                          // Pakai generateTextStyle + copyWith(height: 1.0) supaya baris rata
                          final styledElement = extensionContext
                              .styledElement; // 1. Kunci di variabel lokal
                          final textContent =
                              extensionContext.element?.text ?? '';

                          // 2. Cek Manual (Biar IDE gak protes soal tanda tanya)
                          if (styledElement == null) {
                            return Text(
                              textContent,
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.0,
                                color: textColor,
                              ),
                            );
                          }

                          // 3. Kalau aman baru panggil generateTextStyle
                          return Text(
                            textContent,
                            style: styledElement.style
                                .generateTextStyle()
                                .copyWith(height: 1.0),
                          );
                        },
                      ),
                    ],

                    // =============================================
                    // STYLE MAP (UNTUK ELEMEN HTML STANDAR)
                    // =============================================
                    style: {
                      "body": Style(
                        fontFamily: _currentFontFamily,
                        fontSize: FontSize(_fontSize),
                        lineHeight: LineHeight(_lineHeight),
                        margin: Margins.zero, //  HAPUS MARGIN KIRI-KANAN
                        padding:
                            HtmlPaddings.zero, //  TAMBAHIN INI JUGA BIAR BERSIH
                        color: textColor,
                      ),
                      ".add": Style(
                        fontStyle: FontStyle.italic,
                        color: textColor.withValues(alpha: 0.8),
                        // PENTING: LineHeight-nya samain sama body
                        lineHeight: LineHeight(_lineHeight),
                      ),
                      "p": Style(
                        margin: Margins.only(
                          bottom: 10,
                        ), //  JARAK ANTAR PARAGRAF (TURUNIN DARI DEFAULT 16)
                        display: Display.block,
                      ),
                      "h1": Style(
                        fontSize: FontSize(_fontSize * 1.8),
                        fontWeight: FontWeight.w900,
                        margin: Margins.only(top: 24, bottom: 12),
                        color: textColor,
                        textAlign: TextAlign.center,
                      ),
                      "h2": Style(
                        fontSize: FontSize(_fontSize * 1.5),
                        fontWeight: FontWeight.bold,
                        margin: Margins.only(top: 20, bottom: 10),
                        color: textColor,
                        textAlign: TextAlign.center,
                      ),
                      "h3": Style(
                        fontSize: FontSize(_fontSize * 1.25),
                        fontWeight: FontWeight.w700,
                        margin: Margins.only(top: 16, bottom: 8),
                        color: textColor,
                        textAlign: TextAlign.center,
                      ),
                      //  STYLE SUBHEADING (RATA TENGAH)
                      ".subheading": Style(
                        // 1. Rata Tengah (Permintaan Utama)
                        textAlign: TextAlign.center,

                        // 2. Styling Font (Agak tebal, ukuran sedikit lebih besar dari body)
                        fontFamily: _currentFontFamily,
                        fontSize: FontSize(_fontSize * 1.1),
                        fontWeight: FontWeight.w600,

                        // 3. Warna (Sedikit lebih pudar dari judul utama)
                        color: textColor.withValues(alpha: 0.75),

                        // 4. Jarak (Biar gak nempel sama teks di bawahnya)
                        margin: Margins.only(bottom: 20, top: 4),
                        display: Display.block,
                      ),
                      //  GANTI STYLE BLOCKQUOTE LAMA DENGAN INI:
                      // Kita target class 'gatha-segment' yang tadi kita suntik
                      ".gatha-segment": Style(
                        // 1. MARGIN NOL (KUNCI BIAR NYAMBUNG)
                        margin: Margins.zero,

                        // 2. Padding internal per baris (biar teks gak dempet border)
                        padding: HtmlPaddings.only(
                          left: 8,
                          right: 8,
                          top: 6,
                          bottom: 6,
                        ),

                        // 3. Dekorasi Visual (Sama persis kayak blockquote kemarin)
                        /* backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.1),
                            */
                        border: Border(
                          left: BorderSide(
                            color: textColor.withValues(
                              alpha: 0.6,
                            ), // Ngikut warna tema
                            width: 1,
                          ),
                        ),

                        // 4. Font & Display
                        fontFamily: _currentFontFamily,
                        fontSize: FontSize(_fontSize),
                        lineHeight: LineHeight(_lineHeight),
                        color: textColor.withValues(alpha: 0.9),
                        display: Display.block,
                      ),
                      /* ".ref": Style(
                        fontSize: FontSize.smaller, // Ukuran kecil
                        color: Colors.grey, // Warna abu biar gak ganggu baca
                        textDecoration:
                            TextDecoration.none, // Hapus garis bawah link
                        verticalAlign:
                            VerticalAlign.sup, // Naik dikit (Superscript)
                        margin: Margins.only(
                          right: 4,
                        ), // Kasih jarak dikit ke teks utama
                        display: Display.inline, //  WAJIB: Biar dirender
                      ),*/
                      "header": Style(
                        display: Display.block,
                        margin: Margins.only(bottom: 20),
                      ),
                      "header ul": Style(
                        listStyleType: ListStyleType.none,
                        padding: HtmlPaddings.zero,
                        margin: Margins.zero,
                      ),
                      "header li": Style(
                        textAlign: TextAlign.center,
                        color: colors.text.withValues(alpha: 0.3),
                        fontSize: FontSize.medium,
                        fontWeight: FontWeight.bold,
                        display: Display.block,
                        margin: Margins.only(bottom: 4),
                      ),
                      "footer": Style(display: Display.none),
                      "div.verse-block": Style(
                        fontFamily: _currentFontFamily,
                        fontSize: FontSize(_fontSize),
                        lineHeight: LineHeight(_lineHeight),
                        // fontStyle: FontStyle.italic,
                        color: textColor.withValues(alpha: 0.9),
                        margin: Margins.symmetric(vertical: 12),
                        padding: HtmlPaddings.only(
                          left: 8,
                          top: 12,
                          right: 16,
                          bottom: 12,
                        ),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        //   backgroundColor: Theme.of(context)
                        //       .colorScheme
                        //       .surfaceContainerHighest
                        //       .withValues(alpha: 0.1),
                        display: Display.block, //! Biar <br> ke-render
                      ),
                    },
                  ),
                );
              },
            ),
          ),
          // ),
        ),
      );
    } else if (widget.textData!["root_text"] is Map &&
        !(widget.textData!["root_text"] as Map).containsKey("text")) {
      // PALI ONLY
      final paliOnlyMap = (widget.textData!["root_text"] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      final paliKeys = widget.textData!["keys_order"] is List
          ? List<String>.from(widget.textData!["keys_order"])
          : paliOnlyMap.keys.toList();

      body = RepaintBoundary(
        child: SelectionArea(
          key: ValueKey(widget.uid),
          onSelectionChanged: (content) {
            // Tambahan safety: cek null content
            _currentSelectedText = content?.plainText ?? '';
          },
          contextMenuBuilder: _buildMyContextMenu,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => notification.depth != 0,
            //  child: Scrollbar(
            //    thumbVisibility: false,
            //    thickness: 4,
            //    radius: const Radius.circular(8),
            child: ScrollablePositionedList.builder(
              physics: const BouncingScrollPhysics(),
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding,
                topContentPadding,
                _horizontalPadding,
                _isBottomMenuVisible ? 100 : 40,
              ),
              itemCount: paliKeys.length,
              itemBuilder: (context, index) {
                return _buildSegmentedItem(
                  context,
                  index,
                  paliKeys[index],
                  paliOnlyMap,
                  {},
                  {},
                );
              },
            ),
          ),
          //   ),
        ),
      );
    } else {
      body = Center(
        child: Text(
          "Kesalahan format teks.",
          style: TextStyle(color: textColor),
        ),
      );
    }

    // final titleLower =
    //    widget.textData?["root_text"]?["title"]?.toString().toLowerCase() ?? "";
    //  String typeLabel = "Mūla";

    //  if (titleLower.contains("aṭṭhakathā")) {
    //     typeLabel = "Aṭṭhakathā";
    //   } else if (titleLower.contains("ṭīkā")) {
    //    typeLabel = "Ṭīkā";
    //  }

    final bool showTikaButton = TafsirService().hasTika(widget.uid); // Cek dulu

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          Navigator.of(context).pop();
          return;
        }
        final navigator = Navigator.of(context);
        final allow = await _handleBackReplace();
        if (allow && mounted) {
          navigator.pop(result);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUIHelper.getStyle(context),
        child: Scaffold(
          key: _scaffoldKey,
          appBar: null,
          backgroundColor: bgColor,
          endDrawer: _tocList.isNotEmpty
              ? Drawer(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(24),
                    ),
                  ),
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          MediaQuery.of(context).padding.top + 20,
                          16,
                          20,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Daftar Isi",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          itemCount: _tocList.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = _tocList[index];
                            final level = item['type'] as int;
                            final isH1 = level == 1;
                            final isH2 = level == 2;
                            final double indent = isH1
                                ? 4.0
                                : (isH2 ? 16.0 : 32.0);
                            final FontWeight weight = isH1
                                ? FontWeight.w800
                                : (isH2 ? FontWeight.w600 : FontWeight.normal);
                            final Color textColor = isH1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (!mounted) return;
                                  final targetIndex = item['index'] as int;

                                  int maxIndex;
                                  if (isSegmented && keysOrder.isNotEmpty) {
                                    maxIndex = keysOrder.length - 1;
                                  } else if (_htmlSegments.isNotEmpty) {
                                    maxIndex = _htmlSegments.length - 1;
                                  } else {
                                    return;
                                  }

                                  if (targetIndex < 0 ||
                                      targetIndex > maxIndex) {
                                    return;
                                  }
                                  if (!mounted ||
                                      !_itemScrollController.isAttached) {
                                    return;
                                  }

                                  try {
                                    _itemScrollController.scrollTo(
                                      index: targetIndex,
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment:
                                          0.15, //  TAMBAHIN INI (0.15 = Turun 15%)
                                      // Kalau masih kurang turun, ganti jadi 0.2
                                    );
                                  } catch (e) {
                                    debugPrint(' TOC scroll error: $e');
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    indent + 12,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isH1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 7,
                                            right: 12,
                                          ),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.4),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          item['title'],
                                          style: TextStyle(
                                            fontSize: isH1 ? 16 : 14,
                                            fontWeight: weight,
                                            color: textColor,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              : null,

          body: GestureDetector(
            onHorizontalDragStart: (details) {
              _dragStartX = details.globalPosition.dx;
              _currentDragX = details.globalPosition.dx;
            },

            //  UPDATE BAGIAN INI: Tambah setState biar panahnya gerak real-time
            onHorizontalDragUpdate: (details) {
              setState(() {
                _currentDragX = details.globalPosition.dx;
              });
            },

            //  UPDATE BAGIAN INI: Reset pas dilepas
            onHorizontalDragEnd: (details) {
              // --- TAMBAHAN 2: MATIKAN FOKUS SEBELUM LOGIKA NAVIGASI ---
              // Ini otomatis menghilangkan seleksi teks & menu popup
              FocusManager.instance.primaryFocus?.unfocus();
              // --------------------------------------------------------

              final double distance = _currentDragX - _dragStartX;

              // Logic Navigasi (tetap sama)
              if (distance.abs() > _minDragDistance) {
                if (distance > 0) {
                  if (!_isLoading && !_isFirst) _goToPrevSutta();
                } else {
                  if (!_isLoading && !_isLast) _goToNextSutta();
                }
              }

              // RESET POSISI VISUAL
              setState(() {
                _dragStartX = 0.0;
                _currentDragX = 0.0;
              });
            },

            child: Stack(
              children: [
                // 1. KONTEN UTAMA (body)
                body,
                //  INDIKATOR SWIPE VISUAL
                if (_dragStartX != 0.0 && _currentDragX != 0.0)
                  Builder(
                    builder: (context) {
                      final delta = _currentDragX - _dragStartX;
                      final isSwipeRight = delta > 0; // Mau ke Prev (Mundur)
                      final isSwipeLeft = delta < 0; // Mau ke Next (Maju)

                      // Hitung opacity (0.0 - 1.0) biar smooth
                      final progress = (delta.abs() / _minDragDistance).clamp(
                        0.0,
                        1.0,
                      );

                      // Jangan render kalau gesernya masih dikit banget
                      if (progress < 0.05) return const SizedBox.shrink();

                      // Cek apakah halaman tersedia? Kalau mentok (First/Last), jangan munculin panah
                      // Atau kalau mode Tematik (navigasi dimatikan)
                      if (widget.entryPoint == "tematik") {
                        return const SizedBox.shrink();
                      }
                      if (isSwipeRight && _isFirst) {
                        return const SizedBox.shrink();
                      }
                      if (isSwipeLeft && _isLast) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        top: 0,
                        bottom: 0,
                        // Kalau geser kanan, panah muncul di kiri. Geser kiri, muncul di kanan.
                        left: isSwipeRight ? 24 : null,
                        right: isSwipeLeft ? 24 : null,
                        child: Center(
                          child: Opacity(
                            opacity: progress, // Makin jauh narik, makin jelas
                            child: Transform.scale(
                              scale:
                                  0.5 + (0.5 * progress), // Efek membesar (Pop)
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  // Warna background kontras (Hitam transparan di light mode, Putih di dark)
                                  color: Theme.of(context)
                                      .colorScheme
                                      .inverseSurface
                                      .withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  // Ikon Panah
                                  isSwipeRight
                                      ? Icons.arrow_back_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onInverseSurface,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                //  STATUS BAR COVER (PENUTUP SOLID)
                // Ini biar teks gak kelihatan "jalan" di belakang jam/baterai.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).padding.top,
                  child: Container(
                    color:
                        bgColor, // Pake warna tema halaman (Sepia/Dark/Light)
                  ),
                ),

                // 2. HEADER: Floating Pill Style
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    onTap: _isLoading ? null : _onBackPressed,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.arrow_back,
                                        size: 20,
                                        color: iconColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize
                                        .min, // Biar gak makan tempat vertikal
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start, // Rata kiri
                                    mainAxisAlignment: MainAxisAlignment
                                        .center, // Tengah secara vertikal
                                    children: [
                                      // 1. JUDUL UTAMA
                                      Text(
                                        widget.textData?["suttaplex"]?["original_title"] ??
                                            suttaTitle,
                                        style: TextStyle(
                                          fontSize:
                                              16, // Kecilin dikit biar muat
                                          fontWeight: FontWeight.bold,
                                          color: iconColor,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      // 2. NAMA PENERJEMAH (TAHUN)
                                      // Cek dulu datanya ada gak biar gak error/kosong
                                      if (metadata["author"]
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                          "${metadata['author']}${metadata['pubDate'] != null ? ' (${metadata['pubDate']})' : ''}",
                                          style: TextStyle(
                                            fontSize: 11, // Lebih kecil & tipis
                                            color: iconColor.withValues(
                                              alpha: 0.7,
                                            ), // Agak transparan biar gak balapan sama judul
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: cardColor,
                                        title: Text(
                                          widget.textData?["suttaplex"]?["original_title"] ??
                                              suttaTitle,
                                          style: TextStyle(color: iconColor),
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (shouldShowBlurb &&
                                                  rawBlurb.isNotEmpty) ...[
                                                Html(
                                                  data: rawBlurb,
                                                  style: {
                                                    "body": Style(
                                                      color: iconColor,
                                                    ),
                                                  },
                                                ),
                                                const SizedBox(height: 16),
                                                const Divider(),
                                                const SizedBox(height: 12),
                                              ],
                                              Text(
                                                "Tentang",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: iconColor,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              if (metadata["author"]
                                                  .toString()
                                                  .isNotEmpty) ...[
                                                _buildInfoRow(
                                                  Icons.person_outline,
                                                  "Author",
                                                  metadata["author"],
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                              //  TAMBAHIN INI:
                                              if (metadata["pubDate"] != null &&
                                                  metadata["pubDate"]
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                _buildInfoRow(
                                                  Icons
                                                      .calendar_today_rounded, // Icon kalender
                                                  "Tahun",
                                                  metadata["pubDate"]
                                                      .toString(),
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                              _buildInfoRow(
                                                Icons.language,
                                                "Bahasa",
                                                metadata["langName"],
                                              ),

                                              //  UPDATE LOGIC: Tampilkan kalau ada footer ATAU kalau Segmented (Default CC0)
                                              if (_htmlFooter.isNotEmpty ||
                                                  isSegmented) ...[
                                                const SizedBox(height: 16),
                                                const Divider(),
                                                const SizedBox(height: 12),
                                                Text(
                                                  "Rincian Publikasi",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: iconColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Render HTML footer (link lisensi, prepared by, dll)
                                                Html(
                                                  //  LOGIC UPDATE: Tambahin teks "Sedapat mungkin..." di bawahnya
                                                  data: _htmlFooter.isNotEmpty
                                                      ? _htmlFooter
                                                      : "<p>Teks ini dipublikasikan melalui Creative Commons Zero (CC0 1.0 Universal) Public Domain Dedication.</p>"
                                                            "<p>Sedapat mungkin berdasarkan hukum, Author telah melepaskan semua hak cipta dan hak terkait karya ini.</p>",

                                                  style: {
                                                    "body": Style(
                                                      fontSize: FontSize(13),
                                                      color: iconColor
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                      margin: Margins.zero,
                                                      padding:
                                                          HtmlPaddings.zero,
                                                    ),
                                                    "p": Style(
                                                      margin: Margins.only(
                                                        bottom: 10,
                                                      ),
                                                      textAlign: TextAlign
                                                          .justify, // Opsional: Biar teks hukumnya rata kanan-kiri
                                                    ),
                                                    "a": Style(
                                                      color: Colors.blue,
                                                      textDecoration:
                                                          TextDecoration.none,
                                                    ),
                                                  },
                                                  /*  onLinkTap: (url, _, _) {
                                                  if (url != null) {
                                                    debugPrint(
                                                      "Open link: $url",
                                                    );
                                                  }
                                                },*/
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text("Tutup"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (acronym.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    //decoration: BoxDecoration(
                                    //color: Theme.of(context)
                                    // .colorScheme
                                    // .surfaceContainerHighest
                                    //   .withValues(alpha: 0.5),
                                    //  UPDATE DISINI: Dulu 4, sekarang 8 biar melengkung manis
                                    // borderRadius: BorderRadius.circular(10),
                                    // ),
                                    child: Text(
                                      rawAcronym,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: getNikayaColor(
                                          normalizeNikayaAcronym(acronym),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // 3. BOTTOM MENU: Integrated Glass Style (Layar - 48)
                if (!_connectionError && !isError)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        // Lebar container menu
                        width: MediaQuery.of(context).size.width > 600
                            ? 500
                            : MediaQuery.of(context).size.width - 48,

                        margin: EdgeInsets.zero,

                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(
                              20,
                            ), // Agak buletin dikit biar manis
                            bottom: Radius.zero,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                            bottom: Radius.zero,
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 10.0,
                              sigmaY: 10.0,
                            ),
                            child: Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.85),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ===============================================
                                  //  DRAG HANDLE (AREA SENTUH ADAPTIF)
                                  // ===============================================
                                  GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onVerticalDragEnd: (details) {
                                      final velocity =
                                          details.primaryVelocity ?? 0;

                                      if (velocity > 0 &&
                                          _isBottomMenuVisible) {
                                        setState(
                                          () => _isBottomMenuVisible = false,
                                        );
                                        _savePreferences();
                                      } else if (velocity < 0 &&
                                          !_isBottomMenuVisible) {
                                        setState(
                                          () => _isBottomMenuVisible = true,
                                        );
                                        _savePreferences();
                                      }
                                    },
                                    onTap: () {
                                      setState(
                                        () => _isBottomMenuVisible =
                                            !_isBottomMenuVisible,
                                      );
                                      _savePreferences();
                                    },
                                    // GANTI JADI ANIMATED CONTAINER
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      width: double.infinity,

                                      //  LOGIC PADDING BARU (VERSI DIET)
                                      // Kalau BUKA: Tipis (8 atas, 4 bawah)
                                      // Kalau TUTUP: Sedeng (15 rata), gak segede gaban kayak tadi
                                      padding: _isBottomMenuVisible
                                          ? const EdgeInsets.fromLTRB(
                                              0,
                                              8,
                                              0,
                                              4,
                                            )
                                          : const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),

                                      child: Center(
                                        // VISUAL GARIS (TETAP SAMA)
                                        child: Container(
                                          width: 40,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ===============================================
                                  // MENU CONTENT
                                  // ===============================================
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    height: _isBottomMenuVisible ? null : 0,
                                    child: SingleChildScrollView(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8.0,
                                        ),
                                        child: _buildFloatingActions(
                                          isSegmented,
                                        ),
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
                  ), // ←  INI PENUTUP POSITIONED BOTTOM MENU
                //  GANTI BLOK IF LAMA DENGAN BUILDER INI:
                //  TOMBOL PIL (TENGAH BAWAH) - Cuma muncul di Tafsir Mode
                if (_isTafsirMode) // <--- TAMBAHIN IF INI
                  ValueListenableBuilder<bool>(
                    valueListenable: _showFloatingBtnVN,
                    builder: (context, showBtn, child) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _visibleParaNumVN,
                        builder: (context, paraNum, _) {
                          // 1. Cek Kondisi di sini (pengganti if lama)
                          if (!showBtn || paraNum == null) {
                            return const SizedBox.shrink();
                          }

                          // 2. Render Widget Tombol
                          return Positioned(
                            left: 16,
                            top: MediaQuery.of(context).padding.top + 80,
                            child: Opacity(
                              opacity: _isLoading ? 0.5 : 1.0,
                              child: Material(
                                elevation: 4,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.85),
                                child: InkWell(
                                  // Pake 'paraNum' dari builder, bukan variable lama
                                  onTap: _isLoading
                                      ? null
                                      : () =>
                                            _showTafsirSwitcherDialog(paraNum),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Pake 'paraNum' dari builder
                                        Text(
                                          '§$paraNum',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _isLoading
                                                ? Colors.grey
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.link,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                //  FLOATING SWITCHER (KANAN) - Font Size 12 (Compact)
                if (_isTafsirMode)
                  Builder(
                    builder: (context) {
                      // 1. CARI TAHU TIPE SEKARANG
                      TafsirType currentType = TafsirType.mul;
                      final titleLower =
                          widget.textData?["root_text"]?["title"]
                              ?.toString()
                              .toLowerCase() ??
                          "";

                      if (titleLower.contains("aṭṭhakathā")) {
                        currentType = TafsirType.att;
                      } else if (titleLower.contains("ṭīkā")) {
                        currentType = TafsirType.tik;
                      }

                      // 2. WIDGET TOMBOLNYA
                      return Positioned(
                        right: 16,
                        top: MediaQuery.of(context).padding.top + 80,
                        child: Opacity(
                          opacity: _isLoading
                              ? 0.5
                              : 1.0, //  Samakan nilainya dengan Baris 1622
                          child: Material(
                            elevation: 4,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.85),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // --- TOMBOL M ---
                                  InkWell(
                                    onTap: _isLoading
                                        ? null
                                        : () {
                                            _navigateTafsirInternal(
                                              widget.uid,
                                              TafsirType.mul,
                                            );
                                          },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        "M",
                                        style: TextStyle(
                                          fontSize:
                                              12, // <--- SUDAH DIKECILIN (SAMA KAYAK TETANGGA)
                                          fontWeight:
                                              currentType == TafsirType.mul
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _isLoading
                                              ? Colors.grey.withValues(
                                                  alpha: 0.5,
                                                )
                                              : (currentType == TafsirType.mul
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.secondary
                                                    : Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // GARIS PEMISAH
                                  Container(
                                    width: 1,
                                    height: 12, // Tinggi garis disesuain dikit
                                    color: Colors.grey.withValues(alpha: 0.3),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                  ),

                                  // --- TOMBOL A ---
                                  InkWell(
                                    onTap: _isLoading
                                        ? null
                                        : () {
                                            //  Matikan fungsi tap
                                            _navigateTafsirInternal(
                                              widget.uid,
                                              TafsirType.att,
                                            );
                                          },
                                    //   onTap: () {
                                    //     _navigateTafsirInternal(
                                    //       widget.uid,
                                    //       TafsirType.att,
                                    //    targetParamNum:
                                    //       _visibleParaNum?.toString() ?? "",
                                    //     );
                                    //    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        "A",
                                        style: TextStyle(
                                          fontSize: 12, // <--- SUDAH DIKECILIN
                                          fontWeight:
                                              currentType == TafsirType.att
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _isLoading
                                              ? Colors.grey.withValues(
                                                  alpha: 0.5,
                                                )
                                              : (currentType == TafsirType.att
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.secondary
                                                    : Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // GARIS PEMISAH
                                  if (showTikaButton)
                                    Container(
                                      width: 1,
                                      height: 12,
                                      color: Colors.grey.withValues(alpha: 0.3),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                    ),

                                  // --- TOMBOL T ---
                                  if (showTikaButton)
                                    InkWell(
                                      onTap: _isLoading
                                          ? null
                                          : () {
                                              //  Matikan fungsi tap
                                              _navigateTafsirInternal(
                                                widget.uid,
                                                TafsirType.tik,
                                              );
                                            },

                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          "Ṭ",
                                          style: TextStyle(
                                            fontSize:
                                                12, // <--- SUDAH DIKECILIN
                                            fontWeight:
                                                currentType == TafsirType.tik
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _isLoading
                                                ? Colors.grey.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : (currentType == TafsirType.tik
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.secondary
                                                      : Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                //  REAL DRAGGABLE SCROLLBAR (OPTIMIZED & ISOLATED)
                if (!_isLoading && !_connectionError && !isError)
                  ValueListenableBuilder<double>(
                    valueListenable: _viewportRatioVN,
                    builder: (context, ratio, _) {
                      return ValueListenableBuilder<double>(
                        valueListenable: _scrollProgressVN,
                        builder: (context, progress, _) {
                          return Positioned(
                            right: 0,
                            top: MediaQuery.of(context).padding.top + 80,
                            bottom: _isBottomMenuVisible ? 100 : 20,
                            width: 30,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double trackHeight =
                                    constraints.maxHeight;
                                final double thumbHeight = (trackHeight * ratio)
                                    .clamp(40.0, trackHeight);
                                final double scrollableArea =
                                    trackHeight - thumbHeight;
                                final double thumbTop =
                                    (progress * scrollableArea).clamp(
                                      0.0,
                                      scrollableArea,
                                    );

                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onVerticalDragStart: (_) {
                                    // Dragging state tetep pake setState lokal gpp, atau
                                    // biarin di parent karena event drag jarang terjadi dibanding scroll
                                    setState(() => _isUserDragging = true);
                                  },
                                  onVerticalDragUpdate: (details) {
                                    // LOGIC DRAG (Update ValueNotifier langsung)
                                    final double fingerY =
                                        details.localPosition.dy;
                                    final double targetThumbTop =
                                        fingerY - (thumbHeight / 2);
                                    final double newProgress =
                                        (targetThumbTop / scrollableArea).clamp(
                                          0.0,
                                          1.0,
                                        );

                                    // Update UI Scrollbar langsung
                                    _scrollProgressVN.value = newProgress;

                                    // Update List (Jumping)
                                    int totalItems = 1;
                                    if (_htmlSegments.isNotEmpty) {
                                      totalItems = _htmlSegments.length;
                                    } else if (widget.textData != null &&
                                        widget.textData!["keys_order"]
                                            is List) {
                                      totalItems =
                                          (widget.textData!["keys_order"]
                                                  as List)
                                              .length;
                                    }

                                    if (totalItems > 0 &&
                                        _itemScrollController.isAttached) {
                                      final int targetIndex =
                                          (newProgress * (totalItems - 1))
                                              .floor();
                                      _itemScrollController.jumpTo(
                                        index: targetIndex,
                                        alignment: 0,
                                      );
                                    }
                                  },
                                  onVerticalDragEnd: (_) {
                                    setState(() => _isUserDragging = false);
                                  },
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: thumbTop,
                                        right: 2,
                                        child: Container(
                                          width: 6,
                                          height: thumbHeight,
                                          decoration: BoxDecoration(
                                            color: _isUserDragging
                                                ? accentColor.withValues(
                                                    alpha: 0.8,
                                                  )
                                                /*Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.8)*/
                                                /*: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.4),*/
                                                : textColor.withValues(
                                                    alpha: 0.4,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
              ], // ← PENUTUP STACK (children)
            ),
          ),
          floatingActionButton: null,
        ),
      ),
    );
  }

  // ============================================
  // UPDATED FLOATING ACTIONS (FIX LANDSCAPE LAYOUT)
  // ============================================
  Widget _buildFloatingActions(bool isSegmented) {
    // 1. Cek Logic Navigasi
    final isTematik = widget.entryPoint == "tematik";
    final showToc = _tocList.isNotEmpty && !_connectionError;

    // 2. Deteksi Layout
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isTablet = size.shortestSide >= 600;
    final isPhoneLandscape = isLandscape && !isTablet;

    // 3. Styling Variabel
    final systemScheme = Theme.of(context).colorScheme;
    final iconColor = systemScheme.onSurface;
    final activeColor = systemScheme.primary;
    final disabledClickableColor = Colors.grey.withValues(alpha: 0.5);

    //  FIX PADDING LANDSCAPE:
    // Dulu 4.0, sekarang 12.0 biar tombol paling pinggir gak nempel bezel HP
    final double internalPaddingH = isPhoneLandscape ? 12.0 : 6.0;
    final double internalPaddingV = isPhoneLandscape ? 4.0 : 4.0;

    // Ukuran icon disesuaikan dikit
    final double iconSize = isPhoneLandscape ? 22.0 : 24.0;
    final double separatorHeight = isPhoneLandscape ? 16.0 : 24.0;

    Widget buildBtn({
      required IconData icon,
      required VoidCallback? onTap,
      bool isActive = false,
      String tooltip = "",
      Color? customIconColor,
    }) {
      Color finalColor;
      // Logic warna tetap sama
      if (onTap == null) {
        finalColor = Colors.grey.withValues(alpha: 0.3);
      } else if (customIconColor != null) {
        finalColor = customIconColor;
      } else if (isActive) {
        finalColor = activeColor;
      } else {
        finalColor = iconColor;
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: tooltip,
            child: Container(
              // Padding tombol
              padding: EdgeInsets.symmetric(
                horizontal: isPhoneLandscape ? 8 : 8,
                vertical: isPhoneLandscape ? 8 : 12,
              ),
              decoration: isActive
                  ? BoxDecoration(
                      color: activeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Icon(icon, color: finalColor, size: iconSize),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: internalPaddingH,
        vertical: internalPaddingV,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisSize: MainAxisSize.max,

        //  INI KUNCINYA:
        // Ganti 'spaceBetween' jadi 'spaceEvenly'.
        // spaceBetween = Tombol mentok ke kiri & kanan (Jelek di landscape).
        // spaceEvenly = Jarak dibagi rata, jadi tombol panah agak ke tengah.
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        children: [
          // --- PREV ---
          buildBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: "Sebelumnya",
            customIconColor: (_isFirst || isTematik)
                ? disabledClickableColor
                : null,
            //  Bersih banget kan:
            onTap: _isLoading ? null : _goToPrevSutta,
          ),

          Container(
            width: 1,
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- TOOLS (Translate) ---
          buildBtn(
            icon: Icons.translate_rounded,
            tooltip: "Suttaplex",
            onTap: _isLoading ? null : _openSuttaplexModal,
          ),

          // --- TOOLS (Search) ---
          buildBtn(
            icon: Icons.search_rounded,
            tooltip: "Pencarian",
            onTap: _isLoading ? null : _openSearchModal,
          ),

          // --- TOOLS (Settings) ---
          buildBtn(
            icon: Icons.text_fields_rounded,
            tooltip: "Tampilan",
            onTap: _isLoading
                ? null
                : () => _openViewSettingsModal(isSegmented),
          ),

          //  UPDATE BAGIAN INI:
          // Munculin tombol Link kalau Mode Tafsir ATAU kalau ada section SC/Verse yang kedeteksi
          if (_isTafsirMode || _tafsirAvailableSections.isNotEmpty)
            buildBtn(
              icon: Icons.link,
              tooltip: "Indeks Referensi",
              // Kalau datanya kosong, disable.
              onTap: (_tafsirAvailableSections.isEmpty || _isLoading)
                  ? null
                  : _openTafsirGridModal,
            ),

          // --- TOOLS (Daftar Isi) ---
          if (showToc)
            buildBtn(
              icon: Icons.list_alt_rounded,
              tooltip: "Daftar Isi",
              onTap: _isLoading
                  ? null
                  : () => _scaffoldKey.currentState?.openEndDrawer(),
            ),

          Container(
            width: 1,
            height: separatorHeight,
            color: Colors.grey.withValues(alpha: 0.2),
          ),

          // --- NEXT ---
          buildBtn(
            icon: Icons.chevron_right_rounded,
            tooltip: "Selanjutnya",
            customIconColor: (_isLast || isTematik)
                ? disabledClickableColor
                : null,
            //  Bersih banget kan:
            onTap: _isLoading ? null : _goToNextSutta,
          ),
        ],
      ),
    );
  }

  //  HELPER UI: Tombol Navigasi Cantik (Persis TafsirDetail)
  Widget _buildNavButton(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(ctx).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
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

  // ============================================
  // UPDATED SEARCH MODAL (KEYBOARD SAFE)
  // ============================================
  void _openSearchModal() {
    setState(() {
      _isSearchActive = true;
      //  Paksa show UI saat search
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Wajib true buat handle keyboard
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Ambil tinggi keyboard
            final double keyboardHeight = MediaQuery.of(
              context,
            ).viewInsets.bottom;

            return Padding(
              // Padding bawah responsif keyboard
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // --- BARIS INPUT & NAVIGASI (YANG HILANG KEMAREN) ---
                        Row(
                          children: [
                            // 1. INPUT TEXT FIELD (DIBALIKIN)
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus:
                                    true, // Biar pas dibuka langsung ngetik
                                decoration: InputDecoration(
                                  hintText: "Cari kata...",
                                  prefixIcon: const Icon(Icons.search),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  // Tombol X buat hapus text
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();

                                            // Reset data LOKAL sheet dulu (biar responsif)
                                            _allMatches.clear();
                                            _currentMatchIndex = 0;

                                            // Update UI Sheet
                                            setSheetState(() {});

                                            // Baru update regex global (tanpa paksa rebuild satu layar penuh yg gak perlu)
                                            _cachedSearchRegex = null;
                                            // setState(() {}); // <--- INI HAPUS AJA, GAK PERLU REBUILD BACKGROUND PAS LAGI BUKA MODAL
                                          },
                                        )
                                      : null,
                                ),
                                // Di dalam TextField onChanged:
                                onChanged: (val) {
                                  if (_debounce?.isActive ?? false) {
                                    _debounce!.cancel();
                                  }
                                  _debounce = Timer(
                                    const Duration(milliseconds: 500),
                                    () {
                                      if (!mounted) return;

                                      // 1. Reset
                                      _allMatches.clear();
                                      _currentMatchIndex = 0;

                                      if (val.trim().length < 2) {
                                        setState(
                                          () => _cachedSearchRegex = null,
                                        );
                                        setSheetState(() {});
                                        return;
                                      }

                                      // 2. Bikin Regex
                                      // final regex = RegExp(
                                      //   RegExp.escape(val.trim()),
                                      // caseSensitive: false,
                                      //);
                                      //setState(
                                      //  () => _cachedSearchRegex = regex,
                                      //);
                                      //  BARU: Pake Helper Fuzzy Pali
                                      final regex =
                                          SuttaTextHelper.createPaliRegex(
                                            val.trim(),
                                          );

                                      setState(
                                        () => _cachedSearchRegex = regex,
                                      );

                                      // 3. SCAN LOGIC
                                      final isSegmented =
                                          widget.textData?["segmented"] == true;

                                      if (isSegmented &&
                                          widget.textData?["keys_order"]
                                              is List) {
                                        final keys = List<String>.from(
                                          widget.textData!["keys_order"],
                                        );
                                        final transMap =
                                            widget.textData?["translation_text"]
                                                as Map? ??
                                            {};
                                        final rootMap =
                                            widget.textData?["root_text"]
                                                as Map? ??
                                            {};

                                        //  1. TENTUKAN EFFECTIVE VIEW MODE
                                        // (Logika ini meniru _buildSegmentedItem biar sinkron sama yang dilihat mata)
                                        ViewMode effectiveViewMode = _viewMode;
                                        // Kalau teks ini cuma punya Pali (Gak ada terjemahan), paksa mode LineByLine biar Pali tetep dicari
                                        if (_isRootOnly) {
                                          effectiveViewMode =
                                              ViewMode.lineByLine;
                                        }

                                        for (int i = 0; i < keys.length; i++) {
                                          final key = keys[i];

                                          //  2. BUNGKUS PENCARIAN PALI
                                          // Cuma cari di Pali kalau modenya BUKAN Translation Only
                                          if (effectiveViewMode !=
                                              ViewMode.translationOnly) {
                                            // A. Pali
                                            String paliTxt =
                                                rootMap[key]?.toString() ?? "";
                                            paliTxt = paliTxt.replaceAll(
                                              SuttaTextHelper.htmlTagRegex,
                                              '',
                                            );
                                            int localPali = 0;
                                            for (final _ in regex.allMatches(
                                              paliTxt,
                                            )) {
                                              _allMatches.add(
                                                SearchMatch(i, localPali, true),
                                              ); // isPali: true
                                              localPali++;
                                            }
                                          }

                                          // B. Trans (Selalu dicari kecuali kasus aneh tertentu, tapi defaultnya cari aja)
                                          String transTxt =
                                              transMap[key]?.toString() ?? "";
                                          transTxt = transTxt.replaceAll(
                                            SuttaTextHelper.htmlTagRegex,
                                            '',
                                          );
                                          int localTrans = 0;
                                          for (final _ in regex.allMatches(
                                            transTxt,
                                          )) {
                                            _allMatches.add(
                                              SearchMatch(i, localTrans, false),
                                            ); // isPali: false
                                            localTrans++;
                                          }
                                        }
                                      } else {
                                        // Logic Legacy
                                        for (
                                          int i = 0;
                                          i < _htmlSegments.length;
                                          i++
                                        ) {
                                          String txt = _htmlSegments[i]
                                              .replaceAll(
                                                SuttaTextHelper.htmlTagRegex,
                                                '',
                                              );
                                          int localCounter = 0;
                                          for (final _ in regex.allMatches(
                                            txt,
                                          )) {
                                            _allMatches.add(
                                              SearchMatch(
                                                i,
                                                localCounter,
                                                false,
                                              ),
                                            );
                                            localCounter++;
                                          }
                                        }
                                      }

                                      // 4. Update UI (VERSI BERSIH, HAPUS DUPLIKAT DI BAWAHNYA)
                                      setState(() {});
                                      setSheetState(() {});

                                      if (_allMatches.isNotEmpty) {
                                        _jumpToResult(0);
                                      }
                                    },
                                  );

                                  setSheetState(() {});
                                },
                              ),
                            ),

                            const SizedBox(width: 8),

                            // 2. TOMBOL NAVIGASI (UP/DOWN)
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              tooltip: "Sebelumnya",
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      int newIndex = _currentMatchIndex - 1;
                                      if (newIndex < 0) {
                                        newIndex = _allMatches.length - 1;
                                      }
                                      _jumpToResult(newIndex);
                                      setSheetState(() {});
                                    },
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.keyboard_arrow_down),
                              tooltip: "Selanjutnya",
                              onPressed: _allMatches.isEmpty
                                  ? null
                                  : () {
                                      int newIndex = _currentMatchIndex + 1;
                                      if (newIndex >= _allMatches.length) {
                                        newIndex = 0;
                                      }
                                      _jumpToResult(newIndex);
                                      setSheetState(() {});
                                    },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // --- INDIKATOR HASIL ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _allMatches.isEmpty
                                  ? (_searchController.text.trim().length < 2
                                        ? "Menunggu input..." // Kalau belum ngetik / kurang dari 2 huruf
                                        : "Tidak ditemukan") // Kalau udah ngetik tapi gak ada hasil
                                  : "${_currentMatchIndex + 1} dari ${_allMatches.length} hasil",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                // Warnain merah dikit kalau not found biar jelas
                                color:
                                    (_allMatches.isEmpty &&
                                        _searchController.text.trim().length >=
                                            2)
                                    ? Theme.of(context).colorScheme.error
                                    : (_allMatches.isEmpty
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary),
                              ),
                            ),

                            // Info tambahan (Opsional)
                            if (_allMatches.isNotEmpty)
                              Text(
                                "Tekan panah untuk navigasi",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _debounce?.cancel();
      // Jangan clear controller text disini kalau mau user balik lagi search-nya masih ada
      // Tapi biasanya di clear biar bersih:
      setState(() {
        _isSearchActive = false; // Balik normal
        _searchController.clear();
        _allMatches.clear();
        _cachedSearchRegex = null; // Hapus highlight pas modal ditutup
      });
    });
  }

  void _openSuttaplexModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Suttaplex(
            uid: widget.uid,
            sourceMode: "sutta_detail",
            onSelect: (newUid, lang, authorUid, textData) {
              // Panggil engine, arah animasi default (Next/Kanan)
              _replaceToSutta(
                newUid,
                lang,
                authorUid: authorUid,
                segmented: textData["segmented"] == true,
                textData: textData,
                isNext: true,
                isNavigatedAction:
                    false, // Karena ini ganti terjemahan, bukan pindah sutta
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================
  // SETTINGS MODAL (WITH SCROLL INDICATOR)
  // ============================================
  void _openViewSettingsModal(bool isSegmented) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SuttaSettingsSheet(
          isSegmented: isSegmented,
          lang: widget.lang,
          isRootOnly: _isRootOnly,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          horizontalPadding: _horizontalPadding,
          fontType: _fontType,
          viewMode: _viewMode,
          readerTheme: _readerTheme,

          // 1. Pastikan 3 warna kustom dikirim ke sheet
          customBgColor: _customBgColor,
          customTextColor: _customTextColor,
          customPaliColor: _customPaliColor, // Tambahkan ini

          showVerseNumbers: _showVerseNumbers,

          onFontSizeChanged: (val) {
            setState(() => _fontSize = val);
            _savePreferences();
          },
          onLineHeightChanged: (val) {
            setState(() => _lineHeight = val);
            _savePreferences();
          },
          onPaddingChanged: (val) {
            setState(() => _horizontalPadding = val);
            _savePreferences();
          },
          onFontTypeChanged: (val) {
            setState(() => _fontType = val);
            _savePreferences();
          },
          onViewModeChanged: (val) {
            setState(() => _viewMode = val);
            _savePreferences();
          },
          onThemeChanged: (val) {
            setState(() => _readerTheme = val);
            _savePreferences();
          },

          // 2. Update callback agar menerima 3 argumen (bg, txt, pali)
          onCustomColorsChanged: (bg, txt, pali) {
            // Tambahkan 'pali' di sini
            setState(() {
              _customBgColor = bg;
              _customTextColor = txt;
              _customPaliColor = pali; // Simpan warna pali
            });
            _savePreferences();
          },

          onShowVerseNumbersChanged: (val) {
            setState(() => _showVerseNumbers = val);
            _savePreferences();
          },
        );
      },
    );
  }
}

class SuttaHeaderConfig {
  final bool isH1;
  final bool isH2;
  final bool isH3;
  final String verseNum;
  final TextStyle paliStyle;
  final TextStyle transStyle;
  final double topPadding;
  final double bottomPadding;

  SuttaHeaderConfig({
    required this.isH1,
    required this.isH2,
    required this.isH3,
    required this.verseNum,
    required this.paliStyle,
    required this.transStyle,
    required this.topPadding,
    required this.bottomPadding,
  });
}
