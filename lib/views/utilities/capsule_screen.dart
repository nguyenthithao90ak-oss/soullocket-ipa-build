import 'dart:async';
import 'package:soullocket_app/widgets/skeleton_container.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/services/pending_upload_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/time_capsule_service.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';

class CapsuleScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const CapsuleScreen({super.key, required this.houseId, required this.myName});

  @override
  State<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends State<CapsuleScreen> {
  static const String _pendingUploadKeyPrefix = 'capsule_';
  static const Color _backgroundTop = Color(0xFFB224EF);
  static const Color _backgroundBottom = Color(0xFF7579FF);
  static const Color _tileFill = Color(0x1FFFFFFF);
  static const Color _tileBorder = Color(0x3DFFFFFF);
  static const Color _accentColor = Color(0xFFFF8AA0);
  static const Color _buttonFill = Color(0xFF9354FF);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xE6FFFFFF);
  static const Color _textMuted = Color(0xB3FFFFFF);
  static const Color _dialogSurface = Color(0xCC2B1F66);
  static const Color _dialogInnerSurface = Color(0xB322164F);
  static const Color _dialogBorder = Color(0x66FFFFFF);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  DateTime? _unlockDate;
  XFile? _selectedImage;
  bool _isUploading = false;
  final StorageService _storageService = StorageService();

  List<Map<String, dynamic>> _capsules = [];
  Timer? _timer;
  bool _didPromptPendingUploadRetry = false;

  String get _pendingUploadKey => '$_pendingUploadKeyPrefix${widget.houseId}';

  @override
  void initState() {
    super.initState();
    _loadCapsules();
    unawaited(_promptPendingUploadRetryIfNeeded());
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        SnackBar(
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
    if (imagePath.isNotEmpty) {
      try {
        imageFile = XFile(imagePath);
        if (await imageFile.length() <= 0) {
          imageFile = null;
        }
      } catch (_) {
        imageFile = null;
      }
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
    await _addCapsule();
  }

  void _loadCapsules() {
    TimeCapsuleService().listenToCapsules(widget.houseId).listen((list) {
      if (mounted) {
        setState(() {
          _capsules = list;
          _capsules.sort((a, b) => (b['buried_at'] as int? ?? 0)
              .compareTo(a['buried_at'] as int? ?? 0));
        });
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _addCapsule() async {
    if (_isUploading) return;

    final content = _contentController.text.trim();
    final title = _titleController.text.trim();

    if (widget.houseId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('util_chatmthynh_da24d0'))));
      return;
    }

    if (content.isEmpty || _unlockDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('util_bnchnngymv_4173b0'))));
      return;
    }

    if (_selectedImage != null && !await File(_selectedImage!.path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('util_nhchnkhngc_321118'))));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await PendingUploadService.instance
          .save(_pendingUploadKey, <String, dynamic>{
        'title': title,
        'content': content,
        'unlockDateMs': _unlockDate!.millisecondsSinceEpoch,
        'imagePath': _selectedImage?.path ?? '',
      });
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _storageService.uploadImage(
          widget.houseId,
          'time_capsules',
          _selectedImage!,
          quality: 70,
        );
      }

      await TimeCapsuleService().buryTimeCapsule(
        houseId: widget.houseId,
        title: title,
        message: content,
        imageUrl: imageUrl,
        unlockDate: _unlockDate!,
      );
      await PendingUploadService.instance.clear(_pendingUploadKey);
      if (!mounted) return;

      _titleController.clear();
      _contentController.clear();
      setState(() {
        _unlockDate = null;
        _selectedImage = null;
      });
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('util_khahpthtng_4043ab'))));
    } catch (e) {
      if (mounted) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('util_chathlukho_774aa4'),
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorInfo.message)));
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _unlockDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: context.tr('util_chnngymth_6eec01'),
      cancelText: context.tr('util_hy_1e4050'),
      confirmText: context.tr('util_chnngyny_91b75a'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _buttonFill,
              onPrimary: Colors.white,
              surface: Color(0xFFFFF7FB),
              onSurface: Color(0xFF2B1F66),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _buttonFill,
                textStyle: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
      final updated =
          await TimeCapsuleService().openCapsule(widget.houseId, capsule);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: SLSpacing.all20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: FastBackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: SLSpacing.all24,
                  decoration: BoxDecoration(
                    color: _dialogSurface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _dialogBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💌',
                          style: TextStyle(fontSize: 60),
                          textScaler: TextScaler.linear(1.0)),
                      SLSpacing.h16,
                      Text(
                        context.tr('util_hpthtnglai_31f728'),
                        style: SLTheme.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SLSpacing.h20,
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1).withValues(alpha: 0.12),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_post_office_rounded,
                                  color: Color(0xFF8B5CF6), size: 24),
                            ),
                            SLSpacing.w16,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    L10nService().format('util_capsule_from', {
                                      'sender': updated['sender_uid'] == 'me'
                                          ? context.tr('util_ti_a843eb')
                                          : context.tr('util_ngiy_5bab37')
                                    }),
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SLSpacing.h4,
                                  Text(
                                    L10nService()
                                        .format('util_capsule_open_date', {
                                      'date': DateFormat('dd/MM/yyyy').format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                              updated['unlock_time_ms'] ?? 0))
                                    }),
                                    style: SLTheme.quicksand(
                                      color: _textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SLSpacing.h20,
                      Container(
                        width: double.infinity,
                        padding: SLSpacing.all20,
                        decoration: BoxDecoration(
                          color: _dialogInnerSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _dialogBorder),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 14)
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 350),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (updated['image_url'] != null &&
                                  updated['image_url']
                                      .toString()
                                      .isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () => _showImageFullScreen(
                                      context, updated['image_url']),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
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
                                          errorWidget: (_, _, _) =>
                                              const SizedBox(
                                            height: 220,
                                            child: Center(
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: Colors.white70,
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
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                                Icons.zoom_out_map,
                                                color: Colors.white,
                                                size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SLSpacing.h16,
                              ],
                              Text(
                                updated['content'] ?? '',
                                style: SLTheme.quicksand(
                                    fontSize: 16,
                                    height: 1.6,
                                    fontWeight: FontWeight.w600,
                                    color: _textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SLSpacing.h24,
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _buttonFill,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: SLRadius.lgAll),
                          ),
                          child: Text(context.tr('util_ng_aecc61'),
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: context.tr('util_chathmhpth_c3a6c5'),
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorInfo.message)));
      }
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1B2A36),
        title: Text(
          'Hộp thời gian',
          style: SLTheme.quicksand(
              fontWeight: FontWeight.w900, color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('Tính năng:'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text(
                  '- Gửi gắm một thông điệp, hình ảnh, hoặc video vào tương lai.\n- Hộp sẽ bị khóa cứng và không ai (kể cả bạn) có thể mở ra xem trước thời hạn.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Text(context.tr('Cách sử dụng:'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text(
                  '- Bấm Tạo hộp mới, chọn thời gian mở khóa (ví dụ: kỷ niệm 10 năm).\n- Thêm lời nhắn, ảnh, video, sau đó bấm Niêm phong.\n- Cả hai sẽ nhận được thông báo khi hộp thời gian đến ngày mở khóa.',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Đã hiểu'),
                style: const TextStyle(color: Color(0xFF64B5F6))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBottom,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.tr('util_hpthvtthig_72f391'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 22),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_backgroundTop, _backgroundBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildInputArea(),
                ),
                _buildCapsuleList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: SLSpacing.all20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.30),
                  Colors.white.withValues(alpha: 0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD1E3), Color(0xFFFF8AA0)],
                        ),
                        borderRadius: SLRadius.lgAll,
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mark_email_unread_rounded,
                          color: Color(0xFF5B2B6F)),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            context.tr('util_chnnhngymv_9ffe9f'),
                            style: SLTheme.quicksand(
                              color: _textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SLSpacing.h16,
                _buildTextField(_titleController,
                    context.tr('util_tiuth_e1af07'), Icons.title),
                SLSpacing.h10,
                _buildTextField(
                  _contentController,
                  context.tr('util_nidungbcth_c1342b'),
                  Icons.edit_note,
                  maxLines: 4,
                ),
                SLSpacing.gapH(14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDatePicker()),
                    SLSpacing.w10,
                    Expanded(child: _buildImagePicker()),
                  ],
                ),
                SLSpacing.h16,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _buttonFill,
                      foregroundColor: _textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.26)),
                      ),
                    ),
                    onPressed: _isUploading ? null : _addCapsule,
                    icon: _isUploading
                        ? const SkeletonContainer.square(
                            size: 20,
                          )
                        : const Icon(Icons.lock_clock_rounded),
                    label: Text(
                      _isUploading
                          ? context.tr('util_angkhath_ab590c')
                          : context.tr('util_khathvotng_8d8f0b'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _selectedImage != null;
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasImage
                ? [
                    Colors.white.withValues(alpha: 0.36),
                    Colors.white.withValues(alpha: 0.18)
                  ]
                : [const Color(0x33FFFFFF), const Color(0x1FFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasImage
                ? const Color(0xFFFFD1E3)
                : Colors.white.withValues(alpha: 0.32),
            width: hasImage ? 1.4 : 1,
          ),
        ),
        child: hasImage
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.44)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded,
                            color: Colors.white, size: 18),
                        SLSpacing.gapW(6),
                        Expanded(
                          child: Text(
                            context.tr('util_chnnh_d05e7e'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: SLRadius.pillAll,
                          ),
                          child: Text(
                            context.tr('util_i_d94813'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.26)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: Colors.white, size: 24),
                  ),
                  SLSpacing.h10,
                  Text(
                    context.tr('util_chnnh_719c35'),
                    style: SLTheme.quicksand(
                      color: _textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    context.tr('util_knimnhkm_583184'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: _textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: _tileFill,
        borderRadius: SLRadius.lgAll,
        border: Border.all(
          color: _tileBorder,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: _textPrimary,
        style: SLTheme.quicksand(
          color: const Color(
              0xFF2B1F66), // Dark purple for visibility on white background
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SLTheme.quicksand(color: _textMuted),
          prefixIcon: Icon(icon, color: _accentColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final hasDate = _unlockDate != null;
    final daysLeft = hasDate
        ? _unlockDate!.difference(DateTime.now()).inDays.clamp(0, 3650)
        : null;
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasDate
                ? [const Color(0xFFFFD1E3), const Color(0xFFFF8AA0)]
                : [
                    Colors.white.withValues(alpha: 0.32),
                    Colors.white.withValues(alpha: 0.16)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasDate
                ? Colors.white.withValues(alpha: 0.46)
                : Colors.white.withValues(alpha: 0.30),
          ),
          boxShadow: hasDate
              ? [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.26),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(alpha: hasDate ? 0.26 : 0.16),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  child: Icon(
                    hasDate
                        ? Icons.event_available_rounded
                        : Icons.calendar_month_rounded,
                    color: hasDate ? const Color(0xFF5B2B6F) : Colors.white,
                    size: 21,
                  ),
                ),
                const Spacer(),
                if (hasDate)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: SLRadius.pillAll,
                    ),
                    child: Text(
                      context.tr('util_i_d94813'),
                      style: SLTheme.quicksand(
                        color: const Color(0xFF5B2B6F),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              hasDate
                  ? DateFormat('dd/MM/yyyy').format(_unlockDate!)
                  : context.tr('util_chnngym_02d57f'),
              style: SLTheme.quicksand(
                color: hasDate ? const Color(0xFF5B2B6F) : _textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: hasDate ? 19 : 14,
              ),
            ),
            SLSpacing.h4,
            Text(
              hasDate
                  ? L10nService()
                      .format('util_capsule_days_left', {'days': daysLeft})
                  : context.tr('util_khitingyny_6a6df1'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: hasDate
                    ? const Color(0xFF5B2B6F).withValues(alpha: 0.78)
                    : _textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleList() {
    if (_capsules.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Center(
            child: Text(
              context.tr('util_chachpthno_00896c'),
              style: SLTheme.quicksand(
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      sliver: SliverList.builder(
        itemCount: _capsules.length,
        itemBuilder: (context, index) {
              final capsule = _capsules[index];
              final unlockDate =
                  (capsule['unlock_time_ms'] as num?)?.toInt() ?? 0;
              final isOpen =
                  DateTime.now().millisecondsSinceEpoch >= unlockDate;
              final capsuleId = capsule['id']?.toString() ?? '';

              return Dismissible(
                key: ValueKey('capsule_$capsuleId'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDeleteCapsule(capsule),
                onDismissed: (_) {},
                background: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text('Xóa',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ],
                  ),
                ),
                child: _CapsuleTouchWrapper(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: FastBackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOpen
                                ? [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.15)
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.15),
                                    Colors.white.withValues(alpha: 0.05)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isOpen
                                ? Colors.white.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isOpen &&
                                capsule['image_url'] != null &&
                                capsule['image_url'].toString().isNotEmpty)
                              GestureDetector(
                                onTap: () => _showImageFullScreen(
                                    context, capsule['image_url']),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                  child: Stack(
                                    children: [
                                      SizedBox(
                                        height: 150,
                                        width: double.infinity,
                                        child: CachedNetworkImage(
                                          imageUrl: capsule['image_url'],
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) =>
                                              const SkeletonContainer.rounded(
                                            width: double.infinity,
                                            height: 140,
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            child: const Icon(
                                                Icons.broken_image_rounded,
                                                color: Colors.white38,
                                                size: 40),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.4),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.zoom_out_map_rounded,
                                              color: Colors.white,
                                              size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                              isOpen
                                                  ? Icons
                                                      .mark_email_read_rounded
                                                  : Icons.lock_clock_rounded,
                                              size: 16,
                                              color: isOpen
                                                  ? Colors.white
                                                  : Colors.white60),
                                          SLSpacing.w8,
                                          Text(
                                            L10nService().format(
                                                'util_capsule_open_short', {
                                              'date': DateFormat('dd/MM/yyyy')
                                                  .format(DateTime
                                                      .fromMillisecondsSinceEpoch(
                                                          unlockDate))
                                            }),
                                            style: SLTheme.quicksand(
                                                color: isOpen
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                            color: isOpen
                                                ? const Color(0xFF10B981)
                                                    .withValues(alpha: 0.25)
                                                : const Color(0xFFF59E0B)
                                                    .withValues(alpha: 0.25),
                                            borderRadius: SLRadius.pillAll,
                                            border: Border.all(
                                              color: isOpen
                                                  ? const Color(0xFF10B981)
                                                      .withValues(alpha: 0.5)
                                                  : const Color(0xFFF59E0B)
                                                      .withValues(alpha: 0.5),
                                            )),
                                        child: Text(
                                          isOpen
                                              ? context.tr('util_m_7b4530')
                                              : context
                                                  .tr('util_angkha_d004dc'),
                                          style: SLTheme.quicksand(
                                            color: isOpen
                                                ? const Color(0xFF6EE7B7)
                                                : const Color(0xFFFCD34D),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if (isOpen)
                                    Text(
                                      capsule['title'] ??
                                          capsule['content'] ??
                                          '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: SLTheme.quicksand(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    )
                                  else
                                    Text(
                                      context.tr('util_nidungsmng_ea25c0'),
                                      style: SLTheme.quicksand(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  SLSpacing.h16,
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: isOpen
                                          ? () => _openCapsule(capsule)
                                          : null,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: isOpen
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFF6366F1),
                                                    Color(0xFF8B5CF6)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isOpen
                                              ? null
                                              : Colors.white
                                                  .withValues(alpha: 0.1),
                                          borderRadius: SLRadius.pillAll,
                                          boxShadow: isOpen
                                              ? [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF6366F1)
                                                            .withValues(
                                                                alpha: 0.4),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              context.tr('util_mth_e6d950'),
                                              style: SLTheme.quicksand(
                                                fontWeight: FontWeight.w900,
                                                color: isOpen
                                                    ? Colors.white
                                                    : Colors.white38,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (isOpen) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 14),
                                            ]
                                          ],
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
                  ),
                ),
              );
            },
          ),
        );
  }

  Future<bool> _confirmDeleteCapsule(Map<String, dynamic> capsule) async {
    final capsuleId = capsule['id']?.toString() ?? '';
    if (capsuleId.isEmpty) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xóa hòm thời gian?',
          style: SLTheme.quicksand(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          'Hành động này không thể hoàn tác. Nội dung trong hòm sẽ bị xóa vĩnh viễn.',
          style: SLTheme.quicksand(
              color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy',
                style: SLTheme.quicksand(
                    color: Colors.white54, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xóa',
                style: SLTheme.quicksand(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w900)),
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
          SnackBar(
              content:
                  Text('Xóa thất bại: ${AppErrorMapper.resolve(e).message}')),
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
    _scale = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
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
          scale: _scale.value,
          child: Container(
            margin: widget.margin,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
