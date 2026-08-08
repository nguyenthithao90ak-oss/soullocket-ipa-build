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
        border:
            Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
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
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFAB40), size: 18),
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
            '${_pendingResetRequesterLabel()} đã xác nhận reset qua email. Toàn bộ dữ liệu sẽ bị xoá vào ${_formatResetSchedule(scheduledAt)} nếu không thu hồi kịp thời.',
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFFFAB40).withValues(alpha: 0.6)),
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
                        : const Icon(Icons.undo_rounded,
                            size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _isCancelingReset
                          ? context.tr('util_angthuhiyu_c4c6f7')
                          : context.tr('util_thuhiyucur_db8240'),
                      style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800, color: Colors.white),
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
    return Container(
      margin: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C3483).withValues(alpha: 0.18),
                  const Color(0xFFE91E63).withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFFCE93D8).withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE91E63).withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.security_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Kho lưu trữ riêng tư được mã hóa an toàn. 🔐',
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Chỉ hai bạn mới có thể xem được nội dung.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                const SizedBox(height: 20),
                _AnimatedPressButton(
                  onTap: (_isLoading || _hasPendingReset)
                      ? null
                      : (_encryptionReady ? _uploadPhoto : _prepareVault),
                  borderRadius: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_isLoading || _hasPendingReset)
                            ? [
                                Colors.grey.shade700,
                                Colors.grey.shade600,
                              ]
                            : [
                                const Color(0xFFAD1457),
                                const Color(0xFFE91E63),
                                const Color(0xFFF06292),
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: (_isLoading || _hasPendingReset)
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFFE91E63)
                                    .withValues(alpha: 0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              )
                            ],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _encryptionReady
                                    ? Icons.add_photo_alternate_rounded
                                    : Icons.lock_open_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _encryptionReady
                                    ? context.tr('util_thmnhmt_b7dfc6')
                                    : context.tr('util_mkhakhomt_35391f'),
                                style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontSize: 14.5),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Platform.isIOS || Platform.isMacOS
                        ? 'Tối đa ${StorageService.maxSecretVaultSelectionPerBatch} ảnh/lần  •  Giới hạn ${StorageService.secretVaultDailyLimitFree} ảnh/ngày'
                        : 'Tối đa ${StorageService.maxSecretVaultSelectionPerBatch} ảnh/lần  •  Thường: ${StorageService.secretVaultDailyLimitFree}  •  PRO: ${StorageService.secretVaultDailyLimitVip} ảnh/ngày',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_hasPendingReset) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFFF6D00).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      context.tr('util_tmkhathmnh_eabdb8'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: const Color(0xFFFFAB40),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (!_encryptionReady) ...[
                  const SizedBox(height: 14),
                  _AnimatedPressButton(
                    onTap: _prepareVault,
                    borderRadius: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        context.tr('util_nhplimtkhu_eee7a7'),
                        style: SLTheme.quicksand(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    const Color(0xFFE91E63).withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kho mật đang trống.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Thêm ảnh đầu tiên để bắt đầu bảo mật!',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                  color: Colors.white38, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFCE93D8).withValues(alpha: 0.3)),
                ),
                child: Text(
                  _hasMorePhotos
                      ? '${_photos.length} ảnh gần nhất'
                      : '${_photos.length} ảnh',
                  style: SLTheme.quicksand(
                    color: const Color(0xFFCE93D8),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const Spacer(),
              if (_hasMorePhotos)
                _AnimatedPressButton(
                  onTap: _isLoadingMorePhotos ? null : _loadMorePhotos,
                  borderRadius: 20,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A1B9A).withValues(alpha: 0.35),
                          const Color(0xFFAD1457).withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFCE93D8).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLoadingMorePhotos
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFCE93D8)))
                            : const Icon(Icons.history_rounded,
                                size: 14, color: Color(0xFFCE93D8)),
                        const SizedBox(width: 5),
                        Text(
                          _isLoadingMorePhotos
                              ? context.tr('util_angti_d5fe42')
                              : context.tr('util_nhchn_d2d33c'),
                          style: SLTheme.quicksand(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: const Color(0xFFCE93D8)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              final caption = photo['caption_plain'] as String?;
              final isEncrypted = photo['encrypted'] == true;

              return _AnimatedPressButton(
                onTap: () => _showFullImage(photo['url'], caption),
                borderRadius: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: CloudflareImageHelper.optimizeUrl(photo['url'], width: 600),
                        fit: BoxFit.cover,
                        maxWidthDiskCache: 600,
                        memCacheWidth: 600,
                        filterQuality: FilterQuality.medium,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2D1B69).withValues(alpha: 0.6),
                                const Color(0xFF1A0533).withValues(alpha: 0.6),
                              ],
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
                                color: Color(0xFFCE93D8),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1A0533),
                          child: const Icon(Icons.broken_image,
                              color: Color(0xFF6A1B9A)),
                        ),
                      ),
                      // Bottom gradient overlay
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
                      // Encrypted badge
                      if (isEncrypted)
                        Positioned(
                          bottom: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00897B),
                                  Color(0xFF00ACC1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, color: Colors.white, size: 8),
                                SizedBox(width: 2),
                                Text('AES',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      // Delete button
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => _confirmDelete(photo),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white70, size: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('util_xanhmt_9adda3'),
            style: SLTheme.quicksand(
                fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(context.tr('util_nhnysbxakh_78fc2c'),
            style: SLTheme.quicksand(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('util_hy_1e4050'),
                  style: SLTheme.quicksand(color: Colors.white38))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePhoto(photo);
            },
            child: Text(context.tr('util_xa_4ed187'),
                style: SLTheme.quicksand(
                    color: const Color(0xFFFF5252),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Widget helper cung cấp hiệu ứng nhấn mượt mà (scale + opacity)
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
