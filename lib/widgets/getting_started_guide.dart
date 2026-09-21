import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/services/l10n_service.dart';
import 'first_setup_guide_progress.dart';

enum GettingStartedTopic { account, memory, pairing }

enum GettingStartedResult { read, openFeature }

bool _articleOpen = false;

extension GettingStartedTopicContent on GettingStartedTopic {
  String get titleKey => 'starter_${name}_title';
  String get bodyKey => 'starter_${name}_body';
  IconData get icon => switch (this) {
    GettingStartedTopic.account => Icons.home_outlined,
    GettingStartedTopic.memory => Icons.auto_stories_outlined,
    GettingStartedTopic.pairing => Icons.link_rounded,
  };
}

/// Nội dung offline; mở bài không cấp quyền, gửi lời mời hay tạo dữ liệu thử.
Future<GettingStartedResult?> showGettingStartedArticle(
  BuildContext context,
  GettingStartedTopic topic, {
  bool canOpenFeature = false,
  bool trackReading = false,
}) async {
  if (_articleOpen ||
      !context.mounted ||
      !(ModalRoute.of(context)?.isCurrent ?? true)) {
    return null;
  }
  _articleOpen = true;
  try {
    return await showModalBottomSheet<GettingStartedResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFFFCF8),
      builder: (context) => FractionallySizedBox(
        heightFactor: .9,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(topic.icon, color: const Color(0xFFAC4E6C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr(topic.titleKey),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF392E34),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(topic.bodyKey),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF51434B),
                  ),
                ),
                if (topic == GettingStartedTopic.pairing)
                  for (var step = 1; step <= 4; step++) ...[
                    const SizedBox(height: 20),
                    Text(
                      context.tr('pairing_ui_guide_step_${step}_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF392E34),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('pairing_ui_guide_step_${step}_body'),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF51434B),
                      ),
                    ),
                  ],
                const SizedBox(height: 24),
                Text(
                  context.tr('starter_read_note'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF6B5963),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, GettingStartedResult.read),
                      child: Text(
                        context.tr(
                          trackReading ? 'starter_mark_read' : 'core_done',
                        ),
                      ),
                    ),
                    if (canOpenFeature)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFAC4E6C),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(
                          context,
                          GettingStartedResult.openFeature,
                        ),
                        child: Text(context.tr('starter_open_feature')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    _articleOpen = false;
  }
}

class GettingStartedHelpButton extends StatelessWidget {
  final GettingStartedTopic topic;
  const GettingStartedHelpButton({super.key, required this.topic});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => showGettingStartedArticle(context, topic),
    icon: const Icon(Icons.help_outline_rounded, size: 20),
    label: Text(context.tr(topic.titleKey)),
  );
}

/// Checklist chỉ ghi nhận đã đọc, không suy đoán kết quả ghi dữ liệu trên cloud.
class GettingStartedChecklist extends StatefulWidget {
  static final ValueNotifier<int> changes = ValueNotifier(0);
  final String uid;
  final String houseId;
  final bool isSingle;
  final bool alwaysVisible;
  final bool Function()? isStillValid;
  final ValueChanged<GettingStartedTopic>? onOpenFeature;

  const GettingStartedChecklist({
    super.key,
    required this.uid,
    required this.houseId,
    required this.isSingle,
    this.alwaysVisible = false,
    this.isStillValid,
    this.onOpenFeature,
  });

  @override
  State<GettingStartedChecklist> createState() =>
      _GettingStartedChecklistState();
}

class _GettingStartedChecklistState extends State<GettingStartedChecklist> {
  SharedPreferences? _prefs;
  Set<GettingStartedTopic> _read = {};
  bool _ready = false;
  bool _hidden = false;
  bool _expanded = false;
  bool _opening = false;
  int _generation = 0;

  String get _key => SetupGuideProgress.scopedKey(
    widget.uid,
    widget.houseId,
    'starter_read_v1',
  );
  bool get _valid => mounted && (widget.isStillValid?.call() ?? true);

  @override
  void initState() {
    super.initState();
    _expanded = widget.alwaysVisible;
    GettingStartedChecklist.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    GettingStartedChecklist.changes.removeListener(_load);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GettingStartedChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.houseId != widget.houseId) {
      _read = {};
      _ready = false;
      _hidden = false;
      _expanded = widget.alwaysVisible;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_valid || generation != _generation) return;
      _prefs = prefs;
      final stored = prefs.getStringList(_key) ?? [];
      _read = GettingStartedTopic.values
          .where((topic) => stored.contains(topic.name))
          .toSet();
      _hidden = prefs.getBool('${_key}_hidden') ?? false;
    } catch (_) {
      // Vẫn cho đọc bài khi bộ nhớ tiến độ không khả dụng.
    }
    if (_valid && generation == _generation) setState(() => _ready = true);
  }

  Future<void> _setHidden(bool hidden) async {
    if (!_valid) return;
    setState(() => _hidden = hidden);
    try {
      await _prefs?.setBool('${_key}_hidden', hidden);
      if (_prefs != null) GettingStartedChecklist.changes.value++;
    } catch (_) {}
  }

  Future<void> _open(GettingStartedTopic topic) async {
    if (_opening || !_valid) return;
    final generation = _generation;
    final key = _key;
    setState(() => _opening = true);
    final result = await showGettingStartedArticle(
      context,
      topic,
      canOpenFeature: widget.onOpenFeature != null,
      trackReading: true,
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (!_valid || generation != _generation || key != _key) return;
    if (result == GettingStartedResult.read) {
      setState(() => _read.add(topic));
      try {
        await _prefs?.setStringList(
          key,
          _read.map((topic) => topic.name).toList(),
        );
        if (_prefs != null) GettingStartedChecklist.changes.value++;
      } catch (_) {}
    } else if (result == GettingStartedResult.openFeature) {
      widget.onOpenFeature?.call(topic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready ||
        widget.uid.isEmpty ||
        widget.houseId.isEmpty ||
        (_hidden && !widget.alwaysVisible)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEADDDC)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(
                Icons.explore_outlined,
                color: Color(0xFFAC4E6C),
              ),
              title: Text(
                context.tr('starter_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF392E34),
                ),
              ),
              subtitle: Text(
                '${context.tr('starter_read_status')} ${_read.length}/${GettingStartedTopic.values.length}',
                style: const TextStyle(color: Color(0xFF6B5963)),
              ),
              trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF6B5963),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr(
                        widget.isSingle
                            ? 'starter_single_intro'
                            : 'starter_couple_intro',
                      ),
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xFF6B5963),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final topic in GettingStartedTopic.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          topic.icon,
                          color: const Color(0xFFAC4E6C),
                        ),
                        title: Text(
                          context.tr(topic.titleKey),
                          style: const TextStyle(color: Color(0xFF392E34)),
                        ),
                        subtitle: _read.contains(topic)
                            ? Text(
                                context.tr('starter_read_status'),
                                style: const TextStyle(
                                  color: Color(0xFF526B5A),
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF6B5963),
                        ),
                        onTap: _opening ? null : () => _open(topic),
                      ),
                    Text(
                      context.tr('starter_read_note'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF6B5963),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () =>
                            _setHidden(widget.alwaysVisible ? !_hidden : true),
                        child: Text(
                          context.tr(
                            widget.alwaysVisible && _hidden
                                ? 'starter_show_home'
                                : 'starter_hide',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
