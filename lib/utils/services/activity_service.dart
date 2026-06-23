import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ActivityService {
  static final ActivityService _instance = ActivityService._internal();
  factory ActivityService() => _instance;
  ActivityService._internal();

  static const String _url = 'https://www.boredapi.com/api/activity';

  Future<Map<String, dynamic>?> fetchActivity() async {
    try {
      final response =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      }
    } catch (e) {
      debugPrint('[ActivityService] Error: $e');
    }
    return null;
  }

  /// Translate activity type to Vietnamese
  static String translateType(String? type) {
    switch (type) {
      case 'education':
        return '📚 Học tập';
      case 'recreational':
        return '🎮 Giải trí';
      case 'social':
        return '👥 Xã hội';
      case 'diy':
        return '🔧 Tự làm';
      case 'charity':
        return '💝 Từ thiện';
      case 'cooking':
        return '🍳 Nấu ăn';
      case 'relaxation':
        return '🧘 Thư giãn';
      case 'music':
        return '🎵 Âm nhạc';
      case 'busywork':
        return '💼 Việc vặt';
      default:
        return type ?? 'Hoạt động';
    }
  }
}
