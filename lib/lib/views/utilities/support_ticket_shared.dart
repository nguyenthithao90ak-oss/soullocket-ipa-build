import 'package:soullocket_app/utils/services/l10n_service.dart';

class SupportTopicDefinition {
  const SupportTopicDefinition({
    required this.id,
    required this.chipLabel,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.requiredFields,
    required this.keywords,
  });

  final String id;
  final String chipLabel;
  final String title;
  final String subtitle;
  final String priority;
  final List<String> requiredFields;
  final List<String> keywords;
}

const String supportBuildName = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: '1.0.0',
);
const String supportBuildNumber = String.fromEnvironment(
  'FLUTTER_BUILD_NUMBER',
  defaultValue: '11',
);

String get supportAppVersionLabel =>
    'v$supportBuildName (build $supportBuildNumber)';

final List<SupportTopicDefinition> supportTopicCatalog = [
  SupportTopicDefinition(
    id: '1',
    chipLabel: L10nService().translate('util_tikhon_bbc710'),
    title: L10nService().translate('util_tikhonngnh_eba407'),
    subtitle: L10nService().translate('util_qunmtkhukh_047e0d'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_emailhoccc_ff2f9c'),
      L10nService().translate('util_bnngnhpbng_f2164d'),
      L10nService().translate('util_mnhnhnoang_5e0d35'),
      L10nService().translate('util_thngbolihi_2391f4'),
    ],
    keywords: [
      L10nService().translate('util_ngnhp_5f027d'),
      L10nService().translate('util_tikhon_ab3a50'),
      'email',
      L10nService().translate('util_mtkhu_8b7c6c'),
      'password',
      'login',
      'google',
      'apple',
      'facebook',
      L10nService().translate('util_qunmtkhu_e4e603'),
    ],
  ),
  SupportTopicDefinition(
    id: '2',
    chipLabel: L10nService().translate('util_ghpi_c374d8'),
    title: L10nService().translate('util_ghpimtktni_ddcd54'),
    subtitle: L10nService().translate('util_qrthamgian_2573bb'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_houseidhoc_aac628'),
      L10nService().translate('util_lixyratrnm_a8b481'),
      L10nService().translate('util_bnangngbcn_8052d9'),
      L10nService().translate('util_nucmttrngt_752b49'),
    ],
    keywords: [
      L10nService().translate('util_ghpi_f175c9'),
      'qr',
      L10nService().translate('util_ktni_36931a'),
      L10nService().translate('util_mnh_f293b9'),
      L10nService().translate('util_thamgianh_fb6185'),
      'house',
      'offline',
      'online',
      L10nService().translate('util_mtktni_dff6a9'),
    ],
  ),
  SupportTopicDefinition(
    id: '3',
    chipLabel: L10nService().translate('util_hnhnh_c868d5'),
    title: L10nService().translate('util_hnhnhvideo_0e879b'),
    subtitle:
        L10nService().translate('util_khngticnhm_187885'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_albumnhtkv_783431'),
      L10nService().translate('util_nidunghocn_c538a9'),
      L10nService().translate('util_bnvatilnch_9cac77'),
      L10nService().translate('util_nhvideobli_a02a41'),
    ],
    keywords: [
      L10nService().translate('util_nh_1ed361'),
      'video',
      L10nService().translate('util_nhtk_1b8c37'),
      'album',
      'upload',
      L10nService().translate('util_tinh_e4c67c'),
      'media',
      L10nService().translate('util_knim_61098c'),
    ],
  ),
  SupportTopicDefinition(
    id: '4',
    chipLabel: L10nService().translate('util_tikhon_453eec'),
    title: L10nService().translate('util_tikhonquyn_4f7faa'),
    subtitle: L10nService().translate('util_kimtratrng_be3f31'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_bnthaotcmn_4ac381'),
      L10nService().translate('util_thiimthaot_368a27'),
      L10nService().translate('util_thngbohint_a735e4'),
      L10nService().translate('util_bncnkimtra_840cc9'),
    ],
    keywords: [
      L10nService().translate('util_tikhon_ab3a50'),
      L10nService().translate('util_quynli_898c4c'),
      L10nService().translate('util_trngthi_8e1610'),
      L10nService().translate('util_kimtra_cdbca4'),
      L10nService().translate('util_htr_3f19ab'),
    ],
  ),
  SupportTopicDefinition(
    id: '5',
    chipLabel: L10nService().translate('util_imy_8cdb2f'),
    title: L10nService().translate('util_iinthoingb_0a3af2'),
    subtitle: L10nService().translate('util_imyciliapp_82b357'),
    priority: 'medium',
    requiredFields: [
      L10nService().translate('util_myclgvmymi_0476a9'),
      L10nService().translate('util_bnangngnhp_a63f64'),
      L10nService().translate('util_dliunoangt_3f7809'),
      L10nService().translate('util_bncngicmyc_aca572'),
    ],
    keywords: [
      L10nService().translate('util_imy_760f99'),
      L10nService().translate('util_inthoimi_28f18b'),
      L10nService().translate('util_ngb_0a52bc'),
      L10nService().translate('util_mtdliu_3b15e9'),
      L10nService().translate('util_cili_e4a078'),
      L10nService().translate('util_khiphcdliu_2c4ac7'),
    ],
  ),
  SupportTopicDefinition(
    id: '6',
    chipLabel: L10nService().translate('util_boli_5df258'),
    title: L10nService().translate('util_bolikthutg_ee1692'),
    subtitle:
        L10nService().translate('util_crashapptr_e06701'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_vnkthuthoc_17b4ee'),
      L10nService().translate('util_mnhnhtnhnn_88f01e'),
      L10nService().translate('util_ccbctihinl_8c3be0'),
      L10nService().translate('util_linhhngthn_4d6e7c'),
    ],
    keywords: [
      L10nService().translate('util_li_0c9ec1'),
      'bug',
      'crash',
      L10nService().translate('util_trngmnhnh_87aa01'),
      'lag',
      'treo',
      L10nService().translate('util_khnghin_e4735c'),
      L10nService().translate('util_gp_a4c3bb'),
      L10nService().translate('util_xut_5c3170'),
      L10nService().translate('util_tnhnng_d3cb43'),
    ],
  ),
  SupportTopicDefinition(
    id: '7',
    chipLabel: L10nService().translate('util_tnhcm_edefb8'),
    title: L10nService().translate('util_tvngritnhc_a9c56f'),
    subtitle: L10nService().translate('util_cnclngnghe_db51ce'),
    priority: 'medium',
    requiredFields: [
      L10nService().translate('util_bnangmuncl_37c9e2'),
      L10nService().translate('util_iulmbnbunh_439f48'),
      L10nService().translate('util_bnmunsoull_9fd43e'),
      L10nService().translate('util_ciugcntrnh_4f8ca9'),
    ],
    keywords: [
      L10nService().translate('util_bun_bff2fb'),
      L10nService().translate('util_cn_1fa6ea'),
      L10nService().translate('util_khc_291c9d'),
      L10nService().translate('util_tnhcm_516e30'),
      'chia tay',
      L10nService().translate('util_plc_eced84'),
      L10nService().translate('util_mtmi_1eb61e'),
      L10nService().translate('util_tms_45cdeb'),
    ],
  ),
  SupportTopicDefinition(
    id: '8',
    chipLabel: L10nService().translate('util_xanh_da3be7'),
    title: L10nService().translate('util_xatikhonxa_3f3624'),
    subtitle:
        L10nService().translate('util_rinhixatik_d3f334'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_bnmunrinhx_4458c5'),
      L10nService().translate('util_houseidhoc_98e978'),
      L10nService().translate('util_bnsaoludli_d4eb2e'),
      L10nService().translate('util_bncnhngdnh_5f6bb5'),
    ],
    keywords: [
      L10nService().translate('util_xatikhon_232744'),
      L10nService().translate('util_xanh_21d3f5'),
      L10nService().translate('util_rinh_422814'),
      L10nService().translate('util_hyghpi_90bde0'),
      'chia tay',
      L10nService().translate('util_ngtikhon_78f19f'),
    ],
  ),
  SupportTopicDefinition(
    id: '9',
    chipLabel: '🧑‍💻 Admin',
    title: L10nService().translate('util_gpadminhtr_e7f15b'),
    subtitle:
        L10nService().translate('util_cnadminkim_058bb2'),
    priority: 'high',
    requiredFields: [
      L10nService().translate('util_tmttngnvnc_b6c021'),
      L10nService().translate('util_tikhonhous_b61d39'),
      L10nService().translate('util_bncnadmink_56f479'),
      L10nService().translate('util_nucnhchpli_b6ac44'),
    ],
    keywords: [
      'admin',
      L10nService().translate('util_kimtratay_262ae4'),
      L10nService().translate('util_khn_120b18'),
      L10nService().translate('util_gpadmin_de1679'),
      L10nService().translate('util_htrtrctip_7a2f68'),
    ],
  ),
];

SupportTopicDefinition? supportTopicById(String? id) {
  if (id == null) return null;
  for (final topic in supportTopicCatalog) {
    if (topic.id == id.trim()) {
      return topic;
    }
  }
  return null;
}

SupportTopicDefinition? supportTopicByText(String? rawText) {
  final text = normalizeSupportText(rawText ?? '');
  if (text.isEmpty) return null;

  final byId = supportTopicById(text);
  if (byId != null) return byId;

  for (final topic in supportTopicCatalog) {
    if (topic.keywords.any(text.contains)) {
      return topic;
    }
  }
  return null;
}

String normalizeSupportText(String value) => value.trim().toLowerCase();

String buildSupportDraft(
  SupportTopicDefinition topic, {
  required String contextLabel,
  required String appVersionLabel,
}) {
  final prompts = <String>[
    L10nService().translate('util_tmttngnvna_6929b0'),
    ...topic.requiredFields,
    L10nService().translate('util_ccbcbnthri_d20100'),
    L10nService().translate('util_mcnhhngcnh_808532'),
  ];

  final buffer = StringBuffer()
    ..writeln('[${topic.title.toUpperCase()}]')
    ..writeln(L10nService().translate('util_incngthngt_99a61c'))
    ..writeln();

  for (final prompt in prompts) {
    buffer.writeln('- $prompt');
  }

  final autoAttached = <String>[];
  if (contextLabel.trim().isNotEmpty) {
    autoAttached.add(contextLabel.trim());
  }
  if (appVersionLabel.trim().isNotEmpty) {
    autoAttached.add(appVersionLabel.trim());
  }
  if (autoAttached.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(L10nService().translate('util_thngtinhth_bfb4c1'))
      ..writeln('- ${autoAttached.join(' • ')}');
  }

  return buffer.toString().trimRight();
}

String buildSupportSummary(
  String text, {
  SupportTopicDefinition? topic,
}) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !line.startsWith('['))
      .where((line) => !line.startsWith(L10nService().translate('util_thngtinhth_71b4d7')))
      .toList();

  var snippet = '';
  for (final line in lines) {
    final cleaned = line.startsWith('- ') ? line.substring(2).trim() : line;
    if (!cleaned.contains(':')) {
      snippet = cleaned;
      break;
    }

    final parts = cleaned.split(':');
    if (parts.length < 2) {
      continue;
    }

    final value = parts.sublist(1).join(':').trim();
    if (value.isNotEmpty) {
      snippet = value;
      break;
    }
  }

  if (snippet.isEmpty) {
    snippet = topic?.subtitle ?? L10nService().translate('util_ngidngcnch_2580cd');
  }

  if (snippet.length > 140) {
    snippet = '${snippet.substring(0, 137).trimRight()}...';
  }

  if (topic == null) {
    return snippet;
  }

  return '${topic.title}: $snippet';
}

String buildSupportContextLabel(Map<String, String> context) {
  final parts = <String>[];
  final email = (context['email'] ?? '').trim();
  final uid = (context['uid'] ?? '').trim();
  final houseId = (context['houseId'] ?? '').trim();
  final deviceModel = (context['deviceModel'] ?? '').trim();
  final devicePlatform = (context['devicePlatform'] ?? '').trim();
  final deviceOs = (context['deviceOs'] ?? '').trim();

  if (email.isNotEmpty) {
    parts.add(email);
  } else if (uid.isNotEmpty) {
    parts.add('UID $uid');
  }

  if (houseId.isNotEmpty) {
    parts.add('House $houseId');
  }

  final deviceParts = <String>[];
  if (deviceModel.isNotEmpty) {
    deviceParts.add(deviceModel);
  }
  if (devicePlatform.isNotEmpty) {
    deviceParts.add(devicePlatform);
  }
  if (deviceOs.isNotEmpty) {
    deviceParts.add(deviceOs);
  }
  if (deviceParts.isNotEmpty) {
    parts.add(deviceParts.join(' • '));
  }

  return parts.join(' • ');
}

Map<String, String> normalizeSupportContext(Map<dynamic, dynamic>? raw) {
  final normalized = <String, String>{};
  if (raw == null) {
    return normalized;
  }

  for (final entry in raw.entries) {
    final key = entry.key?.toString().trim() ?? '';
    if (key.isEmpty) {
      continue;
    }
    normalized[key] = entry.value?.toString().trim() ?? '';
  }
  return normalized;
}
