class SingleMatchPreferences {
  static const int minAgeFloor = 18;
  static const int maxAgeCeiling = 60;

  final bool enabled;
  final bool allowAudioCalls;
  final bool allowVideoCalls;
  final int preferredAgeMin;
  final int preferredAgeMax;
  final String goal;
  final String voiceStyle;
  final String intro;
  final List<String> tags;
  final int updatedAt;

  const SingleMatchPreferences({
    this.enabled = true,
    this.allowAudioCalls = true,
    this.allowVideoCalls = true,
    this.preferredAgeMin = 20,
    this.preferredAgeMax = 32,
    this.goal = 'meaningful',
    this.voiceStyle = 'warm',
    this.intro = '',
    this.tags = const <String>[],
    this.updatedAt = 0,
  });

  factory SingleMatchPreferences.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const SingleMatchPreferences();
    }

    int readInt(dynamic value, int fallback) {
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    bool readBool(dynamic value, bool fallback) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      return fallback;
    }

    final rawTags = map['tags'];
    final tags = <String>[];
    final seenTags = <String>{};
    final rawTagValues = rawTags is Map
        ? rawTags.values
        : rawTags is Iterable
            ? rawTags
            : const <dynamic>[];
    for (final value in rawTagValues) {
      final normalized = value.toString().trim();
      if (normalized.isEmpty) {
        continue;
      }
      final key = normalized.toLowerCase();
      if (seenTags.add(key)) {
        tags.add(normalized);
      }
      if (tags.length >= 8) {
        break;
      }
    }

    final rawMin = readInt(map['preferredAgeMin'], 20);
    final rawMax = readInt(map['preferredAgeMax'], 32);
    final safeMin = rawMin.clamp(minAgeFloor, maxAgeCeiling);
    final safeMax = rawMax.clamp(safeMin, maxAgeCeiling);

    return SingleMatchPreferences(
      enabled: readBool(map['enabled'], true),
      allowAudioCalls: readBool(map['allowAudioCalls'], true),
      allowVideoCalls: readBool(map['allowVideoCalls'], true),
      preferredAgeMin: safeMin,
      preferredAgeMax: safeMax,
      goal: (map['goal'] ?? 'meaningful').toString().trim(),
      voiceStyle: (map['voiceStyle'] ?? 'warm').toString().trim(),
      intro: (map['intro'] ?? '').toString().trim(),
      tags: tags,
      updatedAt: readInt(map['updatedAt'], 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'allowAudioCalls': allowAudioCalls,
      'allowVideoCalls': allowVideoCalls,
      'preferredAgeMin': preferredAgeMin,
      'preferredAgeMax': preferredAgeMax,
      'goal': goal,
      'voiceStyle': voiceStyle,
      'intro': intro,
      'tags': tags,
      'updatedAt': updatedAt,
    };
  }

  SingleMatchPreferences copyWith({
    bool? enabled,
    bool? allowAudioCalls,
    bool? allowVideoCalls,
    int? preferredAgeMin,
    int? preferredAgeMax,
    String? goal,
    String? voiceStyle,
    String? intro,
    List<String>? tags,
    int? updatedAt,
  }) {
    final nextMin = (preferredAgeMin ?? this.preferredAgeMin)
        .clamp(minAgeFloor, maxAgeCeiling);
    final nextMax =
        (preferredAgeMax ?? this.preferredAgeMax).clamp(nextMin, maxAgeCeiling);

    return SingleMatchPreferences(
      enabled: enabled ?? this.enabled,
      allowAudioCalls: allowAudioCalls ?? this.allowAudioCalls,
      allowVideoCalls: allowVideoCalls ?? this.allowVideoCalls,
      preferredAgeMin: nextMin,
      preferredAgeMax: nextMax,
      goal: goal ?? this.goal,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      intro: intro ?? this.intro,
      tags: tags ?? this.tags,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool sameAs(SingleMatchPreferences other) {
    if (enabled != other.enabled ||
        allowAudioCalls != other.allowAudioCalls ||
        allowVideoCalls != other.allowVideoCalls ||
        preferredAgeMin != other.preferredAgeMin ||
        preferredAgeMax != other.preferredAgeMax ||
        goal != other.goal ||
        voiceStyle != other.voiceStyle ||
        intro != other.intro ||
        tags.length != other.tags.length) {
      return false;
    }

    for (var index = 0; index < tags.length; index++) {
      if (tags[index] != other.tags[index]) {
        return false;
      }
    }
    return true;
  }
}

class SingleMatchCandidate {
  final String houseId;
  final String displayName;
  final String houseName;
  final String avatarUrl;
  final String bio;
  final String intro;
  final String goal;
  final String voiceStyle;
  final List<String> tags;
  final bool allowAudioCalls;
  final bool allowVideoCalls;
  final bool enabled;
  final String privacy;
  final int updatedAt;
  final int? age;

  const SingleMatchCandidate({
    required this.houseId,
    required this.displayName,
    required this.houseName,
    required this.avatarUrl,
    required this.bio,
    required this.intro,
    required this.goal,
    required this.voiceStyle,
    required this.tags,
    required this.allowAudioCalls,
    required this.allowVideoCalls,
    required this.enabled,
    required this.privacy,
    required this.updatedAt,
    required this.age,
  });

  bool get isPublic => privacy == 'public';
}

class SingleMatchHistoryEntry {
  final String id;
  final String action;
  final String peerHouseId;
  final String peerName;
  final String peerAvatarUrl;
  final String note;
  final String goal;
  final int startedAt;
  final int endedAt;
  final int durationSeconds;
  final double compatibilityScore;

  const SingleMatchHistoryEntry({
    required this.id,
    required this.action,
    required this.peerHouseId,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.note,
    required this.goal,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.compatibilityScore,
  });

  factory SingleMatchHistoryEntry.fromMap(
    String id,
    Map<dynamic, dynamic> map,
  ) {
    int readInt(dynamic value) {
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    double readDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value) ?? 0;
      }
      return 0;
    }

    return SingleMatchHistoryEntry(
      id: id,
      action: (map['action'] ?? '').toString().trim(),
      peerHouseId: (map['peerHouseId'] ?? '').toString().trim(),
      peerName: (map['peerName'] ?? '').toString().trim(),
      peerAvatarUrl: (map['peerAvatarUrl'] ?? '').toString().trim(),
      note: (map['note'] ?? '').toString().trim(),
      goal: (map['goal'] ?? '').toString().trim(),
      startedAt: readInt(map['startedAt']),
      endedAt: readInt(map['endedAt']),
      durationSeconds: readInt(map['durationSeconds']),
      compatibilityScore: readDouble(map['compatibilityScore']),
    );
  }

  bool get isCall => action == 'audio_call' || action == 'video_call';
  bool get isSkipped => action == 'skipped';
}
