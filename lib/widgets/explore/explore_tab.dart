import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import '../panjang_card_builder.dart';

class ExploreTab extends StatelessWidget {
  final List<Map<String, String>> items;
  final IconData defaultIcon;
  final Color defaultColor;

  const ExploreTab({
    super.key,
    required this.items,
    this.defaultIcon = Icons.link,
    this.defaultColor = Colors.orange,
  });

  Future<void> _launchCustomTab(BuildContext context, String url) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: const CustomTabsOptions(
          showTitle: true,
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: true,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: isDarkMode ? Colors.grey[900] : Colors.orange,
          preferredControlTintColor: Colors.white,
          barCollapsingEnabled: true,
        ),
      );
    } catch (e) {
      // ✅ Fix: Check if widget is still mounted before using context
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error membuka $url: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ✅ Fix: Extract warna divider di sini (tanpa withOpacity)
    final dividerColor = isDarkMode
        ? Color.fromARGB(77, 158, 158, 158) // Grey 30% untuk dark
        : Color.fromARGB(102, 158, 158, 158); // Grey 40% untuk light

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item["isHeader"] == "true") {
          final isFirst = index == 0;
          return Padding(
            padding: EdgeInsets.only(top: isFirst ? 12 : 28, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item["title"] ?? "",
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.amber : Colors.grey[700],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Divider(
                  thickness: 1,
                  color: dividerColor, // ✅ Ganti dari Colors.grey.withOpacity()
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: PanjangCardBuilder(
            title: item["title"] ?? "",
            subtitle: item["desc"] ?? "",
            icon: defaultIcon,
            color: defaultColor,
            // isDarkMode: isDarkMode,
            onTap: () {
              final url = item["url"] ?? "";
              if (url.isEmpty) return;
              _launchCustomTab(context, url);
            },
          ),
        );
      },
    );
  }
}
