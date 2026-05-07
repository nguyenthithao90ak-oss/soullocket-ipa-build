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
        color: const Color(0xFF4A1F1F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kho ảnh mật đang chờ reset',
                  softWrap: true,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
            child: OutlinedButton.icon(
              onPressed: _isCancelingReset ? null : _cancelVaultResetRequest,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isCancelingReset
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orangeAccent,
                      ),
                    )
                  : const Icon(Icons.undo_rounded, size: 18),
              label: Text(
                _isCancelingReset
                    ? 'Đang thu hồi yêu cầu...'
                    : 'Thu hồi yêu cầu reset',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
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
        borderRadius: BorderRadius.circular(25),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text(
                  'Kho lưu trữ riêng tư được mã hóa an toàn. 🔐\nChỉ hai bạn mới có thể xem được nội dung.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      fontSize: 13.5),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: (_isLoading || _hasPendingReset)
                      ? null
                      : (_encryptionReady ? _uploadPhoto : _prepareVault),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6))
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
                              const Icon(Icons.lock_outline,
                                  color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                _encryptionReady
                                    ? 'THÊM ẢNH MẬT'
                                    : 'MỞ KHÓA KHO MẬT',
                                style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mỗi lần tối đa ${StorageService.maxSecretVaultSelectionPerBatch} ảnh. Giới hạn ngày: ${StorageService.secretVaultDailyLimitFree} ảnh thường, ${StorageService.secretVaultDailyLimitVip} ảnh PRO.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                if (_hasPendingReset) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Tạm khóa thêm ảnh mới trong lúc Kho ảnh mật đang chờ reset.',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (!_encryptionReady) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _prepareVault,
                    child: Text(
                      'Nhập lại mật khẩu',
                      style: SLTheme.quicksand(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
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
        child: Text(
          'Kho mật đang trống.\nThêm ảnh đầu tiên để bắt đầu bảo mật!',
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
              color: Colors.white38, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _hasMorePhotos
                      ? 'Đang nghe ${_photos.length} ảnh gần nhất'
                      : 'Đã tải ${_photos.length} ảnh',
                  style: SLTheme.quicksand(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (_hasMorePhotos)
                TextButton.icon(
                  onPressed: _isLoadingMorePhotos ? null : _loadMorePhotos,
                  icon: _isLoadingMorePhotos
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history_rounded, size: 16),
                  label: Text(
                    _isLoadingMorePhotos ? 'Đang tải...' : 'Ảnh cũ hơn',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w700),
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              final caption = photo['caption_plain'] as String?;
              final isEncrypted = photo['encrypted'] == true;

              return GestureDetector(
                onTap: () => _showFullImage(photo['url'], caption),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: photo['url'],
                        fit: BoxFit.cover,
                        memCacheWidth: 720,
                        filterQuality: FilterQuality.high,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 35,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      if (isEncrypted)
                        Positioned(
                          bottom: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.8),
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
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => _confirmDelete(photo),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.black45, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
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
        backgroundColor: const Color(0xFF1F1C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xóa ảnh mật?',
            style: SLTheme.quicksand(
                fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text('Ảnh này sẽ bị xóa khỏi kho mật.',
            style: SLTheme.quicksand(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Hủy', style: SLTheme.quicksand(color: Colors.white38))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePhoto(photo);
            },
            child: Text('Xóa',
                style: SLTheme.quicksand(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
