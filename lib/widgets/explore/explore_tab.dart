import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:url_launcher/url_launcher.dart';
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

  /// Buka URL: YouTube/Instagram di app native, website lain di Custom Tabs
  /// Buka URL: YouTube/Instagram di app native, website lain di Custom Tabs
  Future<void> _launchCustomTab(BuildContext context, String url) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    try {
      final Uri uri = Uri.parse(url);

      // 🎯 YouTube atau Instagram → buka di app native
      if (url.contains('youtube.com') ||
          url.contains('youtu.be') ||
          url.contains('instagram.com')) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // 🌐 Website biasa → pakai Custom Tabs
        await custom_tabs.launchUrl(
          uri,
          customTabsOptions: const custom_tabs.CustomTabsOptions(
            showTitle: true,
            urlBarHidingEnabled: true,
            shareState: custom_tabs.CustomTabsShareState.on,
            instantAppsEnabled: true,
          ),
          safariVCOptions: custom_tabs.SafariViewControllerOptions(
            preferredBarTintColor: isDarkMode
                ? Colors.grey[900]
                : Colors.orange,
            preferredControlTintColor: Colors.white,
            barCollapsingEnabled: true,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error membuka link: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final dividerColor = isDarkMode
        ? Color.fromARGB(77, 158, 158, 158)
        : Color.fromARGB(102, 158, 158, 158);

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
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Divider(thickness: 1, color: dividerColor),
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
