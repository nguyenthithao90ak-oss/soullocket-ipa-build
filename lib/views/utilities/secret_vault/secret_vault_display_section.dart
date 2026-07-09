part of '../secret_vault_screen.dart';

extension _SecretVaultDisplayPart on SecretVaultScreenState {
  void _showFullImage(String url, String? caption) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasCaption = caption != null && caption.isNotEmpty;
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(dialogContext).size.height * 0.9;
            final minImageHeight =
                availableHeight < 160.0 ? availableHeight : 160.0;
            final reservedHeight = hasCaption ? 140.0 : 40.0;
            final imageMaxHeight = (availableHeight - reservedHeight)
                .clamp(minImageHeight, availableHeight)
                .toDouble();

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: availableHeight),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                maxWidthDiskCache: 900,
                                imageUrl: url,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                width: double.infinity,
                                height: imageMaxHeight,
                                placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.broken_image,
                                        color: Colors.grey),
                              ),
                            ),
                          ),
                          if (hasCaption) ...[
                            const SizedBox(height: 12),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline,
                                      color: SLColors.success, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      caption,
                                      style: SLTheme.quicksand(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (Platform.isIOS)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEncryptionBadge() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _encryptionReady
            ? SLColors.success.withValues(alpha: 0.15)
            : SLColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: _encryptionReady
                ? SLColors.success.withValues(alpha: 0.4)
                : SLColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _encryptionReady ? Icons.lock : Icons.lock_open,
            color: _encryptionReady ? SLColors.success : SLColors.warning,
            size: 14,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _encStatusMsg,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: _encryptionReady ? SLColors.success : SLColors.warning,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
