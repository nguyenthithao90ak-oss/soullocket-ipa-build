import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

const _rose = Color(0xFFB9516D);

/// Dữ liệu cũ dùng avtUser*, màn ghép nối dùng avatarU*. Hai nơi cùng đọc.
String? pairingAvatarUrl(Map settings, String role) {
  final keys = role == 'user2'
      ? const ['avatarU2', 'avtUser2']
      : const ['avatarU1', 'avtUser1'];
  for (final key in keys) {
    final value = settings[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
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
    final imageUrl = url?.trim() ?? '';
    final fallback = ColoredBox(
      color: second ? const Color(0xFFF0E9E3) : const Color(0xFFFBE8ED),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: second ? const Color(0xFF9B7D6B) : _rose,
          size: size * 0.44,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0DFE3)),
        boxShadow: [
          BoxShadow(
            color: _rose.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
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
    this.connectionDate,
    required this.onEditFirst,
    required this.onEditSecond,
  });

  final String firstName;
  final String secondName;
  final String? firstAvatar;
  final String? secondAvatar;
  final String? connectionDate;
  final VoidCallback onEditFirst;
  final VoidCallback onEditSecond;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
                  color: SLColors.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('pairing_ui_connected_description'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  color: SLColors.textSecond,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF1F4),
                      Color(0xFFFFFDFC),
                      Colors.white,
                    ],
                    stops: [0, 0.55, 1],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFF0DFE3)),
                  boxShadow: [
                    BoxShadow(
                      color: _rose.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFF0DFE3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: _rose,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.tr('pairing_ui_connected_status'),
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _person(
                            context,
                            firstName,
                            firstAvatar,
                            false,
                            onEditFirst,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 27),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFBE5EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: _rose,
                              size: 18,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _person(
                            context,
                            secondName,
                            secondAvatar,
                            true,
                            onEditSecond,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF5F3),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF2E6E1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: _rose,
                            size: 18,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('pairing_start_date'),
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              color: SLColors.textSecond,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            connectionDate ?? context.tr('pairing_no_info'),
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: connectionDate == null ? 16 : 24,
                              fontWeight: FontWeight.w700,
                              color: _rose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('pairing_ui_connected_avatar_hint'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  color: SLColors.textSecond,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _person(
    BuildContext context,
    String name,
    String? url,
    bool second,
    VoidCallback onEdit,
  ) {
    return Semantics(
      button: true,
      label: '${context.tr('pairing_ui_edit_avatar')}: $name',
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Stack(
                children: [
                  PairingAvatar(url: url, second: second),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _rose,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SLColors.ink,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
