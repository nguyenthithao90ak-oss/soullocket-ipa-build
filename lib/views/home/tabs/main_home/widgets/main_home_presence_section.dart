// ignore_for_file: invalid_use_of_protected_member

part of '../../main_home_tab.dart';

extension _MainHomeTabPresenceSection on _MainHomeTabState {
  Widget _buildModernAvatarSection({
    required bool isSingle,
    required String nameU1,
    required String nameU2,
    required String avtUser1,
    required String avtUser2,
  }) {
    final compactMetaLayout = !isSingle && !_showStatus && !_showWeather;
    final dobU1 = _houseSettings?['dobU1']?.toString() ?? '';
    final dobU2 = _houseSettings?['dobU2']?.toString() ?? '';
    final z1 = ZodiacUtils.getZodiac(dobU1);
    final z2 = ZodiacUtils.getZodiac(dobU2);
    final ageDaysU1 = _extractAgeDays(dobU1);
    final ageDaysU2 = _extractAgeDays(dobU2);
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: UiPrefs.notifier.value,
      isWeb: kIsWeb,
    );
    final showDecorGlow = !effectProfile.performanceMode;
    final decorGlowEnabled = DateTime.now().millisecondsSinceEpoch < 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        compactMetaLayout ? 18 : 24,
        20,
        compactMetaLayout ? 14 : 20,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (decorGlowEnabled && showDecorGlow) ...[
            Positioned(
              top: -8,
              left: -4,
              child: IgnorePointer(
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFB7D1).withValues(alpha: 0.28),
                        const Color(0xFFFFB7D1).withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -10,
              child: IgnorePointer(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8FD8FF).withValues(alpha: 0.22),
                        const Color(0xFF8FD8FF).withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: compactMetaLayout
                ? MainAxisAlignment.spaceEvenly
                : MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: _buildModernUserColumn(
                  name: nameU1,
                  avatarUrl: avtUser1,
                  zodiacEmoji: z1?['emoji'] ?? '✦',
                  zodiacName: z1?['name'] ?? '',
                  ageDays: ageDaysU1,
                  role: 'user1',
                  isUser1: true,
                  hideMeta: isSingle,
                  customOnTap: () => _changeAvatar(isUser1: true),
                  customOnLongPress: () => _changeAvatar(isUser1: true),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compactMetaLayout ? 8 : 10,
                  vertical: compactMetaLayout ? 12 : 20,
                ),
                child: _buildModernRelationshipAction(isSingle: isSingle),
              ),
              Flexible(
                child: isSingle
                    ? _buildModernUserColumn(
                        name: '',
                        avatarUrl: '', // Will fall back to placeholder or empty
                        zodiacEmoji: '',
                        zodiacName: '',
                        ageDays: '--',
                        role: 'user2',
                        isUser1: false,
                        hideMeta: true,
                        isGreyedOut: true,
                        customOnTap: _openSingleMatchHub,
                      )
                    : _buildModernUserColumn(
                        name: nameU2,
                        avatarUrl: avtUser2,
                        zodiacEmoji: z2?['emoji'] ?? '✦',
                        zodiacName: z2?['name'] ?? '',
                        ageDays: ageDaysU2,
                        role: 'user2',
                        isUser1: false,
                        hideMeta: false,
                        customOnTap: () => _changeAvatar(isUser1: false),
                        customOnLongPress: () => _changeAvatar(isUser1: false),
                      ),
              ),
            ],
          ),
          for (final flight in _reactionFlights)
            Positioned.fill(
              key: ValueKey('reaction-flight-${flight.id}'),
              child: IgnorePointer(
                child: ShootingHeartEffect(
                  shootToRight: flight.shootToRight,
                  emoji: flight.emoji,
                  assetPath: flight.assetPath,
                  onComplete: () => _removeReactionFlight(flight.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernUserColumn({
    required String name,
    required String avatarUrl,
    required String zodiacEmoji,
    required String zodiacName,
    required String ageDays,
    required String role,
    required bool isUser1,
    required bool hideMeta,
    bool isGreyedOut = false,
    VoidCallback? customOnTap,
    VoidCallback? customOnLongPress,
  }) {
    final statusText = _presenceStatusText(role);
    final statusColor = _presenceStatusColor(role);
    final weatherText = _weatherTextForRole(role, isUser1: isUser1);
    final compactMeta = !hideMeta && !_showStatus && !_showWeather;
    final avatarSize = compactMeta ? 80.0 : 88.0;
    final ageLabel = _formatAgeForDisplay(ageDays);
    final hasAge = ageLabel != '--';

    String displayAge = '';
    if (hasAge) {
      final match = RegExp(r'\d+').firstMatch(ageLabel);
      displayAge = match?.group(0) ?? '';
    }
    return Column(
      children: [
        if (isGreyedOut)
          _buildAvatar(
            name,
            avatarUrl,
            isUser1: isUser1,
            onTap: customOnTap,
            onLongPress: customOnLongPress,
            isUploading: _uploadingAvatarRole == role,
            size: avatarSize,
            isSinglePlaceholder: true,
          )
        else
          _buildAvatar(
            name,
            avatarUrl,
            isUser1: isUser1,
            onTap: customOnTap,
            onLongPress: customOnLongPress,
            isUploading: _uploadingAvatarRole == role,
            size: avatarSize,
          ),
        SizedBox(height: compactMeta ? 8 : 12),
        GestureDetector(
          onTap: () async {
            DateTime initial =
                DateTime.now().subtract(const Duration(days: 365 * 20));
            final currentDob =
                _houseSettings?['dob${isUser1 ? 'U1' : 'U2'}']?.toString() ??
                    '';
            if (currentDob.isNotEmpty) {
              try {
                initial = DateTime.parse(currentDob);
              } catch (_) {}
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFD81B60),
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (!mounted) return;
            if (picked != null && _houseId != null) {
              final newDobStr = picked.toIso8601String().split('T')[0];
              await _dbRef
                  .child('houses/$_houseId/settings')
                  .update({'dob${isUser1 ? 'U1' : 'U2'}': newDobStr});
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((zodiacEmoji != '✦' && zodiacEmoji.isNotEmpty) ||
                  (hasAge && displayAge.isNotEmpty))
                _buildModernBirthZodiacPill(
                  zodiacEmoji: zodiacEmoji,
                  zodiacName: zodiacName,
                  age: displayAge,
                  isUser1: isUser1,
                ),
            ],
          ),
        ),
        SizedBox(height: compactMeta ? 2 : 4),
        GestureDetector(
          onTap: () => _showEditNameDialog(isUser1: isUser1, currentName: name),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compactMeta) SLSpacing.h8,
        if (!hideMeta && _showStatus)
          Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        if (!hideMeta && (_showStatus || _showWeather)) SLSpacing.h8,
        if (!hideMeta && _showWeather)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (weatherText.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  child: Text(
                    weatherText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildModernBirthZodiacPill({
    required String zodiacEmoji,
    required String zodiacName,
    required String age,
    required bool isUser1,
  }) {
    final detail = ZodiacUtils.zodiacDetails[zodiacName];
    final element = detail?['element']?.toString() ?? '';
    final hasZodiac = zodiacEmoji != '✦' && zodiacEmoji.isNotEmpty;
    final hasAge = age.isNotEmpty;

    Color baseColor;
    if (element.contains(context.tr('home_la_70bc13'))) {
      baseColor = const Color(0xFFFF6B6B);
    } else if (element.contains(context.tr('home_nc_0faef8'))) {
      baseColor = const Color(0xFF4EA8FF);
    } else if (element.contains(context.tr('home_t_0796d2'))) {
      baseColor = const Color(0xFF6DD58C);
    } else if (element.contains(context.tr('home_kh_e5d7dd'))) {
      baseColor = const Color(0xFFB56CFF);
    } else {
      baseColor = _profileAccentGradient(isUser1).last;
    }

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: baseColor.withValues(alpha: 0.34), width: 1),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasZodiac) ...[
            Text(
              zodiacEmoji,
              style: const TextStyle(fontSize: 12, height: 1),
            ),
            if (hasAge) const SizedBox(width: 4),
          ],
          if (hasAge)
            Text(
              age,
              style: SLTheme.quicksand(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: baseColor,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}
