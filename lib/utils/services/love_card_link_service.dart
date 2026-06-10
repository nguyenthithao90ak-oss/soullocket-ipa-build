import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/core/constants/app_config.dart';

class LoveCardLinkPayload {
  final String id;
  final String content;
  final String theme;
  final int bgColor;
  final String senderName;
  final String? signature;
  final int timestampMs;
  final String? imageUrl;

  const LoveCardLinkPayload({
    required this.id,
    required this.content,
    required this.theme,
    required this.bgColor,
    required this.senderName,
    this.signature,
    required this.timestampMs,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'content': content,
      'theme': theme,
      'bgColor': bgColor,
      'senderName': senderName,
      'signature': signature,
      'ts': timestampMs,
      'imageUrl': imageUrl,
      'v': 3,
    };
  }

  factory LoveCardLinkPayload.fromMap(Map<dynamic, dynamic> map) {
    return LoveCardLinkPayload(
      id: (map['id'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      theme: (map['theme'] ?? 'love').toString(),
      bgColor: map['bgColor'] is int
          ? map['bgColor'] as int
          : int.tryParse('${map['bgColor']}') ?? 0xFFE94057,
      senderName: (map['senderName'] ?? '').toString(),
      signature: _normalizeOptionalString(map['signature']),
      timestampMs: map['ts'] is int
          ? map['ts'] as int
          : int.tryParse('${map['ts']}') ??
              DateTime.now().millisecondsSinceEpoch,
      imageUrl: _normalizeOptionalString(map['imageUrl']),
    );
  }

  static String? _normalizeOptionalString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class LoveCardLinkService {
  static const String publicShareCollectionPath = 'public_love_card_links';
  static const String viewerPath = '/love-card-open';
  static const Set<String> _supportedPaths = <String>{
    '/love-card',
    '/love-card.html',
    '/love-card-open',
    '/love-card-open.html',
  };

  const LoveCardLinkService();

  String generatePublicCardLinkFromShareId(String shareId) {
    final normalizedShareId = shareId.trim();
    return AppConfig.webUri(
      viewerPath,
      queryParameters: {'id': normalizedShareId},
    ).replace(fragment: 'open').toString();
  }

  String generatePublicCardLink(LoveCardLinkPayload payload) {
    final token = base64Url
        .encode(utf8.encode(jsonEncode(payload.toMap())))
        .replaceAll('=', '');
    return AppConfig.webUri(
      viewerPath,
      queryParameters: {'card': token},
    ).replace(fragment: 'open').toString();
  }

  static bool isSupportedLoveCardUri(Uri uri) {
    if (!AppConfig.isTrustedWebUri(uri)) return false;
    final normalizedPath = _normalizePath(uri.path);
    return _supportedPaths.contains(normalizedPath);
  }

  static LoveCardLinkPayload? payloadFromUri(Uri uri) {
    final token = _tokenFromUri(uri);
    if (token == null || token.isEmpty) return null;

    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(token)));
      final raw = jsonDecode(decoded);
      if (raw is! Map) return null;
      return LoveCardLinkPayload.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<LoveCardLinkPayload?> fetchPayloadByShareId(String shareId) async {
    final normalizedShareId = shareId.trim();
    if (normalizedShareId.isEmpty) {
      return null;
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('$publicShareCollectionPath/$normalizedShareId')
          .get();
      final raw = snapshot.value;
      if (raw is! Map) {
        return null;
      }
      return LoveCardLinkPayload.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static String? shareIdFromUri(Uri uri) {
    final queryShareId = uri.queryParameters['id']?.trim();
    if (queryShareId != null && queryShareId.isNotEmpty) {
      return queryShareId;
    }

    final compactShareId = uri.queryParameters['c']?.trim();
    if (compactShareId != null && compactShareId.isNotEmpty) {
      return compactShareId;
    }

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty || !fragment.contains('=')) {
      return null;
    }

    try {
      final fragmentParams = Uri.splitQueryString(fragment);
      final fragmentShareId = fragmentParams['id']?.trim();
      if (fragmentShareId != null && fragmentShareId.isNotEmpty) {
        return fragmentShareId;
      }

      final compactFragmentShareId = fragmentParams['c']?.trim();
      if (compactFragmentShareId != null && compactFragmentShareId.isNotEmpty) {
        return compactFragmentShareId;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _tokenFromUri(Uri uri) {
    final queryToken = uri.queryParameters['card']?.trim();
    if (queryToken != null && queryToken.isNotEmpty) return queryToken;

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty) return null;

    if (!fragment.contains('=')) {
      return fragment;
    }

    try {
      final fragmentParams = Uri.splitQueryString(fragment);
      final fragmentToken = fragmentParams['card']?.trim();
      if (fragmentToken != null && fragmentToken.isNotEmpty) {
        return fragmentToken;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String _normalizePath(String path) {
    if (path.isEmpty) return '/';
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }
}
