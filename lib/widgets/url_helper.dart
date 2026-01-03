import 'package:url_launcher/url_launcher.dart';

class UrlHelper {
  /// Buka URL dengan app native (YouTube/Instagram) jika ada
  static Future<void> launchURL(String url) async {
    String finalUrl = url;
    
    // Deteksi YouTube
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      finalUrl = _convertToYouTubeApp(url);
    }
    // Deteksi Instagram
    else if (url.contains('instagram.com')) {
      finalUrl = _convertToInstagramApp(url);
    }
    
    final Uri uri = Uri.parse(finalUrl);
    
    try {
      // Coba buka dengan app native
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Paksa buka di app external
        );
      } else {
        // Fallback ke browser jika app tidak ada
        final Uri fallbackUri = Uri.parse(url);
        await launchUrl(
          fallbackUri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      // Fallback ke browser jika error
      final Uri fallbackUri = Uri.parse(url);
      await launchUrl(
        fallbackUri,
        mode: LaunchMode.platformDefault,
      );
    }
  }
  
  /// Convert YouTube URL ke app scheme
  static String _convertToYouTubeApp(String url) {
    // Extract video ID atau channel ID
    if (url.contains('youtube.com/@')) {
      // Channel URL: https://www.youtube.com/@channelname
      final channelName = url.split('@').last.split('/').first;
      return 'vnd.youtube://user/$channelName';
    } else if (url.contains('/channel/')) {
      final channelId = url.split('/channel/').last.split('/').first;
      return 'vnd.youtube://channel/$channelId';
    } else if (url.contains('watch?v=')) {
      final videoId = url.split('watch?v=').last.split('&').first;
      return 'vnd.youtube://watch?v=$videoId';
    }
    
    // Fallback: coba buka di app dengan URL biasa
    return url.replaceAll('https://', 'vnd.youtube://').replaceAll('http://', 'vnd.youtube://');
  }
  
  /// Convert Instagram URL ke app scheme
  static String _convertToInstagramApp(String url) {
    // Extract username
    if (url.contains('instagram.com/')) {
      final parts = url.split('instagram.com/').last.split('/');
      if (parts.isNotEmpty) {
        final username = parts.first;
        return 'instagram://user?username=$username';
      }
    }
    
    return url;
  }
}