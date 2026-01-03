import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';

class FetchResult {
  final Map<String, List<Campaign>> dataByCategory;
  final bool wasFetchedFromServer;

  FetchResult(this.dataByCategory, this.wasFetchedFromServer);

  // Helper getter
  List<Campaign> get allCampaigns =>
      dataByCategory.values.expand((list) => list).toList();
}

class DanaEverydayService {
  static const String baseUrl = 'https://www.danaeveryday.id/campaign_category';
  static const String cacheKeyAll = 'dana_campaigns_all';
  static const Duration cacheDuration = Duration(hours: 1);
  //static const Duration cacheDuration = Duration(minutes: 30);

  static const Map<String, String> categories = {
    'Pembangunan & Renovasi Vihara': '8',
    'Pendidikan Buddhist': '9',
    'Sangha Dana': '10',
    'Sosial Kemanusiaan': '13',
    'Ashoka Spirit': '14',
    'Fangshen': '15',
  };

  // ✅ FETCH SEMUA KATEGORI SEKALI JALAN (PARALLEL)
  Future<FetchResult> fetchAllCampaigns({bool forceRefresh = false}) async {
    try {
      // 1. Cek cache dulu
      if (!forceRefresh) {
        final cached = await _getFromCache();
        if (cached != null) {
          debugPrint('📦 Return from cache (${cached.length} campaigns)');
          return FetchResult(_groupByCategory(cached), false);
        }
      }

      debugPrint('🌐 Fetching from server (6 parallel requests)...');

      // 2. Fetch semua kategori BERSAMAAN (parallel)
      final futures = categories.entries.map((entry) async {
        try {
          final url =
              '$baseUrl/getCampaignFromCategory?category_id=${entry.value}';
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final decoded = json.decode(response.body);

            // ✅ CEK ERROR MESSAGE DARI API
            if (decoded is Map && decoded.containsKey('error')) {
              debugPrint('⚠️ ${entry.key}: ${decoded['error']}');
              return <Campaign>[]; // Return list kosong
            }

            // ✅ HANDLE LIST
            List<dynamic> jsonList = [];
            if (decoded is List) {
              jsonList = decoded;
            } else if (decoded is Map) {
              // Coba cari key data/campaigns/results
              if (decoded.containsKey('data') && decoded['data'] is List) {
                jsonList = decoded['data'];
              } else if (decoded.containsKey('campaigns') &&
                  decoded['campaigns'] is List) {
                jsonList = decoded['campaigns'];
              } else if (decoded.containsKey('results') &&
                  decoded['results'] is List) {
                jsonList = decoded['results'];
              } else {
                debugPrint('⚠️ ${entry.key}: Unknown Map structure');
                return <Campaign>[];
              }
            }

            // ✅ PARSE CAMPAIGNS
            final campaigns = jsonList
                .map((json) {
                  try {
                    return Campaign.fromJson(json);
                  } catch (e) {
                    debugPrint(
                      '⚠️ ${entry.key}: Failed to parse campaign - $e',
                    );
                    return null;
                  }
                })
                .whereType<Campaign>()
                .where(
                  (c) =>
                      c.name.isNotEmpty &&
                      c.imageUrl.isNotEmpty &&
                      c.categoryName.isNotEmpty,
                )
                .toList();

            debugPrint('✅ ${entry.key}: ${campaigns.length} campaigns');
            return campaigns;
          } else {
            debugPrint('❌ ${entry.key}: HTTP ${response.statusCode}');
            return <Campaign>[];
          }
        } catch (e) {
          debugPrint('❌ ${entry.key}: Exception - $e');
          return <Campaign>[];
        }
      });

      // 3. Tunggu semua selesai
      final results = await Future.wait(
        futures,
      ).timeout(const Duration(seconds: 15));

      // 4. Gabung semua jadi 1 list
      final allCampaigns = results.expand((list) => list).toList();

      if (allCampaigns.isEmpty) {
        throw Exception('No campaigns fetched from server');
      }

      // 5. Simpen ke cache
      await _saveToCache(allCampaigns);
      debugPrint('💾 Saved to cache (${allCampaigns.length} total campaigns)');

      return FetchResult(_groupByCategory(allCampaigns), true);
    } catch (e) {
      // Fallback ke cache kalau fetch gagal
      debugPrint('⚠️ Fetch failed: $e');
      final cached = await _getFromCache();
      if (cached != null) {
        debugPrint('📦 Using cached data as fallback');
        return FetchResult(_groupByCategory(cached), false);
      }
      throw Exception('Fetch failed & no cache available: $e');
    }
  }

  // ✅ Group campaigns by category name
  Map<String, List<Campaign>> _groupByCategory(List<Campaign> campaigns) {
    final Map<String, List<Campaign>> result = {};

    for (final campaign in campaigns) {
      final categoryName = campaign.categoryName;
      result.putIfAbsent(categoryName, () => []).add(campaign);
    }

    // Sort each category by percent (tertinggi dulu)
    result.forEach((key, value) {
      value.sort((a, b) => b.percent.compareTo(a.percent));
    });

    return result;
  }

  // ✅ Get top N campaigns (dari semua kategori)
  List<Campaign> getTopCampaigns(FetchResult result, {int limit = 12}) {
    final allCampaigns = List<Campaign>.from(
      result.allCampaigns,
    ); // ✅ Bikin copy dulu
    allCampaigns.sort((a, b) => b.percent.compareTo(a.percent));
    return allCampaigns.take(limit).toList();
  }

  // ✅ Get campaigns untuk 1 kategori spesifik
  List<Campaign> getCampaignsByCategory(
    FetchResult result,
    String categoryName, {
    int? limit,
  }) {
    final campaigns = result.dataByCategory[categoryName] ?? [];
    if (limit != null) {
      return campaigns.take(limit).toList();
    }
    return campaigns;
  }

  // Cache management
  Future<List<Campaign>?> _getFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKeyAll);
      final cachedTime = prefs.getInt('${cacheKeyAll}_time');

      if (cachedData != null && cachedTime != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
        if (age < cacheDuration.inMilliseconds) {
          final List<dynamic> jsonList = json.decode(cachedData);
          return jsonList.map((json) => Campaign.fromJson(json)).toList();
        } else {
          debugPrint(
            '⏰ Cache expired (${Duration(milliseconds: age).inHours} hours old)',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Cache read error: $e');
    }
    return null;
  }

  Future<void> _saveToCache(List<Campaign> campaigns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = campaigns
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'short_description': c.shortDescription,
              'description': c.description,
              'image': c.imageUrl,
              'seo_url': c.seoUrl,
              'donation': c.donation,
              'donation_collected': c.donationCollected,
              'categories_name': c.categoryName,
              'percent': c.percent,
              'start_date': c.startDate.toIso8601String(),
              'end_date': c.endDate.toIso8601String(),
            },
          )
          .toList();

      await prefs.setString(cacheKeyAll, json.encode(jsonList));
      await prefs.setInt(
        '${cacheKeyAll}_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('❌ Save to cache error: $e');
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKeyAll);
    await prefs.remove('${cacheKeyAll}_time');
    debugPrint('🗑️ Cache cleared');
  }

  // ✅ Helper buat ngecek apakah data fresh dari server
  Future<String?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_campaign_update_time');
  }

  Future<void> saveLastUpdateTime(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_campaign_update_time', timestamp);
  }
}
