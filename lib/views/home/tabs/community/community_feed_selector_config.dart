part of '../community_tab.dart';

class _CommunityFeedSelectorOption {
  const _CommunityFeedSelectorOption({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;
}

List<_CommunityFeedSelectorOption> _communityFeedSelectorOptions() {
  return <_CommunityFeedSelectorOption>[
    _CommunityFeedSelectorOption(
      value: 'foryou',
      icon: Icons.explore_rounded,
      label: _ct('Dành Cho Bạn', 'For You'),
    ),
    _CommunityFeedSelectorOption(
      value: 'locket',
      icon: Icons.camera_alt_rounded,
      label: _ct('Khoảnh Khắc (Locket)', 'Moments (Locket)'),
    ),
    _CommunityFeedSelectorOption(
      value: 'global',
      icon: Icons.public,
      label: _ct('Toàn Cầu', 'Global'),
    ),
    _CommunityFeedSelectorOption(
      value: 'friends',
      icon: Icons.people,
      label: _ct('Bạn Bè', 'Friends'),
    ),
    _CommunityFeedSelectorOption(
      value: 'hot',
      icon: Icons.local_fire_department,
      label: _ct('Top Hot 🔥', 'Top Hot 🔥'),
    ),
  ];
}

String _communityFeedLabel(String value) {
  for (final option in _communityFeedSelectorOptions()) {
    if (option.value == value) {
      return option.label;
    }
  }
  return _ct('Dành Cho Bạn', 'For You');
}

IconData _communityFeedIcon(String value) {
  for (final option in _communityFeedSelectorOptions()) {
    if (option.value == value) {
      return option.icon;
    }
  }
  return Icons.explore_rounded;
}
