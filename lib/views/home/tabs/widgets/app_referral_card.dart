import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/service_locator.dart';
import '../../../../models/app_referral.dart';
import '../../../../utils/app_error_mapper.dart';
import '../../../../utils/services/app_referral_service.dart';
import '../../../../utils/services/l10n_service.dart';

class AppReferralCard extends StatefulWidget {
  const AppReferralCard({super.key});

  @override
  State<AppReferralCard> createState() => _AppReferralCardState();
}

class _AppReferralCardState extends State<AppReferralCard> {
  final _codeController = TextEditingController();
  final _service = locator<AppReferralService>();
  StreamSubscription<User?>? _authSubscription;
  AppReferralProfile? _profile;
  bool _loading = true;
  bool _working = false;
  bool _showInput = false;
  String? _message;
  Object? _failure;
  String? _uid;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      _request++;
      setState(() {
        _uid = user?.uid;
        _profile = null;
        _message = null;
        _failure = null;
        _working = false;
        _loading = user != null;
        _codeController.clear();
      });
      if (user != null) unawaited(_refresh());
    });
  }

  bool _sameAccount(String? uid) =>
      mounted &&
      uid != null &&
      _uid == uid &&
      FirebaseAuth.instance.currentUser?.uid == uid;

  Future<void> _refresh() async {
    final uid = _uid;
    if (!_sameAccount(uid)) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _message = null;
      _failure = null;
    });
    try {
      final profile = await _service.loadProfile();
      if (!_sameAccount(uid) || request != _request) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!_sameAccount(uid) || request != _request) return;
      setState(() {
        _loading = false;
        _message = 'referral_unavailable';
        _failure = error;
      });
    }
  }

  Future<void> _copyLink() async {
    final profile = _profile;
    final uid = _uid;
    if (profile == null || _working || !_sameAccount(uid)) return;
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      final link = Uri.parse(profile.link)
          .replace(
            queryParameters: {
              'code': profile.code,
              'lang': L10nScope.of(context).localeCode,
            },
          )
          .toString();
      await Clipboard.setData(ClipboardData(text: link));
      if (_sameAccount(uid)) setState(() => _message = 'referral_copied');
    } catch (error) {
      if (_sameAccount(uid)) {
        setState(() {
          _message = 'referral_unavailable';
          _failure = error;
        });
      }
    } finally {
      if (_sameAccount(uid)) setState(() => _working = false);
    }
  }

  Future<void> _share() async {
    final profile = _profile;
    final uid = _uid;
    if (profile == null || _working || !_sameAccount(uid)) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final l10n = L10nScope.of(context);
    final link = Uri.parse(profile.link)
        .replace(
          queryParameters: {'code': profile.code, 'lang': l10n.localeCode},
        )
        .toString();
    final text = '${l10n.translate('referral_share_text')}\n$link';
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (error) {
      if (_sameAccount(uid)) {
        setState(() {
          _message = 'referral_unavailable';
          _failure = error;
        });
      }
    } finally {
      if (_sameAccount(uid)) setState(() => _working = false);
    }
  }

  Future<void> _applyCode() async {
    final uid = _uid;
    if (_working || !_sameAccount(uid)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      final result = await _service.applyCode(_codeController.text);
      if (!_sameAccount(uid)) return;
      setState(() {
        _message = switch (result) {
          'joined_play' || 'joined_code' => 'referral_recorded',
          'already_recorded' || 'installation_used' => 'referral_already',
          'existing_account' => 'referral_new_account_only',
          'daily_limit' => 'referral_daily_limit',
          'self_referral' => 'referral_self',
          'expired_invite' => 'referral_expired',
          'invalid_code' => 'referral_invalid',
          _ => 'referral_unavailable',
        };
      });
    } catch (error) {
      if (_sameAccount(uid)) {
        setState(() {
          _message = 'referral_unavailable';
          _failure = error;
        });
      }
    } finally {
      if (_sameAccount(uid)) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _request++;
    unawaited(_authSubscription?.cancel());
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    L10nScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFF2ABBE) : const Color(0xFFA83F65);
    final muted = dark ? const Color(0xFFC6BACB) : const Color(0xFF796A7C);
    final profile = _profile;
    return Container(
      key: const ValueKey('app-referral-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF302A38) : const Color(0xFFFFFDFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark ? const Color(0xFF504355) : const Color(0xFFECE1E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism_outlined, color: accent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('referral_title'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: context.tr('referral_refresh'),
                onPressed: _loading || _working || _uid == null
                    ? null
                    : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('referral_intro'),
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          if (profile != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.card_giftcard_rounded, size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr(
                        profile.rewardsEnabled
                            ? 'referral_reward_offer'
                            : 'referral_reward_pending',
                      ),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 10),
            Text(
              context.tr('referral_loading'),
              style: TextStyle(color: muted),
            ),
          ] else if (_uid == null) ...[
            const SizedBox(height: 12),
            Text(context.tr('referral_sign_in')),
          ],
          if (profile != null) ...[
            const SizedBox(height: 18),
            Text(
              context.tr('referral_your_code'),
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 6),
            SelectableText(
              profile.code,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: accent,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width < 350 ? width : (width - 10) / 2,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _share,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(context.tr('referral_share')),
                      ),
                    ),
                    SizedBox(
                      width: width < 350 ? width : (width - 10) / 2,
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _copyLink,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(context.tr('referral_copy')),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (profile.rewardsEnabled) ...[
              Wrap(
                spacing: 18,
                runSpacing: 16,
                children: [
                  _stat(
                    profile.rewardedProHours,
                    'referral_reward_hours',
                    accent,
                    muted,
                  ),
                  _stat(
                    profile.pendingRewards,
                    'referral_reward_waiting',
                    accent,
                    muted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('referral_reward_note'),
                style: TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              if (profile.pendingRewards > 0) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    context.tr('referral_reward_waiting_note'),
                    style: TextStyle(color: accent, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ],
            Wrap(
              spacing: 18,
              runSpacing: 16,
              children: [
                _stat(
                  profile.playInstalls,
                  'referral_play_installs',
                  accent,
                  muted,
                ),
                _stat(profile.joined, 'referral_joined', accent, muted),
                _stat(
                  profile.storeVisits,
                  'referral_store_visits',
                  accent,
                  muted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('referral_count_note'),
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ],
          if (!_loading && _profile == null && _uid != null)
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('referral_retry')),
            ),
          if (_uid != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _working
                  ? null
                  : () => setState(() => _showInput = !_showInput),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(
                _showInput
                    ? Icons.expand_less
                    : Icons.confirmation_number_outlined,
              ),
              label: Flexible(child: Text(context.tr('referral_have_code'))),
            ),
            if (_showInput) ...[
              Text(
                context.tr('referral_input_note'),
                style: TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                enabled: !_working,
                maxLength: 14,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.tr('referral_enter_code'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _applyCode(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _working ? null : _applyCode,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(context.tr('referral_apply')),
                ),
              ),
            ],
          ],
          if (_working) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _failure == null
                    ? context.tr(_message!)
                    : AppErrorMapper.resolve(
                        _failure,
                        fallbackMessage: context.tr('referral_unavailable'),
                      ).message,
                style: TextStyle(color: accent, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(int count, String key, Color accent, Color muted) => SizedBox(
    width: 126,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        Text(
          context.tr(key),
          style: TextStyle(color: muted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}
