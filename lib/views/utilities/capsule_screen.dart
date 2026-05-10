import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/services/pending_upload_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../services/time_capsule_service.dart';
import '../../services/storage_service.dart';
import '../../core/sl_theme.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

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
  static const Color _dialogAccent = Color(0xFFE3D7FF);

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
          content: const Text('Lần chôn khoảnh khắc trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa tìm thấy nhà chung. Bạn vào lại ứng dụng rồi thử lại.')));
      return;
    }

    if (content.isEmpty || _unlockDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chọn ngày mở và viết nội dung thư nhé.')));
      return;
    }

    if (_selectedImage != null &&
        !await File(_selectedImage!.path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ảnh đã chọn không còn sẵn sàng. Bạn chọn lại ảnh rồi thử tiếp.')));
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
          const SnackBar(content: Text('Đã khóa hộp thư tương lai! 🚀')));
    } catch (e) {
      if (mounted) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Chưa thể lưu khoảnh khắc lúc này. Bạn thử lại sau.',
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
      helpText: 'Chọn ngày mở thư',
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày này',
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
                        'HỘP THƯ TƯƠNG LAI',
                        style: SLTheme.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SLSpacing.h20,
                      Container(
                        padding: SLSpacing.all16,
                        decoration: BoxDecoration(
                          color: _dialogInnerSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: const Border(
                              left: BorderSide(color: _dialogAccent, width: 4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '📬 TỪ: ${updated['sender_uid'] == 'me' ? 'Tôi' : 'Người ấy'}',
                                style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color: _textPrimary,
                                    fontSize: 13)),
                            SLSpacing.h4,
                            Text(
                                '📅 Ngày mở: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(updated['unlock_time_ms'] ?? 0))}',
                                style: SLTheme.quicksand(
                                    color: _textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    updated['image_url'],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
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
                          child: Text('ĐÓNG',
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
          fallbackMessage: 'Chưa thể mở hộp thư lúc này. Bạn thử lại sau.',
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorInfo.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundBottom,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'HỘP THƯ VƯỢT THỜI GIAN',
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
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  _buildInputArea(),
                  _buildCapsuleList(),
                ],
              ),
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
                            'Gửi một lá thư cho tương lai',
                            style: SLTheme.quicksand(
                              color: _textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Chọn ảnh, ngày mở và khóa lại cho đúng thời điểm.',
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
                _buildTextField(
                    _titleController, 'Tiêu đề thư...', Icons.title),
                SLSpacing.h10,
                _buildTextField(
                  _contentController,
                  'Nội dung bức thư gửi tương lai...',
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
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
                      ),
                    ),
                    onPressed: _isUploading ? null : _addCapsule,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.lock_clock_rounded),
                    label: Text(
                      _isUploading ? 'ĐANG KHÓA THƯ...' : 'KHÓA THƯ VÀO TƯƠNG LAI',
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
                ? [Colors.white.withValues(alpha: 0.36), Colors.white.withValues(alpha: 0.18)]
                : [const Color(0x33FFFFFF), const Color(0x1FFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasImage ? const Color(0xFFFFD1E3) : Colors.white.withValues(alpha: 0.32),
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
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.44)],
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
                        const Icon(Icons.image_rounded, color: Colors.white, size: 18),
                        SLSpacing.gapW(6),
                        Expanded(
                          child: Text(
                            'Đã chọn ảnh',
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: SLRadius.pillAll,
                          ),
                          child: Text(
                            'Đổi',
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: Colors.white, size: 24),
                  ),
                  SLSpacing.h10,
                  Text(
                    'Chọn ảnh',
                    style: SLTheme.quicksand(
                      color: _textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    'Kỷ niệm đính kèm',
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
          color: const Color(0xFF2B1F66), // Dark purple for visibility on white background
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
                : [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0.16)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasDate ? Colors.white.withValues(alpha: 0.46) : Colors.white.withValues(alpha: 0.30),
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
                    color: Colors.white.withValues(alpha: hasDate ? 0.26 : 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  child: Icon(
                    hasDate ? Icons.event_available_rounded : Icons.calendar_month_rounded,
                    color: hasDate ? const Color(0xFF5B2B6F) : Colors.white,
                    size: 21,
                  ),
                ),
                const Spacer(),
                if (hasDate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: SLRadius.pillAll,
                    ),
                    child: Text(
                      'Đổi',
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
              hasDate ? DateFormat('dd/MM/yyyy').format(_unlockDate!) : 'Chọn ngày mở',
              style: SLTheme.quicksand(
                color: hasDate ? const Color(0xFF5B2B6F) : _textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: hasDate ? 19 : 14,
              ),
            ),
            SLSpacing.h4,
            Text(
              hasDate
                  ? 'Còn khoảng $daysLeft ngày nữa'
                  : 'Khi tới ngày này mới mở được thư',
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
    return _capsules.isEmpty
        ? Center(
            child: Text(
              'Chưa có hộp thư nào kỷ niệm.',
              style: SLTheme.quicksand(
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _capsules.length,
            itemBuilder: (context, index) {
              final capsule = _capsules[index];
              final unlockDate =
                  (capsule['unlock_time_ms'] as num?)?.toInt() ?? 0;
              final isOpen =
                  DateTime.now().millisecondsSinceEpoch >= unlockDate;

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FastBackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: SLSpacing.all16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mở: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(unlockDate))}',
                                style: SLTheme.quicksand(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.orange.withValues(alpha: 0.3),
                                  borderRadius: SLRadius.smAll,
                                ),
                                child: Text(
                                  isOpen ? 'ĐÃ MỞ' : 'ĐANG KHÓA',
                                  style: SLTheme.quicksand(
                                    color: isOpen
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SLSpacing.h12,
                          if (isOpen)
                            Text(
                              capsule['content'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            )
                          else
                            Text(
                              'Nội dung sẽ mở đúng ngày đã hẹn...',
                              style: SLTheme.quicksand(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic),
                            ),
                          SLSpacing.h12,
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap:
                                  isOpen ? () => _openCapsule(capsule) : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? _buttonFill.withValues(alpha: 0.92)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: SLRadius.mdAll,
                                  border: Border.all(
                                    color: isOpen
                                        ? Colors.white.withValues(alpha: 0.24)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  'MỞ THƯ',
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isOpen ? _textPrimary : Colors.white24,
                                    fontSize: 11,
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
              );
            },
          );
  }
}
