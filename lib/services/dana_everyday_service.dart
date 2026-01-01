import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';

class DanaEverydayService {
  static const String baseUrl = 'https://www.danaeveryday.id/campaign_category';
  static const String cacheKeyPrefix = 'dana_campaigns_';
  static const Duration cacheDuration = Duration(hours: 6);

  // Category IDs
  static const Map<String, String> categories = {
    'Pembangunan & Renovasi': '8',
    'Pendidikan Buddhist': '9',
    'Sangha Dana': '10',
    'Sosial Kemanusiaan': '13',
    'Ashoka Spirit': '14',
    'Fangshen': '15',
  };

  /// Fetch campaigns dari satu kategori
  // Di lib/services/dana_everyday_service.dart

  Future<List<Campaign>> fetchCampaigns(String categoryId) async {
    try {
      final cached = await _getFromCache(categoryId);
      if (cached != null) return cached.take(8).toList(); // 🔧 Max 8

      final url = '$baseUrl/getCampaignFromCategory?category_id=$categoryId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final campaigns = jsonList
            .map((json) => Campaign.fromJson(json))
            .take(8) // 🔧 Max 8 per kategori
            .toList();

        await _saveToCache(categoryId, campaigns);
        return campaigns;
      } else {
        throw Exception('Failed to load campaigns: ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }

  /// Fetch campaigns dari multiple categories sekaligus
  Future<Map<String, List<Campaign>>> fetchAllCategories() async {
    final Map<String, List<Campaign>> result = {};

    for (final entry in categories.entries) {
      final campaigns = await fetchCampaigns(entry.value);
      if (campaigns.isNotEmpty) {
        result[entry.key] = campaigns;
      }
    }

    return result;
  }

  /// Fetch hanya top campaigns dari setiap kategori (untuk preview)
  /// Fetch top campaigns dari semua kategori untuk "Semua" view
  Future<List<Campaign>> fetchTopCampaigns() async {
    final allCampaigns = <Campaign>[];

    for (final categoryId in categories.values) {
      final campaigns = await fetchCampaigns(categoryId);
      allCampaigns.addAll(campaigns);
    }

    // Sort by percent (progress tertinggi dulu)
    allCampaigns.sort((a, b) => b.percent.compareTo(a.percent));

    return allCampaigns.take(12).toList(); // 🔧 Max 12 cards
  }

  // Cache Management
  Future<List<Campaign>?> _getFromCache(String categoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$cacheKeyPrefix$categoryId';
      final cacheTimeKey = '${cacheKey}_time';

      final cachedData = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt(cacheTimeKey);

      if (cachedData != null && cachedTime != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
        if (age < cacheDuration.inMilliseconds) {
          final List<dynamic> jsonList = json.decode(cachedData);
          return jsonList.map((json) => Campaign.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
    return null;
  }

  Future<void> _saveToCache(String categoryId, List<Campaign> campaigns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$cacheKeyPrefix$categoryId';
      final cacheTimeKey = '${cacheKey}_time';

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

      await prefs.setString(cacheKey, json.encode(jsonList));
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Save to cache error: $e');
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(cacheKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
