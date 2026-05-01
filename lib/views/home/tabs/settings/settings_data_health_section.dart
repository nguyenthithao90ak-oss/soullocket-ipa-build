part of '../settings_tab.dart';

extension _SettingsDataHealthSection on _SettingsTabState {
  Future<void> _requestUserDataExportFromHealthCenter() async {
    final confirmed = await _showDataExportIntroDialog();
    if (confirmed != true || !mounted) return;

    var verifiedForExport = false;
    final canContinue = await _securityFlowGuard.guard(
      context,
      action: SensitiveActionType.exportUserData,
      houseId: _houseId,
      onWarnStepUp: () async {
        verifiedForExport = await _authenticateDataExportRequest();
        return verifiedForExport;
      },
      continueLabel: 'Xác minh rồi tạo file',
    );
    if (!canContinue || !mounted) {
      return;
    }

    if (!verifiedForExport) {
      verifiedForExport = await _authenticateDataExportRequest();
    }
    if (!verifiedForExport || !mounted) {
      return;
    }

    final rangeDays = await _showDataExportRangeDialog();
    if (rangeDays == null || !mounted) {
      return;
    }

    SLNotice.showInfo(
      context,
      'Đang tạo bản tải xuống dữ liệu ${_dataExportRangeLabel(rangeDays).toLowerCase()}...',
    );
    try {
      final result =
          await DataExportService().requestUserDataExport(rangeDays: rangeDays);
      if (!mounted) return;
      await _showDataExportReadyDialog(result, rangeDays);
    } on DataExportException catch (error) {
      if (!mounted) return;
      SLNotice.showError(context, error.message);
    } catch (_) {
      if (!mounted) return;
      SLNotice.showError(
        context,
        'Không tạo được bản tải xuống dữ liệu. Hãy thử lại sau.',
      );
    }
  }

  Future<bool> _authenticateDataExportRequest() async {
    final hasAppLock = _isAppLockEnabled && _storedLockSecret.trim().isNotEmpty;
    if (hasAppLock) {
      return _authenticateLockSettingsChange();
    }

    if (_passwordLinked) {
      return _showDataExportPasswordDialog();
    }

    _showToast(
      'Hãy bật mã PIN/Khóa app hoặc tạo mật khẩu đăng nhập trước khi xuất dữ liệu.',
      success: false,
    );
    return false;
  }

  Future<int?> _showDataExportRangeDialog() {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Text(
          'Chọn thời gian tải dữ liệu',
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1565C0),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDataExportRangeTile(
              ctx,
              days: 7,
              title: '1 tuần gần nhất',
              subtitle: 'Nhẹ hơn, phù hợp khi chỉ cần dữ liệu mới.',
              icon: Icons.calendar_view_week_rounded,
            ),
            const SizedBox(height: 10),
            _buildDataExportRangeTile(
              ctx,
              days: 60,
              title: '2 tháng gần nhất',
              subtitle: 'Cân bằng giữa dung lượng và độ đầy đủ.',
              icon: Icons.calendar_month_rounded,
            ),
            const SizedBox(height: 10),
            _buildDataExportRangeTile(
              ctx,
              days: 180,
              title: '6 tháng gần nhất',
              subtitle: 'Đầy đủ hơn nhưng file có thể nặng hơn.',
              icon: Icons.date_range_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportRangeTile(
    BuildContext ctx, {
    required int days,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(ctx, days),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE7F2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF243041),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF66758A),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7A8AA0),
            ),
          ],
        ),
      ),
    );
  }

  String _dataExportRangeLabel(int rangeDays) {
    switch (rangeDays) {
      case 7:
        return '1 tuần gần nhất';
      case 180:
        return '6 tháng gần nhất';
      case 60:
      default:
        return '2 tháng gần nhất';
    }
  }

  Future<bool> _showDataExportPasswordDialog() async {
    final passwordCtrl = TextEditingController();
    try {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Text(
            'Xác minh mật khẩu đăng nhập',
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1565C0),
            ),
          ),
          content: TextField(
            controller: passwordCtrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu đăng nhập',
              prefixIcon: Icon(Icons.lock_rounded),
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.tr('cancel'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, passwordCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Xác minh',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
      if (password == null || password.isEmpty) {
        return false;
      }

      final user = _auth.currentUser;
      final email = user?.email?.trim();
      if (user == null || email == null || email.isEmpty) {
        _showToast('Không tìm thấy email đăng nhập để xác minh.',
            success: false);
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (error) {
      final wrongPassword =
          error.code == 'wrong-password' || error.code == 'invalid-credential';
      _showToast(
        wrongPassword
            ? 'Mật khẩu đăng nhập không đúng.'
            : (error.message ?? 'Không xác minh được mật khẩu đăng nhập.'),
        success: false,
      );
      return false;
    } finally {
      passwordCtrl.dispose();
    }
  }

  Future<bool?> _showDataExportIntroDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tải dữ liệu của tôi',
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF243041),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'SoulLocket sẽ tạo một bản tải xuống gồm dữ liệu tài khoản, nhà/ghép đôi, nhật ký, kỷ niệm, chat, vị trí, gói dịch vụ và lựa chọn quyền riêng tư của bạn.\n\nFile tải về có index.html để xem ảnh và các phần dữ liệu dạng .txt dễ đọc hơn. Ảnh trong Kỷ niệm được giới hạn tối đa 100 ảnh trong mỗi lần export và dùng link tải tạm thời để tránh file quá nặng.\n\nTrước khi tạo file, bạn cần xác minh bằng vân tay/Face ID hoặc mã PIN nếu đã bật Khóa app. Nếu chưa bật Khóa app, ứng dụng sẽ yêu cầu mật khẩu đăng nhập.\n\nFile có thể chứa dữ liệu nhạy cảm, đặc biệt là vị trí và tin nhắn. Chỉ chia sẻ với người bạn tin tưởng.',
          style: SLTheme.quicksand(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF445064),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Tạo bản tải xuống',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDataExportReadyDialog(
    DataExportResult result,
    int rangeDays,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Text(
          'Bản tải xuống đã sẵn sàng',
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1565C0),
          ),
        ),
        content: Text(
          'Link tải có hiệu lực trong 7 ngày. Khoảng dữ liệu: ${_dataExportRangeLabel(rangeDays)}. Có thể mở HTML để xem ảnh Kỷ niệm nhanh, hoặc tải ZIP để lấy đầy đủ file .txt. Đã thêm ${result.memoryImagesIncluded} ảnh Kỷ niệm vào trang HTML${result.memoryImagesSkipped > 0 ? ', bỏ qua ${result.memoryImagesSkipped} ảnh vượt giới hạn' : ''}.',
          style: SLTheme.quicksand(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF445064),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.downloadUrl));
              Navigator.pop(ctx);
              _showToast('Đã sao chép link tải.', success: true);
            },
            child: Text(
              'Sao chép link',
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Bản tải xuống dữ liệu SoulLocket của tôi: ${result.downloadUrl}',
                ),
              );
            },
            child: Text(
              'Chia sẻ',
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          if (result.htmlUrl.trim().isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(
                  Uri.parse(result.htmlUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(
                'Mở HTML xem ảnh',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse(result.downloadUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Tải ZIP',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataHealthPanel({bool hideBackButton = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!hideBackButton)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCE7F2)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: SLColors.primaryActive,
                    ),
                  ),
                ),
              if (!hideBackButton) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dữ liệu hệ thống',
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF243041),
                  ),
                ),
              ),
              const Icon(
                Icons.hub_rounded,
                color: SLColors.primaryActive,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Quản lý thông báo của ứng dụng và tạo bản tải xuống dữ liệu cá nhân trong cùng một nơi gọn gàng hơn.',
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF66758A),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE7F2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.download_for_offline_rounded,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tải dữ liệu của tôi',
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF243041),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tạo file tải xuống chứa dữ liệu tài khoản, ghép đôi, nhật ký, kỷ niệm, chat, vị trí và quyền riêng tư.',
                        style: SLTheme.quicksand(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF66758A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildActionBtn(
            icon: Icons.download_rounded,
            label: 'Tạo bản tải xuống dữ liệu',
            gradient: const [Color(0xFFE3F2FD), Color(0xFF42A5F5)],
            textColor: const Color(0xFF1565C0),
            onTap: _requestUserDataExportFromHealthCenter,
          ),
          const SizedBox(height: 16),
          _buildAdvancedPanel(
            hideBackButton: true,
            showSaveButton: false,
            showHeaderCard: false,
          ),
        ],
      ),
    );
  }
}
