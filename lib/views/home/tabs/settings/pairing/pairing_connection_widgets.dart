import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';
import 'package:soullocket_app/widgets/couple_default_avatar.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/home_image_policy.dart';
import 'package:soullocket_app/utils/services/breakup_service.dart';
import 'package:soullocket_app/utils/services/home_startup_media_cache.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../relationship/relationship_actions.dart';
import 'pairing_connection_date.dart';

String? pairingAvatarUrl(Map settings, String role) {
  final value = settings[role == 'user2' ? 'avtUser2' : 'avtUser1'];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

class PairingPalette {
  const PairingPalette(this.dark);

  final bool dark;
  Color get background =>
      dark ? SLSettingsColors.darkCanvas : SLSettingsColors.canvas;
  Color get surface =>
      dark ? SLSettingsColors.darkSurface : SLSettingsColors.surface;
  Color get ink => dark ? SLSettingsColors.darkInk : SLSettingsColors.ink;
  Color get muted =>
      dark ? SLSettingsColors.darkInkSecondary : SLSettingsColors.inkSecondary;
  Color get border =>
      dark ? SLSettingsColors.darkBorder : SLSettingsColors.border;
  Color get rose =>
      dark ? const Color(0xFFF2849B) : SLSettingsColors.accentStrong;
  Color get blush =>
      dark ? const Color(0xFF3A2830) : SLSettingsColors.accentSoft;
  Color get sage => dark ? const Color(0xFF9CCFB4) : SLSettingsColors.success;
  Color get leaf =>
      dark ? const Color(0xFF243329) : SLSettingsColors.successSoft;
}

class PairingAvatar extends StatelessWidget {
  const PairingAvatar({
    super.key,
    this.url,
    this.size = 88,
    this.second = false,
  });

  final String? url;
  final double size;
  final bool second;

  @override
  Widget build(BuildContext context) {
    final colors = PairingPalette(
      Theme.of(context).brightness == Brightness.dark,
    );
    final imageUrl = url?.trim() ?? '';
    final fallback = CoupleDefaultAvatar(female: second);
    final startupFile = HomeStartupMediaCache.getFile(imageUrl);
    Widget cachedOrFallback() => startupFile == null
        ? fallback
        : Image(
            image: HomeImagePolicy.resized(
              FileImage(startupFile),
              width: HomeImagePolicy.avatarPixels,
              height: HomeImagePolicy.avatarPixels,
            ),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? fallback
            : imageUrl.startsWith('assets/')
            ? Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : CachedNetworkImage(
                key: ValueKey(imageUrl),
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: HomeImagePolicy.avatarPixels,
                memCacheHeight: HomeImagePolicy.avatarPixels,
                maxWidthDiskCache: HomeImagePolicy.avatarPixels,
                maxHeightDiskCache: HomeImagePolicy.avatarPixels,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) => cachedOrFallback(),
                errorWidget: (context, url, error) => cachedOrFallback(),
              ),
      ),
    );
  }
}

class PairingConnectedView extends StatelessWidget {
  const PairingConnectedView({
    super.key,
    required this.firstName,
    required this.secondName,
    this.firstAvatar,
    this.secondAvatar,
    this.connection,
    this.connectionLoading = false,
    this.connectionError = false,
    this.uploadingRole,
    required this.onEditFirst,
    required this.onEditSecond,
    required this.onRetry,
    this.now,
    this.breakupRequest,
    this.breakupBusy = false,
    this.currentUid,
    this.onRequestBreakup,
    this.onApproveBreakup,
    this.onWithdrawBreakup,
  });

  final String firstName;
  final String secondName;
  final String? firstAvatar;
  final String? secondAvatar;
  final PairingConnectionDetails? connection;
  final bool connectionLoading;
  final bool connectionError;
  final String? uploadingRole;
  final VoidCallback onEditFirst;
  final VoidCallback onEditSecond;
  final VoidCallback onRetry;
  final DateTime? now;

  /// Yêu cầu hủy ghép nối đang có của House (null khi chưa có yêu cầu).
  final BreakupRequestData? breakupRequest;
  final bool breakupBusy;
  final String? currentUid;
  final VoidCallback? onRequestBreakup;
  final VoidCallback? onApproveBreakup;
  final VoidCallback? onWithdrawBreakup;

  @override
  Widget build(BuildContext context) {
    final colors = PairingPalette(
      Theme.of(context).brightness == Brightness.dark,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('pairing_ui_connected_title'),
                style: SLTheme.quicksand(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('pairing_ui_connected_description'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  color: colors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.leaf,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 17,
                              color: colors.sage,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                context.tr('pairing_ui_connected_status'),
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.sage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final avatarSize = ((constraints.maxWidth - 40) / 2)
                              .clamp(64.0, 96.0);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _person(
                                  context,
                                  colors,
                                  firstName,
                                  firstAvatar,
                                  false,
                                  avatarSize,
                                  onEditFirst,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                  top: avatarSize / 2 - 15,
                                ),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: colors.blush,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: colors.rose,
                                    size: 17,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _person(
                                  context,
                                  colors,
                                  secondName,
                                  secondAvatar,
                                  true,
                                  avatarSize,
                                  onEditSecond,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Divider(height: 1, color: colors.border),
                      const SizedBox(height: 20),
                      _connectionInfo(context, colors),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _breakupPanel(context, colors),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.sync_rounded,
                      color: colors.muted,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.tr('pairing_ui_home_avatar_hint'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        color: colors.muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakupPanel(BuildContext context, PairingPalette colors) {
    final request = breakupRequest;
    final isActive = request?.isActive == true;
    final uid = currentUid?.trim() ?? '';
    final isRequester = isActive &&
        uid.isNotEmpty &&
        request!.requestedByUid.trim() == uid;
    final isPartnerPending = isActive && request!.isPending && !isRequester;
    final canWithdraw = isRequester &&
        SettingsRelationshipActions.canWithdrawBreakup(
          request,
          currentUid: uid,
        );

    final title = !isActive
        ? context.tr('breakup')
        : isPartnerPending
        ? context.tr('home_bnkiaangch_b287d3')
        : SettingsRelationshipActions.breakupStatusTitle(
            request: request,
            isSingle: false,
          );
    final description = !isActive
        ? context.tr('breakup_delete_house')
        : isPartnerPending
        ? '${context.tr('breakup_pending')}\n${SettingsRelationshipActions.breakupStatusDescription(request: request, isSingle: false)}'
        : SettingsRelationshipActions.breakupStatusDescription(
            request: request,
            isSingle: false,
          );

    Widget? action;
    if (!isActive) {
      action = SLSettingsButton(
        label: context.tr('home_chiatayxad_3b2b07'),
        icon: Icons.heart_broken_outlined,
        variant: SLSettingsButtonVariant.danger,
        isDark: colors.dark,
        loading: breakupBusy,
        onPressed: breakupBusy ? null : onRequestBreakup,
      );
    } else if (isPartnerPending) {
      action = SLSettingsButton(
        label: context.tr('home_xcnhn_1e2eb2'),
        icon: Icons.check_rounded,
        variant: SLSettingsButtonVariant.tonal,
        color: colors.sage,
        isDark: colors.dark,
        loading: breakupBusy,
        onPressed: breakupBusy ? null : onApproveBreakup,
      );
    } else if (canWithdraw) {
      action = SLSettingsButton(
        label: context.tr('home_rtliyucu_29ae92'),
        icon: Icons.undo_rounded,
        variant: SLSettingsButtonVariant.secondary,
        isDark: colors.dark,
        loading: breakupBusy,
        onPressed: breakupBusy ? null : onWithdrawBreakup,
      );
    }

    return Semantics(
      container: true,
      label: '$title. $description',
      child: Material(
        color: colors.blush,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.rose.withValues(alpha: 0.34)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.heart_broken_outlined,
                      color: colors.rose,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: SLTheme.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          description,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            color: colors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 14),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionInfo(BuildContext context, PairingPalette colors) {
    final details = connection;
    if (details != null) {
      final localizations = MaterialLocalizations.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      localizations.formatDecimal(
                        details.daysTogether(now ?? DateTime.now()),
                      ),
                      key: const Key('pairing-days-count'),
                      style: SLTheme.quicksand(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: colors.rose,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                Text(
                  context.tr('pairing_ui_days_together'),
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.blush,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: colors.rose,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('pairing_start_date'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        color: colors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      localizations.formatFullDate(details.date),
                      key: const Key('pairing-connection-date'),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (details.fromMembership) ...[
            const SizedBox(height: 14),
            Text(
              context.tr('pairing_ui_date_from_membership'),
              style: SLTheme.quicksand(
                fontSize: 11,
                color: colors.muted,
                height: 1.5,
              ),
            ),
          ],
        ],
      );
    }
    final message = connectionLoading
        ? 'pairing_ui_date_loading'
        : connectionError
        ? 'pairing_ui_date_load_error'
        : 'pairing_ui_date_missing';
    return Column(
      children: [
        if (connectionLoading)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.rose,
            ),
          )
        else
          Icon(Icons.history_rounded, color: colors.muted, size: 24),
        const SizedBox(height: 10),
        Text(
          context.tr(message),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            color: colors.muted,
            height: 1.5,
          ),
        ),
        if (connectionError && !connectionLoading)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: colors.rose,
            ),
            child: Text(context.tr('pairing_ui_state_retry')),
          ),
      ],
    );
  }

  Widget _person(
    BuildContext context,
    PairingPalette colors,
    String name,
    String? url,
    bool second,
    double size,
    VoidCallback onEdit,
  ) {
    final busy = uploadingRole == (second ? 'user2' : 'user1');
    return Semantics(
      button: true,
      enabled: uploadingRole == null,
      label:
          '${context.tr(busy ? 'pairing_ui_avatar_uploading' : 'pairing_ui_edit_avatar')}: $name',
      child: InkWell(
        key: Key(second ? 'pairing-edit-user2' : 'pairing-edit-user1'),
        onTap: uploadingRole == null ? onEdit : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Stack(
                children: [
                  PairingAvatar(url: url, size: size, second: second),
                  if (busy)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!busy)
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: colors.rose,
                          size: 15,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
