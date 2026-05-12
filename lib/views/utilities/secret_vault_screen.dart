import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/utils/services/pending_upload_service.dart';
import 'package:soullocket_app/utils/services/storage_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'dart:ui' as ui;
import '../../services/activity_history_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/encryption_service.dart';
import '../../services/secret_vault_reset_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import '../home/tabs/settings/security/security_otp_dialogs.dart';

part 'secret_vault/secret_vault_reset_flow.dart';
part 'secret_vault/secret_vault_pending_upload_flow.dart';
part 'secret_vault/secret_vault_display_section.dart';
part 'secret_vault/secret_vault_gallery_section.dart';

class SecretVaultScreen extends StatefulWidget {
  final String houseId;

  const SecretVaultScreen({super.key, required this.houseId});

  @override
  SecretVaultScreenState createState() => SecretVaultScreenState();
}

class SecretVaultScreenState extends State<SecretVaultScreen> {
  static const String _recoveryAction = '__use_recovery_code__';
  static const String _pendingVaultUploadKeyPrefix = 'secret_vault_';
  static const int _initialVisiblePhotoLimit =
      StorageService.secretVaultPageSize;
  static const Duration _vaultPrepareTimeout = Duration(seconds: 15);

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final EncryptionService _enc = EncryptionService();
  final SecretVaultResetService _vaultResetService = SecretVaultResetService();
  final DateFormat _resetTimeFormat = DateFormat('HH:mm • dd/MM/yyyy');
  StreamSubscription<DatabaseEvent>? _photosSub;
  StreamSubscription<bool>? _networkSub;
  StreamSubscription<SecretVaultResetRequestInfo?>? _resetRequestSub;

  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = false;
  bool _isRequestingReset = false;
  bool _isCancelingReset = false;
  bool _encryptionReady = false;
  bool _isPreparingVault = false;
  bool _hasRecoveryCode = false;
  SecretVaultResetRequestInfo? _pendingResetRequest;
  String _encStatusMsg = 'Đang chờ mở khóa kho mật...';
  bool _hasMorePhotos = false;
  bool _isLoadingMorePhotos = false;
  int? _oldestLoadedPhotoTs;
  bool _didPromptPendingVaultUploadRetry = false;

  @override
  void initState() {
    super.initState();
    _listenResetRequest();
    _networkSub = ConnectivityService().isOnlineStream.listen((isOnline) {
      if (!isOnline && mounted) {
        setState(() {
          _encryptionReady = false;
          _encStatusMsg =
              'Không có kết nối mạng.\nKho ảnh mật yêu cầu Internet để xác thực.';
          _photos = [];
          _hasMorePhotos = false;
          _isLoadingMorePhotos = false;
        });
        _enc.clearCache(widget.houseId);
      } else if (isOnline &&
          mounted &&
          !_encryptionReady &&
          !_isPreparingVault) {
        _prepareVault();
      }
    });
    _prepareVault();
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    _photosSub?.cancel();
    _resetRequestSub?.cancel();
    super.dispose();
  }

  bool get _hasPendingReset => _pendingResetRequest?.isPending == true;

  bool get _pendingResetRequestedByCurrentUser {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return myUid.isNotEmpty && _pendingResetRequest?.requestedBy == myUid;
  }

  String get _pendingVaultUploadKey =>
      '$_pendingVaultUploadKeyPrefix${widget.houseId}';

  Future<void> _savePendingVaultUpload({
    required List<String> imagePaths,
    required String encryptedCaption,
  }) {
    return _savePendingVaultUploadRecord(
      pendingKey: _pendingVaultUploadKey,
      imagePaths: imagePaths,
      encryptedCaption: encryptedCaption,
    );
  }

  Future<void> _removePendingVaultUploadedImage(String imagePath) {
    return _removePendingVaultUploadedImageRecord(
      pendingKey: _pendingVaultUploadKey,
      imagePath: imagePath,
    );
  }

  Future<void> _promptPendingVaultUploadRetryIfNeeded() async {
    if (_didPromptPendingVaultUploadRetry || !_encryptionReady || !mounted) {
      return;
    }
    final hasPending =
        await _hasPendingVaultUploadRecord(_pendingVaultUploadKey);
    if (!hasPending || !mounted) {
      return;
    }
    _didPromptPendingVaultUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lần upload Kho bí mật trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingVaultUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingVaultUpload() async {
    final retry = await _loadPendingVaultUploadRetry(_pendingVaultUploadKey);
    if (retry == null || !_encryptionReady || !mounted) {
      return;
    }
    if (retry.images.isEmpty) {
      await _clearPendingVaultUploadRecord(_pendingVaultUploadKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không còn ảnh cũ để thử lại upload Kho bí mật.'),
          ),
        );
      }
      return;
    }
    await _uploadPhoto(
      presetImages: retry.images,
      presetEncryptedCaption: retry.encryptedCaption,
      skipCaptionPrompt: true,
    );
  }

  Future<void> _prepareVault() async {
    if (_isPreparingVault) return;
    if (mounted) {
      setState(() => _isPreparingVault = true);
    } else {
      _isPreparingVault = true;
    }
    if (!ConnectivityService().isOnline) {
      if (mounted) {
        setState(() {
          _encryptionReady = false;
          _encStatusMsg =
              'Không có kết nối mạng.\nKho ảnh mật yêu cầu Internet để xác thực.';
        });
      }
      if (mounted) {
        setState(() => _isPreparingVault = false);
      } else {
        _isPreparingVault = false;
      }
      return;
    }

    try {
      // 1. Thử khôi phục key từ bộ nhớ đệm (nếu app chưa bị đóng và chưa hết timeout)
      final restored = await _enc
          .tryRestoreKeyFromSecureStorage(widget.houseId)
          .timeout(_vaultPrepareTimeout);
      if (restored && mounted) {
        final hasRecoveryCode = await _enc
            .hasRecoveryCode(widget.houseId)
            .timeout(_vaultPrepareTimeout);
        setState(() {
          _encryptionReady = true;
          _encStatusMsg = '🔐 Kho mật đang mở';
          _hasRecoveryCode = hasRecoveryCode;
        });
        _loadPhotos();
        unawaited(_promptPendingVaultUploadRetryIfNeeded());
        return;
      }

      // 2. Chưa có key trong RAM hoặc đã hết hạn → yêu cầu nhập passphrase
      final hasSetup = await _enc
          .hasPassphraseSetup(widget.houseId)
          .timeout(_vaultPrepareTimeout);
      final passphrase = await _showPassphraseDialog(hasSetup: hasSetup);
      if (!mounted) return;
      if (passphrase == null) {
        if (mounted) {
          setState(() {
            _encryptionReady = false;
            _isPreparingVault = false;
            _encStatusMsg = 'Đã hủy mở kho mật.';
          });
        }
        return;
      }

      if (passphrase == _recoveryAction) {
        final recoveryCode = await _showRecoveryCodeInputDialog();
        if (!mounted || recoveryCode == null) return;
        setState(() {
          _encryptionReady = false;
          _encStatusMsg = 'Đang xác thực mã khôi phục...';
        });
        await _enc
            .unlockHouseKeyWithRecoveryCode(widget.houseId, recoveryCode)
            .timeout(_vaultPrepareTimeout);
        if (!mounted) return;
        setState(() {
          _encryptionReady = true;
          _encStatusMsg = '🔐 Kho mật đã mở bằng mã khôi phục';
          _hasRecoveryCode = true;
        });
        _loadPhotos();
        unawaited(_promptPendingVaultUploadRetryIfNeeded());
        return;
      }

      setState(() {
        _encryptionReady = false;
        _encStatusMsg = 'Đang xử lý khóa...';
      });

      await _enc
          .unlockHouseKey(widget.houseId, passphrase)
          .timeout(_vaultPrepareTimeout);
      if (mounted) {
        final recoveryCode = await _enc
            .createRecoveryCodeIfMissing(widget.houseId)
            .timeout(_vaultPrepareTimeout);
        if (!mounted) return;
        setState(() {
          _encryptionReady = true;
          _encStatusMsg = hasSetup
              ? '🔐 Kho mật đã mở thành công'
              : '🔐 Đã thiết lập Kho mật thành công';
          _hasRecoveryCode = true;
        });
        if (recoveryCode != null && mounted) {
          await _showGeneratedRecoveryCodeDialog(
            recoveryCode,
            title: 'Mã khôi phục mới',
            message:
                'Lưu mã này ở nơi an toàn. Máy mới có thể dùng mã này để mở kho mật nếu quên passphrase.',
          );
        }
      }
      _loadPhotos();
      unawaited(_promptPendingVaultUploadRetryIfNeeded());
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _encryptionReady = false;
          _encStatusMsg = 'Thao tác mở kho quá lâu. Vui lòng thử lại.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _encryptionReady = false;
          _encStatusMsg = AppErrorMapper.resolve(e).message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPreparingVault = false);
      } else {
        _isPreparingVault = false;
      }
    }
  }

  void _loadPhotos() {
    _photosSub?.cancel();
    final query = _dbRef
        .child('houses/${widget.houseId}/private_secure')
        .orderByChild('ts')
        .limitToLast(_initialVisiblePhotoLimit);
    _photosSub = query.onValue.listen(
      (event) async {
        final raw = event.snapshot.value;
        if (raw is Map) {
          final data = Map<dynamic, dynamic>.from(raw);
          bool needsLegacyMigrationLocal = false;
          final loaded = await Future.wait(
            data.entries.map((entry) async {
              final value = entry.value;
              if (value is! Map) {
                return <String, dynamic>{'id': entry.key};
              }
              final item = Map<String, dynamic>.from(value);
              item['id'] = entry.key;

              if (item['caption'] != null &&
                  item['caption'].toString().isNotEmpty) {
                try {
                  final decrypted = await _enc.decryptMessage(
                    widget.houseId,
                    item['caption'].toString(),
                  );
                  item['caption_plain'] = decrypted;
                  if (decrypted == '[Cần nhập mật khẩu để xem nội dung cũ]') {
                    needsLegacyMigrationLocal = true;
                  }
                } catch (_) {
                  item['caption_plain'] = item['caption'];
                }
              }

              return item;
            }),
          );

          if (needsLegacyMigrationLocal && mounted) {
            setState(() => _encStatusMsg =
                'Có nội dung cũ cần chuyển đổi. Vui lòng thử khóa bằng mật khẩu Web.');
          }

          loaded.sort(
              (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));
          if (mounted) {
            final oldestTs =
                loaded.isEmpty ? null : (loaded.last['ts'] as num?)?.toInt();
            setState(() {
              _photos = loaded;
              _oldestLoadedPhotoTs = oldestTs;
              _hasMorePhotos = loaded.length >= _initialVisiblePhotoLimit;
              _isLoadingMorePhotos = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _photos = [];
              _oldestLoadedPhotoTs = null;
              _hasMorePhotos = false;
              _isLoadingMorePhotos = false;
            });
          }
        }
      },
      onError: (Object error) {
        debugPrint(
          'Secret vault listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể tải kho mật.',
          ).message}',
        );
        if (!mounted) {
          return;
        }
        setState(() => _isLoadingMorePhotos = false);
      },
    );
  }

  void _loadMorePhotos() async {
    if (_isLoadingMorePhotos || !_hasMorePhotos) {
      return;
    }
    setState(() {
      _isLoadingMorePhotos = true;
    });
    final oldestTs = _oldestLoadedPhotoTs;
    if (oldestTs == null) {
      if (mounted) {
        setState(() => _isLoadingMorePhotos = false);
      }
      return;
    }
    try {
      final snapshot = await _dbRef
          .child('houses/${widget.houseId}/private_secure')
          .orderByChild('ts')
          .endAt(oldestTs - 1)
          .limitToLast(StorageService.secretVaultPageSize)
          .get();
      if (!snapshot.exists || snapshot.value == null) {
        if (mounted) {
          setState(() {
            _hasMorePhotos = false;
            _isLoadingMorePhotos = false;
          });
        }
        return;
      }

      final raw = snapshot.value;
      if (raw is! Map) {
        if (mounted) {
          setState(() {
            _hasMorePhotos = false;
            _isLoadingMorePhotos = false;
          });
        }
        return;
      }

      final data = Map<dynamic, dynamic>.from(raw);
      bool needsLegacyMigrationLocal = false;
      final loadedMore = await Future.wait(
        data.entries.map((entry) async {
          final value = entry.value;
          if (value is! Map) {
            return <String, dynamic>{'id': entry.key};
          }
          final item = Map<String, dynamic>.from(value);
          item['id'] = entry.key;
          if (item['caption'] != null &&
              item['caption'].toString().isNotEmpty) {
            try {
              final decrypted = await _enc.decryptMessage(
                widget.houseId,
                item['caption'].toString(),
              );
              item['caption_plain'] = decrypted;
              if (decrypted == '[Cần nhập mật khẩu để xem nội dung cũ]') {
                needsLegacyMigrationLocal = true;
              }
            } catch (_) {
              item['caption_plain'] = item['caption'];
            }
          }
          return item;
        }),
      );
      loadedMore.sort(
        (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0),
      );
      if (!mounted) {
        return;
      }
      if (needsLegacyMigrationLocal) {
        _encStatusMsg =
            'Có nội dung cũ cần chuyển đổi. Vui lòng thử khóa bằng mật khẩu Web.';
      }
      final existingIds = _photos.map((item) => item['id']).toSet();
      final mergedMore = loadedMore
          .where((item) => !existingIds.contains(item['id']))
          .toList(growable: false);
      final nextPhotos = <Map<String, dynamic>>[
        ..._photos,
        ...mergedMore,
      ];
      final nextOldestTs =
          nextPhotos.isEmpty ? null : (nextPhotos.last['ts'] as num?)?.toInt();
      setState(() {
        _photos = nextPhotos;
        _oldestLoadedPhotoTs = nextOldestTs;
        _hasMorePhotos =
            loadedMore.length >= StorageService.secretVaultPageSize;
        _isLoadingMorePhotos = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMorePhotos = false);
      }
    }
  }

  Future<void> _uploadPhoto({
    List<XFile>? presetImages,
    String? presetEncryptedCaption,
    bool skipCaptionPrompt = false,
  }) async {
    if (!_encryptionReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng mở khóa kho mật trước.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toLocal().toString().substring(0, 10);
    final todayKey = 'secret_vault_up_$today';
    final uploadedToday = prefs.getInt(todayKey) ?? 0;

    final vipAccess = await PurchaseService().getVipAccessInfo();
    final isPro = vipAccess.isVip;

    final dailyLimit = isPro
        ? StorageService.secretVaultDailyLimitVip
        : StorageService.secretVaultDailyLimitFree;
    const enforceLocalDailyLimit = true;

    if (enforceLocalDailyLimit && uploadedToday >= dailyLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isPro
              ? 'Đã đạt giới hạn $dailyLimit ảnh/ngày của gói PRO.'
              : 'Đã đạt giới hạn $dailyLimit ảnh/ngày. Nâng cấp PRO để đăng nhiều hơn!'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    final remainingDailySlots = dailyLimit - uploadedToday;
    final pickLimit = StorageService.clampImagePickLimit(
      remainingDailySlots,
      maxAllowed: StorageService.maxSecretVaultSelectionPerBatch,
    );
    if (pickLimit <= 0) {
      return;
    }
    final images =
        presetImages ?? await _storageService.pickImages(limit: pickLimit);
    if (images.isEmpty) return;

    if ((uploadedToday >= dailyLimit ||
            uploadedToday + images.length > dailyLimit) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Bạn đã chạm mốc $uploadedToday/$dailyLimit ảnh hôm nay. Hệ thống sẽ kiểm tra lại trước khi cho tải thêm.',
        ),
        backgroundColor: Colors.orange,
      ));
    }

    if (enforceLocalDailyLimit && uploadedToday + images.length > dailyLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Chỉ còn lại ${dailyLimit - uploadedToday} lượt đăng hôm nay. Bạn đã chọn ${images.length} ảnh.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    const skipDialogKey = 'secret_vault_skip_dialog_until';
    final skipUntil = prefs.getInt(skipDialogKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool askForNote = !skipCaptionPrompt && presetImages == null;

    if (askForNote && nowMs < skipUntil) {
      askForNote = false;
    }

    String captionPlain = '';
    if (askForNote && mounted) {
      final captionCtrl = TextEditingController();
      bool dontAskAgain = false;

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFF1F1C2C),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Thêm ghi chú (tùy chọn)',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: captionCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Mô tả khoảnh khắc này...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: dontAskAgain,
                        onChanged: (v) {
                          setLocalState(() => dontAskAgain = v ?? false);
                        },
                        checkColor: Colors.white,
                        activeColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setLocalState(() => dontAskAgain = !dontAskAgain);
                        },
                        child: Text(
                          'Không hỏi lại trong 2 giờ',
                          style: SLTheme.quicksand(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    if (dontAskAgain) {
                      prefs.setInt(
                          skipDialogKey,
                          DateTime.now().millisecondsSinceEpoch +
                              2 * 60 * 60 * 1000);
                    }
                    Navigator.pop(ctx, '');
                  },
                  child: Text('BỎ QUA',
                      style: SLTheme.quicksand(color: Colors.white38))),
              TextButton(
                  onPressed: () {
                    if (dontAskAgain) {
                      prefs.setInt(
                          skipDialogKey,
                          DateTime.now().millisecondsSinceEpoch +
                              2 * 60 * 60 * 1000);
                    }
                    Navigator.pop(ctx, captionCtrl.text.trim());
                  },
                  child: Text('THÊM',
                      style: SLTheme.quicksand(color: Colors.redAccent))),
            ],
          ),
        ),
      );
      if (result == null) return;
      captionPlain = result;
    }

    setState(() => _isLoading = true);

    try {
      String encryptedCaption = presetEncryptedCaption?.trim() ?? '';
      if (encryptedCaption.isEmpty && captionPlain.isNotEmpty) {
        encryptedCaption =
            await _enc.encryptMessage(widget.houseId, captionPlain);
      }
      await _savePendingVaultUpload(
        imagePaths: images.map((image) => image.path).toList(growable: false),
        encryptedCaption: encryptedCaption,
      );

      int successCount = 0;
      for (final image in images) {
        final upload =
            await _storageService.uploadSecretVaultImage(widget.houseId, image);
        final url = upload?.downloadUrl ?? '';

        if (url.isNotEmpty) {
          await _dbRef
              .child('houses/${widget.houseId}/private_secure')
              .push()
              .set({
            'url': url,
            'storagePath': upload?.storagePath,
            'ts': ServerValue.timestamp,
            'caption': encryptedCaption,
            'encrypted': true,
            'encryptionVersion': 2,
          });
          successCount++;
          await _removePendingVaultUploadedImage(image.path);
        }
      }

      await prefs.setInt(todayKey, uploadedToday + successCount);

      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã thêm $successCount ảnh vào kho mật! 🔐'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final id = photo['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }

    await ActivityHistoryService.instance.add(
      'đã xóa một ảnh riêng tư',
      houseId: widget.houseId,
      title: 'Đã xóa ảnh riêng tư',
      subtitle: photo['caption']?.toString() ?? '',
      action: 'delete',
      module: 'secret_vault',
      entityType: 'secret_photo',
      entityId: id,
      sourceLabel: 'Kho bí mật',
      previewUrl: photo['url']?.toString() ?? '',
      previewType: 'image',
      restorePath: 'houses/${widget.houseId}/private_secure/$id',
      restorePayload: Map<String, dynamic>.from(photo)..remove('id'),
    );

    final storagePath = photo['storagePath']?.toString() ?? '';
    final url = photo['url']?.toString() ?? '';

    if (storagePath.isNotEmpty) {
      await _storageService.deleteFileByPath(storagePath);
    } else if (url.isNotEmpty) {
      await _storageService.deleteImageByUrl(url);
    }

    await _dbRef.child('houses/${widget.houseId}/private_secure/$id').remove();
  }

  Future<String?> _showPassphraseDialog({required bool hasSetup}) async {
    final passphraseCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscurePass = true;
    var obscureConfirm = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF1F1C2C),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            hasSetup ? 'Mở khóa kho mật' : 'Thiết lập kho mật',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasSetup
                      ? 'Nhập mật khẩu kho mật hoặc mật khẩu nhà đã đặt trước đó để mở khóa.'
                      : 'Tạo mật khẩu kho mật. Khóa chỉ được tạo trên thiết bị và không lưu dạng rõ trên hệ thống.',
                  style: SLTheme.quicksand(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseCtrl,
                  obscureText: obscurePass,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu tối thiểu 8 ký tự',
                    hintStyle: const TextStyle(color: Colors.white38),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setLocalState(() => obscurePass = !obscurePass),
                      icon: Icon(
                        obscurePass ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white54,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                if (!hasSetup) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập lại mật khẩu',
                      hintStyle: const TextStyle(color: Colors.white38),
                      suffixIcon: IconButton(
                        onPressed: () => setLocalState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white54,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (hasSetup)
              TextButton(
                onPressed: () => Navigator.pop(ctx, _recoveryAction),
                child: Text(
                  'Dùng mã khôi phục',
                  style: SLTheme.quicksand(color: Colors.blueAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'ĐÓNG',
                style: SLTheme.quicksand(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: () {
                final passphrase = passphraseCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (passphrase.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu kho mật phải từ 8 ký tự.'),
                    ),
                  );
                  return;
                }
                if (!hasSetup && passphrase != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu nhập lại chưa khớp.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, passphrase);
              },
              child: Text(
                hasSetup ? 'MỞ KHÓA' : 'THIẾT LẬP',
                style: SLTheme.quicksand(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showRecoveryCodeInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nhập mã khôi phục',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'VD: ABCD-EFGH-JKLM-NPQR',
            hintStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Đóng',
              style: SLTheme.quicksand(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Mở kho',
              style: SLTheme.quicksand(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGeneratedRecoveryCodeDialog(
    String recoveryCode, {
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: SLTheme.quicksand(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: SelectableText(
                recoveryCode,
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recoveryCode));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép mã khôi phục.')),
              );
            },
            child: Text(
              'Sao chép',
              style: SLTheme.quicksand(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tôi đã lưu',
              style: SLTheme.quicksand(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegenerateRecoveryCode() async {
    Navigator.of(context).pop();
    try {
      final recoveryCode = await _enc.regenerateRecoveryCode(widget.houseId);
      if (!mounted) return;
      setState(() => _hasRecoveryCode = true);
      await _showGeneratedRecoveryCodeDialog(
        recoveryCode,
        title: 'Mã khôi phục đã đổi',
        message: 'Mã cũ sẽ hết hiệu lực. Hãy lưu mã mới này trước khi thoát.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.resolve(
              e,
              fallbackMessage:
                  'Chưa thể tạo lại mã khôi phục lúc này. Hãy thử lại sau ít phút.',
            ).message,
          ),
        ),
      );
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                _hasPendingReset
                    ? Icons.undo_rounded
                    : Icons.delete_forever_rounded,
                color:
                    _hasPendingReset ? Colors.orangeAccent : Colors.redAccent,
              ),
              title: Text(
                _hasPendingReset
                    ? 'Thu hồi yêu cầu reset'
                    : 'Reset Kho ảnh mật',
                style: SLTheme.quicksand(color: Colors.white),
              ),
              subtitle: Text(
                _hasPendingReset
                    ? 'Kho sẽ bị xoá lúc ${_formatResetSchedule(_pendingResetRequest?.scheduledAt ?? 0)} nếu không thu hồi.'
                    : 'Xác nhận qua email chính, chờ 24 giờ rồi xoá toàn bộ dữ liệu Kho ảnh mật.',
                style: SLTheme.quicksand(color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (_hasPendingReset) {
                  _cancelVaultResetRequest();
                } else {
                  _startVaultResetRequestFlow();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.white),
              title: Text('Đổi mật khẩu',
                  style: SLTheme.quicksand(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showChangePasswordDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded, color: Colors.lightBlue),
              title: Text(
                _hasRecoveryCode ? 'Tạo lại mã khôi phục' : 'Tạo mã khôi phục',
                style: SLTheme.quicksand(color: Colors.white),
              ),
              subtitle: Text(
                _hasRecoveryCode
                    ? 'Máy mới có thể dùng mã này để mở kho mật.'
                    : 'Nên tạo để tránh mất quyền mở vault khi đổi máy.',
                style: SLTheme.quicksand(color: Colors.white54),
              ),
              onTap: _handleRegenerateRecoveryCode,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: Text('Khóa lại kho mật',
                  style: SLTheme.quicksand(color: Colors.orange)),
              onTap: () {
                Navigator.pop(ctx);
                _enc.clearCache(widget.houseId);
                setState(() {
                  _encryptionReady = false;
                  _encStatusMsg = 'Đã khóa kho mật';
                  _photos = []; // Xóa ảnh trên UI
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscureOld = true;
    var obscureNew = true;

    final createdAt = await _enc.getPassphraseSetupTime(widget.houseId);
    final now = DateTime.now().millisecondsSinceEpoch;
    // 12 giờ thay vì 3 ngày
    final isWithin12Hours =
        createdAt != null && (now - createdAt) < 12 * 60 * 60 * 1000;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF1F1C2C),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Đổi mật khẩu',
              style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: oldPassCtrl,
                  obscureText: obscureOld,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu cũ',
                    labelStyle: const TextStyle(color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureOld ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54),
                      onPressed: () =>
                          setLocalState(() => obscureOld = !obscureOld),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    labelStyle: const TextStyle(color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureNew ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54),
                      onPressed: () =>
                          setLocalState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (isWithin12Hours) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showVaultResetInfoDialog(isWithin12Hours);
                      },
                      child: Text('Tôi đã quên mật khẩu?',
                          style: SLTheme.quicksand(
                              color: Colors.blueAccent,
                              decoration: TextDecoration.underline)),
                    ),
                  ),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Hủy', style: SLTheme.quicksand(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () async {
                final oldPass = oldPassCtrl.text.trim();
                final newPass = newPassCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();

                if (oldPass.isEmpty || newPass.isEmpty) return;
                if (newPass.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Mật khẩu mới phải từ 8 ký tự.')));
                  return;
                }
                if (newPass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mật khẩu mới chưa khớp.')));
                  return;
                }

                setState(() {
                  _encryptionReady = false;
                  _encStatusMsg = 'Đang đổi mật khẩu và mã hóa lại dữ liệu...';
                });
                Navigator.pop(ctx);

                try {
                  await _enc.changePassphrase(widget.houseId, oldPass, newPass);
                  final recoveryCode =
                      await _enc.createRecoveryCodeIfMissing(widget.houseId);
                  if (mounted) {
                    setState(() {
                      _encryptionReady = true;
                      _encStatusMsg = 'Đã đổi mật khẩu thành công';
                      _hasRecoveryCode = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã đổi mật khẩu thành công!'),
                        backgroundColor: Colors.green));
                    if (recoveryCode != null) {
                      await _showGeneratedRecoveryCodeDialog(
                        recoveryCode,
                        title: 'Mã khôi phục mới',
                        message:
                            'Mật khẩu đã đổi nên mã khôi phục cũ không còn dùng được. Hãy lưu mã mới này.',
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _encryptionReady = true;
                      _encStatusMsg = '🔐 Kho mật đã mở';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Mật khẩu cũ chưa đúng. Bạn kiểm tra lại rồi thử lại nhé.'),
                        backgroundColor: Colors.redAccent));
                  }
                }
              },
              child: Text('ĐỔI MẬT KHẨU',
                  style: SLTheme.quicksand(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  void _showVaultResetInfoDialog(bool isWithin12Hours) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _hasPendingReset ? 'Yêu cầu reset đang chờ' : 'Reset Kho ảnh mật',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: _hasPendingReset ? Colors.orangeAccent : Colors.redAccent,
          ),
        ),
        content: Text(
          _hasPendingReset
              ? 'Kho ảnh mật đã được lên lịch xóa vào ${_formatResetSchedule(_pendingResetRequest?.scheduledAt ?? 0)}. '
                  'Trong thời gian chờ, cả hai người trong nhà đều có thể thu hồi yêu cầu này để giữ lại dữ liệu.'
              : 'Reset Kho ảnh mật sẽ xóa toàn bộ ảnh, ghi chú mã hóa và khóa hiện tại sau 24 giờ. '
                  'Bạn phải xác nhận bằng OTP gửi về email chính.'
                  '${isWithin12Hours ? '\n\nDù bạn vừa đổi mật khẩu gần đây, hệ thống vẫn áp dụng thời gian chờ đủ 1 ngày trước khi xoá dữ liệu.' : ''}',
          style: SLTheme.quicksand(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Huỷ',
              style: SLTheme.quicksand(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_hasPendingReset) {
                _cancelVaultResetRequest();
              } else {
                _startVaultResetRequestFlow();
              }
            },
            child: Text(
              _hasPendingReset ? 'Thu hồi yêu cầu' : 'Xác nhận qua email',
              style: SLTheme.quicksand(
                color:
                    _hasPendingReset ? Colors.orangeAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showForgotPassphraseDialog(bool isWithin12Hours) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Khôi phục kho mật',
            style: SLTheme.quicksand(
                fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(
            isWithin12Hours
                ? 'Vì bạn thiết lập mật khẩu trong vòng 12 giờ qua, bạn có thể tạo mật khẩu mới mà không bị mất ảnh hiện tại.'
                : 'Vì kho này dùng mã hóa đầu cuối, nếu bạn quên mật khẩu thì toàn bộ ảnh bí mật cũ sẽ bị xóa vĩnh viễn và không thể khôi phục.\n\nBạn có chắc chắn muốn xóa kho mật cũ để tạo lại mật khẩu mới không?',
            style: SLTheme.quicksand(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Hủy', style: SLTheme.quicksand(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _encryptionReady = false;
                _encStatusMsg = 'Đang xử lý khôi phục...';
              });
              try {
                if (isWithin12Hours) {
                  await _enc.resetVaultKeepData(widget.houseId);
                  if (mounted) {
                    setState(() {
                      _encStatusMsg =
                          'Kho mật đã được reset (giữ nguyên dữ liệu).';
                      _hasRecoveryCode = false;
                      // Không clear _photos, giữ nguyên dữ liệu trên UI
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Đã reset mật khẩu. Hãy thiết lập mật khẩu mới.'),
                        backgroundColor: Colors.green));
                  }
                } else {
                  await _enc.resetVault(widget.houseId);
                  if (mounted) {
                    setState(() {
                      _encStatusMsg = 'Kho mật đã được reset (đã xóa dữ liệu).';
                      _photos = [];
                      _hasRecoveryCode = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã xóa kho mật cũ. Hãy thiết lập lại.'),
                        backgroundColor: Colors.orange));
                  }
                }
                if (mounted) {
                  _prepareVault(); // Mở lại dialog thiết lập
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _encStatusMsg = 'Lỗi xử lý kho mật';
                  });
                }
              }
            },
            child: Text(isWithin12Hours ? 'Tiếp tục' : 'Xóa và tạo lại',
                style: SLTheme.quicksand(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'KHO ẢNH BÍ MẬT',
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
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_encryptionReady)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => _showSettingsModal(),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2B1B3D), Color(0xFF12121A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildEncryptionBadge(),
              _buildPendingResetBanner(),
              _buildUploadHeader(),
              Expanded(child: _buildPhotoGrid()),
            ],
          ),
        ),
      ),
    );
  }
}
