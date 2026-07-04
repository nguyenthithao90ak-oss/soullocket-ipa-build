part of '../caro_neon_screen.dart';

class _ArenaStageBanner extends StatelessWidget {
  const _ArenaStageBanner({
    required this.title,
    required this.caption,
    required this.badgeText,
    required this.accent,
  });

  final String title;
  final String caption;
  final String badgeText;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xD1140A21), Color(0xCC0D1730)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(30),
        ),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
            ),
            child: Icon(Icons.sports_esports_rounded, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: SLTheme.quicksand(
                    fontSize: 12.6,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD7D1E7),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TinyPill(
            text: badgeText,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _PlayTargetTabs extends StatelessWidget {
  const _PlayTargetTabs({
    required this.playMode,
    required this.onSelected,
  });

  final _CaroPlayMode playMode;
  final ValueChanged<_CaroPlayMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xB00B0815),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(26),
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: const Color(0x335AF1FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TargetChip(
              label: context.tr('util_ringt_2c6365'),
              selected: playMode == _CaroPlayMode.house,
              color: const Color(0xFF4EDBFF),
              onTap: () => onSelected(_CaroPlayMode.house),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TargetChip(
              label: 'BOT NEON',
              selected: playMode == _CaroPlayMode.bot,
              color: const Color(0xFFFF5E9E),
              onTap: () => onSelected(_CaroPlayMode.bot),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(10),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : const Color(0x1A1A2030),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(10),
            ),
            border: Border.all(
              color: selected ? color : const Color(0x33486888),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundToggleButton extends StatelessWidget {
  const _SoundToggleButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? const Color(0x1E4EDBFF) : const Color(0x141E2435),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  enabled ? const Color(0xFF4EDBFF) : const Color(0x33486888),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('util_mchm_7088bf'),
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    enabled
                        ? context.tr('util_bt_9eae51')
                        : context.tr('util_tt_258f00'),
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: enabled
                          ? const Color(0xFF4EDBFF)
                          : const Color(0xFFC9C2DB),
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
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.selectedWinLength,
    required this.roomLocked,
    required this.onSelected,
  });

  final int selectedWinLength;
  final bool roomLocked;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xB00B0815),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(30),
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: const Color(0x335AF1FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              label: context.tr('util_3thng_080f34'),
              caption: context.tr('util_bngnvotrnn_d55348'),
              selected: selectedWinLength == 3,
              enabled: !roomLocked || selectedWinLength == 3,
              onTap: () => onSelected(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeTabButton(
              label: context.tr('util_5thng_5e66bf'),
              caption: context.tr('util_bnrngkonga_033e8e'),
              selected: selectedWinLength == 5,
              enabled: !roomLocked || selectedWinLength == 5,
              onTap: () => onSelected(5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.caption,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glow = selected ? const Color(0xFF4EDBFF) : const Color(0xFFFF69B4);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(10),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? const [Color(0xFF0A1730), Color(0xFF150722)]
                  : const [Color(0xB81A1027), Color(0xB80E1426)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(10),
            ),
            border: Border.all(
                color: glow.withValues(alpha: enabled ? 0.92 : 0.25),
                width: 1.4),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: glow.withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.white : const Color(0xFF777286),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? const Color(0xFFC4BED6)
                      : const Color(0xFF6A6477),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.myName,
    required this.partnerName,
    required this.myRole,
    required this.room,
    required this.statusText,
  });

  final String myName;
  final String partnerName;
  final String myRole;
  final CaroRoom? room;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final partnerRole = room == null
        ? (myRole == 'user2' ? 'user1' : 'user2')
        : (room!.playerXRole == myRole ? room!.playerORole : room!.playerXRole);
    final partnerLabel =
        partnerRole == 'bot' ? 'BOT' : context.tr('util_ngiy_e21b71');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xCC14071C), Color(0xC50C162D), Color(0xCC0E0A1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(30),
        ),
        border: Border.all(color: const Color(0x2EEAF7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PlayerPlate(
                  name: myName,
                  roleLabel: context.tr('util_bn_415bfa'),
                  symbol: room?.symbolForRole(myRole) ?? '',
                  isAccentBlue: true,
                  isWinner: room?.winnerRole == myRole,
                  isTurn: room?.turnRole == myRole && room?.isActive == true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('VS',
                    style: TextStyle(
                        color: Color(0xFFFFD7A1), fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: _PlayerPlate(
                  name: partnerName,
                  roleLabel: partnerLabel,
                  symbol: room?.symbolForRole(partnerRole) ?? '',
                  isAccentBlue: false,
                  isWinner: room?.winnerRole == partnerRole,
                  isTurn:
                      room?.turnRole == partnerRole && room?.isActive == true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              statusText,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE3DCF1),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPlate extends StatelessWidget {
  const _PlayerPlate({
    required this.name,
    required this.roleLabel,
    required this.symbol,
    required this.isAccentBlue,
    required this.isWinner,
    required this.isTurn,
  });

  final String name;
  final String roleLabel;
  final String symbol;
  final bool isAccentBlue;
  final bool isWinner;
  final bool isTurn;

  @override
  Widget build(BuildContext context) {
    final accent =
        isAccentBlue ? const Color(0xFF4EDBFF) : const Color(0xFFFF5E9E);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isAccentBlue ? 20 : 12),
          topRight: Radius.circular(isAccentBlue ? 12 : 20),
          bottomLeft: Radius.circular(isAccentBlue ? 12 : 20),
          bottomRight: Radius.circular(isAccentBlue ? 22 : 10),
        ),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  roleLabel,
                  style: SLTheme.quicksand(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: accent,
                  ),
                ),
              ),
              if (symbol.isNotEmpty)
                Text(
                  symbol,
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (isWinner || isTurn)
            _TinyPill(
              text: isWinner
                  ? context.tr('util_angthng_e4bde5')
                  : context.tr('util_tilt_db7dc9'),
              color: isWinner ? const Color(0xFFFFD76F) : accent,
              darkText: isWinner,
            ),
        ],
      ),
    );
  }
}

class _ArenaActionPanel extends StatelessWidget {
  const _ArenaActionPanel({
    required this.room,
    required this.selectedWinLength,
    required this.myRole,
    required this.isBusy,
    required this.onInvite,
    required this.onJoin,
    required this.onClear,
  });

  final CaroRoom? room;
  final int selectedWinLength;
  final String myRole;
  final bool isBusy;
  final VoidCallback onInvite;
  final VoidCallback onJoin;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final currentRoom = room;
    final buttons = <Widget>[];
    String infoText;

    if (currentRoom == null) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_btu_3cb0f0'),
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.rocket_launch_rounded,
          onTap: isBusy ? null : onInvite,
        ),
      );
      infoText =
          'Bấm Bắt đầu để chọn 3 ô hoặc 5 ô rồi mở bàn riêng. Luật gần nhất là ${selectedWinLength == 5 ? context.tr('util_5thng_5e66bf') : context.tr('util_3thng_080f34')}.';
    } else if (currentRoom.isWaiting && currentRoom.createdByRole != myRole) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_thamgiabn_a8b113'),
          color: const Color(0xFFFF5E9E),
          foreground: Colors.white,
          icon: Icons.login_rounded,
          onTap: isBusy ? null : onJoin,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_nglimi_af8d28'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.close_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
      infoText = context.tr('util_bnangchbnx_ed804e');
    } else if (currentRoom.isWaiting) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_hybn_e09cfc'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.delete_outline_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
      infoText = context.tr('util_limigikhin_d80433');
    } else if (currentRoom.isDone) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_vnmi_ea7b55'),
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.replay_rounded,
          onTap: isBusy ? null : onInvite,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_xabn_fd33c4'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.layers_clear_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
      infoText = context.tr('util_vnxongcthc_418275');
    } else {
      buttons.add(
        _ActionButton(
          label: context.tr('util_lmmibn_976b32'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.refresh_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
      infoText = context.tr('util_chmtrngnhb_816fec');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoStrip(text: infoText),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: buttons,
        ),
      ],
    );
  }
}

class _ArenaBotActionPanel extends StatelessWidget {
  const _ArenaBotActionPanel({
    required this.room,
    required this.selectedWinLength,
    required this.isBusy,
    required this.styleLabel,
    required this.styleDescription,
    required this.onStart,
    required this.onClear,
  });

  final CaroRoom? room;
  final int selectedWinLength;
  final bool isBusy;
  final String styleLabel;
  final String styleDescription;
  final VoidCallback onStart;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final currentRoom = room;
    final buttons = <Widget>[];
    String infoText =
        'Kiểu bot hiện tại: $styleLabel. Luật gần nhất: ${selectedWinLength == 5 ? context.tr('util_5thng_5e66bf') : context.tr('util_3thng_080f34')}. $styleDescription';

    if (currentRoom == null) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_chnbnrivoc_c64e2a'),
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.smart_toy_rounded,
          onTap: isBusy ? null : onStart,
        ),
      );
    } else if (currentRoom.isDone) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_vnmivibot_092422'),
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.replay_rounded,
          onTap: isBusy ? null : onStart,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_ngvn_636849'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.layers_clear_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
      infoText = context.tr('util_vnnyxongct_2f6faa');
    } else {
      buttons.add(
        _ActionButton(
          label: isBusy
              ? context.tr('util_botangngh_6f8ac2')
              : context.tr('util_ibnmi_381420'),
          color: const Color(0xFFFF5E9E),
          foreground: Colors.white,
          icon: Icons.auto_awesome_rounded,
          onTap: isBusy ? null : onStart,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_thotvn_4c3f2f'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.close_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
      infoText =
          'Kiểu bot hiện tại: $styleLabel. Muốn đổi nhịp chơi, hãy mở bàn mới rồi chọn lại.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoStrip(text: infoText),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: buttons,
        ),
      ],
    );
  }
}

// ignore: unused_element
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.room,
    required this.selectedWinLength,
    required this.myRole,
    required this.isBusy,
    required this.onInvite,
    required this.onJoin,
    required this.onClear,
  });

  final CaroRoom? room;
  final int selectedWinLength;
  final String myRole;
  final bool isBusy;
  final VoidCallback onInvite;
  final VoidCallback onJoin;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final currentRoom = room;
    final buttons = <Widget>[];
    if (currentRoom == null) {
      buttons.add(
        _ActionButton(
          label:
              'Mời chơi ${selectedWinLength == 5 ? context.tr('util_5thng_5e66bf') : context.tr('util_3thng_080f34')}',
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.rocket_launch_rounded,
          onTap: isBusy ? null : onInvite,
        ),
      );
    } else if (currentRoom.isWaiting && currentRoom.createdByRole != myRole) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_thamgiabn_a8b113'),
          color: const Color(0xFFFF5E9E),
          foreground: Colors.white,
          icon: Icons.videogame_asset_rounded,
          onTap: isBusy ? null : onJoin,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_xalimi_507183'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.close_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
    } else if (currentRoom.isWaiting) {
      buttons.add(_InfoStrip(text: context.tr('util_limigikhin_670a47')));
      buttons.add(
        _ActionButton(
          label: context.tr('util_hybn_e09cfc'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.delete_outline_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
    } else if (currentRoom.isDone) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_chili_ddbf84'),
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.replay_rounded,
          onTap: isBusy ? null : onInvite,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_xabn_fd33c4'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.layers_clear_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
    } else {
      buttons.add(_InfoStrip(text: context.tr('util_chmtrctipv_16c48f')));
      buttons.add(
        _ActionButton(
          label: context.tr('util_lmmibn_976b32'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.refresh_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: buttons,
    );
  }
}

// ignore: unused_element
class _BotActionPanel extends StatelessWidget {
  const _BotActionPanel({
    required this.room,
    required this.selectedWinLength,
    required this.isBusy,
    required this.onStart,
    required this.onClear,
  });

  final CaroRoom? room;
  final int selectedWinLength;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final currentRoom = room;
    final buttons = <Widget>[
      _InfoStrip(
        text: context.tr('util_botneonc2k_4dc639'),
      ),
    ];

    if (currentRoom == null) {
      buttons.add(
        _ActionButton(
          label:
              'Bắt đầu với Bot ${selectedWinLength == 5 ? '5 ô' : context.tr('util_3_ad928e')}',
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.smart_toy_rounded,
          onTap: isBusy ? null : onStart,
        ),
      );
    } else if (currentRoom.isDone) {
      buttons.add(
        _ActionButton(
          label: context.tr('util_chilivibot_4a56ce'),
          color: const Color(0xFF4EDBFF),
          foreground: const Color(0xFF14051A),
          icon: Icons.replay_rounded,
          onTap: isBusy ? null : onStart,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_ngvn_636849'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.layers_clear_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
    } else {
      buttons.add(
        _ActionButton(
          label: isBusy
              ? context.tr('util_botangngh_6f8ac2')
              : context.tr('util_vnmi_ea7b55'),
          color: const Color(0xFFFF5E9E),
          foreground: Colors.white,
          icon: Icons.auto_awesome_rounded,
          onTap: isBusy ? null : onStart,
        ),
      );
      buttons.add(
        _ActionButton(
          label: context.tr('util_thotvn_4c3f2f'),
          color: const Color(0x291E2638),
          foreground: const Color(0xFFEAE5F8),
          icon: Icons.close_rounded,
          onTap: isBusy ? null : onClear,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: buttons,
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x191D2742),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: const Color(0x245E6FA6)),
      ),
      child: Text(
        text,
        style: SLTheme.quicksand(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFE3DCF1),
          height: 1.45,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color foreground;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(10),
          ),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
