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
    this.defaultIcon = Icons.link, // fallback default
    this.defaultColor = Colors.orange, // fallback default
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error membuka $url: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item["isHeader"] == "true") {
          final isFirst = index == 0;
          return Padding(
            padding: EdgeInsets.only(
              top: isFirst
                  ? 12
                  : 28, // ⬅️ first header ada jarak tipis, lainnya lebih lega
              bottom: 8, // ⬅️ bottom lebih rapat, nggak kejauhan
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    //  Icon(
                    //    Icons.label_important,
                    //    size: 20,
                    //    color: isDarkMode ? Colors.amber : Colors.orange.shade500,
                    //  ),
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
                const SizedBox(height: 4), // garis lebih dekat ke teks
                Divider(
                  thickness: 1,
                  color: isDarkMode
                      ? Colors.grey.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.4),
                ),
              ],
            ),
          );
        }

        // kalau item biasa
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: PanjangCardBuilder(
            title: item["title"] ?? "",
            subtitle: item["desc"] ?? "",
            icon: defaultIcon, // ⬅️ pakai defaultIcon
            color: defaultColor, // ⬅️ pakai defaultColor
            isDarkMode: isDarkMode,
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

  /* IconData? _mapIcon(String? name) {
    switch (name) {
      case "apps":
        return Icons.apps_rounded;
      case "library_books":
        return Icons.library_books_rounded;
      case "article":
        return Icons.article_rounded;
      case "download":
        return Icons.download_rounded;
      case "forum":
        return Icons.forum_rounded;
      case "share":
        return Icons.share_rounded;
      case "list":
        return Icons.list_alt_rounded;
      default:
        return null; // fallback ke defaultIcon
    }
  }

  Color? _mapColor(String? name) {
    switch (name) {
      case "orange":
        return Colors.orange.shade700;
      case "blue":
        return Colors.blue.shade700;
      case "red":
        return Colors.red.shade600;
      case "green":
        return Colors.green.shade700;
      case "purple":
        return Colors.purple.shade700;
      case "teal":
        return Colors.teal.shade600;
      default:
        return null; // fallback ke defaultColor
    }
  }
*/
}
