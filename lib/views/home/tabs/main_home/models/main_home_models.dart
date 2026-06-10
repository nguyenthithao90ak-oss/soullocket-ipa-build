part of '../../main_home_tab.dart';

class _PartnerInteractionPreset {
  final String type;
  final String label;
  final String emoji;
  final String? assetPath;
  final int weight;
  final bool showInSmartSuggestion;
  final List<Color> gradient;
  final Color accent;
  final List<String> titles;
  final List<String> messages;

  const _PartnerInteractionPreset({
    required this.type,
    required this.label,
    required this.emoji,
    this.assetPath,
    required this.weight,
    this.showInSmartSuggestion = true,
    required this.gradient,
    required this.accent,
    required this.titles,
    required this.messages,
  });
}

class _CountdownQuickOption {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isPremium;

  const _CountdownQuickOption({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.isPremium = false,
  });
}

final List<_PartnerInteractionPreset> _kPartnerInteractionPresets = [
  _PartnerInteractionPreset(
    type: 'miss',
    label: L10nService().translate('home_nh_dbe2a3'),
    emoji: '\u{1F496}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
    weight: 42,
    gradient: [const Color(0xFFFFD8E6), const Color(0xFFFFF3F7)],
    accent: const Color(0xFFD94C86),
    titles: [
      L10nService().translate('home_bngthynhbn_bec395'),
      L10nService().translate('home_ninhhmnayl_c198ba'),
      L10nService().translate('home_vachmtimln_3276d5'),
      L10nService().translate('home_timvachuno_0ead05'),
    ],
    messages: [
      L10nService().translate('home_mnhnhbnnhi_0ce277'),
      L10nService().translate('home_nuangrnhth_106afb'),
      L10nService().translate('home_ninhnytbtl_d710d1'),
      L10nService().translate('home_hmnayappon_b24d85'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'angry',
    label: L10nService().translate('home_gin_6a4c8c'),
    emoji: '\u{1F63E}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_154.png',
    weight: 12,
    gradient: [const Color(0xFFFFE6DC), const Color(0xFFFFF6F2)],
    accent: const Color(0xFFE26A3A),
    titles: [
      L10nService().translate('home_hidibnmtxu_6797cf'),
      L10nService().translate('home_timbongang_723ae6'),
      L10nService().translate('home_ngitaangch_9bba64'),
      L10nService().translate('home_caivahihn_f4d08a'),
    ],
    messages: [
      L10nService().translate('home_dmnhmtculh_7fd032'),
      L10nService().translate('home_ginyuthinn_5571ec'),
      L10nService().translate('home_appnimnhan_6da32a'),
      L10nService().translate('home_nhnvythich_d803dc'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'furious',
    label: L10nService().translate('home_tc_b95b66'),
    emoji: '\u{1F621}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_049.png',
    weight: 7,
    showInSmartSuggestion: false,
    gradient: [const Color(0xFFFFD7DC), const Color(0xFFFFF1F3)],
    accent: const Color(0xFFE53935),
    titles: [
      L10nService().translate('home_angtcbnthi_64bf6d'),
      L10nService().translate('home_mtanghmhmc_fba5f5'),
      L10nService().translate('home_cctcnyangr_0e11a9'),
      L10nService().translate('home_appbomnhan_b7ae64'),
    ],
    messages: [
      L10nService().translate('home_tcthtnhaqu_271a15'),
      L10nService().translate('home_mnhanghnmt_8e8bfd'),
      L10nService().translate('home_ngcntcnyko_2d0b69'),
      L10nService().translate('home_tnhiutcgin_e4afb9'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'kiss',
    label: L10nService().translate('home_hn_fac010'),
    emoji: '\u{1F48B}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_047.png',
    weight: 18,
    gradient: [const Color(0xFFFFE1EC), const Color(0xFFFFF7FA)],
    accent: const Color(0xFFE14A8B),
    titles: [
      L10nService().translate('home_mtnhnbayti_86e78b'),
      L10nService().translate('home_chumimtcit_397222'),
      L10nService().translate('home_hmnaymunhn_497e6f'),
      L10nService().translate('home_nhnvacgii_525974'),
    ],
    messages: [
      L10nService().translate('home_chtmtcitht_853bb2'),
      L10nService().translate('home_mongsmchnb_a0d867'),
      L10nService().translate('home_nhnnyngtnh_b71d16'),
      L10nService().translate('home_btlynhnang_9777e9'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'tease',
    label: L10nService().translate('home_tru_d66cdf'),
    emoji: '\u{1F921}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_070.png',
    weight: 9,
    showInSmartSuggestion: false,
    gradient: [const Color(0xFFE8E1FF), const Color(0xFFF8F5FF)],
    accent: const Color(0xFF7B61D9),
    titles: [
      L10nService().translate('home_trubnmtcht_8d59f6'),
      L10nService().translate('home_ctnhiutinh_65cac5'),
      L10nService().translate('home_apprmnhchc_c0e0c1'),
      L10nService().translate('home_mtctrollsi_3e9083'),
    ],
    messages: [
      L10nService().translate('home_ngquumnhch_c8478e'),
      L10nService().translate('home_nhnlytnhiu_b1083d'),
      L10nService().translate('home_hmnaymnhmu_a37ef4'),
      L10nService().translate('home_cmxctinhng_880e07'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'hug',
    label: L10nService().translate('home_m_07a3b7'),
    emoji: '\u{1F428}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_082.png',
    weight: 17,
    gradient: [const Color(0xFFDDF3FF), const Color(0xFFF5FBFF)],
    accent: const Color(0xFF2D8FE3),
    titles: [
      L10nService().translate('home_munmbnthtc_8dbdc1'),
      L10nService().translate('home_mtcimmmang_a4337e'),
      L10nService().translate('home_gibncmgica_3316e3'),
      L10nService().translate('home_cimhmnayth_ed8aaa'),
    ],
    messages: [
      L10nService().translate('home_mmtcichomt_008c95'),
      L10nService().translate('home_nuhmnayhib_caad7f'),
      L10nService().translate('home_mnhmunbnth_006ca7'),
      L10nService().translate('home_cxemylmtch_a4c528'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'cry',
    label: L10nService().translate('home_khc_92394f'),
    emoji: '\u{1F62D}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_089.png',
    weight: 8,
    showInSmartSuggestion: false,
    gradient: [const Color(0xFFDDEBFF), const Color(0xFFF4F8FF)],
    accent: const Color(0xFF5B8DEF),
    titles: [
      L10nService().translate('home_hmnaymnhhi_f08993'),
      L10nService().translate('home_cmtchicman_356344'),
      L10nService().translate('home_timangmmxu_3e8961'),
      L10nService().translate('home_mnhangcnbn_a499ab'),
    ],
    messages: [
      L10nService().translate('home_hmnaymnhhi_40066d'),
      L10nService().translate('home_chmunbnmvn_7cc683'),
      L10nService().translate('home_nubnrnhthg_b3d8ae'),
      L10nService().translate('home_cmxchmnayh_3339d1'),
    ],
  ),
  _PartnerInteractionPreset(
    type: 'poop',
    label: 'Troll',
    emoji: '\u{1F4A9}',
    assetPath:
        'assets/images/interaction_stickers/custom/numbered/sticker_071.png',
    weight: 6,
    showInSmartSuggestion: false,
    gradient: [const Color(0xFFFFE1B9), const Color(0xFFFFF4E6)],
    accent: const Color(0xFFB96B2C),
    titles: [
      L10nService().translate('home_nmbnmtctro_d63911'),
      L10nService().translate('home_iconnychch_7c1d8c'),
      L10nService().translate('home_appvaxinph_8d0198'),
      L10nService().translate('home_coinhyltra_05d9cb'),
    ],
    messages: [
      L10nService().translate('home_ngginychlm_c57f3e'),
      L10nService().translate('home_nhnlychici_90dd44'),
      L10nService().translate('home_mnhgibnmtc_2c2f61'),
      L10nService().translate('home_chlchcnhth_1d0092'),
    ],
  ),
];

const Duration _kInteractionSuggestionRefreshInterval = Duration(minutes: 2);
const int _kReactionThrowBurstLimit = 30;
const Duration _kReactionThrowWindow = Duration(seconds: 15);
const Duration _kReactionFlightMaxReplayAge = Duration(seconds: 45);
const Duration _kReactionFlightListenGrace = Duration(seconds: 5);
const int _kMaxVisibleReactionFlights = 24;
const Duration _kWeatherReverseGeocodeCacheTtl = Duration(hours: 6);
const int _kWeatherReverseGeocodeCacheMaxEntries = 24;
const Duration _kWeatherRefreshSkipTtl = Duration(minutes: 12);
const Duration _kWeatherDuplicateWriteSkipTtl = Duration(minutes: 45);

_PartnerInteractionPreset? _maybePresetForInteractionType(String type) {
  for (final item in _kPartnerInteractionPresets) {
    if (item.type == type) {
      return item;
    }
  }
  return null;
}

Widget _buildInteractionVisual({
  required dynamic visual,
  String? assetPath,
  required double size,
  double? emojiSize,
  Color? iconColor,
  BoxFit fit = BoxFit.contain,
  List<Shadow>? emojiShadows,
  bool preferAsset = true,
}) {
  final resolvedAssetPath = assetPath != null && assetPath.trim().isNotEmpty
      ? assetPath.trim()
      : (visual is String && visual.startsWith('assets/') ? visual : null);

  if (preferAsset && resolvedAssetPath != null) {
    return Image.asset(
      resolvedAssetPath,
      width: size,
      height: size,
      fit: fit,
      isAntiAlias: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _buildInteractionVisual(
        visual: visual,
        size: size,
        emojiSize: emojiSize,
        iconColor: iconColor,
        fit: fit,
        emojiShadows: emojiShadows,
        preferAsset: false,
      ),
    );
  }

  if (visual is IconData) {
    return Icon(
      visual,
      size: 55,
      color: iconColor ?? Colors.white,
    );
  }

  return Center(
    child: Text(
      visual?.toString() ?? '',
      style: TextStyle(
        fontSize: 40,
        height: 1,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        fontFamilyFallback: const [
          'Noto Color Emoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
        ],
      ),
    ),
  );
}

_PartnerInteractionPreset _presetForInteractionType(String type) {
  return _kPartnerInteractionPresets.firstWhere(
    (item) => item.type == type,
    orElse: () => _kPartnerInteractionPresets.first,
  );
}

_PartnerInteractionPreset _defaultSmartInteractionPreset() {
  for (final item in _kPartnerInteractionPresets) {
    if (item.showInSmartSuggestion) return item;
  }
  return _kPartnerInteractionPresets.first;
}

String _emojiForInteractionType(String type) {
  final preset = _maybePresetForInteractionType(type);
  if (preset != null) return preset.emoji;
  return switch (type) {
    'hot' => '\u{1F4A7}',
    'warmth' => '\u{1F9E3}',
    _ => '\u{1F496}',
  };
}

class _HomeReactionFlight {
  final String id;
  final String fromRole;
  final String toRole;
  final String emoji;
  final String assetPath;
  final int sentAtMs;

  const _HomeReactionFlight({
    required this.id,
    required this.fromRole,
    required this.toRole,
    required this.emoji,
    this.assetPath = '',
    required this.sentAtMs,
  });

  bool get shootToRight => fromRole == 'user1';
}
