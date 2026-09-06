part of '../../main_home_tab.dart';

extension _MainHomeTabPresenceSection on _MainHomeTabState {
  Widget _buildModernAvatarSection({
    required bool isSingle,
    required String nameU1,
    required String nameU2,
    required String avtUser1,
    required String avtUser2,
  }) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: _presenceDataNotifier,
      builder: (context, _, _) {
        final compactMetaLayout = !isSingle && !_showStatus && !_showWeather;
        final dobU1 = _houseSettings?['dobU1']?.toString() ?? '';
        final dobU2 = _houseSettings?['dobU2']?.toString() ?? '';
        final z1 = ZodiacUtils.getZodiac(dobU1);
        final z2 = ZodiacUtils.getZodiac(dobU2);
        final ageDaysU1 = _extractAgeDays(dobU1);
        final ageDaysU2 = _extractAgeDays(dobU2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _HomeScrapbookCard(
            padding: EdgeInsets.zero,
            radius: 28,
            accentColor: SLColors.thread,
            adornment: _HomeCardAdornment.photoCorners,
            visualStyle: _HomeCardVisualStyle.couple,
            child: Padding(
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
                  if (!isSingle)
                    const Positioned(
                      top: 40,
                      left: 42,
                      right: 42,
                      height: 54,
                      child: IgnorePointer(
                        child: CustomPaint(painter: _CoupleThreadPainter()),
                      ),
                    ),
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
                          zodiacEmoji: z1?['emoji'] ?? '',
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
                        child: _buildModernRelationshipAction(
                          isSingle: isSingle,
                        ),
                      ),
                      Flexible(
                        child: isSingle
                            ? _buildModernUserColumn(
                                name: '',
                                avatarUrl:
                                    '', // Will fall back to placeholder or empty
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
                                zodiacEmoji: z2?['emoji'] ?? '',
                                zodiacName: z2?['name'] ?? '',
                                ageDays: ageDaysU2,
                                role: 'user2',
                                isUser1: false,
                                hideMeta: false,
                                customOnTap: () =>
                                    _changeAvatar(isUser1: false),
                                customOnLongPress: () =>
                                    _changeAvatar(isUser1: false),
                              ),
                      ),
                    ],
                  ),
                  Positioned.fill(
                    child: ValueListenableBuilder<List<_HomeReactionFlight>>(
                      valueListenable: _reactionFlightsNotifier,
                      builder: (context, flights, _) {
                        final hasLeft = flights.any((f) => f.shootToRight);
                        final hasRight = flights.any((f) => !f.shootToRight);
                        final hasCollision = hasLeft && hasRight;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final flight in flights)
                              Positioned.fill(
                                key: ValueKey('reaction-flight-${flight.id}'),
                                child: IgnorePointer(
                                  child: ShootingHeartEffect(
                                    shootToRight: flight.shootToRight,
                                    emoji: flight.emoji,
                                    assetPath: flight.assetPath,
                                    imageUrl: flight.imageUrl,
                                    hasCollision: hasCollision,
                                    onComplete: () =>
                                        _removeReactionFlight(flight.id),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

    final data = _presenceForRole(role);
    final isSleeping = PresenceService.isSleeping(data);

    Widget avatarWidget = isGreyedOut
        ? _buildAvatar(
            name,
            avatarUrl,
            isUser1: isUser1,
            onTap: customOnTap,
            onLongPress: customOnLongPress,
            isUploading: _uploadingAvatarRole == role,
            uploadProgressNotifier: _uploadingAvatarRole == role
                ? _avatarUploadProgressNotifier
                : null,
            size: avatarSize,
            isSinglePlaceholder: true,
          )
        : _buildAvatar(
            name,
            avatarUrl,
            isUser1: isUser1,
            onTap: customOnTap,
            onLongPress: customOnLongPress,
            isUploading: _uploadingAvatarRole == role,
            uploadProgressNotifier: _uploadingAvatarRole == role
                ? _avatarUploadProgressNotifier
                : null,
            size: avatarSize,
          );

    if (isSleeping) {
      avatarWidget = Stack(
        alignment: Alignment.center,
        children: [
          avatarWidget,
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.nights_stay_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        avatarWidget,
        SizedBox(height: compactMeta ? 8 : 12),
        GestureDetector(
          onTap: () async {
            DateTime initial = DateTime.now().subtract(
              const Duration(days: 365 * 20),
            );
            final currentDob =
                _houseSettings?['dob${isUser1 ? 'U1' : 'U2'}']?.toString() ??
                '';
            if (currentDob.isNotEmpty) {
              try {
                initial = DateTime.parse(currentDob);
              } catch (error) {
                debugPrint(
                  '[SuppressedError] lib/views/home/tabs/main_home/widgets/main_home_presence_section.dart: $error',
                );
              }
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
              await _dbRef.child('houses/$_houseId/settings').update({
                'dob${isUser1 ? 'U1' : 'U2'}': newDobStr,
              });
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((zodiacEmoji.isNotEmpty) || (hasAge && displayAge.isNotEmpty))
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
        if (!hideMeta)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showWeather && weatherText.isNotEmpty) ...[
                Text(
                  weatherText,
                  style: const TextStyle(fontSize: 12, height: 1),
                ),
                const SizedBox(width: 4),
              ],
              if (_showStatus)
                Flexible(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
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
    final hasZodiac = zodiacEmoji.isNotEmpty;
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
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: baseColor.withValues(alpha: 0.34), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasZodiac) ...[
            Text(zodiacEmoji, style: const TextStyle(fontSize: 16, height: 1)),
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

class _CoupleThreadPainter extends CustomPainter {
  const _CoupleThreadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 20) return;

    final path = Path()
      ..moveTo(0, size.height * 0.52)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.04,
        size.width * 0.36,
        size.height * 0.94,
        size.width * 0.5,
        size.height * 0.50,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.06,
        size.width * 0.78,
        size.height * 0.96,
        size.width,
        size.height * 0.48,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = SLColors.thread.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    final center = Offset(size.width * 0.5, size.height * 0.48);
    final heart = Path()
      ..moveTo(center.dx, center.dy + 6)
      ..cubicTo(
        center.dx - 12,
        center.dy - 2,
        center.dx - 7,
        center.dy - 10,
        center.dx,
        center.dy - 4,
      )
      ..cubicTo(
        center.dx + 7,
        center.dy - 10,
        center.dx + 12,
        center.dy - 2,
        center.dx,
        center.dy + 6,
      );
    canvas.drawPath(
      heart,
      Paint()..color = SLColors.primary.withValues(alpha: 0.20),
    );
  }

  @override
  bool shouldRepaint(covariant _CoupleThreadPainter oldDelegate) => false;
}
