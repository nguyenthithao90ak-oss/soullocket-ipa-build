import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/services/l10n_service.dart';
import 'getting_started_guide.dart';

enum HelpPlatform { android, ios, web, other }

HelpPlatform get currentHelpPlatform => kIsWeb
    ? HelpPlatform.web
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => HelpPlatform.android,
        TargetPlatform.iOS => HelpPlatform.ios,
        _ => HelpPlatform.other,
      };

class AppHelpArticle {
  const AppHelpArticle(this.id, this.titleKey, this.icon, this.bodyKeys);
  final String id;
  final String titleKey;
  final IconData icon;
  final List<String> bodyKeys;
}

/// Nội dung đóng gói, không truy vấn tài khoản, GPS hay dữ liệu người dùng.
List<AppHelpArticle> appHelpArticles(HelpPlatform platform) => [
  for (final topic in GettingStartedTopic.values)
    AppHelpArticle(topic.name, topic.titleKey, topic.icon, [
      topic.bodyKey,
      if (topic == GettingStartedTopic.pairing)
        for (var i = 1; i <= 4; i++) ...[
          'pairing_ui_guide_step_${i}_title',
          'pairing_ui_guide_step_${i}_body',
        ],
    ]),
  AppHelpArticle('gps', 'map_refresh_privacy', Icons.location_on_outlined, [
    'map_refresh_privacy_body',
    'help_location_stop',
    if (platform == HelpPlatform.web) 'map_refresh_browser_body',
    'map_refresh_service_off',
    'map_refresh_service_off_body',
    'map_refresh_permission_blocked',
    'map_refresh_permission_blocked_body',
    'map_refresh_approximate',
    'map_refresh_approximate_body',
    'map_refresh_waiting',
    'map_refresh_waiting_body',
    'map_refresh_last_position',
    'map_refresh_stale_distance',
    'map_refresh_unavailable',
    'map_refresh_unavailable_body',
  ]),
  const AppHelpArticle(
    'security',
    'help_security_title',
    Icons.lock_outline_rounded,
    ['help_security_body'],
  ),
  const AppHelpArticle(
    'personalize',
    'home_tychnhvngm_09a3bd',
    Icons.tune_rounded,
    ['help_personalize_body'],
  ),
  AppHelpArticle('widget', 'help_widget_title', Icons.widgets_outlined, [
    'help_widget_intro',
    switch (platform) {
      HelpPlatform.android => 'help_widget_android',
      HelpPlatform.ios => 'ios_widget_pin_guide',
      _ => 'help_widget_web',
    },
    if (platform == HelpPlatform.android || platform == HelpPlatform.ios)
      'help_widget_refresh',
  ]),
  const AppHelpArticle('utilities', 'nav_apps', Icons.search_rounded, [
    'help_utilities_body',
  ]),
  const AppHelpArticle(
    'recovery',
    'help_recovery_title',
    Icons.support_agent_rounded,
    ['help_recovery_body', 'guide_safe_recovery'],
  ),
];

String normalizeHelpQuery(String value) {
  var result = value.toLowerCase().trim();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵäå',
    'e': 'èéẹẻẽêềếệểễë',
    'i': 'ìíịỉĩîï',
    'o': 'òóọỏõôồốộổỗơờớợởỡö',
    'u': 'ùúụủũưừứựửữûü',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in groups.entries) {
    for (final rune in entry.value.runes) {
      result = result.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

List<AppHelpArticle> searchAppHelp(
  String query,
  HelpPlatform platform,
  String Function(String) translate,
) {
  final words = normalizeHelpQuery(
    query,
  ).split(' ').where((word) => word.isNotEmpty);
  return appHelpArticles(platform)
      .where((article) {
        final text = normalizeHelpQuery(
          [
            translate(article.titleKey),
            ...article.bodyKeys.map(translate),
          ].join(' '),
        );
        return words.every(text.contains);
      })
      .toList(growable: false);
}

bool _helpArticleOpen = false;

/// Trả về true chỉ khi người dùng tự chọn “Mở tính năng”. Không chạy tác vụ ngầm.
Future<bool> showAppHelpArticle(
  BuildContext context,
  String id, {
  bool canOpenFeature = false,
  String? statusKey,
  HelpPlatform? platform,
}) async {
  if (_helpArticleOpen ||
      !context.mounted ||
      !(ModalRoute.of(context)?.isCurrent ?? true)) {
    return false;
  }
  final articles = appHelpArticles(
    platform ?? currentHelpPlatform,
  ).where((article) => article.id == id);
  if (articles.isEmpty) return false;
  final article = articles.first;
  _helpArticleOpen = true;
  try {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: const Color(0xFFFFFCF8),
          builder: (context) => FractionallySizedBox(
            heightFactor: .9,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(article.icon, color: const Color(0xFFAC4E6C)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr(article.titleKey),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF392E34),
                            ),
                          ),
                        ),
                        IconButton(
                          color: const Color(0xFF51434B),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (statusKey != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          context.tr(statusKey),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAC4E6C),
                          ),
                        ),
                      ),
                    for (final key in article.bodyKeys)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          context.tr(key),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: const Color(0xFF51434B),
                            fontWeight:
                                key.endsWith('_body') ||
                                    key.startsWith('help_') ||
                                    key.startsWith('starter_')
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFAC4E6C),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.tr('core_done')),
                        ),
                        if (canOpenFeature)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFAC4E6C),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.tr('starter_open_feature')),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  } finally {
    _helpArticleOpen = false;
  }
}

class AppHelpButton extends StatelessWidget {
  const AppHelpButton({
    super.key,
    required this.articleId,
    this.iconOnly = false,
    this.statusKey,
  });
  final String articleId;
  final bool iconOnly;
  final String? statusKey;
  @override
  Widget build(BuildContext context) {
    final title = appHelpArticles(
      currentHelpPlatform,
    ).firstWhere((a) => a.id == articleId).titleKey;
    void open() => showAppHelpArticle(context, articleId, statusKey: statusKey);
    return iconOnly
        ? IconButton(
            tooltip: context.tr(title),
            onPressed: open,
            icon: const Icon(Icons.help_outline_rounded),
          )
        : TextButton.icon(
            onPressed: open,
            icon: const Icon(Icons.help_outline_rounded, size: 20),
            label: Text(context.tr(title)),
          );
  }
}

class AppHelpCenterScreen extends StatefulWidget {
  const AppHelpCenterScreen({
    super.key,
    this.featureActions = const {},
    this.onSupport,
    this.onReplayHome,
    this.onReplaySettings,
    this.isStillValid,
    this.platform,
  });
  final Map<String, VoidCallback> featureActions;
  final VoidCallback? onSupport;
  final VoidCallback? onReplayHome;
  final VoidCallback? onReplaySettings;
  final bool Function()? isStillValid;
  final HelpPlatform? platform;
  @override
  State<AppHelpCenterScreen> createState() => _AppHelpCenterScreenState();
}

class _AppHelpCenterScreenState extends State<AppHelpCenterScreen> {
  final _search = TextEditingController();
  bool _opening = false;
  bool get _valid => mounted && (widget.isStillValid?.call() ?? true);
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _leaveFor(VoidCallback? action) {
    if (action == null ||
        !_valid ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    // Đóng trung tâm trước khi mở tính năng/tour để không chồng route.
    final isStillValid = widget.isStillValid;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStillValid?.call() ?? true) action();
    });
  }

  Future<void> _open(AppHelpArticle article) async {
    if (_opening) return;
    setState(() => _opening = true);
    final openFeature = await showAppHelpArticle(
      context,
      article.id,
      platform: widget.platform,
      canOpenFeature: _valid && widget.featureActions.containsKey(article.id),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (openFeature && _valid) _leaveFor(widget.featureActions[article.id]);
  }

  @override
  Widget build(BuildContext context) {
    final results = searchAppHelp(
      _search.text,
      widget.platform ?? currentHelpPlatform,
      context.tr,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF8),
        foregroundColor: const Color(0xFF392E34),
        title: Text(context.tr('auth_guide_short')),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  context.tr('help_intro'),
                  style: const TextStyle(height: 1.5, color: Color(0xFF6B5963)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  style: const TextStyle(color: Color(0xFF392E34)),
                  cursorColor: const Color(0xFFAC4E6C),
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(color: Color(0xFF6B5963)),
                    prefixIconColor: const Color(0xFF6B5963),
                    suffixIconColor: const Color(0xFF6B5963),
                    labelText: context.tr('help_search'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.tr('messenger_clear_search'),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.tr('help_empty'),
                      style: const TextStyle(color: Color(0xFF51434B)),
                    ),
                  ),
                for (final article in results)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      leading: Icon(
                        article.icon,
                        color: const Color(0xFFAC4E6C),
                      ),
                      title: Text(
                        context.tr(article.titleKey),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF392E34),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF6B5963),
                      ),
                      onTap: _opening ? null : () => _open(article),
                    ),
                  ),
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onReplayHome != null)
                      TextButton(
                        onPressed: () => _leaveFor(widget.onReplayHome),
                        child: Text(context.tr('guide_replay_home')),
                      ),
                    if (widget.onReplaySettings != null)
                      TextButton(
                        onPressed: () => _leaveFor(widget.onReplaySettings),
                        child: Text(context.tr('guide_replay_settings')),
                      ),
                    if (widget.onSupport != null)
                      TextButton.icon(
                        onPressed: () => _leaveFor(widget.onSupport),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: Text(context.tr('support_center')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
