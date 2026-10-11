import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/widgets/sl_date_picker.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:math';

import 'package:soullocket_app/widgets/skeleton_container.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/services/pending_upload_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/screen_activity_mixin.dart';
import '../../utils/services/time_capsule_service.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../core/sl_theme.dart';
import 'widgets/capsule_design.dart';

class CapsuleScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const CapsuleScreen({super.key, required this.houseId, required this.myName});

  @override
  State<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends State<CapsuleScreen>
    with ScreenActivityMixin {
  static const String _pendingUploadKeyPrefix = 'capsule_';
  // Hộp thời gian dùng nền giấy ấm và mực berry để chữ luôn rõ trên màn hình nhỏ.
  Color get _backgroundTop => CapsulePalette.canvasTop(context);
  Color get _backgroundBottom => CapsulePalette.canvas(context);
  Color get _surface => CapsulePalette.surface(context);
  Color get _surfaceSoft => CapsulePalette.field(context);
  Color get _tileBorder => CapsulePalette.border(context);
  Color get _accentColor => CapsulePalette.accent(context);
  static const Color _buttonFill = SLColors.primaryActive;
  Color get _textPrimary => CapsulePalette.ink(context);
  Color get _textSecondary => CapsulePalette.muted(context);
  Color get _textMuted => CapsulePalette.subtle(context);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  DateTime? _unlockDate;
  XFile? _selectedImage;
  bool _isUploading = false;
  final StorageService _storageService = StorageService();

  List<Map<String, dynamic>> _capsules = [];
  Timer? _timer;
  StreamSubscription<List<Map<String, dynamic>>>? _capsulesSubscription;
  bool _didPromptPendingUploadRetry = false;

  String get _pendingUploadKey =>
      '$_pendingUploadKeyPrefix${FirebaseAuth.instance.currentUser?.uid ?? 'signed_out'}_${widget.houseId}';

  @override
  void initState() {
    super.initState();
    _loadCapsules();
    unawaited(_promptPendingUploadRetryIfNeeded());
  }

  @override
  void onScreenActivityChanged(bool active) {
    _timer?.cancel();
    _timer = active
        ? Timer.periodic(const Duration(minutes: 1), (_) {
            if (isScreenActive) setState(() {});
          })
        : null;
    if (active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isScreenActive) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_capsulesSubscription?.cancel());
    super.dispose();
  }

  Future<void> _promptPendingUploadRetryIfNeeded() async {
    if (_didPromptPendingUploadRetry || !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('util_lnchnkhonh_9b7b2c')),
          action: SnackBarAction(
            label: context.tr('util_thli_4dffdf'),
            onPressed: () {
              unawaited(_retryPendingUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingUpload() async {
    final pending = await PendingUploadService.instance.load(_pendingUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    final imagePath = pending['imagePath']?.toString().trim() ?? '';
    XFile? imageFile;
    final imageSessionId = pending['imageUploadSessionId']?.toString() ?? '';
    if (imagePath.isNotEmpty && imageSessionId.isEmpty) {
      try {
        imageFile = XFile(imagePath);
        if (await imageFile.length() <= 0) {
          imageFile = null;
        }
      } catch (_) {
        imageFile = null;
      }
    }
    if (imagePath.isNotEmpty && imageSessionId.isEmpty && imageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(content: Text(context.tr('util_nhchnkhngc_321118'))),
        );
      }
      return;
    }
    final unlockDateMs = (pending['unlockDateMs'] as num?)?.toInt();
    if (unlockDateMs == null) {
      return;
    }
    setState(() {
      _titleController.text = pending['title']?.toString() ?? '';
      _contentController.text = pending['content']?.toString() ?? '';
      _unlockDate = DateTime.fromMillisecondsSinceEpoch(unlockDateMs);
      _selectedImage = imageFile;
    });
    await _addCapsule(retryDraft: pending);
  }

  void _loadCapsules() {
    _capsulesSubscription = TimeCapsuleService()
        .listenToCapsules(widget.houseId)
        .listen(
          (list) {
            if (mounted) {
              setState(() {
                _capsules = list;
                _capsules.sort(
                  (a, b) => (b['buried_at'] as int? ?? 0).compareTo(
                    a['buried_at'] as int? ?? 0,
                  ),
                );
              });
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SLSnackBar(content: Text(context.tr('util_chathlukho_774aa4'))),
            );
          },
        );
  }

  Future<void> _pickImage() async {
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _addCapsule({Map<String, dynamic>? retryDraft}) async {
    if (_isUploading) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final houseId = widget.houseId;
    final pendingKey = _pendingUploadKey;
    final unlockDate = _unlockDate;
    final selectedImage = _selectedImage;
    void requireCurrentScope() {
      if (FirebaseAuth.instance.currentUser?.uid != uid ||
          widget.houseId != houseId) {
        throw StateError('Time capsule upload scope changed');
      }
    }

    final content = _contentController.text.trim();
    final title = _titleController.text.trim();

    if (widget.houseId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('util_chatmthynh_da24d0'))),
      );
      return;
    }

    if (content.isEmpty || unlockDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('util_bnchnngymv_4173b0'))),
      );
      return;
    }

    if (selectedImage != null &&
        !kIsWeb &&
        !await File(selectedImage.path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('util_nhchnkhngc_321118'))),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _isUploading = true;
    });

    try {
      requireCurrentScope();
      final draft = <String, dynamic>{
        ...?retryDraft,
        'uid': uid,
        'houseId': houseId,
        'title': title,
        'content': content,
        'unlockDateMs': unlockDate.millisecondsSinceEpoch,
        'imagePath': selectedImage?.path ?? retryDraft?['imagePath'] ?? '',
      };
      var capsuleId = draft['capsuleId']?.toString() ?? '';
      if (capsuleId.isEmpty) {
        final random = Random.secure();
        capsuleId =
            '${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 30)}_${random.nextInt(1 << 30)}';
        draft['capsuleId'] = capsuleId;
      }
      await PendingUploadService.instance.save(pendingKey, draft);
      String? imageStoragePath;
      String? imageUploadSessionId = draft['imageUploadSessionId']?.toString();
      if (selectedImage != null &&
          (imageUploadSessionId == null || imageUploadSessionId.isEmpty)) {
        requireCurrentScope();
        final imageUpload = await _storageService.uploadTimeCapsuleImage(
          houseId,
          selectedImage,
          quality: 70,
        );
        imageStoragePath = imageUpload?.storagePath;
        imageUploadSessionId = imageUpload?.sessionId;
        if (imageStoragePath == null || imageUploadSessionId == null) {
          throw StateError('Time capsule image upload was not confirmed');
        }
        requireCurrentScope();
        capsuleId = imageUploadSessionId;
        draft['capsuleId'] = capsuleId;
        draft['imageUploadSessionId'] = imageUploadSessionId;
        draft['imageStoragePath'] = imageStoragePath;
        await PendingUploadService.instance.save(pendingKey, draft);
      }

      requireCurrentScope();
      await TimeCapsuleService().buryTimeCapsule(
        houseId: houseId,
        title: title,
        message: content,
        imageUploadSessionId: imageUploadSessionId,
        capsuleId: capsuleId,
        unlockDate: unlockDate,
      );
      requireCurrentScope();
      try {
        await PendingUploadService.instance.clear(pendingKey);
      } catch (_) {}
      if (!mounted) return;
      await _capsulesSubscription?.cancel();
      if (!mounted) return;
      _loadCapsules();

      _titleController.clear();
      _contentController.clear();
      setState(() {
        _unlockDate = null;
        _selectedImage = null;
      });
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('util_khahpthtng_4043ab'))),
      );
    } catch (e) {
      if (mounted) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('util_chathlukho_774aa4'),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SLSnackBar(content: Text(errorInfo.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showSLDatePicker(
      context: context,
      initialDate: _unlockDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: context.tr('util_chnngymth_6eec01'),
      cancelText: context.tr('util_hy_1e4050'),
      confirmText: context.tr('util_chnngyny_91b75a'),
    );
    if (picked != null && picked != _unlockDate) {
      setState(() {
        _unlockDate = picked;
      });
    }
  }

  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              memCacheWidth: 600,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, _, _) => const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white70,
                size: 50,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCapsule(Map<String, dynamic> capsule) async {
    try {
      final updated = await TimeCapsuleService().openCapsule(
        widget.houseId,
        capsule,
      );
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return SLAlertDialog(
            title: SLDialogHeading(
              title: context.tr('util_hpthtnglai_31f728'),
              icon: Icons.mark_email_read_outlined,
              tone: SLDialogTone.success,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SLDialogStyle.field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SLDialogStyle.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nService().format('util_capsule_from', {
                          'sender': updated['sender_uid'] == 'me'
                              ? context.tr('util_ti_a843eb')
                              : context.tr('util_ngiy_5bab37'),
                        }),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: SLColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        L10nService().format('util_capsule_open_date', {
                          'date': LocaleDateFormat.date(
                            DateTime.fromMillisecondsSinceEpoch(
                              updated['unlock_time_ms'] ?? 0,
                            ),
                          ),
                        }),
                        style: const TextStyle(
                          fontSize: 13,
                          color: SLDialogStyle.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (updated['image_url'] != null &&
                    updated['image_url'].toString().isNotEmpty) ...[
                  GestureDetector(
                    onTap: () =>
                        _showImageFullScreen(context, updated['image_url']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CachedNetworkImage(
                            imageUrl: updated['image_url'],
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            filterQuality: FilterQuality.medium,
                            placeholder: (_, _) =>
                                const SkeletonContainer.rounded(
                                  width: double.infinity,
                                  height: 220,
                                  borderRadius: BorderRadius.zero,
                                ),
                            errorWidget: (_, _, _) => const SizedBox(
                              height: 220,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: SLDialogStyle.secondary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.zoom_out_map,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(updated['content'] ?? ''),
              ],
            ),
            actions: [
              SLDialogAction(
                primary: true,
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('util_ng_aecc61')),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('util_chathmhpth_c3a6c5'),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SLSnackBar(content: Text(errorInfo.message)));
      }
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('p3_capsule_help_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('p3_help_features_label'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SLColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('p3_capsule_help_features'),
                style: const TextStyle(color: SLColors.textSecond),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('p3_help_how_to_label'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SLColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('p3_capsule_help_how_to'),
                style: const TextStyle(color: SLColors.textSecond),
              ),
            ],
          ),
        ),
        actions: [
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('p3_understood')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBottom,
      appBar: capsuleAppBar(
        context,
        onBack: () => Navigator.pop(context),
        onHelp: () => _showInfoDialog(context),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundTop, _backgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                physics: SLResponsive.scrollPhysicsForPlatform(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    _buildModernInputArea(),
                    _buildModernCapsuleList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bố cục mới dùng nền giấy và bề mặt sáng để nội dung không bị chìm trên
  // gradient tím. Các callback và controller vẫn dùng chung luồng hiện tại.
  Widget _buildModernInputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _tileBorder),
          boxShadow: [
            BoxShadow(
              color: SLColors.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: CapsulePalette.tint(context),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    color: _accentColor,
                    size: 24,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('util_gimtlthcho_a87e43'),
                        style: SLTheme.quicksand(
                          color: _textPrimary,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        context.tr('util_chnnhngymv_9ffe9f'),
                        style: SLTheme.quicksand(
                          color: _textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SLSpacing.h18,
            _buildModernTextField(
              _titleController,
              context.tr('util_tiuth_e1af07'),
              Icons.title_rounded,
            ),
            SLSpacing.h10,
            _buildModernTextField(
              _contentController,
              context.tr('util_nidungbcth_c1342b'),
              Icons.notes_rounded,
              maxLines: 4,
            ),
            SLSpacing.gapH(14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackChoices =
                    constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21;
                final datePicker = _buildModernDatePicker();
                final imagePicker = _buildModernImagePicker();
                if (stackChoices) {
                  return Column(
                    children: [datePicker, SLSpacing.h10, imagePicker],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: datePicker),
                    SLSpacing.w10,
                    Expanded(child: imagePicker),
                  ],
                );
              },
            ),
            SLSpacing.h16,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: _buttonFill,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _buttonFill.withValues(alpha: 0.48),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isUploading ? null : _addCapsule,
                icon: _isUploading
                    ? const SkeletonContainer.square(size: 20)
                    : const Icon(Icons.lock_clock_rounded, size: 20),
                label: Text(
                  _isUploading
                      ? context.tr('util_angkhath_ab590c')
                      : context.tr('util_khathvotng_8d8f0b'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tileBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: _accentColor,
        style: SLTheme.quicksand(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.3,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SLTheme.quicksand(
            color: _textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: _accentColor, size: 21),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(2, 14, 14, 14),
        ),
      ),
    );
  }

  Widget _buildModernImagePicker() {
    final hasImage = _selectedImage != null;
    if (!hasImage) {
      return CapsuleChoiceTile(
        key: const ValueKey('capsule-image-choice'),
        label: context.tr('util_chnnh_719c35'),
        title: context.tr('util_chnnh_719c35'),
        subtitle: context.tr('util_knimnhkm_583184'),
        icon: Icons.add_photo_alternate_rounded,
        onTap: _pickImage,
      );
    }
    return Semantics(
      button: true,
      label: context.tr('util_chnnh_719c35'),
      child: GestureDetector(
        onTap: _pickImage,
        child: AnimatedContainer(
          duration: CapsulePalette.motion(context),
          height: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hasImage ? SLColors.primarySoft : _surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage
                  ? SLColors.primary.withValues(alpha: 0.5)
                  : _tileBorder,
              width: hasImage ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        SLColors.ink.withValues(alpha: 0.58),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 9,
                right: 9,
                bottom: 8,
                child: Row(
                  children: [
                    const Icon(
                      Icons.image_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    SLSpacing.gapW(6),
                    Expanded(
                      child: Text(
                        context.tr('util_chnnh_d05e7e'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDatePicker() {
    final hasDate = _unlockDate != null;
    final daysLeft = hasDate
        ? _unlockDate!.difference(DateTime.now()).inDays.clamp(0, 3650)
        : null;
    return CapsuleChoiceTile(
      key: const ValueKey('capsule-date-choice'),
      label: context.tr('util_chnngym_02d57f'),
      title: hasDate
          ? LocaleDateFormat.date(_unlockDate!)
          : context.tr('util_chnngym_02d57f'),
      subtitle: hasDate
          ? L10nService().format('util_capsule_days_left', {'days': daysLeft})
          : null,
      icon: hasDate
          ? Icons.event_available_rounded
          : Icons.calendar_month_rounded,
      selected: hasDate,
      onTap: () => _selectDate(context),
    );
  }

  Widget _buildModernCapsuleList() {
    if (_capsules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tileBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CapsulePalette.tint(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: _accentColor,
                  size: 24,
                ),
              ),
              SLSpacing.h10,
              Text(
                context.tr('util_chachpthno_00896c'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: _textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _capsules.length,
      itemBuilder: (context, index) {
        final capsule = _capsules[index];
        final unlockDate = (capsule['unlock_time_ms'] as num?)?.toInt() ?? 0;
        final isOpen = DateTime.now().millisecondsSinceEpoch >= unlockDate;
        final capsuleId = capsule['id']?.toString() ?? '';

        return Dismissible(
          key: ValueKey('capsule_$capsuleId'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDeleteCapsule(capsule),
          onDismissed: (_) {},
          background: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: SLColors.danger,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                const SizedBox(height: 4),
                Text(
                  context.tr('p3_delete'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          child: _CapsuleTouchWrapper(
            margin: const EdgeInsets.only(bottom: 14),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isOpen
                      ? CapsulePalette.status(
                          context,
                          open: true,
                        ).withValues(alpha: 0.35)
                      : _tileBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SLColors.ink.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isOpen &&
                      capsule['image_url'] != null &&
                      capsule['image_url'].toString().isNotEmpty)
                    GestureDetector(
                      onTap: () =>
                          _showImageFullScreen(context, capsule['image_url']),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17),
                        ),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 154,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: capsule['image_url'],
                                fit: BoxFit.cover,
                                memCacheWidth: 600,
                                placeholder: (_, _) =>
                                    const SkeletonContainer.rounded(
                                      width: double.infinity,
                                      height: 154,
                                    ),
                                errorWidget: (context, url, error) => Container(
                                  color: SLColors.bgMuted,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: SLColors.textTertiary,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: SLColors.ink.withValues(alpha: 0.66),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_out_map_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    isOpen
                                        ? Icons.mark_email_read_rounded
                                        : Icons.lock_clock_rounded,
                                    size: 17,
                                    color: CapsulePalette.status(
                                      context,
                                      open: isOpen,
                                    ),
                                  ),
                                  SLSpacing.w8,
                                  Expanded(
                                    child: Text(
                                      L10nService().format(
                                        'util_capsule_open_short',
                                        {
                                          'date': LocaleDateFormat.date(
                                            DateTime.fromMillisecondsSinceEpoch(
                                              unlockDate,
                                            ),
                                          ),
                                        },
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: SLTheme.quicksand(
                                        color: _textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SLSpacing.w8,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: CapsulePalette.statusTint(
                                  context,
                                  open: isOpen,
                                ),
                                borderRadius: SLRadius.pillAll,
                              ),
                              child: Text(
                                isOpen
                                    ? context.tr('util_m_7b4530')
                                    : context.tr('util_angkha_d004dc'),
                                style: SLTheme.quicksand(
                                  color: CapsulePalette.status(
                                    context,
                                    open: isOpen,
                                  ),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isOpen)
                          Text(
                            capsule['title']?.toString().trim().isNotEmpty ==
                                    true
                                ? capsule['title'].toString()
                                : capsule['content']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: _textPrimary,
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        else
                          Text(
                            context.tr('util_nidungsmng_ea25c0'),
                            style: SLTheme.quicksand(
                              color: _textMuted,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: isOpen
                                ? () => _openCapsule(capsule)
                                : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: _accentColor,
                              disabledForegroundColor: SLColors.textTertiary,
                            ),
                            icon: Icon(
                              isOpen
                                  ? Icons.visibility_outlined
                                  : Icons.lock_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              context.tr('util_mth_e6d950'),
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Future<bool> _confirmDeleteCapsule(Map<String, dynamic> capsule) async {
    final capsuleId = capsule['id']?.toString() ?? '';
    if (capsuleId.isEmpty) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('p3_capsule_delete_title')),
        content: Text(context.tr('p3_capsule_delete_message')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('p3_cancel')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('p3_delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await TimeCapsuleService().deleteCapsule(widget.houseId, capsuleId);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(
              L10nService().format('p3_capsule_delete_failed', {
                'error': AppErrorMapper.resolve(e).message,
              }),
            ),
          ),
        );
      }
      return false;
    }
  }
}

class _CapsuleTouchWrapper extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _CapsuleTouchWrapper({required this.child, this.margin});

  @override
  State<_CapsuleTouchWrapper> createState() => _CapsuleTouchWrapperState();
}

class _CapsuleTouchWrapperState extends State<_CapsuleTouchWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.965,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: MediaQuery.disableAnimationsOf(context) ? 1 : _scale.value,
          child: Container(margin: widget.margin, child: child),
        ),
        child: widget.child,
      ),
    );
  }
}
