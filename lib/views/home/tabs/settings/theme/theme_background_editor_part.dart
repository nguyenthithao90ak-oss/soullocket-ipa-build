// ignore_for_file: unused_element
part of '../../settings_tab.dart';

extension _SettingsTabThemeBackgroundEditorPart on _SettingsTabState {
  Widget _buildThemeBackgroundPreviewCard(String imageUrl) {
    final safeImageUrl = imageUrl.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3D9E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_iphone_rounded,
                size: 16,
                color: Color(0xFFD81B60),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('theme_preview'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFF7BDD3)),
                ),
                child: Text(
                  '9:16',
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 178,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2433),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD81B60).withOpacity(0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: _themeBackgroundAspectRatio.ratioX /
                    _themeBackgroundAspectRatio.ratioY,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildThemeBackgroundPreviewImage(safeImageUrl),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.14),
                              Colors.transparent,
                              Colors.black.withOpacity(0.24),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.42, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.84),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                context.tr('theme_preview_love_days'),
                                style: SLTheme.quicksand(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD81B60),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.82),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                size: 11,
                                color: Color(0xFFFF5E92),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.78),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.92),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8A65),
                                    Color(0xFFFF5E92),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  '55',
                                  style: SLTheme.quicksand(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 0.95,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ngày rồi',
                                style: SLTheme.quicksand(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF7E5F72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 44,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildThemeBackgroundPreviewBlock(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildThemeBackgroundPreviewBlock(),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              5,
                              (index) => Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? const Color(0xFFD81B60)
                                      : const Color(0xFFE8AFC6),
                                  shape: BoxShape.circle,
                                ),
                              ),
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
          const SizedBox(height: 10),
          Text(
            context.tr('theme_preview_desc'),
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A5B76),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeBackgroundPreviewImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF3F8),
              Color(0xFFFFE3EC),
              Color(0xFFF6D7FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 24,
              color: Color(0xFFD81B60),
            ),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      memCacheWidth: 1080,
      placeholder: (_, __) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF3F8),
              Color(0xFFFFE3EC),
              Color(0xFFF6D7FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFFFFEEF5),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFD81B60),
        ),
      ),
    );
  }

  Widget _buildThemeBackgroundPreviewBlock() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.88)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 22,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9FBC),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            width: double.infinity,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFF7C8D9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFEED8E4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
