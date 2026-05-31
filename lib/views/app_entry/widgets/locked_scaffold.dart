import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../core/sl_theme.dart';

class LockedScaffold extends StatelessWidget {
  final VoidCallback onUnlock;

  const LockedScaffold({
    super.key,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFFBF8),
        accentColor: SLColors.primary,
        secondaryAccent: SLColors.accentPurple,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                SLTheme.softPanel(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              SLColors.primary.withValues(alpha: 0.16),
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: SLColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 40,
                          color: SLColors.primary,
                        ),
                      ),
                      SLSpacing.h20,
                      Text(
                        context.tr('app_entry_ngdngbkha_85ff01'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                      ),
                      SLSpacing.h12,
                      Text(
                        context.tr('app_entry_xcthcliqua_184be1'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecond,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onUnlock,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(
                      context.tr('app_entry_mkha_5bfc67'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
