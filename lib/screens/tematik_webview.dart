// lib/screens/tematik_webview.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // 🔥 TAMBAH INI
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/tematik_chapter_list.dart';
import 'menu_page.dart';
import 'suttaplex.dart';

class TematikWebView extends StatefulWidget {
  final String url;
  final String title;
  final int? chapterIndex;

  const TematikWebView({
    super.key,
    required this.url,
    required this.title,
    this.chapterIndex,
  });

  @override
  State<TematikWebView> createState() => _TematikWebViewState();
}

class _TematikWebViewState extends State<TematikWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            _applyCustomCSS();
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
          // 🔥 TAMBAH INI: Handle link clicks
          // 🔥 TAMBAH INI: Handle link clicks
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            print('🔗 Navigation request: $url');

            // ✅ Cek apakah link ke suttacentral.net
            if (url.contains('suttacentral.net/')) {
              print('✅ Detected suttacentral link');

              final uid = _extractUidFromUrl(url);
              print('🔍 Extracted UID: $uid');

              if (uid != null && uid.isNotEmpty) {
                // 🔥 Pengecualian: pli-tv-bu-pm dan pli-tv-bi-pm langsung sutta
                final isExceptionSutta =
                    uid == 'pli-tv-bu-pm' || uid == 'pli-tv-bi-pm';

                // 🔥 Pattern untuk detect sutta ID (ada angka di dalamnya)
                final hasNumber = RegExp(r'\d').hasMatch(uid);

                print(
                  '🎯 isExceptionSutta: $isExceptionSutta, hasNumber: $hasNumber',
                );

                if (isExceptionSutta || hasNumber) {
                  print('📖 Opening Suttaplex');
                  _openSuttaplex(uid);
                } else {
                  print('📂 Opening MenuPage');
                  final parentAcronym = _extractPrefix(uid);
                  print('📌 Parent Acronym: $parentAcronym');

                  _openMenuPage(uid, parentAcronym); // 🔥 Pakai modal
                }

                print('🚫 Preventing navigation');
                return NavigationDecision.prevent;
              }
            }

            print('➡️ Allowing navigation');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  String? _extractUidFromUrl(String url) {
    try {
      var targetUrl = url;

      // 🔥 Kalau ada Google redirect, ambil URL asli dari parameter 'q'
      if (url.contains('google.com/url')) {
        final uri = Uri.parse(url);
        final qParam = uri.queryParameters['q'];
        if (qParam != null && qParam.contains('suttacentral.net')) {
          targetUrl = qParam;
          print('🔄 Extracted from Google redirect: $targetUrl');
        }
      }

      final uri = Uri.parse(targetUrl);
      print('🔍 Parsing URL: $targetUrl');
      print('🔍 URI path: ${uri.path}');

      final segments = uri.pathSegments;
      print('🔍 Path segments: $segments');

      if (segments.isEmpty) return null;

      String uid = segments[0];
      print('🔍 First segment (raw): $uid');

      // 🔥 Validasi: harus dimulai dengan huruf, bisa ada angka/dash/dot
      if (RegExp(r'^[a-z][a-z0-9\-\.]*$', caseSensitive: false).hasMatch(uid)) {
        print('✅ Valid UID: $uid');
        return uid.toLowerCase();
      }

      print('❌ Invalid UID format: $uid');
      return null;
    } catch (e) {
      debugPrint('❌ Error parsing URL: $e');
      return null;
    }
  }

  String _extractPrefix(String uid) {
    // --- FILTER 1: KHUSUS VINAYA (Manual Mapping) ---
    if (uid.startsWith("pli-tv-")) {
      if (uid.contains("bu-vb-pj")) return "Bu Pj";
      if (uid.contains("bu-vb-ss")) return "Bu Ss";
      if (uid.contains("bu-vb-ay")) return "Bu Ay";
      if (uid.contains("bu-vb-np")) return "Bu Np";
      if (uid.contains("bu-vb-pc")) return "Bu Pc";
      if (uid.contains("bu-vb-pd")) return "Bu Pd";
      if (uid.contains("bu-vb-sk")) return "Bu Sk";
      if (uid.contains("bu-vb-as")) return "Bu As";
      if (uid.contains("bi-vb-pj")) return "Bi Pj";
      if (uid.contains("bi-vb-ss")) return "Bi Ss";
      if (uid.contains("bi-vb-np")) return "Bi Np";
      if (uid.contains("bi-vb-pc")) return "Bi Pc";
      if (uid.contains("bi-vb-pd")) return "Bi Pd";
      if (uid.contains("bi-vb-sk")) return "Bi Sk";
      if (uid.contains("bi-vb-as")) return "Bi As";
      if (uid.contains("kd")) return "Kd";
      if (uid.contains("pvr")) return "Pvr";
      if (uid.contains("bu-pm")) return "Bu";
      if (uid.contains("bi-pm")) return "Bi";
    }

    // --- DEFAULT: Ambil huruf di awal sebelum angka atau dash ---
    final match = RegExp(
      r'^([a-z]+)(?=\d|-|$)',
      caseSensitive: false,
    ).firstMatch(uid);
    return match?.group(1)?.toUpperCase() ?? '';
  }

  // 🔥 FUNGSI BARU: Buka MenuPage modal
  void _openMenuPage(String uid, String parentAcronym) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: MenuPage(uid: uid, parentAcronym: parentAcronym),
          ),
        ),
      ),
    );
  }

  // 🔥 FUNGSI BARU: Buka Suttaplex modal
  void _openSuttaplex(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Suttaplex(
              uid: uid,
              sourceMode: "search", // ✅ Tandai dari search
            ),
          ),
        ),
      ),
    );
  }

  void _applyCustomCSS() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      _controller.runJavaScript('''
        document.body.style.setProperty("color", "white");
        document.body.style.setProperty("background-color", "#121212");
        
        var node = document.createElement('style');
        node.type = 'text/css';
        node.innerHTML = 
        `
        article.post-outer-container {
          background: #121212 !important;
          color: white;
        }
        .page_body .centered {
          background: #121212 !important;
        }
        .boxmirip {
          background: #212121 !important;
        }
        div.navbarmirip {
          background: #bf360c !important;
        }
        div.navbarmirip a {
          color: white !important;
        }
        div.navbarmirip a:hover {
          background-color: #870000 !important;
        }
        dl.faq .desc {
          background-color: #5A5A5A !important;
        }
        .post-body {
          display: block !important;
          color: white !important;
        }
        `;
        document.head.appendChild(node);
      ''');
    } else {
      _controller.runJavaScript('''
        var node = document.createElement('style');
        node.type = 'text/css';
        node.innerHTML = 
        `
        article.post-outer-container {
          background: #eceff1 !important;
        }
        .page_body .centered {
          background: #eceff1 !important;
        }
        .post-body {
          display: block !important;
        }
        `;
        document.head.appendChild(node);
      ''');
    }
  }

  void _showChapterList() {
    if (widget.chapterIndex == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TematikChapterList(
          chapterIndex: widget.chapterIndex!,
          onChecklistChanged: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal Memuat',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Periksa koneksi internet Anda',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Muat Ulang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            // 🔥 FIX: Kasih gesture recognizer biar bisa scroll
            WebViewWidget(
              controller: _controller,
              gestureRecognizers: {
                Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
                ),
              },
            ),
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.deepOrange),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.chapterIndex != null
          ? FloatingActionButton.extended(
              onPressed: _showChapterList,
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.list_alt),
              label: const Text(
                'Daftar Teks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
