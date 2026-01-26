import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';

// ============================================================
// 🧠 HELPER CLASS: OTAK PEMROSESAN TEKS
// Berisi logic Regex, HTML Decoding, dan Highlight Search
// ============================================================
class SuttaTextHelper {
  //  ALAT DECODE ABADI (Hemat Memori)
  static final HtmlUnescape unescape = HtmlUnescape();

  //  CACHE REGEX
  static final RegExp htmlTagRegex = RegExp(r'<[^>]*>');
  static final RegExp vaggaUidRegex = RegExp(
    r'^([a-z]+(?:-[a-z]+)?)(\d+)(?:\.(\d+))?',
  );

  // ============================================================
  // 1. FUZZY PALI SEARCH REGEX CREATOR
  // ============================================================
  static RegExp createPaliRegex(String query) {
    //  VALIDASI: Kalau query kosong, return regex yang gak match apa-apa
    if (query.trim().isEmpty) {
      return RegExp(r'(?!)'); // Negative lookahead (never matches)
    }

    // Hapus simbol < dan > biar user gak bisa search tag HTML
    final cleanQuery = query.replaceAll(RegExp(r'[<>]'), '');

    //  VALIDASI: Setelah dibersihkan masih ada isi?
    if (cleanQuery.isEmpty) {
      return RegExp(r'(?!)');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < cleanQuery.length; i++) {
      final char = cleanQuery[i].toLowerCase();
      switch (char) {
        case 'a':
          buffer.write('(?:a|ā)');
          break;
        case 'i':
          buffer.write('(?:i|ī)');
          break;
        case 'u':
          buffer.write('(?:u|ū)');
          break;
        case 'm':
          buffer.write('(?:m|ṃ|ṁ)');
          break;
        case 'n':
          buffer.write('(?:n|ṇ|ñ|ṅ)');
          break;
        case 't':
          buffer.write('(?:t|ṭ)');
          break;
        case 'd':
          buffer.write('(?:d|ḍ)');
          break;
        case 'l':
          buffer.write('(?:l|ḷ)');
          break;
        default:
          // Escape karakter spesial regex kayak (, [, *, ?
          buffer.write(RegExp.escape(char));
      }
    }

    try {
      return RegExp(buffer.toString(), caseSensitive: false);
    } catch (e) {
      //  SAFETY: Kalau regex invalid, return yang aman
      debugPrint("⚠️ Invalid regex pattern: $e");
      return RegExp(r'(?!)');
    }
  }

  // ============================================================
  // 2. INJECT HIGHLIGHTS KE HTML (Untuk Mode Non-Segmented)
  // Menambahkan tag <x-highlight> ke dalam string HTML
  // ============================================================
  static String injectSearchHighlights(
    String content,
    int listIndex,
    bool isPaliTarget,
    RegExp? searchRegex,
    List<SearchMatch> allMatches,
    int currentMatchIndex,
  ) {
    //  VALIDASI: Cek semua input
    if (searchRegex == null || content.trim().isEmpty) return content;

    try {
      // 1. Decode HTML entities (&nbsp; → spasi, &amp; → &, dll)
      final decoded = unescape.convert(content);

      //  VALIDASI: Hasil decode bisa kosong
      if (decoded.isEmpty) return content;

      // 2. Strip tags untuk matching (Biar search gak kena tag HTML)
      final cleanText = decoded.replaceAll(htmlTagRegex, '');

      // 3. Find all matches di clean text
      final matches = searchRegex.allMatches(cleanText).toList();
      if (matches.isEmpty) return content;

      // 4. Build position map: clean index → original index
      final Map<int, int> cleanToOriginal = {};
      int cleanIdx = 0;
      bool insideTag = false;

      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] == '<') {
          insideTag = true;
        } else if (decoded[i] == '>') {
          insideTag = false;
          continue;
        }

        if (!insideTag) {
          cleanToOriginal[cleanIdx] = i;
          cleanIdx++;
        }
      }

      // Map untuk end position (next character after last match char)
      cleanToOriginal[cleanIdx] = decoded.length;

      // 5. Inject highlights (dari belakang agar posisi tidak bergeser)
      String result = decoded;

      for (int i = matches.length - 1; i >= 0; i--) {
        final match = matches[i];

        // Check if active
        bool isActive = false;
        if (allMatches.isNotEmpty && currentMatchIndex < allMatches.length) {
          final activeMatch = allMatches[currentMatchIndex];
          if (activeMatch.listIndex == listIndex &&
              activeMatch.isPali == isPaliTarget &&
              activeMatch.localIndex == i) {
            isActive = true;
          }
        }

        //  SAFE: Map dengan default fallback
        final origStart = cleanToOriginal[match.start] ?? 0;
        final origEnd = cleanToOriginal[match.end] ?? decoded.length;

        //  VALIDASI: Pastikan range valid
        if (origStart >= result.length ||
            origEnd > result.length ||
            origStart >= origEnd) {
          continue; // Skip kalau range invalid
        }

        // Extract segment (termasuk tag HTML di dalamnya jika ada)
        final segment = result.substring(origStart, origEnd);

        // Build highlight wrapper
        final bgColor = isActive ? "#FF8C00" : "#FFFF00"; // Orange / Yellow
        final color = isActive ? "white" : "black";
        final activeAttr = isActive ? 'data-active="true"' : '';

        final wrapper =
            "<x-highlight style='background-color: $bgColor; "
            "color: $color; font-weight: bold; border-radius: 4px; "
            "padding: 0 2px;' $activeAttr>$segment</x-highlight>";

        // Replace (inject)
        result =
            result.substring(0, origStart) +
            wrapper +
            result.substring(origEnd);
      }

      return result;
    } catch (e) {
      debugPrint("❌ Highlight error: $e");
      return content; // Fallback: return original
    }
  }

  // ============================================================
  // 3. PARSE HTML KE TEXTSPANS DENGAN HIGHLIGHT (Untuk Segmented)
  // Memecah HTML jadi potongan teks kecil biar bisa dirender RichText
  // ============================================================
  static List<InlineSpan> parseHtmlToSpansWithHighlight(
    String htmlText,
    TextStyle baseStyle,
    int listIndex,
    bool isPali,
    RegExp? searchRegex,
    List<SearchMatch> allMatches,
    int currentMatchIndex,
  ) {
    //  VALIDASI: Input kosong
    if (htmlText.trim().isEmpty) return [];

    try {
      // 🧹 BERSIH-BERSIH TAG KHUSUS SUTTACENTRAL
      htmlText = htmlText
          .replaceAll(RegExp(r'\s*<j>\s*'), '\n') // Enjambment
          .replaceAll(
            RegExp(r'<br\s*/?>', caseSensitive: false),
            '\n',
          ) // Line Break
          .replaceAll('&nbsp;', ' '); // Non-breaking space

      final spans = <InlineSpan>[];

      // Regex Tag HTML sederhana (Bold, Italic, Span)
      final tagRegex = RegExp(
        r'<(/)?(em|i|b|strong|span)([^>]*)>',
        caseSensitive: false,
      );

      int lastIndex = 0;
      List<TextStyle> styleStack = [baseStyle];

      // Counter lokal untuk sinkronisasi dengan SearchMatch
      int localMatchCounter = 0;

      for (final match in tagRegex.allMatches(htmlText)) {
        if (match.start > lastIndex) {
          final plainText = htmlText.substring(lastIndex, match.start);

          if (plainText.isNotEmpty) {
            final decodedText = unescape.convert(plainText);

            //  MAGIC: Build Highlighted Spans
            final highlightedSpans = _buildHighlightedSpans(
              decodedText,
              styleStack.last,
              listIndex,
              isPali,
              localMatchCounter,
              searchRegex,
              allMatches,
              currentMatchIndex,
            );

            spans.addAll(highlightedSpans.spans);
            localMatchCounter = highlightedSpans.newCounter; // Update counter
          }
        }

        // --- LOGIC PARSING TAG ---
        final isClosing = match.group(1) == '/';
        final tagName = match.group(2)?.toLowerCase();

        //  VALIDASI: tagName bisa null
        if (tagName == null) {
          lastIndex = match.end;
          continue;
        }

        if (!isClosing) {
          final parentStyle = styleStack.last;
          TextStyle newStyle = parentStyle;

          if (tagName == 'b' || tagName == 'strong') {
            newStyle = parentStyle.copyWith(fontWeight: FontWeight.bold);
          } else if (tagName == 'em' || tagName == 'i') {
            newStyle = parentStyle.copyWith(fontStyle: FontStyle.italic);
          }
          styleStack.add(newStyle);
        } else {
          if (styleStack.length > 1) {
            styleStack.removeLast();
          }
        }

        lastIndex = match.end;
      }

      // Render sisa teks terakhir
      if (lastIndex < htmlText.length) {
        final remainingText = htmlText.substring(lastIndex);
        final decodedText = unescape.convert(remainingText);

        final highlightedSpans = _buildHighlightedSpans(
          decodedText,
          styleStack.last,
          listIndex,
          isPali,
          localMatchCounter,
          searchRegex,
          allMatches,
          currentMatchIndex,
        );
        spans.addAll(highlightedSpans.spans);
      }

      //  SAFETY: Jangan return list kosong, minimal kasih TextSpan kosong
      if (spans.isEmpty) {
        return [TextSpan(text: '', style: baseStyle)];
      }

      return spans;
    } catch (e) {
      debugPrint("❌ Parse HTML error: $e");
      // Fallback: Return teks mentah tanpa formatting
      return [TextSpan(text: htmlText, style: baseStyle)];
    }
  }

  // ============================================================
  // 4. CORE ENGINE: MEMECAH TEKS JADI BIASA & HIGHLIGHT
  // (Fungsi Private yang dipanggil parseHtmlToSpansWithHighlight)
  // ============================================================
  static HighlightResult _buildHighlightedSpans(
    String text,
    TextStyle currentStyle,
    int listIndex,
    bool isPaliTarget,
    int startCounter,
    RegExp? searchRegex,
    List<SearchMatch> allMatches,
    int currentMatchIndex,
  ) {
    //  VALIDASI: Text kosong
    if (text.isEmpty) {
      return HighlightResult([], startCounter);
    }

    // Kalau gak ada search atau query kependekan, balikin teks polos
    if (searchRegex == null) {
      return HighlightResult([
        TextSpan(text: text, style: currentStyle),
      ], startCounter);
    }

    try {
      final matches = searchRegex.allMatches(text);
      if (matches.isEmpty) {
        return HighlightResult([
          TextSpan(text: text, style: currentStyle),
        ], startCounter);
      }

      final spans = <InlineSpan>[];
      int textCursor = 0;
      int currentCounter = startCounter;

      for (final match in matches) {
        //  VALIDASI: Range bisa invalid
        if (match.start < 0 ||
            match.end > text.length ||
            match.start >= match.end) {
          continue;
        }

        // 1. Teks sebelum highlight
        if (match.start > textCursor) {
          spans.add(
            TextSpan(
              text: text.substring(textCursor, match.start),
              style: currentStyle,
            ),
          );
        }

        // 2. Cek apakah highlight ini AKTIF? (Warna Orange)
        bool isActive = false;
        if (allMatches.isNotEmpty && currentMatchIndex < allMatches.length) {
          final activeMatch = allMatches[currentMatchIndex];
          // Syarat: Index Baris sama, Tipe sama (Pali/Indo), dan Urutan Counter sama
          if (activeMatch.listIndex == listIndex &&
              activeMatch.isPali == isPaliTarget &&
              activeMatch.localIndex == currentCounter) {
            isActive = true;
          }
        }

        // 3. Render HIGHLIGHT
        spans.add(
          TextSpan(
            text: text.substring(match.start, match.end),
            style: currentStyle.copyWith(
              backgroundColor: isActive ? Colors.orange : Colors.yellow,
              color: isActive ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        textCursor = match.end;
        currentCounter++; // Nambah counter setiap ketemu kata
      }

      // 4. Sisa teks setelah highlight terakhir
      if (textCursor < text.length) {
        spans.add(
          TextSpan(text: text.substring(textCursor), style: currentStyle),
        );
      }

      return HighlightResult(spans, currentCounter);
    } catch (e) {
      debugPrint("❌ Highlight build error: $e");
      // Fallback: Return teks polos
      return HighlightResult([
        TextSpan(text: text, style: currentStyle),
      ], startCounter);
    }
  }
}

// ============================================================
// MODELS (Helper Class)
// ============================================================

// Helper class buat return 2 nilai sekaligus (List Spans + Counter Baru)
class HighlightResult {
  final List<InlineSpan> spans;
  final int newCounter;
  HighlightResult(this.spans, this.newCounter);
}

// Model untuk menyimpan data hasil pencarian
class SearchMatch {
  final int listIndex; // Index baris/paragraf ke berapa
  final int localIndex; // Urutan kata ke berapa di dalam baris itu
  final bool isPali; //  PENANDA: Apakah ini teks Pali atau Terjemahan?

  SearchMatch(this.listIndex, this.localIndex, this.isPali);
}
