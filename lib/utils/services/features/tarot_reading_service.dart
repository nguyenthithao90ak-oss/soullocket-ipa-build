import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/zodiac_utils.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/love_insight_service.dart';

String _t(bool isEnglish, String vi, String en) => isEnglish ? en : vi;

String _safeText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int? _calculateAgeYears(String dob) {
  if (dob.trim().isEmpty) return null;
  try {
    final parsed = DateTime.parse(dob);
    final now = DateTime.now();
    var years = now.year - parsed.year;
    final hasPassedBirthday = now.month > parsed.month ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hasPassedBirthday) years--;
    return years < 0 ? null : years;
  } catch (_) {
    return null;
  }
}

String? _ageLabel(int? ageYears, bool isEnglish) {
  if (ageYears == null) return null;
  return isEnglish ? '$ageYears years' : '$ageYears tuổi';
}

String? _localizedZodiacName(String? raw, bool isEnglish) {
  if (raw == null || raw.isEmpty || !isEnglish) return raw;
  const zodiacMap = {
    'Bạch Dương': 'Aries',
    'Kim Ngưu': 'Taurus',
    'Song Tử': 'Gemini',
    'Cự Giải': 'Cancer',
    'Sư Tử': 'Leo',
    'Xử Nữ': 'Virgo',
    'Thiên Bình': 'Libra',
    'Thiên Yết': 'Scorpio',
    'Nhân Mã': 'Sagittarius',
    'Ma Kết': 'Capricorn',
    'Bảo Bình': 'Aquarius',
    'Song Ngư': 'Pisces',
  };
  return zodiacMap[raw] ?? raw;
}

String? _elementFromZodiac(String? zodiacKey) {
  if (zodiacKey == null || zodiacKey.isEmpty) return null;
  final raw =
      ZodiacUtils.zodiacDetails[zodiacKey]?['element']?.toString() ?? '';
  if (raw.isEmpty) return null;
  return raw.split(' ').first.trim();
}

class _MaturityLens {
  final String label;
  final String summary;

  const _MaturityLens({required this.label, required this.summary});
}

_MaturityLens _resolveMaturityLens(int? ageYears, bool isEnglish) {
  if (ageYears == null) {
    return _MaturityLens(
      label: _t(isEnglish, 'nhịp tự nhận thức', 'self-awareness lens'),
      summary: _t(
        isEnglish,
        'Tarot đang đọc lớp cảm xúc hiện tại nhiều hơn là tuổi thật, nên phần bản năng và nhu cầu an toàn được nhấn mạnh.',
        'Tarot is reading the current emotional layer more than age itself, so instinct and the need for safety are emphasized.',
      ),
    );
  }
  if (ageYears <= 20) {
    return _MaturityLens(
      label: _t(
          isEnglish, 'tuổi gọi tên rung động', 'the phase of naming feelings'),
      summary: _t(
        isEnglish,
        'Ở tuổi này, trái tim dễ rung động nhanh nhưng cũng đang học cách phân biệt cảm xúc thật với sự chú ý thoáng qua.',
        'At this age, the heart responds quickly, but it is also learning to separate true feeling from passing attention.',
      ),
    );
  }
  if (ageYears <= 26) {
    return _MaturityLens(
      label: _t(isEnglish, 'tuổi khám phá bản thân khi yêu',
          'the phase of discovering yourself in love'),
      summary: _t(
        isEnglish,
        'Giai đoạn này thường vừa muốn yêu sâu vừa muốn giữ bản sắc riêng, nên kết nối mập mờ rất dễ làm bạn mệt.',
        'This stage often wants deep love while protecting personal identity, so vague connections can become exhausting fast.',
      ),
    );
  }
  if (ageYears <= 33) {
    return _MaturityLens(
      label: _t(isEnglish, 'tuổi cân bằng cảm xúc và tiêu chuẩn',
          'the phase of balancing feeling and standards'),
      summary: _t(
        isEnglish,
        'Ở tuổi này, trái tim không chỉ cần rung động mà còn cần độ rõ ràng, sự nhất quán và cảm giác được chọn thật.',
        'At this age, the heart no longer wants chemistry alone; it also wants clarity, consistency, and the sense of being genuinely chosen.',
      ),
    );
  }
  if (ageYears <= 40) {
    return _MaturityLens(
      label: _t(isEnglish, 'tuổi ưu tiên sự bền vững',
          'the phase of choosing durability'),
      summary: _t(
        isEnglish,
        'Giai đoạn này thường nhìn tình cảm qua giá trị dài hạn: ai giữ lời, ai ổn định và ai đủ chín để cùng đi lâu.',
        'This stage often reads love through long-term value: who follows through, who is stable, and who is mature enough to go far with you.',
      ),
    );
  }
  return _MaturityLens(
    label: _t(isEnglish, 'tuổi chọn chiều sâu', 'the phase of choosing depth'),
    summary: _t(
      isEnglish,
      'Trái tim ở giai đoạn này thường không còn hứng thú với cảm xúc ồn ào; nó chọn sự sâu, thật và an tâm.',
      'At this stage, the heart is usually no longer interested in noisy intensity; it chooses depth, truth, and peace.',
    ),
  );
}

String _compatibilityTitle(int score, bool isEnglish) {
  if (!isEnglish) return '';
  if (score >= 92) return 'Soul-level chemistry';
  if (score >= 84) return 'Natural harmony';
  if (score >= 72) return 'Promising chemistry';
  if (score >= 60) return 'Attraction with lessons';
  return 'Requires conscious effort';
}

String _compatibilityDescription({
  required int score,
  required bool isEnglish,
  required String? viewerElement,
  required String? partnerElement,
}) {
  if (!isEnglish) return '';
  final pair = '${viewerElement ?? ''}-${partnerElement ?? ''}';
  if (pair == 'Lửa-Khí' || pair == 'Khí-Lửa') {
    return 'This pair can keep each other inspired and alive, but it still needs emotional grounding to avoid burning too fast.';
  }
  if (pair == 'Đất-Nước' || pair == 'Nước-Đất') {
    return 'This pairing tends to nourish trust and emotional safety, making it easier to build something stable and lasting.';
  }
  if (score >= 84) {
    return 'Your temperaments tend to move well together, which makes understanding easier when both sides stay honest.';
  }
  if (score >= 68) {
    return "There is attraction here, but the bond grows best when both sides learn each other's emotional language instead of assuming.";
  }
  return 'This bond can still work, but it asks for patience, honesty, and more conscious adjustment from both sides.';
}

class TarotSpreadSlot {
  final String id;
  final String labelKey;

  const TarotSpreadSlot({required this.id, required this.labelKey});
}

class TarotSpreadTemplate {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final String badgeKey;
  final List<TarotSpreadSlot> slots;

  const TarotSpreadTemplate({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.badgeKey,
    required this.slots,
  });
}

class TarotReadingSelection {
  final String slotId;
  final String label;
  final String cardName;
  final bool isReversed;
  final String baseMeaning;

  const TarotReadingSelection({
    required this.slotId,
    required this.label,
    required this.cardName,
    required this.isReversed,
    required this.baseMeaning,
  });
}

class TarotReadingMetric {
  final String label;
  final String value;

  const TarotReadingMetric({required this.label, required this.value});
}

class TarotReadingFacet {
  final String title;
  final String accent;
  final String body;

  const TarotReadingFacet({
    required this.title,
    required this.accent,
    required this.body,
  });
}

class TarotCardReading {
  final String slotId;
  final String label;
  final String headline;
  final String interpretation;

  const TarotCardReading({
    required this.slotId,
    required this.label,
    required this.headline,
    required this.interpretation,
  });
}

class TarotPersonalizedReading {
  final String headline;
  final String profileTag;
  final String profileSummary;
  final String spreadSummary;
  final String energySummary;
  final String advice;
  final List<TarotReadingMetric> metrics;
  final List<TarotReadingFacet> facets;
  final List<TarotCardReading> cards;

  const TarotPersonalizedReading({
    required this.headline,
    required this.profileTag,
    required this.profileSummary,
    required this.spreadSummary,
    required this.energySummary,
    required this.advice,
    required this.metrics,
    required this.facets,
    required this.cards,
  });

  TarotCardReading? cardFor(String slotId) {
    for (final card in cards) {
      if (card.slotId == slotId) return card;
    }
    return null;
  }

  String interpretationFor(String slotId, String fallback) {
    return cardFor(slotId)?.interpretation ?? fallback;
  }
}

class TarotViewerProfile {
  final String localeCode;
  final String relationshipMode;
  final String viewerRole;
  final String viewerName;
  final String partnerName;
  final String viewerDob;
  final String partnerDob;
  final int? viewerAgeYears;
  final int? partnerAgeYears;
  final String? viewerAgeLabel;
  final String? partnerAgeLabel;
  final String? viewerZodiacKey;
  final String? viewerZodiacLabel;
  final String? viewerZodiacEmoji;
  final String? partnerZodiacKey;
  final String? partnerZodiacLabel;
  final String? partnerZodiacEmoji;
  final String? viewerElement;
  final String? partnerElement;
  final int? compatibilityScore;
  final String? compatibilityTitle;
  final String? compatibilityDescription;
  final String maturityLabel;
  final String maturitySummary;

  const TarotViewerProfile({
    required this.localeCode,
    required this.relationshipMode,
    required this.viewerRole,
    required this.viewerName,
    required this.partnerName,
    required this.viewerDob,
    required this.partnerDob,
    required this.viewerAgeYears,
    required this.partnerAgeYears,
    required this.viewerAgeLabel,
    required this.partnerAgeLabel,
    required this.viewerZodiacKey,
    required this.viewerZodiacLabel,
    required this.viewerZodiacEmoji,
    required this.partnerZodiacKey,
    required this.partnerZodiacLabel,
    required this.partnerZodiacEmoji,
    required this.viewerElement,
    required this.partnerElement,
    required this.compatibilityScore,
    required this.compatibilityTitle,
    required this.compatibilityDescription,
    required this.maturityLabel,
    required this.maturitySummary,
  });

  bool get isEnglish => localeCode.startsWith('en');
  bool get isSingle => relationshipMode == 'single';
  bool get hasViewerAge => viewerAgeYears != null;
  bool get hasViewerZodiac =>
      viewerZodiacLabel != null && viewerZodiacLabel!.trim().isNotEmpty;
  bool get hasCompatibility => compatibilityScore != null;

  factory TarotViewerProfile.fromSettings({
    required String viewerRole,
    required String relationshipMode,
    required String localeCode,
    required Map<String, dynamic> settings,
    required String fallbackName,
  }) {
    final isEnglish = localeCode.startsWith('en');
    final isSingle = relationshipMode == 'single';
    final nameU1 =
        _safeText(settings['nameU1'], fallback: isEnglish ? 'You' : 'Bạn');
    final nameU2 = _safeText(
      settings['nameU2'],
      fallback: isSingle
          ? (isEnglish ? 'Future partner' : 'Người thương tương lai')
          : (isEnglish ? 'Your partner' : 'Người ấy'),
    );
    final dobU1 = _safeText(settings['dobU1']);
    final dobU2 = _safeText(settings['dobU2']);
    final viewerName = viewerRole == 'user2'
        ? (nameU2.isEmpty ? fallbackName : nameU2)
        : (nameU1.isEmpty ? fallbackName : nameU1);
    final partnerName = viewerRole == 'user2' ? nameU1 : nameU2;
    final viewerDob = viewerRole == 'user2' ? dobU2 : dobU1;
    final partnerDob = viewerRole == 'user2' ? dobU1 : dobU2;
    final viewerAgeYears = _calculateAgeYears(viewerDob);
    final partnerAgeYears = _calculateAgeYears(partnerDob);
    final viewerInfo = ZodiacUtils.getZodiac(viewerDob);
    final partnerInfo = ZodiacUtils.getZodiac(partnerDob);
    final viewerZodiacKey = viewerInfo?['name'];
    final partnerZodiacKey = partnerInfo?['name'];
    final viewerElement = _elementFromZodiac(viewerZodiacKey);
    final partnerElement = _elementFromZodiac(partnerZodiacKey);
    final maturityLens = _resolveMaturityLens(viewerAgeYears, isEnglish);
    int? compatibilityScore;
    String? compatibilityTitle;
    String? compatibilityDescription;
    if (!isSingle &&
        viewerZodiacKey != null &&
        viewerZodiacKey.isNotEmpty &&
        partnerZodiacKey != null &&
        partnerZodiacKey.isNotEmpty) {
      final rawCompatibility =
          ZodiacUtils.getCompatibility(viewerZodiacKey, partnerZodiacKey);
      compatibilityScore =
          int.tryParse('${rawCompatibility['score'] ?? ''}') ?? 0;
      if (isEnglish) {
        compatibilityTitle = _compatibilityTitle(compatibilityScore, true);
        compatibilityDescription = _compatibilityDescription(
          score: compatibilityScore,
          isEnglish: true,
          viewerElement: viewerElement,
          partnerElement: partnerElement,
        );
      } else {
        compatibilityTitle = rawCompatibility['title']?.toString();
        compatibilityDescription = rawCompatibility['desc']?.toString();
      }
    }

    return TarotViewerProfile(
      localeCode: localeCode,
      relationshipMode: relationshipMode,
      viewerRole: viewerRole,
      viewerName: viewerName,
      partnerName: partnerName,
      viewerDob: viewerDob,
      partnerDob: partnerDob,
      viewerAgeYears: viewerAgeYears,
      partnerAgeYears: partnerAgeYears,
      viewerAgeLabel: _ageLabel(viewerAgeYears, isEnglish),
      partnerAgeLabel: _ageLabel(partnerAgeYears, isEnglish),
      viewerZodiacKey: viewerZodiacKey,
      viewerZodiacLabel: _localizedZodiacName(viewerZodiacKey, isEnglish),
      viewerZodiacEmoji: viewerInfo?['emoji'],
      partnerZodiacKey: partnerZodiacKey,
      partnerZodiacLabel: _localizedZodiacName(partnerZodiacKey, isEnglish),
      partnerZodiacEmoji: partnerInfo?['emoji'],
      viewerElement: viewerElement,
      partnerElement: partnerElement,
      compatibilityScore: compatibilityScore,
      compatibilityTitle: compatibilityTitle,
      compatibilityDescription: compatibilityDescription,
      maturityLabel: maturityLens.label,
      maturitySummary: maturityLens.summary,
    );
  }
}

class _TarotMessageSignals {
  final int messageCount;
  final int averageLength;
  final int emojiCount;
  final int exclamationCount;
  final int questionCount;
  final int affectionScore;
  final int positiveScore;

  const _TarotMessageSignals({
    required this.messageCount,
    required this.averageLength,
    required this.emojiCount,
    required this.exclamationCount,
    required this.questionCount,
    required this.affectionScore,
    required this.positiveScore,
  });
}

class TarotReadingService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LoveInsightService _loveInsightService = LoveInsightService();

  String _pickOracleLine(
    bool isEnglish,
    int seed, {
    required List<String> vi,
    required List<String> en,
  }) {
    final items = isEnglish ? en : vi;
    if (items.isEmpty) return '';
    return items[seed.abs() % items.length];
  }

  static const List<TarotSpreadTemplate> spreads = [
    TarotSpreadTemplate(
      id: 'pulse',
      titleKey: 'tarot_spread_pulse_title',
      subtitleKey: 'tarot_spread_pulse_desc',
      badgeKey: 'tarot_spread_badge_pulse',
      slots: [
        TarotSpreadSlot(
            id: 'current_pulse', labelKey: 'tarot_slot_current_pulse'),
        TarotSpreadSlot(id: 'hidden_tide', labelKey: 'tarot_slot_hidden_tide'),
        TarotSpreadSlot(id: 'heart_path', labelKey: 'tarot_slot_heart_path'),
      ],
    ),
    TarotSpreadTemplate(
      id: 'mirror',
      titleKey: 'tarot_spread_mirror_title',
      subtitleKey: 'tarot_spread_mirror_desc',
      badgeKey: 'tarot_spread_badge_mirror',
      slots: [
        TarotSpreadSlot(id: 'self_state', labelKey: 'tarot_slot_self_state'),
        TarotSpreadSlot(
            id: 'partner_state', labelKey: 'tarot_slot_partner_state'),
        TarotSpreadSlot(id: 'friction', labelKey: 'tarot_slot_friction'),
        TarotSpreadSlot(id: 'bridge', labelKey: 'tarot_slot_bridge'),
      ],
    ),
    TarotSpreadTemplate(
      id: 'map',
      titleKey: 'tarot_spread_map_title',
      subtitleKey: 'tarot_spread_map_desc',
      badgeKey: 'tarot_spread_badge_map',
      slots: [
        TarotSpreadSlot(id: 'root', labelKey: 'tarot_slot_root'),
        TarotSpreadSlot(id: 'need', labelKey: 'tarot_slot_need'),
        TarotSpreadSlot(id: 'expression', labelKey: 'tarot_slot_expression'),
        TarotSpreadSlot(id: 'block', labelKey: 'tarot_slot_block'),
        TarotSpreadSlot(id: 'next_7', labelKey: 'tarot_slot_next_7'),
      ],
    ),
    TarotSpreadTemplate(
      id: 'next',
      titleKey: 'tarot_spread_next_title',
      subtitleKey: 'tarot_spread_next_desc',
      badgeKey: 'tarot_spread_badge_next',
      slots: [
        TarotSpreadSlot(id: 'release', labelKey: 'tarot_slot_release'),
        TarotSpreadSlot(id: 'invite', labelKey: 'tarot_slot_invite'),
        TarotSpreadSlot(id: 'timing', labelKey: 'tarot_slot_timing'),
        TarotSpreadSlot(id: 'sign', labelKey: 'tarot_slot_sign'),
      ],
    ),
  ];

  static const List<String> _affectionKeywords = [
    'yêu',
    'thương',
    'nhớ',
    'iu',
    'cưng',
    'ôm',
    'hôn',
    'bé',
    'anh',
    'em',
  ];

  static const List<String> _positiveKeywords = [
    'vui',
    'hạnh phúc',
    'ổn',
    'tốt',
    'dễ thương',
    'haha',
    'hihi',
    'hehe',
    'cười',
    'ấm áp',
  ];

  static final RegExp _emojiRegex = RegExp(
    r'[❤️💖💕💞💝🥰😍😘😊😄😁🤩✨😂🤣😚😻🥹🤍💙💚💛💜]',
    unicode: true,
  );

  Future<TarotPersonalizedReading> buildReading({
    required String houseId,
    required TarotViewerProfile viewerProfile,
    required TarotSpreadTemplate spread,
    required List<TarotReadingSelection> selections,
  }) async {
    final normalizedHouseId = houseId.trim();
    final insights = await _loveInsightService.computeInsights(
        normalizedHouseId, viewerProfile.relationshipMode);
    final messages = await _loadRecentMessages(normalizedHouseId);
    final signals = _buildSignals(messages);
    return _buildFallbackReading(
      viewerProfile: viewerProfile,
      spread: spread,
      insights: insights,
      signals: signals,
      selections: selections,
    );
  }

  Future<List<String>> _loadRecentMessages(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return const [];
    try {
      final snap = await _dbRef
          .child('houses/$normalizedHouseId/chat_room/messages')
          .orderByChild('ts')
          .limitToLast(50)
          .get();
      if (!snap.exists || snap.value == null) return const [];
      final raw = Map<dynamic, dynamic>.from(snap.value as Map);
      final items = raw.values
          .whereType<Map>()
          .map((value) => Map<dynamic, dynamic>.from(value))
          .where((item) => (item['type'] ?? 'text').toString() == 'text')
          .map((item) => (item['text'] ?? item['content'] ?? '').toString())
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      return items.reversed.take(16).toList().reversed.toList();
    } catch (e) {
      debugPrint('[TarotReading] load messages error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể tải tin nhắn gần đây cho tarot.',
      ).message}');
      return const [];
    }
  }

  _TarotMessageSignals _buildSignals(List<String> messages) {
    if (messages.isEmpty) {
      return const _TarotMessageSignals(
        messageCount: 0,
        averageLength: 0,
        emojiCount: 0,
        exclamationCount: 0,
        questionCount: 0,
        affectionScore: 0,
        positiveScore: 0,
      );
    }

    var totalLength = 0;
    var emojiCount = 0;
    var exclamationCount = 0;
    var questionCount = 0;
    var affectionScore = 0;
    var positiveScore = 0;
    for (final message in messages) {
      totalLength += message.length;
      emojiCount += _emojiRegex.allMatches(message).length;
      exclamationCount += '!'.allMatches(message).length;
      questionCount += '?'.allMatches(message).length;
      final normalized = message.toLowerCase();
      for (final keyword in _affectionKeywords) {
        if (normalized.contains(keyword)) affectionScore++;
      }
      for (final keyword in _positiveKeywords) {
        if (normalized.contains(keyword)) positiveScore++;
      }
    }

    return _TarotMessageSignals(
      messageCount: messages.length,
      averageLength: totalLength ~/ messages.length,
      emojiCount: emojiCount,
      exclamationCount: exclamationCount,
      questionCount: questionCount,
      affectionScore: affectionScore,
      positiveScore: positiveScore,
    );
  }

  TarotPersonalizedReading _buildFallbackReading({
    required TarotViewerProfile viewerProfile,
    required TarotSpreadTemplate spread,
    required LoveInsightData insights,
    required _TarotMessageSignals signals,
    required List<TarotReadingSelection> selections,
  }) {
    final isEnglish = viewerProfile.isEnglish;
    final viewerLoveScore =
        viewerProfile.viewerRole == 'user2' ? insights.loveU2 : insights.loveU1;
    final partnerLoveScore = viewerProfile.isSingle
        ? 0
        : (viewerProfile.viewerRole == 'user2'
            ? insights.loveU1
            : insights.loveU2);
    final warmthIndex = _warmthIndex(insights, signals);
    final dominantEnergy = _dominantEnergyKey(selections);
    final profileTag = _profileTag(
      isEnglish: isEnglish,
      dominantEnergy: dominantEnergy,
      interactionRate: insights.interactionRate,
      affectionScore: signals.affectionScore,
      viewerElement: viewerProfile.viewerElement,
    );

    final metrics = <TarotReadingMetric>[
      if (viewerProfile.viewerAgeLabel != null)
        TarotReadingMetric(
          label: _t(isEnglish, 'Độ tuổi', 'Age'),
          value: viewerProfile.viewerAgeLabel!,
        ),
      if (viewerProfile.hasViewerZodiac)
        TarotReadingMetric(
          label: _t(isEnglish, 'Cung mệnh', 'Zodiac'),
          value:
              '${viewerProfile.viewerZodiacEmoji ?? ''} ${viewerProfile.viewerZodiacLabel!}'
                  .trim(),
        ),
      TarotReadingMetric(
        label: _t(isEnglish, 'Nhiệt cảm xúc', 'Emotional heat'),
        value: _warmthText(isEnglish, warmthIndex),
      ),
      TarotReadingMetric(
        label: _t(isEnglish, 'Nhịp kết nối', 'Connection rhythm'),
        value: _interactionText(isEnglish, insights.interactionRate),
      ),
      if (viewerProfile.hasCompatibility)
        TarotReadingMetric(
          label: _t(isEnglish, 'Độ hợp', 'Compatibility'),
          value: '${viewerProfile.compatibilityScore}%',
        ),
    ];

    final facets = <TarotReadingFacet>[
      TarotReadingFacet(
        title: _t(isEnglish, 'Lăng kính cảm xúc', 'Emotional lens'),
        accent: _t(isEnglish, 'Nội tâm', 'Inner tide'),
        body: _facetEmotion(
          viewerProfile,
          insights,
          signals,
          dominantEnergy,
          warmthIndex,
        ),
      ),
      TarotReadingFacet(
        title: _t(isEnglish, 'Lăng kính giao tiếp', 'Communication lens'),
        accent: _t(isEnglish, 'Lời nói', 'Words'),
        body: _facetCommunication(viewerProfile, insights, signals),
      ),
      TarotReadingFacet(
        title: _t(isEnglish, 'Nhu cầu sâu bên trong', 'Attachment lens'),
        accent: _t(isEnglish, 'Nhu cầu', 'Needs'),
        body: _facetAttachment(
          viewerProfile,
          viewerLoveScore,
          partnerLoveScore,
        ),
      ),
      TarotReadingFacet(
        title: _t(isEnglish, 'Nhịp thời điểm', 'Timing lens'),
        accent: _t(isEnglish, 'Thời điểm', 'Timing'),
        body: _facetTiming(viewerProfile, insights, signals),
      ),
      TarotReadingFacet(
        title: _t(isEnglish, 'Độ hợp cung và khí chất',
            'Compatibility and chemistry'),
        accent: _t(isEnglish, 'Hợp mệnh', 'Chemistry'),
        body: _facetCompatibility(viewerProfile),
      ),
    ];

    final cards = selections
        .map(
          (selection) => TarotCardReading(
            slotId: selection.slotId,
            label: selection.label,
            headline: _cardHeadline(
              selection.slotId,
              isEnglish,
              viewerProfile.isSingle,
            ),
            interpretation: _slotInterpretation(
              selection,
              viewerProfile,
              insights,
              signals,
              dominantEnergy,
            ),
          ),
        )
        .toList();

    return TarotPersonalizedReading(
      headline: _headline(
        viewerProfile,
        insights,
        signals,
        dominantEnergy,
      ),
      profileTag: profileTag,
      profileSummary: _profileSummary(
        viewerProfile,
        signals,
        viewerLoveScore,
        profileTag,
      ),
      spreadSummary: _spreadSummary(viewerProfile, spread.id),
      energySummary: _energySummary(
        viewerProfile,
        insights,
        signals,
        warmthIndex,
        viewerLoveScore,
        partnerLoveScore,
      ),
      advice: _advice(
        viewerProfile,
        insights,
        signals,
        viewerLoveScore,
        partnerLoveScore,
      ),
      metrics: metrics,
      facets: facets,
      cards: cards,
    );
  }

  int _warmthIndex(LoveInsightData insights, _TarotMessageSignals signals) {
    final composite = insights.positivity +
        (signals.affectionScore * 7) +
        (signals.positiveScore * 4) +
        (min(signals.emojiCount, 6) * 2);
    if (composite >= 108) return 3;
    if (composite >= 86) return 2;
    if (composite >= 64) return 1;
    return 0;
  }

  String _warmthText(bool isEnglish, int index) {
    switch (index) {
      case 3:
        return _t(isEnglish, 'Rất ấm và mở', 'Very warm and open');
      case 2:
        return _t(isEnglish, 'Ấm và có tín hiệu', 'Warm with visible signals');
      case 1:
        return _t(isEnglish, 'Lúc gần lúc xa', 'Mixed and shifting');
      default:
        return _t(isEnglish, 'Đang dè chừng', 'Guarded');
    }
  }

  String _interactionText(bool isEnglish, double rate) {
    if (rate >= 1.2) {
      return _t(isEnglish, 'Đều và chủ động', 'Steady and active');
    }
    if (rate >= 0.7) return _t(isEnglish, 'Có kết nối', 'Connected');
    if (rate >= 0.45) {
      return _t(isEnglish, 'Mỏng nhưng chưa lạnh', 'Thin but not cold');
    }
    return _t(isEnglish, 'Chậm và thiếu nhịp', 'Slow and uneven');
  }

  String _attachmentNeed(String? element, bool isEnglish) {
    switch (element) {
      case 'Lửa':
        return _t(isEnglish, 'được nhìn thấy và trân trọng',
            'being seen and appreciated');
      case 'Nước':
        return _t(
          isEnglish,
          'an toàn cảm xúc và sự dịu dàng có thật',
          'emotional safety and real tenderness',
        );
      case 'Khí':
        return _t(
          isEnglish,
          'đối thoại thông minh và không gian thở',
          'intelligent dialogue and breathing room',
        );
      case 'Đất':
        return _t(isEnglish, 'sự ổn định và hành động đều',
            'stability and consistent action');
      default:
        return _t(isEnglish, 'cảm giác được hiểu thật',
            'the feeling of being truly understood');
    }
  }

  String _dominantEnergyKey(List<TarotReadingSelection> selections) {
    var warm = 0;
    var reflective = 0;
    var steady = 0;
    var transformative = 0;
    var intense = 0;
    for (final selection in selections) {
      final name = selection.cardName;
      if ({
        'The Lovers',
        'The Sun',
        'The Star',
        'The Empress',
        'Ace of Cups',
        'Two of Cups',
        'Ten of Cups',
        'Queen of Cups',
      }.contains(name)) {
        warm++;
      } else if ({
        'The High Priestess',
        'The Hermit',
        'The Moon',
        'The Hanged Man',
        'Page of Cups',
        'Four of Swords',
      }.contains(name)) {
        reflective++;
      } else if ({
        'Temperance',
        'Justice',
        'The Emperor',
        'The Hierophant',
        'King of Pentacles',
        'Knight of Pentacles',
      }.contains(name)) {
        steady++;
      } else if ({
        'Death',
        'Judgement',
        'Wheel of Fortune',
        'The World',
        'Six of Swords',
        'Eight of Cups',
      }.contains(name)) {
        transformative++;
      } else {
        intense++;
      }
    }
    final scores = {
      'warm': warm,
      'reflective': reflective,
      'steady': steady,
      'transformative': transformative,
      'intense': intense,
    };
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _profileTag({
    required bool isEnglish,
    required String dominantEnergy,
    required double interactionRate,
    required int affectionScore,
    required String? viewerElement,
  }) {
    if (dominantEnergy == 'reflective') {
      return _t(isEnglish, 'người yêu bằng chiều sâu', 'a depth-led heart');
    }
    if (dominantEnergy == 'transformative' || dominantEnergy == 'intense') {
      return _t(
        isEnglish,
        'trái tim mạnh nhưng cần ranh giới',
        'a strong heart that still needs boundaries',
      );
    }
    if (interactionRate < 0.45) {
      return _t(isEnglish, 'người đang đợi tín hiệu chắc chắn',
          'a heart waiting for certainty');
    }
    if (affectionScore >= 3 || viewerElement == 'Nước') {
      return _t(
        isEnglish,
        'người mang năng lượng dịu và mở',
        'a soft and open emotional energy',
      );
    }
    return _t(
      isEnglish,
      'người giữ nhịp cảm xúc khá cân bằng',
      'a fairly balanced emotional rhythm',
    );
  }

  String _headline(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
    String dominantEnergy,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    if (viewerProfile.hasCompatibility &&
        (viewerProfile.compatibilityScore ?? 0) >= 88 &&
        insights.positivity >= 70) {
      return _t(
        isEnglish,
        'Trải bài nghiêng về một kết nối có độ hợp cao: tình cảm vẫn có nền tốt, chỉ cần đi đúng nhịp để chạm sâu hơn.',
        'This spread leans toward a highly compatible bond: the emotional foundation is there, it simply needs the right rhythm to deepen.',
      );
    }
    if (insights.interactionRate < 0.45) {
      return _t(
        isEnglish,
        'Điểm nghẽn hiện tại không nằm ở việc hết thương, mà ở nhịp kết nối đang chậm hơn cảm xúc thật.',
        'The present blockage does not look like a lack of feeling, but a connection rhythm that is lagging behind the true emotion.',
      );
    }
    if (dominantEnergy == 'transformative' || dominantEnergy == 'intense') {
      return _t(
        isEnglish,
        'Tarot cho thấy bạn đang ở giai đoạn thay da cảm xúc: thứ không đủ thật sẽ khó đứng vững trước trái tim hiện tại của bạn.',
        'Tarot points to an emotional shedding phase: what is not real enough will struggle to stand in front of your current heart.',
      );
    }
    if (signals.affectionScore >= 4 || insights.positivity >= 76) {
      return _t(
        isEnglish,
        'Trải bài khá sáng: cảm xúc đang mở, nhưng nó cần một cách bày tỏ chín hơn để được đáp lại đúng mức.',
        'The spread is fairly bright: feelings are opening up, but they need a more mature expression to be fully received.',
      );
    }
    return _t(
      isEnglish,
      'Tarot cho thấy trái tim của bạn không hời hợt. Điều nó cần lúc này là rõ ràng, đều nhịp, và cảm giác được hiểu thật.',
      'Tarot shows your heart is not shallow. What it needs now is clarity, steadiness, and the feeling of being truly understood.',
    );
  }

  String _profileSummary(
    TarotViewerProfile viewerProfile,
    _TarotMessageSignals signals,
    int viewerLoveScore,
    String profileTag,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final zodiacText = viewerProfile.hasViewerZodiac
        ? _t(
            isEnglish,
            'Mang khí chất ${viewerProfile.viewerZodiacLabel}, bạn thường yêu theo cách rất riêng và khó bị cuốn bởi thứ nửa vời.',
            'With the tone of ${viewerProfile.viewerZodiacLabel}, you tend to love in your own way and are rarely moved by anything half-real.',
          )
        : _t(
            isEnglish,
            'Bạn không còn hợp với kiểu cảm xúc nửa vời hoặc mập mờ kéo dài.',
            'You are not aligned with half-hearted feelings or prolonged ambiguity.',
          );
    final signalText = signals.messageCount == 0
        ? _t(
            isEnglish,
            'Tarot đang đọc nhiều hơn từ nhịp hoạt động và các lá bài, nên phần vô thức được nhấn mạnh khá rõ.',
            'Tarot is reading more from activity rhythm and the cards themselves, so the unconscious layer stands out strongly here.',
          )
        : _t(
            isEnglish,
            'Nhịp tin nhắn gần đây cho thấy cảm xúc của bạn ${signals.averageLength >= 28 ? 'có chiều sâu và chịu khó quan sát' : 'không phô ra hết, nhưng vẫn có độ thật rõ rệt'}.',
            'Recent messages suggest your feelings ${signals.averageLength >= 28 ? 'carry depth and careful observation' : 'do not show everything, yet still feel very real'}.',
          );
    return _t(
      isEnglish,
      '${viewerProfile.viewerName} hiện mang màu của $profileTag. ${viewerProfile.maturitySummary} $zodiacText Điểm mở lòng của bạn đang ở khoảng $viewerLoveScore/100. $signalText',
      '${viewerProfile.viewerName} currently carries the energy of $profileTag. ${viewerProfile.maturitySummary} $zodiacText Your openness is around $viewerLoveScore/100. $signalText',
    );
  }

  String _spreadSummary(TarotViewerProfile viewerProfile, String spreadId) {
    final isEnglish = viewerProfile.isEnglish;
    switch (spreadId) {
      case 'pulse':
        return _t(
          isEnglish,
          'Nhịp cảm xúc soi điều đang nổi lên, phần bạn đang giấu, và cánh cửa mở tim gần nhất.',
          'Emotional Pulse reads what is rising, what is being hidden, and the nearest doorway for the heart to open.',
        );
      case 'mirror':
        return _t(
          isEnglish,
          'Gương cảm xúc cho thấy hai phía đang mang gì, điểm va chạm nằm ở đâu, và chiếc cầu chữa lành nên bắt đầu từ đâu.',
          'Emotional Mirror shows what both sides are carrying, where the friction lives, and where healing should begin.',
        );
      case 'map':
        return _t(
          isEnglish,
          'Bản đồ mối quan hệ đào sâu từ gốc cảm xúc, nhu cầu thật, cách yêu, rào cản hiện tại đến hướng đi 7 ngày tới.',
          'Relationship Map goes deep from emotional roots and true needs to love language, present blocks, and the direction of the next 7 days.',
        );
      default:
        return _t(
          isEnglish,
          'Chương kế tiếp tập trung vào điều cần buông, điều cần mời vào, nhịp thời điểm và dấu hiệu sẽ xuất hiện.',
          'Next Chapter focuses on what to release, what to invite in, the timing, and the sign that is about to show up.',
        );
    }
  }

  String _energySummary(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
    int warmthIndex,
    int viewerLoveScore,
    int partnerLoveScore,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final warmth = _warmthText(isEnglish, warmthIndex).toLowerCase();
    final rhythm =
        _interactionText(isEnglish, insights.interactionRate).toLowerCase();
    if (viewerProfile.isSingle) {
      return _t(
        isEnglish,
        'Trường cảm xúc hiện tại nghiêng về $warmth, còn nhịp kết nối bên ngoài thì $rhythm. Tarot cho thấy bạn đang học cách phân biệt rung động thật với cảm xúc nhất thời.',
        'The current emotional field leans $warmth, while outer connection rhythm feels $rhythm. Tarot suggests you are learning to distinguish real feeling from passing chemistry.',
      );
    }
    final balanceLine = viewerLoveScore > partnerLoveScore + 8
        ? _t(isEnglish, 'Bạn đang mở lòng mạnh hơn đối phương một nhịp.',
            'You are opening your heart one beat ahead of the other person.')
        : partnerLoveScore > viewerLoveScore + 8
            ? _t(
                isEnglish,
                'Đối phương dường như đang để nhiều tình cảm ra ngoài hơn bạn.',
                'The other person seems to be putting more feeling on the surface than you are.')
            : _t(
                isEnglish,
                'Hai phía đang mở lòng khá cân nhau, chỉ khác cách thể hiện.',
                'Both sides appear fairly equal in openness, only different in expression.');
    final signalLine = signals.affectionScore >= 3
        ? _t(
            isEnglish,
            'Những dấu vết trò chuyện gần đây vẫn giữ được độ mềm và quan tâm.',
            'Recent conversation traces still carry softness and care.')
        : _t(
            isEnglish,
            'Cảm xúc có vẻ thật, nhưng lời nói đang dè hơn cảm xúc bên trong.',
            'The feeling looks real, but the words are more guarded than the inner emotion.');
    return _t(
      isEnglish,
      'Năng lượng hiện tại ${viewerProfile.hasCompatibility ? 'có độ hợp khá rõ' : 'chưa hề lạnh'}: cảm xúc $warmth, kết nối $rhythm. $balanceLine $signalLine',
      'The current energy ${viewerProfile.hasCompatibility ? 'shows visible compatibility' : 'is not cold at all'}: feelings are $warmth and the connection rhythm is $rhythm. $balanceLine $signalLine',
    );
  }

  String _advice(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
    int viewerLoveScore,
    int partnerLoveScore,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final seed = viewerLoveScore +
        partnerLoveScore +
        signals.emojiCount +
        (insights.positivity.round() * 3);
    final oracleAdvice = viewerProfile.isSingle
        ? _pickOracleLine(
            isEnglish,
            seed,
            vi: const [
              'Lá bài khuyên bạn giữ tiêu chuẩn cảm xúc rõ ràng: điều gì làm tim dịu xuống thì giữ lại, điều gì làm tim phải gồng lên thì lùi ra.',
              'Nguồn trực giác nghiêng về chữa lành: đừng mở cửa trái tim chỉ vì cô đơn, hãy mở khi bạn thấy sự bình yên đi cùng sức hút.',
              'Theo mạch tarot cổ điển, vận tình cảm đẹp hơn khi bạn đi chậm mà sáng: quan sát sự nhất quán trước khi trao thêm kỳ vọng.',
              'Thông điệp từ trải bài là chọn người có mặt thật trong hành động, vì năng lượng bền luôn mạnh hơn cảm xúc bùng lên ngắn hạn.',
            ],
            en: const [
              'The cards advise keeping your emotional standards clear: keep what softens your heart, step back from what makes it brace itself.',
              'The intuitive current leans toward healing: do not open your heart out of loneliness, open it when peace arrives with attraction.',
              'In the classical tarot flow, love looks better when you move slowly but clearly: watch consistency before giving more expectation.',
              'The spread points toward choosing real presence in action, because steady energy outlasts short emotional fireworks.',
            ],
          )
        : _pickOracleLine(
            isEnglish,
            seed,
            vi: const [
              'Lời khuyên của tarot là chọn một hành động dịu nhưng thật: mở lòng vừa đủ, giữ ranh giới vừa đủ, và để năng lượng đẹp có chỗ lớn lên.',
              'Theo dòng chữa lành, mối liên kết này hợp với sự mềm mại có ý thức: bớt thử lòng, tăng sự hiện diện, để cảm xúc được an toàn mà nở ra.',
              'Lá bài nghiêng về thực hành: thay vì đòi câu trả lời hoàn hảo, hãy nuôi kết nối bằng những điều nhỏ nhưng nhất quán và tử tế.',
              'Mạch tarot trực giác khuyên hai bạn giữ không gian sáng cho nhau: nói thật, đừng quá phòng thủ, và để trái tim thở trước khi quyết định lớn.',
            ],
            en: const [
              'The tarot advice is to choose one gentle but real action: open just enough, hold just enough boundary, and let good energy grow.',
              'In the healing current, this bond responds best to conscious softness: less testing, more presence, so feeling can unfold safely.',
              'The cards lean practical here: instead of demanding a perfect answer, feed the bond through small acts that stay consistent and kind.',
              'The intuitive stream advises keeping a bright space between you: speak truth, lower the armor, and let the heart breathe before big decisions.',
            ],
          );
    if (oracleAdvice.isNotEmpty) return oracleAdvice;
    if (viewerProfile.isSingle) {
      if ((viewerProfile.viewerAgeYears ?? 0) >= 28) {
        return _t(
          isEnglish,
          'Lời khuyên của Tarot: đừng phản hồi bằng sự mập mờ. Hãy chọn người đi kèm sự rõ ràng, đều nhịp, và biết giữ lời hơn là chỉ nói hay.',
          'Tarot advice: do not answer with ambiguity. Choose the person who brings clarity, steadiness, and follow-through, not just beautiful words.',
        );
      }
      return _t(
        isEnglish,
        'Lời khuyên của Tarot: hãy nói ra một nhu cầu thật ngắn nhưng thật thật của bạn. Khi trái tim dám gọi tên điều mình cần, người phù hợp sẽ lộ ra nhanh hơn.',
        'Tarot advice: say one need out loud, briefly but truthfully. When your heart names what it needs, the right person reveals themselves faster.',
      );
    }
    if (insights.interactionRate < 0.45) {
      return _t(
        isEnglish,
        '7 ngày tới, ưu tiên một lời hỏi han mềm và cụ thể hơn là nói chuyện nặng. Mối liên kết này cần được làm ấm lại bằng nhịp đều trước khi đòi câu trả lời lớn.',
        'Over the next 7 days, prioritize one gentle and specific check-in over a heavy conversation. This bond needs warmth through consistency before it can hold big answers.',
      );
    }
    if (viewerLoveScore > partnerLoveScore + 10) {
      return _t(
        isEnglish,
        'Bạn đang cho đi nhiều hơn một nhịp. Đừng giảm sự dịu dàng của mình, nhưng hãy thêm ranh giới: quan sát xem đối phương có tự bước thêm một bước không.',
        'You are giving one beat more than the other person. Do not lose your softness, but add a boundary: watch whether they take one step forward on their own.',
      );
    }
    if (signals.averageLength <= 16) {
      return _t(
        isEnglish,
        'Điều nên làm ngay là nói rõ một ý thay vì để đối phương tự đoán. Với trái tim hiện tại của bạn, rõ ràng là lãng mạn hơn im lặng.',
        'The immediate move is to say one thing clearly instead of making the other person guess. For your current heart, clarity is more romantic than silence.',
      );
    }
    return _t(
      isEnglish,
      'Tarot khuyên hai bạn giữ nhịp yêu bằng những hành động nhỏ nhưng đều: một câu hỏi thật lòng, một phản hồi đúng lúc, và ít kiểm tra lòng nhau hơn.',
      'Tarot advises keeping the bond alive through small but steady acts: one honest question, one timely response, and less emotional testing.',
    );
  }

  String _facetEmotion(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
    String dominantEnergy,
    int warmthIndex,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final energyLine = dominantEnergy == 'warm'
        ? _t(
            isEnglish,
            'Các lá bài nghiêng về trường ấm: tình cảm vẫn còn cửa đi vào, không phải kiểu đã nguội.',
            'The cards lean warm: there is still a doorway into feeling here, not a field that has gone cold.')
        : dominantEnergy == 'reflective'
            ? _t(
                isEnglish,
                'Trải bài nghiêng về phần chưa nói ra: cảm xúc có chiều sâu hơn bề mặt bạn đang để lộ.',
                'The spread leans toward the unsaid layer: the feeling is deeper than what is currently being shown on the surface.')
            : dominantEnergy == 'steady'
                ? _t(
                    isEnglish,
                    'Tarot cho thấy trái tim đang tìm sự yên tâm và nhịp ổn định hơn là cảm xúc bốc cao chóng tàn.',
                    'Tarot suggests the heart is seeking reassurance and stability more than dramatic intensity that burns out quickly.')
                : dominantEnergy == 'transformative'
                    ? _t(
                        isEnglish,
                        'Đây là giai đoạn lột xác cảm xúc: bạn không còn hợp với điều gì đẹp trên bề mặt nhưng thiếu chiều sâu thật.',
                        'This is an emotional shedding phase: you are no longer aligned with what looks beautiful on the surface but lacks real depth.')
                    : _t(
                        isEnglish,
                        'Các lá bài mang sắc thái mạnh: cảm xúc thật có thể rất lớn, nên bài học nằm ở cách giữ bình tĩnh để không làm nó tràn bờ.',
                        'The cards carry intensity: the feeling may be very real and strong, so the lesson is about staying calm enough not to let it spill over.');
    final warmthLine = _t(
      isEnglish,
      'Tổng năng lượng gần đây cho thấy bầu khí cảm xúc ${_warmthText(isEnglish, warmthIndex).toLowerCase()}.',
      'Recent overall energy suggests an emotional climate that feels ${_warmthText(isEnglish, warmthIndex).toLowerCase()}.',
    );
    return '$energyLine $warmthLine ${viewerProfile.maturitySummary}';
  }

  String _facetCommunication(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final oracleCommunication = _pickOracleLine(
      isEnglish,
      signals.messageCount +
          (signals.questionCount * 3) +
          (insights.positivity.round() * 5),
      vi: const [
        'Theo biểu tượng của trải bài, điều quan trọng lúc này không phải nói nhiều mà là nói đúng phần thật nhất của trái tim.',
        'Nguồn tarot trực giác cho thấy lớp ngôn ngữ đang nghiêng về sự chân thành mềm: lời ít nhưng ấm sẽ mở cửa tốt hơn lời đẹp mà mơ hồ.',
        'Nếu đọc theo mạch cổ điển, các lá bài nhấn vào sự rõ ràng và thiện ý; năng lượng đẹp đến từ cách bạn đặt lời nói đúng chỗ.',
        'Thông điệp nổi bật của trải bài là giữ lời nói sáng và gọn: điều được nói ra từ bình an thường chạm sâu hơn điều nói ra từ lo sợ.',
      ],
      en: const [
        'Through the symbols of this spread, what matters now is not saying more, but saying the truest part of the heart.',
        'The intuitive tarot stream shows a language of gentle honesty: fewer words with warmth open more than beautiful but foggy speech.',
        'In the classical reading flow, the cards emphasize clarity and goodwill; good energy comes from placing words with intention.',
        'The standout message here is to keep speech bright and clean: words spoken from calm tend to reach deeper than words spoken from fear.',
      ],
    );
    if (oracleCommunication.isNotEmpty) return oracleCommunication;
    if (signals.messageCount == 0) {
      return _t(
        isEnglish,
        'Chưa có đủ dấu vết tin nhắn để đọc lời nói, nên Tarot thấy rõ hơn phần cảm xúc bên trong và nhịp hoạt động. Điều đó thường cho thấy có cảm giác thật nhưng chưa được đặt thành lời.',
        'There is not enough message data to read the spoken layer, so Tarot sees the inner emotional movement and activity rhythm more clearly. That usually means the feeling is present, but not yet fully named.',
      );
    }
    if (signals.averageLength >= 34 && signals.questionCount >= 2) {
      return _t(
        isEnglish,
        'Bạn có xu hướng giao tiếp bằng chiều sâu và muốn hiểu bản chất vấn đề trước khi mở hết lòng. Điểm mạnh là tinh tế, điểm cần nhớ là đừng hỏi nhiều hơn mức bạn bộc lộ thật.',
        'You tend to communicate through depth and want to understand the root before opening fully. The strength is sensitivity, the caution is not to ask for more than you are willing to reveal.',
      );
    }
    if (signals.averageLength <= 16) {
      return _t(
        isEnglish,
        'Lời nói hiện tại ngắn hơn cảm xúc thật. Nút thắt không phải thiếu thương, mà là người còn lại khó đoán đúng điều bạn đang cần nếu mọi thứ chỉ dừng ở câu ngắn.',
        'The current words are shorter than the true feeling. The knot is not a lack of care, but that the other person may struggle to read what you need if everything stays in short lines.',
      );
    }
    return _t(
      isEnglish,
      'Nhịp giao tiếp đang ở mức vừa phải: có sự quan tâm nhưng đôi lúc vẫn giữ ý. Điều Tarot khuyên là nói rõ một điều cụ thể thay vì chờ đối phương tự cảm hết phần chưa nói.',
      'The communication rhythm is moderate: there is care, but some thoughts are still being held back. Tarot advises stating one concrete truth instead of waiting for the other person to sense all the unspoken layers.',
    );
  }

  String _facetAttachment(
    TarotViewerProfile viewerProfile,
    int viewerLoveScore,
    int partnerLoveScore,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final coreNeed = _attachmentNeed(viewerProfile.viewerElement, isEnglish);
    if (viewerProfile.isSingle) {
      return _t(
        isEnglish,
        'Nhu cầu sâu của bạn lúc này là $coreNeed. Ở giai đoạn tuổi hiện tại, trái tim không còn chỉ cần hấp dẫn; nó cần cảm giác an tâm và nhất quán để đi tiếp.',
        'Your deeper need right now is $coreNeed. At this stage of life, the heart no longer wants attraction alone; it wants reassurance and consistency to move forward.',
      );
    }
    final balanceLine = viewerLoveScore > partnerLoveScore + 8
        ? _t(
            isEnglish,
            'Bạn có xu hướng cho đi cảm xúc trước, nên nhu cầu được đáp lại rõ ràng cũng cao hơn.',
            'You tend to give emotion first, so your need for a visible return is naturally higher.')
        : partnerLoveScore > viewerLoveScore + 8
            ? _t(
                isEnglish,
                'Đối phương có vẻ mong gắn kết mạnh hơn một nhịp, vì vậy cách bạn phản hồi rất quan trọng.',
                'The other person seems to want closeness one beat more strongly, so the way you respond matters a lot.')
            : _t(
                isEnglish,
                'Hai phía có nhu cầu gần nhau, chỉ khác ngôn ngữ yêu.',
                'Both sides have fairly similar needs, only different love languages.');
    return _t(
      isEnglish,
      'Nhu cầu sâu của bạn đang nghiêng về $coreNeed. $balanceLine',
      'Your deeper need is leaning toward $coreNeed. $balanceLine',
    );
  }

  String _facetTiming(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final seed = (insights.interactionRate * 100).round() +
        (signals.exclamationCount * 7) +
        signals.positiveScore;
    final oracleTiming =
        insights.interactionRate >= 1.1 && insights.positivity >= 70
            ? _pickOracleLine(
                isEnglish,
                seed,
                vi: const [
                  'Dòng chảy của trải bài đang mở: đây là lúc thuận để tiến một bước mềm, miễn là bạn vẫn giữ được sự bình tâm.',
                  'Các lá bài đồng thuận về thời điểm khá sáng; một cử chỉ tử tế hoặc một lời nói thật lúc này dễ được đón nhận hơn.',
                  'Nguồn bói chữa lành cho thấy cánh cửa đang hé mở, hợp với một bước tiến nhẹ nhàng hơn là một cú thúc mạnh.',
                ],
                en: const [
                  'The spread is opening in flow: this is a good time for one soft step, as long as you stay grounded.',
                  'The cards agree that the timing looks bright; one kind gesture or one honest sentence is more likely to be received now.',
                  'The healing stream suggests the door is slightly open, which favors a gentle move more than a forceful push.',
                ],
              )
            : insights.interactionRate < 0.45
                ? _pickOracleLine(
                    isEnglish,
                    seed,
                    vi: const [
                      'Trải bài chưa khuyến khích đẩy nhanh. Hợp hơn là để mọi thứ lắng lại, rồi chọn một thời điểm êm để chạm vào điều quan trọng.',
                      'Mạch thời điểm đang nghiêng về hồi phục và gom năng lượng; đi chậm lúc này thường đẹp hơn cố ép kết quả.',
                      'Tarot cho thấy nên nuôi lại sự ấm áp trước, rồi mới nói tới bước lớn hơn trong kết nối này.',
                    ],
                    en: const [
                      'The spread does not support rushing. It is better to let things settle, then touch the important matter in a softer moment.',
                      'The timing stream leans toward recovery and gathering energy; moving slowly looks better than forcing an outcome.',
                      'Tarot suggests restoring warmth first before asking this connection to carry a bigger step.',
                    ],
                  )
                : _pickOracleLine(
                    isEnglish,
                    seed,
                    vi: const [
                      'Nhịp của trải bài hợp với một bước chắc tay hơn là nhiều động tác dồn dập.',
                      'Dòng chảy hiện tại khuyên chọn thời điểm khi lòng đã yên, vì quyết định từ bình an sẽ bền hơn.',
                      'Các lá bài cho thấy thời điểm đẹp đến từ sự tỉnh táo và đều đặn, không đến từ vội vàng.',
                    ],
                    en: const [
                      'The spread favors one steady move more than many rushed actions.',
                      'The current flow advises choosing a moment when the heart is calm, because decisions made from peace tend to last longer.',
                      'The cards suggest that good timing comes from steadiness and clarity, not urgency.',
                    ],
                  );
    if (oracleTiming.isNotEmpty) return oracleTiming;
    if (insights.interactionRate >= 1.1 && insights.positivity >= 70) {
      return _t(
        isEnglish,
        'Đây là nhịp khá đẹp để tiến thêm một bước mềm: nói rõ cảm xúc, hẹn một cuộc trò chuyện tử tế, hoặc đặt lại kỳ vọng cho cùng một hướng.',
        'This is a strong window for one soft step forward: state your feeling, ask for a kind conversation, or realign expectations toward the same direction.',
      );
    }
    if (insights.interactionRate < 0.45) {
      return _t(
        isEnglish,
        'Tarot không khuyên đi quá mạnh ngay lúc này. Nhịp đúng là khơi lại sự gần gũi trước, rồi mới chạm vào câu hỏi lớn. Thời điểm đẹp là trong 3 đến 7 ngày tới với một tín hiệu nhỏ nhưng rõ.',
        'Tarot does not advise pushing too hard right now. The right timing is to restore softness first, then touch the bigger question. The best window is within the next 3 to 7 days with one small but clear signal.',
      );
    }
    return signals.exclamationCount > 1
        ? _t(
            isEnglish,
            'Cảm xúc khá nhanh và dễ dâng lên, nên càng cần chọn đúng lúc để tránh quá tải.',
            'Emotion rises quickly here, so timing matters even more to avoid overwhelm.')
        : _t(
            isEnglish,
            'Nhịp hiện tại hợp với một bước chậm nhưng chắc hơn là nhiều hành động dồn dập.',
            'The current rhythm favors one steady move more than many hurried actions.');
  }

  String _facetCompatibility(TarotViewerProfile viewerProfile) {
    final isEnglish = viewerProfile.isEnglish;
    if (viewerProfile.hasCompatibility) {
      return '${viewerProfile.compatibilityTitle}. ${viewerProfile.compatibilityDescription}';
    }
    if (viewerProfile.hasViewerZodiac) {
      final rawLoveStyle = ZodiacUtils
              .zodiacDetails[viewerProfile.viewerZodiacKey]?['love']
              ?.toString()
              .trim() ??
          '';
      if (!isEnglish && rawLoveStyle.isNotEmpty) {
        return 'Cung ${viewerProfile.viewerZodiacLabel} của bạn cho thấy cách yêu thiên về: $rawLoveStyle';
      }
      return _t(
        isEnglish,
        'Nếu nhìn theo khí chất ${viewerProfile.viewerZodiacLabel}, bạn thường hợp kiểu người biết nói thật, giữ nhịp đều và không làm cảm xúc của bạn bị treo lửng quá lâu.',
        'Through the tone of ${viewerProfile.viewerZodiacLabel}, you tend to fit best with people who speak honestly, keep a steady pace, and do not leave your feelings hanging for too long.',
      );
    }
    return _t(
      isEnglish,
      'Khi chưa có đủ dữ liệu cung mệnh, Tarot vẫn cho thấy bạn hợp với kiểu kết nối rõ ràng, tôn trọng nhịp cảm xúc và không ép bạn yêu nhanh hơn mức mình sẵn sàng.',
      'Without enough zodiac data, Tarot still suggests you fit best with a bond that is clear, respectful of emotional timing, and does not force you to move faster than you are ready for.',
    );
  }

  String _cardHeadline(String slotId, bool isEnglish, bool isSingle) {
    switch (slotId) {
      case 'current_pulse':
        return _t(
            isEnglish, 'Nhịp cảm xúc hiện tại', 'Current emotional pulse');
      case 'hidden_tide':
        return _t(isEnglish, 'Phần đang giấu', 'Hidden tide');
      case 'heart_path':
        return _t(isEnglish, 'Hướng mở tim', 'Heart-opening path');
      case 'self_state':
        return _t(isEnglish, 'Bạn đang mang gì', 'What you are carrying');
      case 'partner_state':
        return _t(
          isEnglish,
          isSingle ? 'Người bạn đang nghĩ tới' : 'Phía đối phương',
          isSingle ? 'The person on your mind' : 'The other side',
        );
      case 'friction':
        return _t(isEnglish, 'Điểm va chạm', 'Point of friction');
      case 'bridge':
        return _t(isEnglish, 'Cầu nối chữa lành', 'Healing bridge');
      case 'root':
        return _t(isEnglish, 'Gốc cảm xúc', 'Emotional root');
      case 'need':
        return _t(isEnglish, 'Nhu cầu sâu', 'Deeper need');
      case 'expression':
        return _t(isEnglish, 'Cách bạn thể hiện', 'Your love expression');
      case 'block':
        return _t(isEnglish, 'Rào cản hiện tại', 'Current block');
      case 'next_7':
        return _t(isEnglish, 'Hướng đi 7 ngày tới', 'The next 7 days');
      case 'release':
        return _t(isEnglish, 'Điều nên buông', 'What to release');
      case 'invite':
        return _t(isEnglish, 'Điều nên mở cửa', 'What to invite in');
      case 'timing':
        return _t(isEnglish, 'Nhịp thời điểm', 'Timing pulse');
      case 'sign':
        return _t(isEnglish, 'Dấu hiệu sắp đến', 'Incoming sign');
      default:
        return _t(isEnglish, 'Thông điệp của lá bài', 'Card message');
    }
  }

  String _slotInterpretation(
    TarotReadingSelection selection,
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
    String dominantEnergy,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final needText = _attachmentNeed(viewerProfile.viewerElement, isEnglish);
    final rhythm =
        _interactionText(isEnglish, insights.interactionRate).toLowerCase();
    final slotLine = switch (selection.slotId) {
      'current_pulse' => _t(
          isEnglish,
          'Ở vị trí này, lá bài nói rằng cảm xúc hiện tại đang ${dominantEnergy == 'warm' ? 'muốn được đón nhận' : dominantEnergy == 'reflective' ? 'cần được gọi tên rõ ràng' : 'đòi hỏi bạn phải nhìn sâu hơn vào điều mình thật sự muốn'}.',
          'In this position, the card says your present feeling ${dominantEnergy == 'warm' ? 'wants to be received' : dominantEnergy == 'reflective' ? 'needs to be named clearly' : 'is asking you to look deeper into what you truly want'}.'),
      'hidden_tide' => _t(
          isEnglish,
          'Phần bị giấu nhiều nhất không phải là thiếu thương, mà là nỗi sợ mình mở lòng trước rồi không được đáp lại đúng mức.',
          'What is most hidden is not a lack of feeling, but the fear of opening first and not being met with the same depth.'),
      'heart_path' => _t(
          isEnglish,
          'Con đường mở tim ở đây không phải thêm kịch tính, mà là nói đúng một điều thật và để người kia thấy nhịp cảm xúc thật của bạn.',
          'The heart-opening path here is not about more drama, but about saying one true thing and letting the other person see your real rhythm.'),
      'self_state' => _t(
          isEnglish,
          'Vị trí này phản chiếu bạn đang mang theo nhu cầu $needText và có xu hướng quan sát rất kỹ trước khi trao thêm niềm tin.',
          'This position reflects that you are carrying the need for $needText and tend to observe carefully before offering more trust.'),
      'partner_state' => viewerProfile.isSingle
          ? _t(
              isEnglish,
              'Nếu đang nghĩ tới một người cụ thể, lá này cho thấy họ có thể cũng đang do dự hoặc chưa đủ rõ để bước hẳn vào vùng cảm xúc của bạn.',
              'If you have a specific person in mind, this card suggests they may also be hesitating or not yet clear enough to fully step into your emotional space.')
          : _t(
              isEnglish,
              'Lá bài cho thấy phía đối phương đang giữ cảm xúc theo cách riêng của họ. Điều quan trọng là đừng dịch sự chậm lại thành hết thương quá sớm.',
              'This card shows the other side is holding feeling in their own way. The key is not to translate slowness into a lack of care too early.'),
      'friction' => _t(
          isEnglish,
          'Điểm va chạm hiện tại nằm ở chỗ cảm xúc đi một nhịp, lời nói đi một nhịp khác. Khi nhịp kết nối đang $rhythm, hiểu lầm rất dễ lớn hơn sự thật.',
          'The current friction lives where feelings move in one rhythm and words move in another. When the connection rhythm feels $rhythm, misunderstandings can grow larger than the truth.'),
      'bridge' => _t(
          isEnglish,
          'Cầu nối chữa lành đến từ một hành động nhỏ nhưng rõ: hỏi han cụ thể, phản hồi đúng lúc, hoặc thừa nhận điều mình đang thật sự sợ.',
          'The healing bridge comes from one small but clear act: a specific check-in, a timely response, or naming what you are truly afraid of.'),
      'root' => _t(
          isEnglish,
          'Gốc cảm xúc ở đây cho thấy chuyện hiện tại không chỉ là người kia, mà còn là cách trái tim bạn đang định nghĩa an toàn và giá trị của chính mình.',
          'The emotional root here shows that this is not only about the other person, but also about how your heart is defining safety and self-worth.'),
      'need' => _t(
          isEnglish,
          'Nhu cầu sâu hiện ra rất rõ: bạn cần $needText hơn là những rung động đẹp nhưng thiếu độ chắc.',
          'The deeper need is very clear: you need $needText more than beautiful sparks that lack steadiness.'),
      'expression' => _t(
          isEnglish,
          'Cách bạn thể hiện yêu thương có thể dịu hơn hoặc sâu hơn mức người khác nhìn thấy ngay. Tarot nhắc rằng không phải ai cũng tự đọc được phần mềm đó nếu bạn không nói ra.',
          'Your way of expressing love may be softer or deeper than others can immediately read. Tarot reminds you that not everyone can sense that softness if you never name it.'),
      'block' => _t(
          isEnglish,
          'Rào cản hiện tại là thói quen tự đoán ý nhau hoặc tự ép mình phải ổn. Lá này nhắc bạn gỡ nút bằng sự thật, không phải bằng đoán lòng.',
          'The present block is the habit of guessing each other or forcing yourself to look fine. This card asks you to untie the knot with truth, not with emotional guessing.'),
      'next_7' => _t(
          isEnglish,
          'Trong 7 ngày tới, hướng đi đẹp nhất là một bước nhỏ nhưng có chủ đích. Đừng cố giải quyết mọi thứ trong một lần nói chuyện duy nhất.',
          'Over the next 7 days, the best direction is one small but intentional move. Do not try to solve everything in one conversation.'),
      'release' => _t(
          isEnglish,
          'Điều nên buông ở đây là cách yêu dựa trên suy đoán, tự thử lòng, hoặc đòi đối phương phải hiểu hết mà chưa từng được nói rõ.',
          'What should be released here is love built on guessing, emotional testing, or expecting the other person to understand what has never been clearly said.'),
      'invite' => _t(
          isEnglish,
          'Điều nên mời vào là sự rõ ràng, nhịp đều, và cảm giác được đáp lại bằng hành động thực tế chứ không chỉ hứa hẹn.',
          'What should be invited in is clarity, steadiness, and the feeling of being met through real action, not promises alone.'),
      'timing' => _t(
          isEnglish,
          'Lá này nhấn mạnh chuyện thời điểm: đừng vội khi tim còn rối, nhưng cũng đừng chờ quá lâu đến mức cảm xúc đẹp bị nguội vì thiếu tín hiệu.',
          'This card emphasizes timing: do not rush while the heart is tangled, but do not wait so long that good feeling cools down from lack of signal.'),
      'sign' => _t(
          isEnglish,
          'Dấu hiệu sắp tới thường không quá ồn ào: một tin nhắn rõ ràng hơn, một phản hồi chủ động hơn, hoặc cảm giác nhẹ người vì bạn biết mình cần gì.',
          'The sign ahead is not usually loud: a clearer message, a more active response, or the relief of finally knowing what you need.'),
      _ => '',
    };
    final reverseLine = selection.isReversed
        ? _t(
            isEnglish,
            'Vì lá này xuất hiện ở thế ngược, năng lượng đó đang bị nén, chậm, hoặc dễ đi chệch nếu bạn tiếp tục giữ im lặng.',
            'Because this card appears reversed, that energy is compressed, delayed, or easily diverted if silence continues.')
        : _t(
            isEnglish,
            'Ở thế xuôi, lá này cho thấy vẫn còn một đường đi đẹp nếu bạn chọn cách thể hiện trưởng thành và đều nhịp.',
            'In upright position, this card shows there is still a beautiful way forward if you choose a mature and steady expression.');
    return '${selection.baseMeaning} $slotLine $reverseLine';
  }
}
