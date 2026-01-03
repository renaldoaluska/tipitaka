import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:tipitaka/widgets/compact_card.dart';
import 'package:url_launcher/url_launcher.dart';

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
        ? const Color.fromARGB(77, 158, 158, 158)
        : const Color.fromARGB(102, 158, 158, 158);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        // --- TAMPILAN HEADER (Tetap dipertahankan) ---
        if (item["isHeader"] == "true") {
          final isFirst = index == 0;
          return Padding(
            padding: EdgeInsets.only(top: isFirst ? 12 : 28, bottom: 12),
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

        // --- TAMPILAN ITEM (Menggunakan CompactCardBuilder agar sama dengan Home) ---
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CompactCard(
            // 👈 Pakai widget dari file terpisah
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

/// Widget Card yang sama persis dengan yang ada di home.dart
class CompactCardBuilder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CompactCardBuilder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDarkMode
          ? Colors.grey[850]?.withValues(alpha: 0.4)
          : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Icon dengan ukuran lebih kecil
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines:
                          2, // Diubah jadi 2 agar deskripsi panjang tidak terpotong terlalu cepat
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Icon Open in New
              Icon(
                Icons.open_in_new,
                size: 16,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
