import 'package:html_unescape/html_unescape.dart';

class Campaign {
  final String id;
  final String name;
  final String shortDescription;
  final String description;
  final String imageUrl;
  final String seoUrl;
  final int donation; // Target
  final int donationCollected; // Terkumpul
  final String categoryName;
  final int percent;
  final DateTime startDate;
  final DateTime endDate;

  Campaign({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.imageUrl,
    required this.seoUrl,
    required this.donation,
    required this.donationCollected,
    required this.categoryName,
    required this.percent,
    required this.startDate,
    required this.endDate,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    final unescape = HtmlUnescape(); // Buat instance

    return Campaign(
      id: json['id'] ?? '',
      name: unescape.convert(json['name'] ?? ''), // 🔧 Decode HTML entities
      shortDescription: unescape.convert(json['short_description'] ?? ''),
      description: unescape.convert(json['description'] ?? ''),
      imageUrl: json['image'] ?? '',
      seoUrl: json['seo_url'] ?? '',
      donation: int.tryParse(json['donation'].toString()) ?? 0,
      donationCollected:
          int.tryParse(json['donation_collected'].toString()) ?? 0,
      categoryName: unescape.convert(
        json['categories_name'] ?? '',
      ), // 🔧 Decode
      percent: int.tryParse(json['percent'].toString()) ?? 0,
      startDate: DateTime.tryParse(json['start_date']) ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']) ?? DateTime.now(),
    );
  }

  String get fullUrl => 'https://www.danaeveryday.id/campaign/$seoUrl';

  String get formattedTarget => _formatRupiah(donation);
  String get formattedCollected => _formatRupiah(donationCollected);

  static String _formatRupiah(int amount) {
    if (amount >= 1000000000) {
      double m = amount / 1000000000;
      if (m == m.toInt()) {
        return 'Rp ${m.toInt()}M';
      }
      // Truncate ke 2 desimal (potong, bukan bulatkan)
      double truncated = (m * 100).truncate() / 100;
      return 'Rp ${truncated.toStringAsFixed(2)}M';
    } else if (amount >= 1000000) {
      double jt = amount / 1000000;
      if (jt == jt.toInt()) {
        return 'Rp ${jt.toInt()}jt';
      }
      // Truncate ke 2 desimal (potong, bukan bulatkan)
      double truncated = (jt * 100).truncate() / 100;
      return 'Rp ${truncated.toStringAsFixed(2)}jt';
    } else if (amount >= 1000) {
      double rb = amount / 1000;
      if (rb == rb.toInt()) {
        return 'Rp ${rb.toInt()}rb';
      }
      // Truncate ke 1 desimal (potong, bukan bulatkan)
      double truncated = (rb * 10).truncate() / 10;
      return 'Rp ${truncated.toStringAsFixed(1)}rb';
    }
    return 'Rp $amount';
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 0;
    return endDate.difference(now).inDays;
  }
}
