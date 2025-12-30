// lib/screens/tematik_webview.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/tematik_chapter_list.dart';

class TematikWebView extends StatefulWidget {
  final String url;
  final String title;
  final int? chapterIndex; // Tambah ini untuk tau chapter mana

  const TematikWebView({
    super.key,
    required this.url,
    required this.title,
    this.chapterIndex, // Optional, kalo null berarti bukan pendahuluan chapter
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
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _applyCustomCSS() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      // Dark mode CSS
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
      // Light mode CSS
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
          onChecklistChanged: () {
            // Optional: bisa refresh sesuatu kalo perlu
          },
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
            WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.deepOrange),
              ),
            ),
        ],
      ),
      // Floating button cuma muncul kalo ada chapterIndex
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
