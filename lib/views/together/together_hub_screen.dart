import 'package:flutter/material.dart';

import '../../utils/services/l10n_service.dart';
import '../../widgets/sl_feedback.dart';
import '../utilities/widgets/keepsake_design.dart';

enum TogetherActivity { soulMerge, soulBlock, drawing, collage }

/// Danh sách hoạt động hiện có; không tải dữ liệu hay tự khởi tạo màn con.
class TogetherHubScreen extends StatefulWidget {
  const TogetherHubScreen({
    super.key,
    required this.isSingle,
    required this.onOpenActivity,
  });

  final bool isSingle;
  final Future<void> Function(TogetherActivity activity) onOpenActivity;

  @override
  State<TogetherHubScreen> createState() => _TogetherHubScreenState();
}

class _TogetherHubScreenState extends State<TogetherHubScreen> {
  bool _openingActivity = false;

  Future<void> _openActivity(TogetherActivity activity) async {
    if (_openingActivity) return;
    _openingActivity = true;
    try {
      await widget.onOpenActivity(activity);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('together_open_error'))),
      );
    } finally {
      _openingActivity = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(
      widget.isSingle ? 'together_hub_solo_title' : 'together_hub_title',
    );
    return Scaffold(
      key: const ValueKey('together-hub-screen'),
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 28),
          children: [
            KeepsakeHeader(
              title: title,
              subtitle: context.tr(
                widget.isSingle
                    ? 'together_hub_solo_description'
                    : 'together_hub_description',
              ),
              icon: Icons.interests_outlined,
            ),
            _TogetherSectionTitle(label: context.tr('together_group_play')),
            if (!widget.isSingle) ...[
              _TogetherActivityCard(
                key: const ValueKey('together-soul-merge'),
                title: context.tr('p4_soul_title'),
                description: context.tr('together_merge_description'),
                badge: context.tr('together_badge_pair'),
                icon: Icons.favorite_border_rounded,
                featured: true,
                onTap: () => _openActivity(TogetherActivity.soulMerge),
              ),
              const SizedBox(height: 12),
            ],
            _TogetherActivityCard(
              key: const ValueKey('together-soul-block'),
              title: context.tr('game_soul_block_name'),
              description: context.tr('together_block_description'),
              badge: context.tr('together_badge_solo'),
              icon: Icons.extension_outlined,
              onTap: () => _openActivity(TogetherActivity.soulBlock),
            ),
            const SizedBox(height: 28),
            _TogetherSectionTitle(label: context.tr('together_group_create')),
            _TogetherActivityCard(
              key: const ValueKey('together-drawing'),
              title: context.tr('utility_title_drawing'),
              description: context.tr('together_drawing_description'),
              badge: context.tr('together_badge_local'),
              icon: Icons.gesture_rounded,
              onTap: () => _openActivity(TogetherActivity.drawing),
            ),
            const SizedBox(height: 12),
            _TogetherActivityCard(
              key: const ValueKey('together-collage'),
              title: context.tr('utility_title_collage'),
              description: context.tr('together_collage_description'),
              badge: context.tr('together_badge_solo'),
              icon: Icons.photo_library_outlined,
              onTap: () => _openActivity(TogetherActivity.collage),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogetherSectionTitle extends StatelessWidget {
  const _TogetherSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: KeepsakeStyle.text(context, size: 15, weight: FontWeight.w600),
      ),
    ),
  );
}

class _TogetherActivityCard extends StatelessWidget {
  const _TogetherActivityCard({
    super.key,
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
    required this.onTap,
    this.featured = false,
  });

  final String title;
  final String description;
  final String badge;
  final IconData icon;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: featured
          ? KeepsakeStyle.accentSurface(context)
          : KeepsakeStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: KeepsakeStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: featured
                            ? KeepsakeStyle.surface(context)
                            : KeepsakeStyle.accentSurface(context),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          icon,
                          size: 24,
                          color: KeepsakeStyle.accent(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: KeepsakeStyle.text(
                            context,
                            size: 17,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge,
                          style: KeepsakeStyle.text(
                            context,
                            size: 11,
                            weight: FontWeight.w600,
                            color: KeepsakeStyle.accent(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      textDirection: Directionality.of(context),
                      color: KeepsakeStyle.muted(context),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: KeepsakeStyle.text(
                  context,
                  size: 13,
                  color: KeepsakeStyle.muted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
