import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/zodiac_utils.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/love_insight_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
  return UiCopy.bilingual('copy_750f44691f6d', isEnglish, {'value1': ageYears});
}

String? _localizedZodiacName(String? raw, bool isEnglish) =>
    raw == null ? null : ZodiacUtils.localizedName(raw, isEnglish: isEnglish);

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
      label: UiCopy.bilingual('copy_360c4d0aaac3', isEnglish),
      summary: UiCopy.bilingual('copy_c73d3ee38997', isEnglish),
    );
  }
  if (ageYears <= 20) {
    return _MaturityLens(
      label: UiCopy.bilingual('copy_a4390f73a2ea', isEnglish),
      summary: UiCopy.bilingual('copy_2bdd95882564', isEnglish),
    );
  }
  if (ageYears <= 26) {
    return _MaturityLens(
      label: UiCopy.bilingual('copy_6cc2d86e8a81', isEnglish),
      summary: UiCopy.bilingual('copy_663fd4d8099b', isEnglish),
    );
  }
  if (ageYears <= 33) {
    return _MaturityLens(
      label: UiCopy.bilingual('copy_b275c139fdb9', isEnglish),
      summary: UiCopy.bilingual('copy_5967b0739a81', isEnglish),
    );
  }
  if (ageYears <= 40) {
    return _MaturityLens(
      label: UiCopy.bilingual('copy_359e38068fc4', isEnglish),
      summary: UiCopy.bilingual('copy_e8a0b808b4c7', isEnglish),
    );
  }
  return _MaturityLens(
    label: UiCopy.bilingual('copy_33046d32bb5b', isEnglish),
    summary: UiCopy.bilingual('copy_279922355541', isEnglish),
  );
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
        _safeText(settings['nameU1'], fallback: UiCopy.text('copy_40ffd8d0f1c7'));
    final nameU2 = _safeText(
      settings['nameU2'],
      fallback: isSingle
          ? UiCopy.text('copy_fd4ca9e4d18c')
          : UiCopy.text('copy_145933221191'),
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
      compatibilityTitle = rawCompatibility['title']?.toString();
      compatibilityDescription = rawCompatibility['desc']?.toString();
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
    int seed, {
    required List<String> keys,
  }) {
    if (keys.isEmpty) return '';
    return UiCopy.text(keys[seed.abs() % keys.length]);
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
          label: UiCopy.bilingual('copy_101001be15a5', isEnglish),
          value: viewerProfile.viewerAgeLabel!,
        ),
      if (viewerProfile.hasViewerZodiac)
        TarotReadingMetric(
          label: UiCopy.bilingual('copy_698257e8dc93', isEnglish),
          value:
              '${viewerProfile.viewerZodiacEmoji ?? ''} ${viewerProfile.viewerZodiacLabel!}'
                  .trim(),
        ),
      TarotReadingMetric(
        label: UiCopy.bilingual('copy_1717baa2c26a', isEnglish),
        value: _warmthText(isEnglish, warmthIndex),
      ),
      TarotReadingMetric(
        label: UiCopy.bilingual('copy_897ffdabcbe5', isEnglish),
        value: _interactionText(isEnglish, insights.interactionRate),
      ),
      if (viewerProfile.hasCompatibility)
        TarotReadingMetric(
          label: UiCopy.bilingual('copy_7652e17ba3fb', isEnglish),
          value: '${viewerProfile.compatibilityScore}%',
        ),
    ];

    final facets = <TarotReadingFacet>[
      TarotReadingFacet(
        title: UiCopy.bilingual('copy_2d4384028ed5', isEnglish),
        accent: UiCopy.bilingual('copy_22b1e894f6ea', isEnglish),
        body: _facetEmotion(
          viewerProfile,
          insights,
          signals,
          dominantEnergy,
          warmthIndex,
        ),
      ),
      TarotReadingFacet(
        title: UiCopy.bilingual('copy_e6bd7d6f4479', isEnglish),
        accent: UiCopy.bilingual('copy_160225dbc62a', isEnglish),
        body: _facetCommunication(viewerProfile, insights, signals),
      ),
      TarotReadingFacet(
        title: UiCopy.bilingual('copy_64e106c7ae8c', isEnglish),
        accent: UiCopy.bilingual('copy_ea17a77e67a2', isEnglish),
        body: _facetAttachment(
          viewerProfile,
          viewerLoveScore,
          partnerLoveScore,
        ),
      ),
      TarotReadingFacet(
        title: UiCopy.bilingual('copy_23c57b4dc1b9', isEnglish),
        accent: UiCopy.bilingual('copy_020b0562702a', isEnglish),
        body: _facetTiming(viewerProfile, insights, signals),
      ),
      TarotReadingFacet(
        title: UiCopy.bilingual('copy_38321c4b5334', isEnglish),
        accent: UiCopy.bilingual('copy_44069c434e91', isEnglish),
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
        return UiCopy.bilingual('copy_7a52e7e19ad8', isEnglish);
      case 2:
        return UiCopy.bilingual('copy_f6c02fc5925d', isEnglish);
      case 1:
        return UiCopy.bilingual('copy_e949f7a44b5a', isEnglish);
      default:
        return UiCopy.bilingual('copy_3847a5e7e0f6', isEnglish);
    }
  }

  String _interactionText(bool isEnglish, double rate) {
    if (rate >= 1.2) {
      return UiCopy.bilingual('copy_24afe779a9ff', isEnglish);
    }
    if (rate >= 0.7) return UiCopy.bilingual('copy_cdadc36b5b6b', isEnglish);
    if (rate >= 0.45) {
      return UiCopy.bilingual('copy_489b52e84a91', isEnglish);
    }
    return UiCopy.bilingual('copy_823d8a8dcfbe', isEnglish);
  }

  String _attachmentNeed(String? element, bool isEnglish) {
    switch (element) {
      case 'Lửa':
        return UiCopy.bilingual('copy_9f157962dc7c', isEnglish);
      case 'Nước':
        return UiCopy.bilingual('copy_7d0399eac729', isEnglish);
      case 'Khí':
        return UiCopy.bilingual('copy_4596a5a823a3', isEnglish);
      case 'Đất':
        return UiCopy.bilingual('copy_ea2a3883fcdd', isEnglish);
      default:
        return UiCopy.bilingual('copy_9b9f8658fa76', isEnglish);
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
      return UiCopy.bilingual('copy_02b61087569a', isEnglish);
    }
    if (dominantEnergy == 'transformative' || dominantEnergy == 'intense') {
      return UiCopy.bilingual('copy_d997f0b36549', isEnglish);
    }
    if (interactionRate < 0.45) {
      return UiCopy.bilingual('copy_a18f1a68239a', isEnglish);
    }
    if (affectionScore >= 3 || viewerElement == 'Nước') {
      return UiCopy.bilingual('copy_86c15f82fba8', isEnglish);
    }
    return UiCopy.bilingual('copy_c5934d7ac02d', isEnglish);
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
      return UiCopy.bilingual('copy_e6ed7fcfd444', isEnglish);
    }
    if (insights.interactionRate < 0.45) {
      return UiCopy.bilingual('copy_53146b79b890', isEnglish);
    }
    if (dominantEnergy == 'transformative' || dominantEnergy == 'intense') {
      return UiCopy.bilingual('copy_da6448949836', isEnglish);
    }
    if (signals.affectionScore >= 4 || insights.positivity >= 76) {
      return UiCopy.bilingual('copy_a0d5c81a4b4e', isEnglish);
    }
    return UiCopy.bilingual('copy_d41f56fe09a1', isEnglish);
  }

  String _profileSummary(
    TarotViewerProfile viewerProfile,
    _TarotMessageSignals signals,
    int viewerLoveScore,
    String profileTag,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final zodiacText = viewerProfile.hasViewerZodiac
        ? UiCopy.bilingual('copy_f40a61830d9c', isEnglish, {'value1': viewerProfile.viewerZodiacLabel})
        : UiCopy.bilingual('copy_c6e15eb627b9', isEnglish);
    final signalText = signals.messageCount == 0
        ? UiCopy.bilingual('copy_4fc975a8b773', isEnglish)
        : UiCopy.text('copy_c2c1d4665d95', {
            'value1': L10nService().translate(signals.averageLength >= 28
                ? 'tarot_signal_deep'
                : 'tarot_signal_reserved'),
          });
    return UiCopy.bilingual('copy_de59a2a0a4ee', isEnglish, {'value1': viewerProfile.viewerName, 'value2': profileTag, 'value3': viewerProfile.maturitySummary, 'value4': zodiacText, 'value5': viewerLoveScore, 'value6': signalText});
  }

  String _spreadSummary(TarotViewerProfile viewerProfile, String spreadId) {
    final isEnglish = viewerProfile.isEnglish;
    switch (spreadId) {
      case 'pulse':
        return UiCopy.bilingual('copy_6f3f11406b58', isEnglish);
      case 'mirror':
        return UiCopy.bilingual('copy_a57616a3688d', isEnglish);
      case 'map':
        return UiCopy.bilingual('copy_dfe232c8dc44', isEnglish);
      default:
        return UiCopy.bilingual('copy_b2568abb9e4d', isEnglish);
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
      return UiCopy.bilingual('copy_e9812d14417c', isEnglish, {'value1': warmth, 'value2': rhythm});
    }
    final balanceLine = viewerLoveScore > partnerLoveScore + 8
        ? UiCopy.bilingual('copy_7ea8fbdfd4aa', isEnglish)
        : partnerLoveScore > viewerLoveScore + 8
            ? UiCopy.bilingual('copy_c1954c9997a7', isEnglish)
            : UiCopy.bilingual('copy_97bfb623d1eb', isEnglish);
    final signalLine = signals.affectionScore >= 3
        ? UiCopy.bilingual('copy_830aab11f815', isEnglish)
        : UiCopy.bilingual('copy_dbe61da586f5', isEnglish);
    return UiCopy.text('copy_9b2c5f7a5a11', {
      'value1': L10nService().translate(viewerProfile.hasCompatibility
          ? 'tarot_energy_compatible'
          : 'tarot_energy_warm'),
      'value2': warmth,
      'value3': rhythm,
      'value4': balanceLine,
      'value5': signalLine,
    });
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
            seed,
            keys: const [
              'copy_23445894e70a',
              'copy_a96ef7ee6675',
              'copy_e410c73062ac',
              'copy_163cf1c71b28',
            ],
          )
        : _pickOracleLine(
            seed,
            keys: const [
              'copy_4e48fa36d0f0',
              'copy_0f7c797db866',
              'copy_a432fb8beb98',
              'copy_311c1613e739',
            ],
          );
    if (oracleAdvice.isNotEmpty) return oracleAdvice;
    if (viewerProfile.isSingle) {
      if ((viewerProfile.viewerAgeYears ?? 0) >= 28) {
        return UiCopy.bilingual('copy_959ce8a7e980', isEnglish);
      }
      return UiCopy.bilingual('copy_99f5a95331fb', isEnglish);
    }
    if (insights.interactionRate < 0.45) {
      return UiCopy.bilingual('copy_c01e1cb8aab3', isEnglish);
    }
    if (viewerLoveScore > partnerLoveScore + 10) {
      return UiCopy.bilingual('copy_3c4ef5e62361', isEnglish);
    }
    if (signals.averageLength <= 16) {
      return UiCopy.bilingual('copy_39d5608febf2', isEnglish);
    }
    return UiCopy.bilingual('copy_7e06d5186df0', isEnglish);
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
        ? UiCopy.bilingual('copy_af27c335c577', isEnglish)
        : dominantEnergy == 'reflective'
            ? UiCopy.bilingual('copy_d384b3d75775', isEnglish)
            : dominantEnergy == 'steady'
                ? UiCopy.bilingual('copy_c06595f6364d', isEnglish)
                : dominantEnergy == 'transformative'
                    ? UiCopy.bilingual('copy_78cbb41a0db1', isEnglish)
                    : UiCopy.bilingual('copy_d45332321e1e', isEnglish);
    final warmthLine = UiCopy.bilingual('copy_7b92a8bae8d6', isEnglish, {'value1': _warmthText(isEnglish, warmthIndex).toLowerCase()});
    return '$energyLine $warmthLine ${viewerProfile.maturitySummary}';
  }

  String _facetCommunication(
    TarotViewerProfile viewerProfile,
    LoveInsightData insights,
    _TarotMessageSignals signals,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final oracleCommunication = _pickOracleLine(
      signals.messageCount +
          (signals.questionCount * 3) +
          (insights.positivity.round() * 5),
      keys: const [
        'copy_0f5d368dbf2b',
        'copy_0e8c5f5417c6',
        'copy_fd0dbf077183',
        'copy_5d885addb2ad',
      ],
    );
    if (oracleCommunication.isNotEmpty) return oracleCommunication;
    if (signals.messageCount == 0) {
      return UiCopy.bilingual('copy_7fb89dfdbe51', isEnglish);
    }
    if (signals.averageLength >= 34 && signals.questionCount >= 2) {
      return UiCopy.bilingual('copy_e71446270fb6', isEnglish);
    }
    if (signals.averageLength <= 16) {
      return UiCopy.bilingual('copy_ae7eb49ca86c', isEnglish);
    }
    return UiCopy.bilingual('copy_fafc7bf6a79d', isEnglish);
  }

  String _facetAttachment(
    TarotViewerProfile viewerProfile,
    int viewerLoveScore,
    int partnerLoveScore,
  ) {
    final isEnglish = viewerProfile.isEnglish;
    final coreNeed = _attachmentNeed(viewerProfile.viewerElement, isEnglish);
    if (viewerProfile.isSingle) {
      return UiCopy.bilingual('copy_c7f1cc970532', isEnglish, {'value1': coreNeed});
    }
    final balanceLine = viewerLoveScore > partnerLoveScore + 8
        ? UiCopy.bilingual('copy_5e0258776fdf', isEnglish)
        : partnerLoveScore > viewerLoveScore + 8
            ? UiCopy.bilingual('copy_fd59329bddff', isEnglish)
            : UiCopy.bilingual('copy_62b6fae2265f', isEnglish);
    return UiCopy.bilingual('copy_1056e725f64b', isEnglish, {'value1': coreNeed, 'value2': balanceLine});
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
                seed,
                keys: const [
                  'copy_28095b6c0e84',
                  'copy_b17f20498e4b',
                  'copy_5069a9eb881b',
                ],
              )
            : insights.interactionRate < 0.45
                ? _pickOracleLine(
                    seed,
                    keys: const [
                      'copy_a2d65c69d4dc',
                      'copy_18f6da86eacd',
                      'copy_4ad7fd9ae055',
                    ],
                  )
                : _pickOracleLine(
                    seed,
                    keys: const [
                      'copy_5ae0cb2d8ab4',
                      'copy_dfd56fef5891',
                      'copy_b33883e903f6',
                    ],
                  );
    if (oracleTiming.isNotEmpty) return oracleTiming;
    if (insights.interactionRate >= 1.1 && insights.positivity >= 70) {
      return UiCopy.bilingual('copy_0d92d8cf686f', isEnglish);
    }
    if (insights.interactionRate < 0.45) {
      return UiCopy.bilingual('copy_1db33ebe3502', isEnglish);
    }
    return signals.exclamationCount > 1
        ? UiCopy.bilingual('copy_9e182fff6582', isEnglish)
        : UiCopy.bilingual('copy_36504913265f', isEnglish);
  }

  String _facetCompatibility(TarotViewerProfile viewerProfile) {
    final isEnglish = viewerProfile.isEnglish;
    if (viewerProfile.hasCompatibility) {
      return '${viewerProfile.compatibilityTitle}. ${viewerProfile.compatibilityDescription}';
    }
    if (viewerProfile.hasViewerZodiac) {
      final rawLoveStyle = ZodiacUtils.localizedDetails(viewerProfile.viewerZodiacKey ?? '')?['love']
              ?.toString()
              .trim() ??
          '';
      if (!isEnglish && rawLoveStyle.isNotEmpty) {
        return UiCopy.text('copy_ececea8c80e3', {'value1': viewerProfile.viewerZodiacLabel, 'value2': rawLoveStyle});
      }
      return UiCopy.bilingual('copy_e87392b24f82', isEnglish, {'value1': viewerProfile.viewerZodiacLabel});
    }
    return UiCopy.bilingual('copy_5a40a1765eb8', isEnglish);
  }

  String _cardHeadline(String slotId, bool isEnglish, bool isSingle) {
    switch (slotId) {
      case 'current_pulse':
        return UiCopy.bilingual('copy_9218c5953eb8', isEnglish);
      case 'hidden_tide':
        return UiCopy.bilingual('copy_4bf15bf3b841', isEnglish);
      case 'heart_path':
        return UiCopy.bilingual('copy_32223129138c', isEnglish);
      case 'self_state':
        return UiCopy.bilingual('copy_a4075ad52e59', isEnglish);
      case 'partner_state':
        return isSingle
            ? UiCopy.text('copy_6e13fe2f0852')
            : UiCopy.text('copy_d70c709b472a');
      case 'friction':
        return UiCopy.bilingual('copy_a0c2533f0b71', isEnglish);
      case 'bridge':
        return UiCopy.bilingual('copy_1c3af5307831', isEnglish);
      case 'root':
        return UiCopy.bilingual('copy_4210398a0cde', isEnglish);
      case 'need':
        return UiCopy.bilingual('copy_cda9b273f261', isEnglish);
      case 'expression':
        return UiCopy.bilingual('copy_440c1a6aeea1', isEnglish);
      case 'block':
        return UiCopy.bilingual('copy_22d8bd5a5701', isEnglish);
      case 'next_7':
        return UiCopy.bilingual('copy_46745861d9dc', isEnglish);
      case 'release':
        return UiCopy.bilingual('copy_2ad401bc0fde', isEnglish);
      case 'invite':
        return UiCopy.bilingual('copy_fc046557cfd9', isEnglish);
      case 'timing':
        return UiCopy.bilingual('copy_23c57b4dc1b9', isEnglish);
      case 'sign':
        return UiCopy.bilingual('copy_83ddc2ad5ed3', isEnglish);
      default:
        return UiCopy.bilingual('copy_7f33184fe5d1', isEnglish);
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
      'current_pulse' => UiCopy.text('copy_c38335bc8ea9', {
          'value1': L10nService().translate(dominantEnergy == 'warm'
              ? 'tarot_feeling_received'
              : dominantEnergy == 'reflective'
                  ? 'tarot_feeling_named'
                  : 'tarot_feeling_deeper'),
        }),
      'hidden_tide' => UiCopy.bilingual('copy_b9c45ed214e5', isEnglish),
      'heart_path' => UiCopy.bilingual('copy_3cd396e60771', isEnglish),
      'self_state' => UiCopy.bilingual('copy_8c3b1146e615', isEnglish, {'value1': needText}),
      'partner_state' => viewerProfile.isSingle
          ? UiCopy.bilingual('copy_9d24d7963941', isEnglish)
          : UiCopy.bilingual('copy_984c662b4b1f', isEnglish),
      'friction' => UiCopy.bilingual('copy_c07faad1e3c0', isEnglish, {'value1': rhythm}),
      'bridge' => UiCopy.bilingual('copy_6ab16037eb42', isEnglish),
      'root' => UiCopy.bilingual('copy_1d4d28b70180', isEnglish),
      'need' => UiCopy.bilingual('copy_7fc3c185d5d1', isEnglish, {'value1': needText}),
      'expression' => UiCopy.bilingual('copy_25495f48051b', isEnglish),
      'block' => UiCopy.bilingual('copy_556d54e53259', isEnglish),
      'next_7' => UiCopy.bilingual('copy_81916c668a15', isEnglish),
      'release' => UiCopy.bilingual('copy_01be4003f686', isEnglish),
      'invite' => UiCopy.bilingual('copy_1b516dac44ac', isEnglish),
      'timing' => UiCopy.bilingual('copy_dc3ebff0110d', isEnglish),
      'sign' => UiCopy.bilingual('copy_cb8be28171cc', isEnglish),
      _ => '',
    };
    final reverseLine = selection.isReversed
        ? UiCopy.bilingual('copy_96c02c91fce8', isEnglish)
        : UiCopy.bilingual('copy_225fe7e7a432', isEnglish);
    return '${selection.baseMeaning} $slotLine $reverseLine';
  }
}
