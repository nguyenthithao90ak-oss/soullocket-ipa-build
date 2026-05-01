import '../core/constants/app_config.dart';

enum QRPayloadKind {
  login,
  house,
  community,
  unknown,
}

class QRPayloadCodec {
  static const String loginPrefix = 'SOULLOCKET:LOGIN:';
  static const String housePrefix = 'SOULLOCKET:HOUSE:';
  static const String communityPrefix = 'SOULLOCKET:COMMUNITY:';

  static const List<String> _legacyHousePrefixes = <String>[
    'HOUSE:',
    'HOUSE_ID:',
  ];

  static const List<String> _houseQueryKeys = <String>[
    'houseId',
    'house_id',
    'id',
    'hid',
    'targetHouseId',
    'target',
  ];

  static String encodeLoginToken(String token) {
    return '$loginPrefix${token.trim()}';
  }

  static String encodeHouseId(String houseId) {
    return '$housePrefix${houseId.trim()}';
  }

  static QRPayloadKind detectKind(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return QRPayloadKind.unknown;

    final upper = value.toUpperCase();
    if (upper.startsWith(loginPrefix)) {
      return QRPayloadKind.login;
    }
    if (upper.startsWith(housePrefix)) {
      return QRPayloadKind.house;
    }
    if (upper.startsWith(communityPrefix)) {
      return QRPayloadKind.community;
    }
    return QRPayloadKind.unknown;
  }

  static bool isLoginPayload(String raw) {
    return extractLoginToken(raw) != null;
  }

  static String? extractLoginToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.toUpperCase().startsWith(loginPrefix)) return null;

    final token = value.substring(loginPrefix.length).trim();
    return token.isEmpty ? null : token;
  }

  static String? extractHouseId(String raw) {
    final value = _sanitize(raw);
    if (value.isEmpty) return null;
    if (isLoginPayload(value)) return null;

    final kind = detectKind(value);
    if (kind == QRPayloadKind.house) {
      return _sanitize(value.substring(housePrefix.length));
    }
    if (kind == QRPayloadKind.community) {
      return _sanitize(value.substring(communityPrefix.length));
    }

    final upper = value.toUpperCase();
    for (final prefix in _legacyHousePrefixes) {
      if (upper.startsWith(prefix)) {
        return _sanitize(value.substring(prefix.length));
      }
    }

    if (value.startsWith('@')) {
      return _sanitize(value.substring(1));
    }

    final directUri = _tryParseUri(value);
    final fromUri = _extractFromUri(directUri);
    if (fromUri != null) {
      return fromUri;
    }

    if (value.contains(AppConfig.webHost) ||
        value.contains('soullockket.web.app') ||
        value.contains('soullocket.com')) {
      final hostUri = _tryParseUri(
        value.contains('://') ? value : 'https://$value',
      );
      final fromHostUri = _extractFromUri(hostUri);
      if (fromHostUri != null) {
        return fromHostUri;
      }
    }

    final compact = _sanitize(value.replaceAll(RegExp(r'\s+'), ''));
    return compact.isEmpty ? null : compact;
  }

  static Uri? _tryParseUri(String value) {
    if (value.isEmpty) return null;
    return Uri.tryParse(value);
  }

  static String? _extractFromUri(Uri? uri) {
    if (uri == null) return null;

    for (final key in _houseQueryKeys) {
      final raw = uri.queryParameters[key];
      final candidate = _sanitize(raw);
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }

    final segments = uri.pathSegments
        .map(_sanitize)
        .where((item) => item.isNotEmpty)
        .toList();
    if (segments.isNotEmpty) {
      return segments.last;
    }

    return null;
  }

  static String _sanitize(String? value) {
    if (value == null) return '';
    return value.trim().replaceAll('"', '').replaceAll("'", '');
  }
}
