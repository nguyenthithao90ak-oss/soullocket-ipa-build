part of '../secret_vault_screen.dart';

extension _SecretVaultGallerySectionPart on SecretVaultScreenState {
  Widget _buildPendingResetBanner() {
    if (!_hasPendingReset) {
      return const SizedBox.shrink();
    }

    final scheduledAt = _pendingResetRequest?.scheduledAt ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B1A1A).withValues(alpha: 0.95),
            const Color(0xFF3D0E0E).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF1744).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFAB40),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('util_khonhmtang_7c1b4d'),
                  softWrap: true,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            L10nScope.of(context).format(
              'ui_utilities_value1_has_confirmed_the_reset_via_email_8737e3',
              {
                'value1': _pendingResetRequesterLabel(),
                'value2': _formatResetSchedule(scheduledAt),
              },
            ),
            style: SLTheme.quicksand(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              height: 1.45,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _AnimatedPressButton(
              onTap: _isCancelingReset ? null : _cancelVaultResetRequest,
              borderRadius: 14,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFFAB40).withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isCancelingReset
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFAB40),
                            ),
                          )
                        : const Icon(
                            Icons.undo_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isCancelingReset
                            ? context.tr('util_angthuhiyu_c4c6f7')
                            : context.tr('util_thuhiyucur_db8240'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadHeader() {
    final busy = _isLoading || _isPreparingVault;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _vaultBgAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _vaultBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _vaultField,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _vaultAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.tr(
                    'ui_utilities_secure_encrypted_private_storage_04d8a5',
                  ),
                  style: SLTheme.quicksand(
                    color: _vaultTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('ui_utilities_only_the_two_of_you_can_view_429942'),
            style: SLTheme.quicksand(
              color: _vaultTextSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: busy || _hasPendingReset
                ? null
                : (_encryptionReady
                      ? () {
                          _uploadPhoto();
                        }
                      : () {
                          _prepareVault();
                        }),
            style: FilledButton.styleFrom(
              backgroundColor: _vaultAccent,
              foregroundColor: _vaultBg,
              disabledBackgroundColor: _vaultField,
              disabledForegroundColor: _vaultTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _vaultTextSecondary,
                    ),
                  )
                : Icon(
                    _encryptionReady
                        ? Icons.add_photo_alternate_outlined
                        : Icons.lock_open_rounded,
                  ),
            label: Text(
              _encryptionReady
                  ? context.tr('util_thmnhmt_b7dfc6')
                  : context.tr('util_mkhakhomt_35391f'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          if (_encryptionReady) ...[
            const SizedBox(height: 14),
            FutureBuilder<VipAccessInfo>(
              future: _vaultPlan,
              builder: (context, snapshot) {
                final plan =
                    snapshot.data ??
                    const VipAccessInfo(
                      isVip: false,
                      planId: '',
                      expiresAtMs: null,
                    );
                final daily =
                    vault_policy.secretVaultDailyBytes(plan) / (1024 * 1024);
                final total =
                    vault_policy.secretVaultTotalBytes(plan) / (1024 * 1024);
                return Text(
                  L10nScope.of(context).format('vault_byte_limits', {
                    'daily': NumberFormat.decimalPattern(
                      LocaleDateFormat.intlLocale,
                    ).format(daily),
                    'total': NumberFormat.decimalPattern(
                      LocaleDateFormat.intlLocale,
                    ).format(total),
                  }),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: _vaultTextSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                );
              },
            ),
          ],
          if (_hasPendingReset) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('util_tmkhathmnh_eabdb8'),
              style: SLTheme.quicksand(color: const Color(0xFFFFCC80)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPhotoSlivers() {
    if (!_encryptionReady) {
      return [
        SliverToBoxAdapter(
          child: VaultGalleryPlaceholder(
            icon: Icons.lock_outline_rounded,
            title: _encStatusMsg,
          ),
        ),
      ];
    }
    if (_photos.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: VaultGalleryPlaceholder(
            icon: Icons.photo_library_outlined,
            title: context.tr('ui_utilities_the_vault_is_empty_33d92f'),
            detail: context.tr('vault_empty_add_photo'),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: VaultGallerySummary(
            countLabel: _hasMorePhotos
                ? L10nScope.of(context).format(
                    'ui_utilities_value1_most_recent_photo_5ba47b',
                    {'value1': _photos.length},
                  )
                : L10nScope.of(context).format(
                    'ui_utilities_value1_photos_df06c7',
                    {'value1': _photos.length},
                  ),
            hasMorePhotos: _hasMorePhotos,
            isLoadingMore: _isLoadingMorePhotos,
            loadMoreLabel: _isLoadingMorePhotos
                ? context.tr('util_angti_d5fe42')
                : context.tr('util_nhchn_d2d33c'),
            onLoadMore: _loadMorePhotos,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _photos.length,
          itemBuilder: (context, index) {
            final photo = _photos[index];
            final caption = photo['caption_plain'] as String?;
            final isEncrypted = photo['encrypted'] == true;

            return _AnimatedPressButton(
              onTap: () => _showFullImage(photo, caption),
              borderRadius: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildVaultImage(
                      photo,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      loading: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_vaultBgAlt, _vaultField],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: _vaultAccent,
                            ),
                          ),
                        ),
                      ),
                      error: Container(
                        color: _vaultField,
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: _vaultTextSecondary,
                        ),
                      ),
                    ),
                    // Lớp nền giúp huy hiệu rõ trên ảnh.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Huy hiệu mã hóa giữ cùng bảng màu của Kho bí mật.
                    if (isEncrypted)
                      PositionedDirectional(
                        bottom: 8,
                        start: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _vaultBg.withValues(alpha: 0.9),
                            border: Border.all(
                              color: _vaultAccent.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                color: _vaultAccent,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'AES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Vùng chạm 48dp vẫn gọi xác nhận xóa hiện có.
                    PositionedDirectional(
                      top: 4,
                      end: 4,
                      child: IconButton(
                        tooltip: context.tr('util_xanhmt_9adda3'),
                        onPressed: () => _confirmDelete(photo),
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                          backgroundColor: Colors.black.withValues(alpha: 0.65),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  void _confirmDelete(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('util_xanhmt_9adda3')),
        content: Text(context.tr('util_nhnysbxakh_78fc2c')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

            onPressed: () {
              Navigator.pop(ctx);
              _deletePhoto(photo);
            },
            child: Text(context.tr('util_xa_4ed187')),
          ),
        ],
      ),
    );
  }
}

/// Tóm tắt gallery chỉ trình bày nhãn và gọi callback phân trang hiện có.
class VaultGallerySummary extends StatelessWidget {
  const VaultGallerySummary({
    super.key,
    required this.countLabel,
    required this.loadMoreLabel,
    required this.hasMorePhotos,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final String countLabel;
  final String loadMoreLabel;
  final bool hasMorePhotos;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _vaultField,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _vaultBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: _vaultAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        countLabel,
                        style: SLTheme.quicksand(
                          color: _vaultTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasMorePhotos)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Semantics(
                  liveRegion: isLoadingMore,
                  child: OutlinedButton.icon(
                    onPressed: isLoadingMore ? null : onLoadMore,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      foregroundColor: _vaultAccent,
                      backgroundColor: _vaultField,
                      disabledForegroundColor: _vaultTextSecondary,
                      side: const BorderSide(color: _vaultBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: isLoadingMore
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _vaultAccent,
                            ),
                          )
                        : const Icon(Icons.history_rounded, size: 20),
                    label: Text(
                      loadMoreLabel,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Trạng thái trống/khóa cuộn được khi chiều cao còn lại hoặc chữ lớn.
class VaultGalleryPlaceholder extends StatelessWidget {
  const VaultGalleryPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_vaultField, _vaultBgAlt],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _vaultAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(icon, color: _vaultAccent, size: 44),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: _vaultTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      detail!,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: _vaultTextSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget helper cung cấp hiệu ứng nhấn mượt mà.
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    this.borderRadius = 0,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _ctrl.forward();
    }
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
  }

  void _onTapCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : _onTapDown,
      onTapUp: widget.onTap == null ? null : _onTapUp,
      onTapCancel: widget.onTap == null ? null : _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: MediaQuery.disableAnimationsOf(context) ? 1 : _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
