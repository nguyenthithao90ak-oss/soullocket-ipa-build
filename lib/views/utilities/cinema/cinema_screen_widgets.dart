part of '../cinema_screen.dart';

extension _CinemaScreenStateWidgetsPart on _CinemaScreenState {
  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Rạp chiếu phim',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Cùng nhau xem YouTube đồng bộ từ xa (vừa xem vừa chat/call).\n- Bạn tua video hoặc tạm dừng, máy người ấy cũng đồng bộ theo lập tức.'),
              SizedBox(height: 12),
              Text('Cách sử dụng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Dán link video YouTube vào ô tìm kiếm hoặc chọn từ lịch sử.\n- Khi video phát, cả hai sẽ xem cùng một khoảnh khắc. Bất kỳ ai bấm Pause hoặc tua đi, hệ thống sẽ đồng bộ cho người còn lại.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final reel = _activeReel;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _circleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            _circleButton(
              icon: Icons.info_outline_rounded,
              onTap: () => _showInfoDialog(context),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _pill(
                  icon: reel == null
                      ? Icons.schedule_rounded
                      : Icons.local_movies_rounded,
                  label: reel == null
                      ? context.tr('util_chngmcknim_626e2b')
                      : context.tr('util_sutchiutro_a8a347'),
                  color: reel == null
                      ? const Color(0xFF7FD3FF)
                      : Color(reel.accentValue),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(_CinemaDailyReel? reel) {
    final nextMilestone = _nextAnniversaryMilestone(DateTime.now(), _startDate);
    final nextShow = nextMilestone?.date;
    final metricValues = reel == null
        ? <Map<String, String>>[
            <String, String>{
              'label': context.tr('util_btu_3cb0f0'),
              'value':
                  _startDate == null ? '--/--/----' : _formatDate(_startDate!),
            },
            <String, String>{
              'label': context.tr('util_khonh_8160c2'),
              'value': '${_records.length} ảnh',
            },
            <String, String>{
              'label': context.tr('util_mcktip_3705df'),
              'value': nextShow == null ? '--/--/----' : _formatDate(nextShow),
            },
          ]
        : <Map<String, String>>[
            <String, String>{
              'label': context.tr('util_btu_3cb0f0'),
              'value':
                  _startDate == null ? '--/--/----' : _formatDate(_startDate!),
            },
            <String, String>{
              'label': context.tr('util_khunghnh_cba5af'),
              'value': '${reel.items.length}/$_kCinemaReelFrameLimit',
            },
            <String, String>{
              'label': context.tr('util_txalc_c19250'),
              'value': _formatClock(reel.expiresAt),
            },
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final accent =
            reel == null ? const Color(0xFF8AD8FF) : Color(reel.accentValue);
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xCC122033),
                Color(0xCC1B1732),
                Color(0xCC2E1525),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x5A000000),
                blurRadius: 42,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: compact ? 50 : 56,
                    height: compact ? 50 : 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          accent.withValues(alpha: 0.26),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Icon(
                      reel == null
                          ? Icons.movie_filter_outlined
                          : Icons.movie_creation_outlined,
                      color: Colors.white,
                      size: compact ? 27 : 30,
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              context.tr('util_rpknim_d094b9'),
                              style: SLTheme.quicksand(
                                fontSize: compact ? 22 : 25,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            _pill(
                              icon: reel == null
                                  ? Icons.schedule_rounded
                                  : Icons.local_fire_department_rounded,
                              label: reel == null
                                  ? context.tr('util_chmsut_dbc583')
                                  : context.tr('util_angsngn_6f20a4'),
                              color: accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _houseName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 14 : 16),
              Text(
                reel == null
                    ? context.tr('util_nngmcknimh_7b8732')
                    : context.tr('util_sutchiuhmn_0b4972'),
                style: SLTheme.quicksand(
                  fontSize: compact ? 13.5 : 14.5,
                  height: 1.48,
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
              SizedBox(height: compact ? 14 : 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(metricValues.length, (index) {
                  final metric = metricValues[index];
                  return SizedBox(
                    width: compact
                        ? (constraints.maxWidth - 10) / 2
                        : (constraints.maxWidth - 20) / 3,
                    child: _metricCard(
                      label: metric['label']!,
                      value: metric['value']!,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegacyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x18FFC857),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x55FFC857)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFFD87A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('util_linkphimcv_f4802e'),
              style: SLTheme.quicksand(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedShowtimeCard() {
    final nextMilestone = _nextAnniversaryMilestone(DateTime.now(), _startDate);
    final nextShow = nextMilestone?.date;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x227FD3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF7FD3FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nextShow == null
                      ? context.tr('util_chaxcnhcmc_84ba6e')
                      : 'Suất gần nhất sẽ mở vào ${_formatDate(nextShow)}',
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (nextMilestone != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    nextMilestone.title,
                    style: SLTheme.quicksand(
                      fontSize: 12.6,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFDFA2),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Khi tới đúng mốc đó, reel sẽ tự chọn tối đa $_kCinemaReelFrameLimit ảnh và phát như một video ngắn.',
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.42,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    _CinemaDailyReel reel,
    _CinemaMemoryRecord item,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: const Color(0xFF121B2B),
              child: InkWell(
                onTap: _openPlayer,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: SizedBox(
                    key: ValueKey<String>('${reel.dateKey}_${item.id}'),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _buildContainedImage(item.imageUrl),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black.withValues(alpha: 0.18),
                                  Colors.transparent,
                                  const Color(0xED05070D),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            right: 14,
                            child: _buildStoryProgress(
                              itemCount: reel.items.length,
                              activeIndex: _previewIndex,
                              keySalt: reel.dateKey,
                            ),
                          ),
                          Positioned(
                            top: 32,
                            left: 16,
                            right: 16,
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _pill(
                                    icon: Icons.local_movies_rounded,
                                    label: reel.title,
                                    color: Color(reel.accentValue),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _pill(
                                  icon: Icons.auto_awesome_motion_rounded,
                                  label:
                                      '${_previewIndex + 1}/${reel.items.length}',
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(42),
                                  child: FastBackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(42),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'PHÁT REEL',
                                            style: SLTheme.quicksand(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _formatLongDate(DateTime.now()),
                                  style: SLTheme.quicksand(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.authorName.isEmpty
                                      ? context.tr('util_videoknimh_23d177')
                                      : 'Khung hình có ảnh được lưu bởi ${item.authorName}.',
                                  style: SLTheme.quicksand(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: Colors.white.withValues(alpha: 0.80),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (reel.items.length > 1) ...<Widget>[
                            Positioned(
                              left: 12,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _overlayArrow(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: _showPreviousPreview,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _overlayArrow(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: _showNextPreview,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _metricCard(
                  label: context.tr('util_thilng_77d9bd'),
                  value: _formatDurationLabel(reel.items.length),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  label: context.tr('util_ngunnh_7abd29'),
                  value: '${_records.length} ảnh nhật ký',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilmstrip(_CinemaDailyReel reel) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: SingleChildScrollView(
        controller: _filmstripController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List<Widget>.generate(reel.items.length, (index) {
            final item = reel.items[index];
            final isActive = index == _previewIndex;
            return GestureDetector(
              onTap: () => _setPreviewIndex(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _kCinemaFilmstripCardWidth,
                margin: EdgeInsets.only(
                  right: index == reel.items.length - 1
                      ? 0
                      : _kCinemaFilmstripSpacing,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isActive
                        ? Color(reel.accentValue)
                        : Colors.white.withValues(alpha: 0.06),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: isActive
                      ? <BoxShadow>[
                          BoxShadow(
                            color:
                                Color(reel.accentValue).withValues(alpha: 0.26),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _networkImage(item.displayUrl),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.54),
                            ],
                          ),
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(reel.accentValue)
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              context.tr('util_angchiu_6db1a2'),
                              style: SLTheme.quicksand(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildReelInfoCard(_CinemaDailyReel reel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(reel.accentValue).withValues(alpha: 0.24),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.theaters_rounded,
                  color: Color(reel.accentValue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.tr('util_thngtinsut_5983b0'),
                      style: SLTheme.quicksand(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reel.subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 13.2,
                        height: 1.42,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildBulletLine(
                  Icons.shuffle_rounded,
                  'Chọn ngẫu nhiên tối đa $_kCinemaReelFrameLimit ảnh từ toàn bộ kho kỷ niệm.',
                ),
                const SizedBox(height: 10),
                _buildBulletLine(
                  Icons.lock_clock_rounded,
                  context.tr('util_ginguyndan_dadbe6'),
                ),
                const SizedBox(height: 10),
                _buildBulletLine(
                  Icons.delete_sweep_rounded,
                  'Tự xóa lúc ${_formatClock(reel.expiresAt)} để ngày kỷ niệm sau dựng lại reel mới.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Color(reel.accentValue).withValues(alpha: 0.26),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _openPlayer,
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
              label: Text(context.tr('util_mvideotonm_ca3c77')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child:
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.78)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: SLTheme.quicksand(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF121A28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: SLTheme.quicksand(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
          if (child != null) child,
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: SLTheme.quicksand(
            fontSize: 13.5,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryProgress({
    required int itemCount,
    required int activeIndex,
    required String keySalt,
    double height = 4,
  }) {
    return Row(
      children: List<Widget>.generate(itemCount, (index) {
        final isDone = index < activeIndex;
        final isActive = index == activeIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == itemCount - 1 ? 0 : 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: height,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: isActive
                        ? TweenAnimationBuilder<double>(
                            key: ValueKey<String>(
                                '$keySalt-$index-$activeIndex'),
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: _kCinemaFrameDuration,
                            builder: (context, value, child) {
                              return FractionallySizedBox(
                                widthFactor: value,
                                child: child,
                              );
                            },
                            child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.92)),
                          )
                        : FractionallySizedBox(
                            widthFactor: isDone ? 1 : 0,
                            child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.75)),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).map((segment) => segment).toList(growable: false),
    );
  }

  Widget _networkImage(String url) {
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    if (isNetwork) {
      return CachedNetworkImage(
        maxWidthDiskCache: 720,
        imageUrl: url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        placeholder: (_, __) => Container(
          color: const Color(0xFF182334),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Color(0xFFFF6FA5),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFF182334),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 30,
          ),
        ),
      );
    } else {
      return Image.file(
        File(url),
        cacheWidth: 1440,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF182334),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 30,
          ),
        ),
      );
    }
  }

  Widget _buildContainedImage(
    String url, {
    int memCacheWidth = 720,
    double errorIconSize = 30,
  }) {
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: isNetwork
            ? CachedNetworkImage(
                maxWidthDiskCache: memCacheWidth,
                imageUrl: url,
                fit: BoxFit.scaleDown,
                filterQuality: FilterQuality.medium,
                alignment: Alignment.center,
                placeholder: (_, __) => const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFFF6FA5),
                  ),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: errorIconSize,
                ),
              )
            : Image.file(
                File(url),
                cacheWidth: memCacheWidth,
                fit: BoxFit.scaleDown,
                filterQuality: FilterQuality.medium,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: errorIconSize,
                ),
              ),
      ),
    );
  }

  Widget _buildGlow({required Color color, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color,
              blurRadius: size * 0.5,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({required String label, required String value}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _overlayArrow({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
