part of '../../love_card_screen.dart';

class _LoveThemeData {
  final String key;
  final String chip;
  final String title;
  final String subtitle;
  final String signature;
  final String effectLabel;
  final IconData icon;
  final IconData accentIcon;
  final List<int> colors;
  final List<String> suggestions;

  const _LoveThemeData({
    required this.key,
    required this.chip,
    required this.title,
    required this.subtitle,
    required this.signature,
    required this.effectLabel,
    required this.icon,
    required this.accentIcon,
    required this.colors,
    required this.suggestions,
  });
}

final Map<String, _LoveThemeData> _loveCardThemes = {
  'love': _LoveThemeData(
    key: 'love',
    chip: L10nService().translate('util_tnhyu_2814db'),
    title: L10nService().translate('util_dudngvmp_f089f1'),
    subtitle: L10nService().translate('util_mttmthipng_edf010'),
    signature: L10nService().translate('util_tngilunnhb_c60ef5'),
    effectLabel: L10nService().translate('util_tritimlpln_02cb79'),
    icon: Icons.favorite_rounded,
    accentIcon: Icons.auto_awesome_rounded,
    colors: [0xFFFF8A9A, 0xFFFFB7B2],
    suggestions: [
      L10nService().translate('util_hmnayemchm_044f98'),
      L10nService().translate('util_cmnanhvlun_c91c56'),
      L10nService().translate('util_nucmtiuemm_ca0d9f'),
    ],
  ),
  'birthday': _LoveThemeData(
    key: 'birthday',
    chip: L10nService().translate('util_sinhnht_71c600'),
    title: L10nService().translate('util_rcrvvuiti_6474ca'),
    subtitle: L10nService().translate('util_gimtlichcs_98053f'),
    signature: L10nService().translate('util_chcmngsinh_1db118'),
    effectLabel: L10nService().translate('util_phogiybngn_b5a4e9'),
    icon: Icons.cake_rounded,
    accentIcon: Icons.celebration_rounded,
    colors: [0xFFFAD0C4, 0xFFFFD1FF],
    suggestions: [
      L10nService().translate('util_chcngiemth_aa51d4'),
      L10nService().translate('util_tuimichmon_39d4fa'),
      L10nService().translate('util_sinhnhtnye_c15d9e'),
    ],
  ),
  'anniversary': _LoveThemeData(
    key: 'anniversary',
    chip: L10nService().translate('util_knim_4f6aeb'),
    title: L10nService().translate('util_trangtrngv_a5c5a8'),
    subtitle: L10nService().translate('util_lmnibtctmc_3d3dd8'),
    signature: L10nService().translate('util_mtngyngnhc_02e59f'),
    effectLabel: L10nService().translate('util_hoquangkc_1a4d18'),
    icon: Icons.diamond_rounded,
    accentIcon: Icons.workspace_premium_rounded,
    colors: [0xFFA1C4FD, 0xFFC2E9FB],
    suggestions: [
      L10nService().translate('util_thmmtctmcn_3bd0b1'),
      L10nService().translate('util_cmnanhvcng_10ce9b'),
      L10nService().translate('util_miknimvian_00727b'),
    ],
  ),
  'miss': _LoveThemeData(
    key: 'miss',
    chip: L10nService().translate('util_nhnhau_5dc5c1'),
    title: L10nService().translate('util_nhnhngvsul_592c70'),
    subtitle: L10nService().translate('util_hpchonhngl_122496'),
    signature: L10nService().translate('util_nhbnnhiulm_fcda3f'),
    effectLabel: L10nService().translate('util_msaodum_19d800'),
    icon: Icons.nights_stay_rounded,
    accentIcon: Icons.star_rounded,
    colors: [0xFFBDB2FF, 0xFFFFC6FF],
    suggestions: [
      L10nService().translate('util_chlhmnayem_258ff3'),
      L10nService().translate('util_nucchnmtni_49f5c3'),
      L10nService().translate('util_cnhngngyem_63cc72'),
    ],
  ),
};
