part of '../../main_home_tab.dart';

// class _MainHomeAvatarSection extends StatelessWidget {
//   final _MainHomeTabState state;
//   final bool isSingle;
//   final String nameU1;
//   final String nameU2;
//   final String avtUser1;
//   final String avtUser2;
//   final String houseAvatar;
//
//   const _MainHomeAvatarSection({
//
//     required this.state,
//     required this.isSingle,
//     required this.nameU1,
//     required this.nameU2,
//     required this.avtUser1,
//     required this.avtUser2,
//     required this.houseAvatar,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final dobU1 = state._houseSettings?['dobU1']?.toString() ?? '';
//     final dobU2 = state._houseSettings?['dobU2']?.toString() ?? '';
//
//     final z1 = ZodiacUtils.getZodiac(dobU1);
//     final z2 = ZodiacUtils.getZodiac(dobU2);
//     final ageDaysU1 = state._extractAgeDays(dobU1);
//     final ageDaysU2 = state._extractAgeDays(dobU2);
//
//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.7),
//         borderRadius: BorderRadius.circular(35),
//         boxShadow: [
//           BoxShadow(
//               color: const Color(0xFFD81B60).withValues(alpha: 0.14),
//               blurRadius: 32,
//               offset: const Offset(0, 8)),
//         ],
//         border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2.5),
//       ),
//       child: isSingle
//           ? Column(
//               children: [
//                 Container(
//                   width: 140,
//                   height: 140,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     border:
//                         Border.all(color: const Color(0xFFFF80AB), width: 3),
//                     boxShadow: [
//                       BoxShadow(
//                           color: const Color(0xFFFF80AB).withValues(alpha: 0.4),
//                           blurRadius: 20,
//                           offset: const Offset(0, 4))
//                     ],
//                   ),
//                   child: ClipRRect(
//                     borderRadius: SLRadius.pillAll,
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             color: const Color(0xFF1E293B),
//                             child: const Icon(Icons.favorite,
//                                 color: Colors.white24, size: 40),
//                           ),
//                         ),
//                         Expanded(
//                           child: Container(
//                             color: const Color(0xFFFF80AB),
//                             child: const Icon(Icons.favorite,
//                                 color: Colors.white, size: 40),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 SLSpacing.h12,
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Flexible(
//                       child: Text(nameU1,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: SLTheme.quicksand(
//                               fontSize: 22,
//                               fontWeight: FontWeight.w900,
//                               color: const Color(0xFF9C27B0))),
//                     ),
//                     if (state._shouldShowAdminBadge('user1'))
//                       state._buildAdminBadge(
//                         iconSize: 15,
//                         padding: const EdgeInsets.only(left: 6),
//                       ),
//                   ],
//                 ),
//                 SLSpacing.h8,
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Container(
//                       width: 28,
//                       height: 28,
//                       alignment: Alignment.center,
//                       decoration: const BoxDecoration(
//                           color: Color(0xFFFFF4E5), shape: BoxShape.circle),
//                       child: Text(z1?['emoji'] ?? '✨',
//                           style: const TextStyle(fontSize: 14)),
//                     ),
//                     SLSpacing.w8,
//                     Container(
//                       constraints: const BoxConstraints(maxWidth: 120),
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 14, vertical: 4),
//                       decoration: BoxDecoration(
//                           color: const Color(0xFFFFE3F1),
//                           borderRadius: SLRadius.lgAll),
//                       child: Text(
//                           ageDaysU1 == '0'
//                               ? '--'
//                               : state._formatAgeForDisplay(ageDaysU1),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: SLTheme.quicksand(
//                               fontSize: 13,
//                               fontWeight: FontWeight.w900,
//                               color: const Color(0xFFD81B60))),
//                     ),
//                   ],
//                 ),
//               ],
//             )
//           : Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Expanded(
//                   child: _LegacyUserColumn(
//                     state: state,
//                     name: nameU1,
//                     avatarUrl: avtUser1,
//                     zodiacEmoji: z1?['emoji'] ?? '✦',
//                     ageDays: ageDaysU1,
//                     role: 'user1',
//                     weatherText: state._weatherTextForRole('user1', isUser1: true),
//                     statusText: state._presenceStatusText('user1'),
//                     statusColor: state._presenceStatusColor('user1'),
//                     isUser1: true,
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.only(top: 24),
//                   child: state._buildRelationshipCenterAction(isSingle: false),
//                 ),
//                 Expanded(
//                   child: _LegacyUserColumn(
//                     state: state,
//                     name: nameU2,
//                     avatarUrl: avtUser2,
//                     zodiacEmoji: z2?['emoji'] ?? '✦',
//                     ageDays: ageDaysU2,
//                     role: 'user2',
//                     weatherText: state._weatherTextForRole('user2', isUser1: false),
//                     statusText: state._presenceStatusText('user2'),
//                     statusColor: state._presenceStatusColor('user2'),
//                     isUser1: false,
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }

class _StableAvatarNetworkImage extends StatelessWidget {
  final String imageUrl;
  final String fallbackAsset;
  final BoxFit fit;

  const _StableAvatarNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return Image.asset(
        fallbackAsset,
        fit: fit,
        gaplessPlayback: true,
      );
    }

    final startupFile = HomeStartupMediaCache.getFile(url);

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      maxWidthDiskCache: 256,
      maxHeightDiskCache: 256,
      memCacheWidth: 256,
      memCacheHeight: 256,
      placeholder: (context, url) {
        if (startupFile != null && startupFile.existsSync() && startupFile.lengthSync() > 0) {
          return Image.file(
            startupFile,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Image.asset(
              fallbackAsset,
              fit: fit,
              gaplessPlayback: true,
            ),
          );
        }
        return Image.asset(
          fallbackAsset,
          fit: fit,
          gaplessPlayback: true,
        );
      },
      errorWidget: (context, url, error) {
        // Tự động xóa file cache bị hỏng khi nạp lỗi để lần sau tải lại file sạch
        unawaited(_cleanCorruptedCache(url));
        return Image.asset(
          fallbackAsset,
          fit: fit,
          gaplessPlayback: true,
        );
      },
    );
  }

  Future<void> _cleanCorruptedCache(String url) async {
    try {
      final cachedFile = await AppCacheManager.instance.getFileFromCache(url);
      final file = cachedFile?.file;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

extension _MainHomeAvatarSectionExt on _MainHomeTabState {
  Widget _buildAvatar(
    String name,
    String url, {
    required bool isUser1,
    double? size,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isUploading = false,
    double? uploadProgress,
    bool isSinglePlaceholder = false,
  }) {
    // Nếu tham số size được truyền vào (từ _LegacyAvatarSection), dùng luôn size đó.
    // Nếu không có, mới lấy từ UiPrefs.
    final effectiveSize = size ?? UiPrefs.notifier.value.avatarSizePx;
    final avatarUrl = url.trim();
    final frameKey =
        isSinglePlaceholder ? 'circle' : UiPrefs.notifier.value.avatarFrameKey;
    final framePadding =
        LegacyWebUi.avatarFramePaddingForKey(frameKey, effectiveSize);
    final frameRadius =
        LegacyWebUi.avatarBorderRadiusForKey(frameKey, effectiveSize);
    final frameIsCircle = LegacyWebUi.avatarFrameIsCircle(frameKey);
    final fallbackAsset = isUser1
        ? 'assets/images/avatar_male.jpg'
        : 'assets/images/avatar_female.jpg';
    final avatarContent = isSinglePlaceholder
        ? const _AnimatedSinglePlaceholder()
        : _StableAvatarNetworkImage(
            key: ValueKey<String>(
              'home-avatar-${isUser1 ? 'user1' : 'user2'}',
            ),
            imageUrl: avatarUrl,
            fallbackAsset: fallbackAsset,
            fit: BoxFit.cover,
          );

    final showChooseImageHint =
        avatarUrl.isEmpty && !isUploading && !isSinglePlaceholder;
    final clippedAvatar = frameIsCircle
        ? ClipOval(child: avatarContent)
        : ClipRRect(
            borderRadius: frameRadius,
            child: avatarContent,
          );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        onLongPress: isUploading ? null : onLongPress,
        child: SizedBox(
          width: effectiveSize,
          height: effectiveSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Avatar Circle
              Align(
                alignment: Alignment.center,
                child: isSinglePlaceholder
                    ? Container(
                        width: effectiveSize,
                        height: effectiveSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3F4F6),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: framePadding,
                          child: clippedAvatar,
                        ),
                      )
                    : SlAvatarFrame(
                        frameKey: frameKey,
                        size: effectiveSize,
                        accentColor: isUser1
                            ? LegacyWebUi.accentPink
                            : LegacyWebUi.accentBlue,
                        isUser1: isUser1,
                        child: avatarContent,
                      ),
              ),
              if (showChooseImageHint)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _BlinkingAvatarHint(),
                  ),
                ),
              // Uploading Indicator
              if (isUploading)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: effectiveSize,
                    height: effectiveSize,
                    decoration: BoxDecoration(
                      shape:
                          frameIsCircle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: frameIsCircle ? null : frameRadius,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              value: uploadProgress,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.9)),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          if (uploadProgress != null)
                            Text(
                              '${(uploadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

//   Widget _buildQuestionAvatarPlaceholder() {
//     return Container(
//       color: const Color(0xFFD1D5DB),
//       alignment: Alignment.center,
//       child: Text(
//         '?',
//         style: SLTheme.quicksand(
//           fontSize: 28,
//           fontWeight: FontWeight.w900,
//           color: const Color(0xFF6B7280),
//         ),
//       ),
//     );
//   }
}

class _PlaceholderParticle {
  final double angle;
  final double maxDistance;
  final String text;
  final double scale;
  final double rotation;

  _PlaceholderParticle({
    required this.angle,
    required this.maxDistance,
    required this.text,
    required this.scale,
    required this.rotation,
  });
}

class _AnimatedSinglePlaceholder extends StatefulWidget {
  const _AnimatedSinglePlaceholder();

  @override
  State<_AnimatedSinglePlaceholder> createState() =>
      __AnimatedSinglePlaceholderState();
}

class __AnimatedSinglePlaceholderState extends State<_AnimatedSinglePlaceholder>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _revealController;
  late AnimationController _particleController;
  late AnimationController _pulseController;

  int _currentIndex = 0;
  bool _isSpinning = true;
  final List<_PlaceholderParticle> _particles = [];

  final List<String> _emojis = const [
    '❓',
    '💖',
    '🔍',
    '👤',
    '✨',
    '💌',
    '🎁',
    '🥰',
    '🌹',
    '🔮',
    '🧸',
    '🎈',
    '💎'
  ];

  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _startCycle();
  }

  void _generateParticles() {
    _particles.clear();
    final List<String> particleEmojis = ['❤️', '✨', '🌸', '⭐', '💖', '💛'];
    for (int i = 0; i < 8; i++) {
      final angle = (i * (2 * pi) / 8) + _random.nextDouble() * 0.3;
      final maxDistance = 45.0 + _random.nextDouble() * 20.0;
      final text = particleEmojis[_random.nextInt(particleEmojis.length)];
      final scale = 0.6 + _random.nextDouble() * 0.6;
      final rotation = _random.nextDouble() * pi;
      _particles.add(_PlaceholderParticle(
        angle: angle,
        maxDistance: maxDistance,
        text: text,
        scale: scale,
        rotation: rotation,
      ));
    }
  }

  Future<void> _startCycle() async {
    while (mounted) {
      // 1. Giai đoạn 1: Quay tít tìm kiếm
      _pulseController.stop();
      if (!mounted) return;
      setState(() {
        _isSpinning = true;
      });
      _spinController.repeat();

      // Cho quay trong 2.0 giây
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;

      // Dừng quay
      _spinController.stop();

      // 2. Giai đoạn 2: Reveal emoji mới + nổ hạt
      setState(() {
        _isSpinning = false;
        int nextIndex = _random.nextInt(_emojis.length);
        while (nextIndex == _currentIndex && _emojis.length > 1) {
          nextIndex = _random.nextInt(_emojis.length);
        }
        _currentIndex = nextIndex;
        _generateParticles();
      });

      _revealController.forward(from: 0.0);
      _particleController.forward(from: 0.0);

      // Chờ cho animation reveal hoàn thành một nửa rồi bắt đầu pulse
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _pulseController.repeat(reverse: true);

      // Chờ tiếp thời gian hiển thị tĩnh (3.2 giây nữa, tổng cộng 4 giây tĩnh)
      await Future.delayed(const Duration(milliseconds: 3200));
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _revealController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final center = size / 2;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 1. Radar scan / Glow ring
            if (_isSpinning)
              AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _spinController.value * 2 * pi,
                    child: Container(
                      width: size * 0.9,
                      height: size * 0.9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.pinkAccent.withValues(alpha: 0.0),
                            Colors.pinkAccent.withValues(alpha: 0.3),
                            Colors.pinkAccent.withValues(alpha: 0.6),
                            Colors.pinkAccent.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.4, 0.8, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              // Nhấp nháy vòng tròn đỏ mờ khi tĩnh (pulse glow)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final double pulse = _pulseController.value;
                  return Container(
                    width: size * 0.85,
                    height: size * 0.85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4081)
                              .withValues(alpha: 0.2 * pulse),
                          blurRadius: 10 + 10 * pulse,
                          spreadRadius: 2 + 5 * pulse,
                        ),
                      ],
                    ),
                  );
                },
              ),

            // 2. Hạt lấp lánh nổ ra (Particle Burst)
            if (!_isSpinning)
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final progress = _particleController.value;
                  if (progress >= 1.0) return const SizedBox.shrink();

                  return Stack(
                    clipBehavior: Clip.none,
                    children: _particles.map((p) {
                      final dx = cos(p.angle) * p.maxDistance * progress;
                      final dy = sin(p.angle) * p.maxDistance * progress;
                      final opacity = (1.0 - progress).clamp(0.0, 1.0);
                      final scale = p.scale * (1.0 - progress * 0.4);

                      return Positioned(
                        left: center + dx - 8,
                        top: center + dy - 8,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.rotate(
                            angle: p.rotation + progress * 2 * pi,
                            child: Transform.scale(
                              scale: scale,
                              child: Text(
                                p.text,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            // 3. Emoji chính ở giữa
            _isSpinning
                ? AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      final rotationValue = _spinController.value * 2 * pi;
                      final scaleValue = 1.0 -
                          (sin(_spinController.value * pi * 2).abs() * 0.12);
                      return Transform.scale(
                        scale: scaleValue,
                        child: Transform.rotate(
                          angle: rotationValue,
                          child: Text(
                            '❓',
                            style: TextStyle(
                              fontSize: size * 0.45,
                              shadows: const [
                                Shadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _revealController,
                      curve: Curves.elasticOut,
                    ),
                    child: Text(
                      _emojis[_currentIndex],
                      style: TextStyle(
                        fontSize: size * 0.48,
                        shadows: const [
                          Shadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
