import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class QuoteService {
  static final QuoteService _instance = QuoteService._internal();
  factory QuoteService() => _instance;
  QuoteService._internal();

  static const String _primaryUrl =
      'https://api.quotable.io/random?tags=love';
  static const String _fallbackUrl =
      'https://quote-garden.onrender.com/api/v3/quotes/random?genre=love';

  Future<Map<String, String>?> fetchQuote() async {
    // Try primary
    try {
      final response =
          await http.get(Uri.parse(_primaryUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content']?.toString().trim() ?? '';
        final author = data['author']?.toString().trim() ?? '';
        if (content.isNotEmpty) {
          return {'content': content, 'author': author};
        }
      }
    } catch (e) {
      debugPrint('[QuoteService] Primary failed: $e');
    }

    // Try fallback
    try {
      final response = await http
          .get(Uri.parse(_fallbackUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final quotes = data['quotes'] as List?;
        if (quotes != null && quotes.isNotEmpty) {
          final q = quotes[0] as Map<String, dynamic>;
          final content = q['quote']?.toString().trim() ?? '';
          final author = q['author']?.toString().trim() ?? '';
          if (content.isNotEmpty) {
            return {'content': content, 'author': author};
          }
        }
      }
    } catch (e) {
      debugPrint('[QuoteService] Fallback failed: $e');
    }

    return null;
  }
}
