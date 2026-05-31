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
  static const int _maxPayloadLength = 2048;
  static const int _maxIdLength = 256;

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
    final normalizedToken = _sanitizeToken(token);
    return normalizedToken.isEmpty ? loginPrefix : '$loginPrefix$normalizedToken';
  }

  static String encodeHouseId(String houseId) {
    final normalizedHouseId = _sanitize(houseId);
    return normalizedHouseId.isEmpty ? housePrefix : '$housePrefix$normalizedHouseId';
  }

  static QRPayloadKind detectKind(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > _maxPayloadLength) {
      return QRPayloadKind.unknown;
    }

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
    if (value.isEmpty || value.length > _maxPayloadLength) return null;
    if (!value.toUpperCase().startsWith(loginPrefix)) return null;

    final token = _sanitizeToken(value.substring(loginPrefix.length));
    return token.isEmpty ? null : token;
  }

  static String? extractHouseId(String raw) {
    final value = _sanitize(raw);
    if (value.isEmpty || value.length > _maxPayloadLength) return null;
    if (isLoginPayload(value)) return null;

    final kind = detectKind(value);
    if (kind == QRPayloadKind.house) {
      return _normalizedId(value.substring(housePrefix.length));
    }
    if (kind == QRPayloadKind.community) {
      return _normalizedId(value.substring(communityPrefix.length));
    }

    final upper = value.toUpperCase();
    for (final prefix in _legacyHousePrefixes) {
      if (upper.startsWith(prefix)) {
        return _normalizedId(value.substring(prefix.length));
      }
    }

    if (value.startsWith('@')) {
      return _normalizedId(value.substring(1));
    }

    final directUri = _tryParseUri(value);
    final fromUri = _extractFromUri(directUri);
    if (fromUri != null) {
      return fromUri;
    }

    final knownWebHosts = <String>{
      if (AppConfig.webHost.isNotEmpty) AppConfig.webHost,
      'soullockket.web.app',
      'soullocket.com',
    };
    final lowerValue = value.toLowerCase();
    if (knownWebHosts.any(lowerValue.contains)) {
      final hostUri = _tryParseUri(
        value.contains('://') ? value : 'https://$value',
      );
      final fromHostUri = _extractFromUri(hostUri);
      if (fromHostUri != null) {
        return fromHostUri;
      }
    }

    if (directUri != null && directUri.hasScheme) {
      return null;
    }

    final compact = _sanitize(value.replaceAll(RegExp(r'\s+'), ''));
    return _normalizedId(compact);
  }

  static Uri? _tryParseUri(String value) {
    if (value.isEmpty) return null;
    return Uri.tryParse(value);
  }

  static String? _extractFromUri(Uri? uri) {
    if (uri == null) return null;

    for (final key in _houseQueryKeys) {
      final raw = uri.queryParameters[key];
      final candidate = _normalizedId(raw);
      if (candidate != null) {
        return candidate;
      }
    }

    final segments = uri.pathSegments
        .map(_sanitize)
        .where((item) => item.isNotEmpty)
        .toList();
    if (segments.isNotEmpty) {
      return _normalizedId(segments.last);
    }

    return null;
  }

  static String _sanitize(String? value) {
    if (value == null) return '';
    return value
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('/', '')
        .replaceAll('\\', '');
  }

  static String? _normalizedId(String? value) {
    final candidate = _sanitize(value);
    if (candidate.isEmpty || candidate.length > _maxIdLength) return null;
    return candidate;
  }

  static String _sanitizeToken(String? value) {
    if (value == null) return '';
    return value.trim().replaceAll('"', '').replaceAll("'", '').replaceAll('/', '');
  }
}
