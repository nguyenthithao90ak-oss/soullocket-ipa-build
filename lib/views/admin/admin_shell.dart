import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../core/sl_theme.dart';
import '../../utils/services/auth_service.dart';
import 'widgets/admin_shared_widgets.dart';
import 'admin_login_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_users_screen.dart';
import 'admin_content_screen.dart';
import 'admin_rewards_screen.dart';
import 'admin_payment_screen.dart';
import 'admin_abuse_screen.dart';
import 'admin_config_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_feedback_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const Duration _adminCheckTimeout = Duration(seconds: 8);

  late final Stream<firebase_auth.User?> _authStream;
  String? _adminCheckUid;
  Future<bool>? _adminCheckFuture;

  @override
  void initState() {
    super.initState();
    _authStream = firebase_auth.FirebaseAuth.instance.authStateChanges();
  }

  Future<bool> _resolveAdminAccess(firebase_auth.User user) {
    if (_adminCheckFuture == null || _adminCheckUid != user.uid) {
      _adminCheckUid = user.uid;
      _adminCheckFuture = AuthService()
          .isUserAdmin(user, forceRefresh: true)
          .timeout(_adminCheckTimeout, onTimeout: () => false);
    }
    return _adminCheckFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AdminScaffold(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<bool>(
          future: _resolveAdminAccess(user),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const AdminScaffold(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (adminSnapshot.data != true) {
              return AdminAccessDenied(user: user);
            }

            return AdminMainLayout(user: user);
          },
        );
      },
    );
  }
}

class AdminMainLayout extends StatefulWidget {
  final firebase_auth.User user;
  const AdminMainLayout({super.key, required this.user});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF10182A),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            selectedLabelTextStyle: SLTheme.quicksand(
              color: const Color(0xFFFF4B91),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: SLTheme.quicksand(
              color: const Color(0xFF9AA8C4),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            selectedIconTheme: const IconThemeData(color: Color(0xFFFF4B91)),
            unselectedIconTheme: const IconThemeData(color: Color(0xFF9AA8C4)),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_rounded),
                label: Text(context.tr('admin_tngquan_09c0fd')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.people_alt_rounded),
                label: Text(context.tr('admin_nhusers_ee6459')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.content_paste_search_rounded),
                label: Text(context.tr('admin_nidung_ee7ca5')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.card_giftcard_rounded),
                label: Text(context.tr('admin_phnthng_060774')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.payment_rounded),
                label: Text(context.tr('admin_thanhton_d555e4')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.security_rounded),
                label: Text(context.tr('admin_chnglmdng_a289dc')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_applications_rounded),
                label: Text(context.tr('admin_cuhnhtb_f67357')),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.history_rounded),
                label: Text('Audit Logs'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.feedback_rounded),
                label: Text('Góp ý'),
              ),
            ],
          ),
          const VerticalDivider(
              thickness: 1, width: 1, color: Color(0xFF2A364E)),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                AdminOverviewScreen(user: widget.user),
                AdminUsersScreen(user: widget.user),
                AdminContentScreen(user: widget.user),
                AdminRewardsScreen(user: widget.user),
                AdminPaymentScreen(user: widget.user),
                AdminAbuseScreen(user: widget.user),
                AdminConfigScreen(user: widget.user),
                AdminAuditLogsScreen(user: widget.user),
                AdminFeedbackScreen(user: widget.user),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key, required this.user});

  final firebase_auth.User user;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: SLSpacing.all24,
            child: AdminGlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    color: Color(0xFFFF4B91),
                    size: 40,
                  ),
                  SLSpacing.h16,
                  Text(
                    context.tr('admin_tikhonchac_cf5bb6'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SLSpacing.h12,
                  Text(
                    '${user.email ?? context.tr('admin_tikhonhint_4c8a88')} đăng nhập thành công nhưng chưa có custom claim admin hợp lệ.',
                    style: SLTheme.quicksand(
                      color: const Color(0xFFB7C1D6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                  SLSpacing.h24,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await AuthService().signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4B91),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.lgAll,
                        ),
                      ),
                      child: Text(
                        context.tr('admin_ngxut_0b3c82'),
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
