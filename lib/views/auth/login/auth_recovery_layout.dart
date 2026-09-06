import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'auth_keepsake_details.dart';
import 'auth_visual_style.dart';
import 'aurora_hero_background.dart';

/// Chỉ là phần trình bày, không thực hiện gửi mã hay đổi mật khẩu.
class AuthRecoveryLayout extends StatelessWidget {
  const AuthRecoveryLayout({
    super.key,
    required this.child,
    required this.onBack,
    this.busy = false,
    this.footer,
  });
  final Widget child;
  final VoidCallback onBack;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Scaffold(
      backgroundColor: style.background,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AuroraHeroBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 920;
                final inset = MediaQuery.viewInsetsOf(context).bottom;
                final header = AuthKeepsakeHeader(
                  title: context.tr('auth_cute_recovery_title'),
                  subtitle: context.tr('auth_cute_recovery_subtitle'),
                  wide: wide,
                  recovery: true,
                );
                final form = AuthKeepsakeCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      child,
                      if (footer != null) ...[
                        const SizedBox(height: 18),
                        footer!,
                      ],
                    ],
                  ),
                );
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 450 ? 16 : 32,
                    8,
                    constraints.maxWidth < 450 ? 16 : 32,
                    24 + inset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1000 : 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                key: const ValueKey('auth_recovery_back'),
                                onPressed: busy ? null : onBack,
                                tooltip: context.tr('auth_cute_back_login'),
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: style.ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  context.tr('forgot_pwd_appbar_title'),
                                  style: style.text(
                                    size: 14,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const AuthStickerBadge(
                                icon: Icons.lock_outline_rounded,
                                size: 32,
                              ),
                            ],
                          ),
                          SizedBox(height: wide ? 52 : 20),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 64),
                                    child: header,
                                  ),
                                ),
                                SizedBox(width: 420, child: form),
                              ],
                            )
                          else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 26),
                              child: header,
                            ),
                            form,
                          ],
                          const SizedBox(height: 18),
                          Text(
                            context.tr('auth_cute_recovery_note'),
                            textAlign: TextAlign.center,
                            style: style.text(size: 11, color: style.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AuthRecoveryIntro extends StatelessWidget {
  const AuthRecoveryIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AuthStickerBadge(icon: icon, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eyebrow,
                style: style.text(
                  size: 11,
                  weight: FontWeight.w600,
                  color: style.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: style.text(size: 19, weight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: style.text(size: 13, color: style.muted, height: 1.5),
        ),
      ],
    );
  }
}
