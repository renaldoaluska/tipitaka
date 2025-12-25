import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/downloader.dart';
import '../services/db_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _progress = 0.0;
  bool _isDownloading = false;
  List<Map<String, dynamic>> _dataSutta = [];

  // 👇 PASTE LINK GITHUB KAMU DI SINI (Harus berakhiran .zip)
  final String _downloadUrl =
      "https://github.com/renaldoaluska/tipitakaindonesia/releases/download/db/4nikaya.zip";

  // Fungsi buat jalanin download
  void _downloadNikaya() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    final downloader = DownloaderService();

    // Kita download dan simpan sebagai '4nikaya.db' di dalam folder module
    bool success = await downloader.downloadModule(
      url: _downloadUrl,
      fileName: '4nikaya.db',
      onProgress: (val) {
        setState(() => _progress = val);
      },
    );

    setState(() => _isDownloading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Download Selesai! Sedang membaca data..."),
        ),
      );
      _bacaDataDatabase(); // Langsung refresh data
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal Download :(")));
    }
  }

  // Fungsi buat baca DB (Pake fungsi baru 'testGabungan')
  void _bacaDataDatabase() async {
    // 👇 INI YANG DIGANTI: Panggil testGabungan, bukan testReadNikaya
    var data = await DatabaseHelper.instance.testGabungan();

    setState(() {
      _dataSutta = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tripitaka Dev"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Tombol refresh manual buat ngetes
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _bacaDataDatabase,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- BAGIAN TOMBOL DOWNLOAD ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: _isDownloading
                ? Column(
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 10),
                      Text("Mengunduh Module... ${(_progress * 100).toInt()}%"),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _downloadNikaya,
                    icon: const Icon(Icons.download),
                    label: const Text("Download Modul 4 Nikaya"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
          ),

          const Divider(thickness: 2),

          // --- BAGIAN LIST DATA ---
          Expanded(
            child: _dataSutta.isEmpty
                ? const Center(
                    child: Text(
                      "Data kosong.\nKlik Download dulu, atau Refresh jika sudah download.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _dataSutta.length,
                    itemBuilder: (context, index) {
                      final item = _dataSutta[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Menampilkan Book ID (misal: dn1)
                              Text(
                                "ID: ${item['bookid'] ?? 'Tanpa ID'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              const Divider(),
                              // Menampilkan Konten HTML pakai flutter_html
                              Html(
                                data: item['content'] ?? '<p>Kosong</p>',
                                style: {"body": Style(fontSize: FontSize(16))},
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
