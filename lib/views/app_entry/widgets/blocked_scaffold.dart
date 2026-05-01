import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';

class BlockedScaffold extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onSignOut;
  final VoidCallback? onAppeal;
  final bool showActions;

  const BlockedScaffold({
    super.key,
    required this.title,
    required this.message,
    this.onSignOut,
    this.onAppeal,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFFBF8),
        accentColor: SLColors.primary,
        secondaryAccent: SLColors.accentPurple,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SLTheme.softPanel(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            SLColors.primary.withOpacity(0.16),
                            Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: SLColors.primary.withOpacity(0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 34,
                        color: SLColors.primary,
                      ),
                    ),
                    SLSpacing.h16,
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h12,
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecond,
                      ),
                    ),
                    if (showActions) ...[
                      SLSpacing.h24,
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (onSignOut != null)
                            OutlinedButton(
                              onPressed: onSignOut,
                              child: const Text('Đăng xuất'),
                            ),
                          if (onAppeal != null)
                            ElevatedButton(
                              onPressed: onAppeal,
                              child: const Text('Kháng nghị'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
