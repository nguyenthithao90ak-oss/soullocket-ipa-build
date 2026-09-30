import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/love_insight_service.dart';
import 'insight_profile_avatar.dart';

class HomeInsightCard extends StatelessWidget {
  final LoveInsightData? data;
  final bool isSingle;
  final String nameU1;
  final String nameU2;
  final String avatarU1;
  final String avatarU2;
  final String updatedAtText;
  final VoidCallback onTap;
  final Widget? dragHandle;

  const HomeInsightCard({
    super.key,
    required this.data,
    required this.isSingle,
    required this.nameU1,
    required this.nameU2,
    required this.avatarU1,
    required this.avatarU2,
    required this.updatedAtText,
    required this.onTap,
    this.dragHandle,
  });

  static const _ink = Color(0xFF492E3A);
  static const _muted = Color(0xFF806C73);
  static const _rose = Color(0xFF99516B);

  @override
  Widget build(BuildContext context) {
    final insight = data;
    final title = context.tr(
      isSingle ? 'home_tngquanhmn_0e1b6b' : 'home_hnhtrnhiqu_cbcf59',
    );
    return Material(
      key: const ValueKey('home-insight-card'),
      color: const Color(0xFFFFFBF8),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E8EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 20,
                      color: _rose,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ?dragHandle,
                  const Icon(Icons.chevron_right_rounded, color: _rose),
                ],
              ),
              const SizedBox(height: 18),
              if (insight == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    context.tr('home_anggomthmc_0715ce'),
                    style: SLTheme.quicksand(color: _muted, height: 1.5),
                  ),
                )
              else ...[
                _buildOverview(context, insight),
                const SizedBox(height: 16),
                _buildAdvice(context, insight),
                const SizedBox(height: 12),
                Text(
                  context.tr('insight_score_note'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 10,
                    height: 1.5,
                    color: _muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context, LoveInsightData insight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF693149), Color(0xFF9B4B66)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              isSingle ? 'home_chshotng_328c7a' : 'home_chshnhphc_7c8e85',
            ),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFDFE5),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final score = _buildScore(context, insight);
              if (isSingle) return Center(child: score);
              final first = _buildMember(
                context,
                role: 'user1',
                name: nameU1,
                avatar: avatarU1,
                value: insight.loveU1,
              );
              final second = _buildMember(
                context,
                role: 'user2',
                name: nameU2,
                avatar: avatarU2,
                value: insight.loveU2,
              );
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(12) > 17) {
                return Column(
                  children: [
                    score,
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 16),
                        Expanded(child: second),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: first),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: score,
                  ),
                  Expanded(child: second),
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFAE788A)),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              _buildSummary(
                Icons.local_fire_department_outlined,
                L10nService().translateActiveDays(insight.activeDays),
              ),
              _buildSummary(
                Icons.collections_bookmark_outlined,
                L10nService().translateMemoriesPerMonth(
                  insight.memoryThisMonth,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMember(
    BuildContext context, {
    required String role,
    required String name,
    required String avatar,
    required int value,
  }) {
    final displayName = name.trim().isEmpty
        ? context.tr(role == 'user1' ? 'home_bn_1fd75b' : 'home_ngiy_5bab37')
        : name.trim();
    return Column(
      key: ValueKey('home-insight-$role'),
      children: [
        InsightProfileAvatar(name: displayName, avatarUrl: avatar, size: 60),
        const SizedBox(height: 8),
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.clamp(0, 100)}/100',
          style: SLTheme.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFD2BF),
          ),
        ),
      ],
    );
  }

  Widget _buildScore(BuildContext context, LoveInsightData insight) {
    final score = insight.loveScore.clamp(0, 100);
    return Semantics(
      label: context.tr(
        isSingle ? 'insight_title_single' : 'insight_title_couple',
      ),
      value: '$score/100',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 60,
                color: Color(0xFF9C6076),
              ),
              Positioned.fill(
                child: CircularProgressIndicator(
                  key: const ValueKey('home-insight-score'),
                  value: score / 100,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: const Color(0xFFFFCEB7),
                  backgroundColor: const Color(0xFFAD7488),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    children: [
                      Text(
                        '$score',
                        style: SLTheme.quicksand(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '/100',
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          color: const Color(0xFFFFDFE5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFFFD2BF)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFE6D7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvice(BuildContext context, LoveInsightData insight) {
    final suggestion = insight.suggestion.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('home_linhndudng_83e5d9'),
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _rose,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          suggestion.isEmpty
              ? context.tr(
                  isSingle
                      ? 'insight_advice_single_low'
                      : 'insight_advice_couple_low',
                )
              : suggestion,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 12,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        if (updatedAtText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            updatedAtText,
            style: SLTheme.quicksand(fontSize: 10, color: _muted),
          ),
        ],
      ],
    );
  }
}
